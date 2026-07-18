#!/usr/bin/env python3
"""SceneLex 渲染层编排 — 场景规格 → 可播放教学资源。

当前实现: plan (渲染计划编译) / show (展开提示词预览) / list。
render (图像/TTS 适配器) 与 assemble (playback 组装) 在适配器就绪后接入;
ComfyUI 工作流由用户提供后配置。

设计约束:
- 版本目录 data/drafts/renders/{scene_id}/v{NN}/ 永不覆盖, 重渲即新版本;
- 内容/风格分离: 计划 prompt 只写内容, 渲染时追加 prompts/render-style.yaml;
- 一致性靠卡片: 外观集中在 characters/setting, beat prompt 用 {char:id} 与
  {setting} 占位符引用, 展开时机械替换, 保证跨 beat 文字级一致;
- 模型名只进 manifest (追溯层), 不进场景规格。

用法:
    python3 tools/render.py plan reluctant-01-proto-01   # 编译渲染计划 → 新版本目录
    python3 tools/render.py show reluctant-01-proto-01   # 预览展开后的最终提示词
    python3 tools/render.py list                         # 渲染版本一览
"""

import argparse
import re
import sys

import yaml

import draft
import llm

SCENE_ID = re.compile(
    r"^([a-z][a-z_]*-\d{2})-(proto|contrast|counter|boundary|transfer)-\d{2}$"
)
PLACEHOLDER = re.compile(r"\{(char:[a-z][a-z0-9_-]*|setting)\}")


def renders_dir():
    return draft.DRAFTS / "renders"


def locate(scene_id):
    """定位场景与词义规格文件, 返回 (scene_path, sense_path, sense_id)。"""
    m = SCENE_ID.fullmatch(scene_id)
    if not m:
        sys.exit(f"场景 ID '{scene_id}' 不符合 {{sense_id}}-{{type}}-{{nn}} 约定")
    sense_id = m.group(1)
    for base in (draft.ROOT / "data" / "scenes" / sense_id,
                 draft.DRAFTS / "scenes" / sense_id):
        p = base / f"{scene_id}.yaml"
        if p.exists():
            scene_path = p
            break
    else:
        sys.exit(f"找不到场景 '{scene_id}' (正式库与草稿库均无)")
    sense_path = draft.resolve_sense_path(sense_id)
    if not sense_path:
        sys.exit(f"找不到义项 '{sense_id}'")
    return scene_path, sense_path, sense_id


def next_version(scene_id):
    base = renders_dir() / scene_id
    taken = [int(p.name[1:]) for p in base.glob("v[0-9][0-9]") if p.is_dir()] \
        if base.exists() else []
    return max(taken, default=0) + 1


def load_style():
    path = draft.PROMPTS / "render-style.yaml"
    if not path.exists():
        return "", ""
    doc = yaml.safe_load(draft.read(path)) or {}
    return doc.get("positive", ""), doc.get("negative", "")


def expand_prompt(text, characters, setting_desc):
    """把 {char:id} / {setting} 占位符机械替换为卡片描述 (一致性保证)。"""
    def sub(match):
        key = match.group(1)
        if key == "setting":
            return setting_desc
        return characters[key[len("char:"):]]
    return PLACEHOLDER.sub(sub, text)


def normalize_plan(plan):
    """容错归一化: 模型习惯给可选字段写 null, 一律删掉而不是校验失败。"""
    for b in plan.get("beats", []):
        if not isinstance(b, dict):
            continue
        if b.get("negative") is None:
            b["negative"] = ""
        audio = b.get("audio")
        if isinstance(audio, dict):
            for key in [k for k, v in audio.items() if v is None]:
                del audio[key]
    return plan


def plan_issues(plan, scene_doc):
    """schema 之外的引用一致性检查。"""
    issues = []
    chars = {c["id"] for c in plan.get("characters", [])}
    spec_beats = [b.get("beat") for b in scene_doc.get("storyboard", [])]
    plan_beats = [b.get("beat") for b in plan.get("beats", [])]
    if spec_beats and plan_beats != spec_beats:
        issues.append(f"beat 序列与场景规格不一致: 计划 {plan_beats} vs 规格 {spec_beats}")
    for b in plan.get("beats", []):
        text = f"{b.get('prompt', '')} {b.get('negative', '')}"
        for match in PLACEHOLDER.finditer(text):
            key = match.group(1)
            if key != "setting" and key[len("char:"):] not in chars:
                issues.append(f"beat {b.get('beat')} 引用未定义角色 {{{key}}}")
        leftover = re.findall(r"\{[^}]*\}", PLACEHOLDER.sub("", text))
        if leftover:
            issues.append(f"beat {b.get('beat')} 含无法解析的占位符 {leftover}")
    return issues


# ---------------------------------------------------------------- plan

def cmd_plan(args):
    scene_id = args.scene_id.strip()
    scene_path, sense_path, _ = locate(scene_id)
    scene_doc = yaml.safe_load(draft.read(scene_path))

    prompt = (draft.read(draft.PROMPTS / "render-plan.md")
              .replace("{{SCHEMA}}",
                       draft.read(draft.ROOT / "schema" / "render-plan.schema.json"))
              .replace("{{SCENE}}", draft.read(scene_path))
              .replace("{{SENSE}}", draft.read(sense_path))
              .replace("{{SCENE_ID}}", scene_id))

    print(f"→ 编译 '{scene_id}' 渲染计划 ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = draft.extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")
    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as e:
        dump = renders_dir() / scene_id / "_unparsed-plan.txt"
        dump.parent.mkdir(parents=True, exist_ok=True)
        dump.write_text(blocks[0], encoding="utf-8")
        sys.exit(f"YAML 解析失败, 原文已存 {dump.relative_to(draft.ROOT)}:\n{e}")
    if not isinstance(doc, dict):
        sys.exit("渲染计划的 YAML 根节点必须是对象")

    normalize_plan(doc)
    # 路径与版本字段由工具决定, 模型输出不得控制 (同 draft.py 纪律)
    n = next_version(scene_id)
    doc["scene_ref"] = scene_id
    doc["spec_version"] = int(scene_doc.get("version", 1))
    doc["version"] = n
    doc["status"] = "draft"
    doc.setdefault("schema_version", "1.0")

    out_dir = renders_dir() / scene_id / f"v{n:02d}"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "render-plan.yaml"
    out.write_text(
        yaml.safe_dump(doc, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    print(f"✓ 渲染计划已写入 {out.relative_to(draft.ROOT)}")

    errs = draft.schema_check(doc, draft.load_schema("render-plan.schema.json"),
                              out.name)
    errs += [f"  ✗ {out.name} {msg}" for msg in plan_issues(doc, scene_doc)]
    if errs:
        print(f"\n⚠ {len(errs)} 处问题, 渲染前需修复:", file=sys.stderr)
        for e in errs:
            print(e, file=sys.stderr)
        sys.exit(1)
    print(f"✓ 计划校验通过。预览: python3 tools/render.py show {scene_id}")


# ---------------------------------------------------------------- show

def _load_plan(scene_id, version=None):
    n = version or (next_version(scene_id) - 1)
    if n < 1:
        sys.exit(f"'{scene_id}' 还没有渲染计划; 先运行 render.py plan {scene_id}")
    path = renders_dir() / scene_id / f"v{n:02d}" / "render-plan.yaml"
    if not path.exists():
        sys.exit(f"版本 v{n:02d} 没有 render-plan.yaml")
    return yaml.safe_load(draft.read(path)), n


def cmd_show(args):
    scene_id = args.scene_id.strip()
    plan, n = _load_plan(scene_id, args.version)
    style_pos, style_neg = load_style()
    chars = {c["id"]: c["description"] for c in plan.get("characters", [])}
    setting = plan.get("setting", {}).get("description", "")

    print(f"=== {scene_id} v{n:02d} (spec v{plan.get('spec_version')}) ===")
    for b in plan.get("beats", []):
        print(f"\n--- beat {b['beat']}  ({b.get('duration')}s) ---")
        prompt = expand_prompt(b["prompt"], chars, setting)
        print(f"prompt   | {prompt}" + (f", {style_pos}" if style_pos else ""))
        negative = ", ".join(x for x in (b.get("negative"), style_neg) if x)
        print(f"negative | {negative}")
        audio = b.get("audio", {})
        marker = "  [目标词]" if audio.get("contains_target_word") else ""
        if audio.get("type") == "tts":
            print(f"audio    | TTS ({audio.get('voice_hint', '?')}):"
                  f" {audio.get('text')}{marker}")
        elif audio.get("type") == "sfx":
            print(f"audio    | SFX: {audio.get('text')}")
        else:
            print("audio    | (静默)")


# ---------------------------------------------------------------- list

def cmd_list(args):
    base = renders_dir()
    if not base.exists() or not any(base.iterdir()):
        print("尚无渲染计划。")
        return
    for scene_dir in sorted(base.iterdir()):
        if not scene_dir.is_dir():
            continue
        versions = sorted(p.name for p in scene_dir.glob("v[0-9][0-9]"))
        for v in versions:
            vdir = scene_dir / v
            has_plan = (vdir / "render-plan.yaml").exists()
            has_manifest = (vdir / "render-manifest.yaml").exists()
            stage = "已渲染" if has_manifest else ("计划就绪" if has_plan else "空")
            print(f"  {scene_dir.name} {v}: {stage}")


# ---------------------------------------------------------------- render

def _init_manifest(plan, scene_id, n, image_info):
    m = SCENE_ID.fullmatch(scene_id)
    return {
        "schema_version": "1.0",
        "scene_ref": scene_id,
        "sense_ref": m.group(1),
        "spec_version": plan.get("spec_version", 1),
        "plan_version": n,
        "version": n,
        "status": "candidate",
        "created_at": __import__("time").strftime(
            "%Y-%m-%dT%H:%M:%SZ", __import__("time").gmtime()),
        "renderer": {"image": {
            "protocol": "comfyui",
            "model": image_info.get("model", "unknown"),
            "workflow": image_info.get("workflow", "unknown"),
        }},
        "license": "",
        "beats": [{"beat": b["beat"], "images": [],
                   "audio": {"type": b.get("audio", {}).get("type", "silence")}}
                  for b in plan.get("beats", [])],
    }


def cmd_render(args):
    import time as _time
    import imagegen

    scene_id = args.scene_id.strip()
    plan, n = _load_plan(scene_id, args.version)
    style_pos, style_neg = load_style()
    chars = {c["id"]: c["description"] for c in plan.get("characters", [])}
    setting = plan.get("setting", {}).get("description", "")
    vdir = renders_dir() / scene_id / f"v{n:02d}"
    manifest_path = vdir / "render-manifest.yaml"
    manifest = yaml.safe_load(draft.read(manifest_path)) \
        if manifest_path.exists() else None

    beats = plan.get("beats", [])
    if args.beat:
        beats = [b for b in beats if b["beat"] == args.beat]
        if not beats:
            sys.exit(f"计划中没有 beat {args.beat}")

    total = len(beats) * args.count
    done = 0
    for b in beats:
        positive = expand_prompt(b["prompt"], chars, setting)
        if style_pos:
            positive = f"{positive}, {style_pos}"
        negative = ", ".join(x for x in (b.get("negative"), style_neg) if x)
        for _ in range(args.count):
            m_beat = None
            if manifest:
                m_beat = next((x for x in manifest["beats"]
                               if x["beat"] == b["beat"]), None)
            taken = len(m_beat["images"]) if m_beat else 0
            # 候选文件按字母递增, 永不覆盖
            while True:
                fname = f"beat-{b['beat']:02d}-{chr(ord('a') + taken)}.png"
                if not (vdir / fname).exists():
                    break
                taken += 1
            done += 1
            print(f"→ [{done}/{total}] beat {b['beat']} → {fname} ...",
                  file=sys.stderr)
            t0 = _time.monotonic()
            data, info = imagegen.generate(positive, negative)
            (vdir / fname).write_bytes(data)
            print(f"  ✓ {len(data) // 1024} KB, {_time.monotonic() - t0:.0f}s",
                  file=sys.stderr)
            if manifest is None:
                manifest = _init_manifest(plan, scene_id, n, info)
                manifest["license"] = imagegen.license_note()
                m_beat = next(x for x in manifest["beats"]
                              if x["beat"] == b["beat"])
            elif m_beat is None:
                m_beat = {"beat": b["beat"], "images": [],
                          "audio": {"type": b.get("audio", {}).get("type",
                                                                   "silence")}}
                manifest["beats"].append(m_beat)
            m_beat["images"].append({"file": fname, "seed": info["seed"],
                                     "selected": False})
            manifest_path.write_text(
                yaml.safe_dump(manifest, allow_unicode=True, sort_keys=False),
                encoding="utf-8",
            )

    errs = draft.schema_check(manifest,
                              draft.load_schema("render-manifest.schema.json"),
                              manifest_path.name)
    if errs:
        print("\n⚠ manifest 校验问题:", file=sys.stderr)
        for e in errs:
            print(e, file=sys.stderr)
        sys.exit(1)
    print(f"✓ 渲染完成, 清单: {manifest_path.relative_to(draft.ROOT)}")


def main():
    parser = argparse.ArgumentParser(description="SceneLex 渲染层编排")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("plan", help="把场景规格编译为渲染计划 (新版本目录)")
    p.add_argument("scene_id")
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("show", help="预览展开后的最终提示词与音频指令")
    p.add_argument("scene_id")
    p.add_argument("--version", "-v", type=int, help="计划版本 (默认最新)")
    p.set_defaults(func=cmd_show)

    sub.add_parser("list", help="渲染版本一览").set_defaults(func=cmd_list)

    p = sub.add_parser("render", help="按最新计划渲染图像候选 (ComfyUI)")
    p.add_argument("scene_id")
    p.add_argument("--version", "-v", type=int, help="计划版本 (默认最新)")
    p.add_argument("--beat", "-b", type=int, help="只渲染指定 beat (重渲/补渲)")
    p.add_argument("--count", "-n", type=int, default=1,
                   help="每 beat 候选张数 (默认 1)")
    p.set_defaults(func=cmd_render)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
