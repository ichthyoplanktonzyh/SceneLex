#!/usr/bin/env python3
"""SceneLex Director — 把语义节拍编译成可执行的 Shot Plan。

    WordSense + SceneSpec → Shot Plan

Shot Plan 是 Scene 之后唯一的叙事执行权威: 它决定镜头如何拆分、顺序、画面状态
变化、构图、摄影机行为、时长、语义证据与连续性。后续的 Keyframe / Animatic /
视频模型只执行 Shot Plan, 不再自行重新拆分 Scene。

Shot Plan 保持风格中立与模型中立: 不写视觉风格、不写供应商或 checkpoint、不写
最终提示词、不写 workflow / seed / sampler。那些属于 Style Bible 与渲染适配层。

用法:
    python3 tools/director.py plan reluctant-01-proto-01
    python3 tools/director.py show reluctant-01-proto-01
    python3 tools/director.py list
    python3 tools/director.py show-legacy reluctant-01-proto-01  # 旧 Director Prompt
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

import draft
import llm
import revisions
import shot_plan as shot_plan_lib


SCENE_ID = re.compile(
    r"^([a-z][a-z_]*-\d{2})-(proto|contrast|counter|boundary|transfer)-\d{2}$"
)
PROFILE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
DEFAULT_PROFILE = "generic-video"

PLAN_FILE = "shot-plan.yaml"


def shot_plans_dir() -> Path:
    return draft.DRAFTS / "shot-plans"


def director_dir() -> Path:
    """旧 Director Prompt 目录 (legacy 原型, 只读)。"""
    return draft.DRAFTS / "director"


def locate(scene_id: str) -> tuple[Path, Path]:
    match = SCENE_ID.fullmatch(scene_id)
    if not match:
        sys.exit(f"场景 ID '{scene_id}' 不符合约定")
    sense_id = match.group(1)
    for base in (
        draft.ROOT / "data" / "scenes" / sense_id,
        draft.DRAFTS / "scenes" / sense_id,
    ):
        path = base / f"{scene_id}.yaml"
        if path.exists():
            scene_path = path
            break
    else:
        sys.exit(f"找不到场景 '{scene_id}'")
    sense_path = draft.resolve_sense_path(sense_id)
    if not sense_path:
        sys.exit(f"找不到义项 '{sense_id}'")
    return scene_path, sense_path


def profile_path(profile: str) -> Path:
    if not PROFILE_ID.fullmatch(profile):
        sys.exit(f"视频能力 profile '{profile}' 含非法字符")
    path = draft.PROMPTS / "video-model-profiles" / f"{profile}.md"
    if not path.exists():
        available = sorted(p.stem for p in path.parent.glob("*.md"))
        sys.exit(f"找不到 profile '{profile}'; 可选: {', '.join(available)}")
    return path


def next_version(scene_id: str) -> int:
    base = shot_plans_dir() / scene_id
    taken = [
        int(path.name[1:])
        for path in base.glob("v[0-9][0-9]")
        if path.is_dir()
    ] if base.exists() else []
    return max(taken, default=0) + 1


def load_upstream(scene_id: str) -> tuple[dict, dict, Path, Path]:
    """读取 Scene 与 WordSense, 并要求语义修订状态为 CURRENT。

    普通 ``validate.py`` 容忍 NEEDS_REVIEW (旧场景不该卡住全库校验), 但新的下游
    视频执行计划不应建立在已知过时的语义修订上: 一份按第 1 版语义契约拍出来的镜头
    序列, 在语义契约已经改到第 2 版之后可能整段证据都不再成立。这里没有
    ``--allow-stale`` 逃生通道 — 正确做法是重新审核或重新生成 Scene。
    """
    scene_path, sense_path = locate(scene_id)
    scene = yaml.safe_load(draft.read(scene_path))
    sense = yaml.safe_load(draft.read(sense_path))
    if not isinstance(scene, dict):
        sys.exit(f"场景 {draft._rel(scene_path)} 的 YAML 根节点必须是对象")
    if not isinstance(sense, dict):
        sys.exit(f"义项 {draft._rel(sense_path)} 的 YAML 根节点必须是对象")

    check = revisions.check_scene_revision(scene, sense)
    if check.status != revisions.CURRENT:
        sys.exit(
            f"场景 '{scene_id}' 的语义修订状态是 {check.status}, 不能编译 Shot Plan:\n"
            f"  {check.message}\n"
            "Shot Plan 是视频执行权威, 只能从语义修订 CURRENT 的 SceneSpec 1.1 编译。"
        )
    return scene, sense, scene_path, sense_path


# ---------------------------------------------------------------- plan

def _dump(scene_id: str, name: str, text: str) -> Path:
    """失败输出进旁路文件, 永不占用正常 Shot Plan 路径。"""
    path = shot_plans_dir() / scene_id / name
    path.parent.mkdir(parents=True, exist_ok=True)
    draft._atomic_write(path, text if text.endswith("\n") else text + "\n")
    return path


def cmd_plan(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    scene, sense, scene_path, sense_path = load_upstream(scene_id)

    template = draft.read(draft.PROMPTS / "shot-plan.md")
    prompt = (
        template
        .replace("{{SCHEMA}}", draft.read(draft.ROOT / "schema" / "shot-plan.schema.json"))
        .replace("{{SENSE}}", draft.read(sense_path))
        .replace("{{SCENE}}", draft.read(scene_path))
        .replace("{{SCENE_ID}}", scene_id)
    )

    version = next_version(scene_id)
    print(f"→ Director 编译 '{scene_id}' Shot Plan v{version:02d} ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = draft.extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("Director 未返回 YAML 内容")
    try:
        document = yaml.safe_load(blocks[0])
    except yaml.YAMLError as exc:
        path = _dump(scene_id, "_unparsed-shot-plan.txt", blocks[0])
        sys.exit(f"YAML 解析失败, 原文已存 {draft._rel(path)}:\n{exc}")
    if not isinstance(document, dict):
        path = _dump(scene_id, "_unparsed-shot-plan.txt", blocks[0])
        sys.exit(f"Shot Plan 的 YAML 根节点必须是对象; 原文已存 {draft._rel(path)}")

    drift = shot_plan_lib.check_shot_plan_identity(
        document, scene=scene, sense=sense, version=version
    )
    if drift:
        path = _dump(scene_id, "_invalid-shot-plan.yaml", blocks[0])
        sys.exit(
            f"{shot_plan_lib.IDENTITY_DRIFT_KEYWORD}: 模型显式写出的权威字段与上游"
            f"冲突 ({len(drift)} 处):\n" + "\n".join(drift)
            + f"\n原始输出已存 {draft._rel(path)}; 请检查提示词, 不要手工改字段了事。"
        )

    shot_plan_lib.apply_authoritative_fields(
        document, scene=scene, sense=sense, version=version
    )

    errors = draft.schema_check(
        document, draft.load_schema("shot-plan.schema.json"), PLAN_FILE
    )
    errors += [
        f"  ✗ {PLAN_FILE} {issue}"
        for issue in shot_plan_lib.validate_shot_plan(document, scene)
    ]
    if errors:
        path = _dump(scene_id, "_invalid-shot-plan.yaml", blocks[0])
        print(f"\n⚠ {len(errors)} 处问题, Shot Plan 未写入正常路径:", file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        print(f"  原始输出已存 {draft._rel(path)}", file=sys.stderr)
        sys.exit(1)

    out = shot_plans_dir() / scene_id / f"v{version:02d}" / PLAN_FILE
    draft._atomic_write(
        out,
        yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100),
    )
    print(f"✓ Shot Plan 已写入 {draft._rel(out)}")
    for warning in shot_plan_lib.shot_plan_warnings(document):
        print(f"⚠ {warning}", file=sys.stderr)
    print(f"✓ 校验通过。查看: python3 tools/director.py show {scene_id}")


def cmd_generate(args: argparse.Namespace) -> None:
    """已弃用的旧命令名; 与 plan 完全同一实现, 不再生成 director-prompt.yaml。"""
    print(
        "warning: director.py generate 已弃用, 请使用 director.py plan。"
        "它现在编译 Shot Plan, 不再生成旧的 director-prompt.yaml。",
        file=sys.stderr,
    )
    if getattr(args, "profile", None) not in (None, DEFAULT_PROFILE):
        print(
            f"warning: --profile {args.profile} 被忽略 — Shot Plan 是模型中立的执行"
            "计划, 目标视频能力属于后续渲染适配层。",
            file=sys.stderr,
        )
    cmd_plan(args)


# ---------------------------------------------------------------- show / list

def load_plan(scene_id: str, version: int | None = None) -> tuple[dict, int]:
    selected = version or next_version(scene_id) - 1
    if selected < 1:
        sys.exit(
            f"'{scene_id}' 还没有 Shot Plan; 先运行 "
            f"python3 tools/director.py plan {scene_id}"
        )
    path = shot_plans_dir() / scene_id / f"v{selected:02d}" / PLAN_FILE
    if not path.exists():
        sys.exit(f"版本 v{selected:02d} 没有 {PLAN_FILE}")
    return yaml.safe_load(draft.read(path)), selected


def cmd_show(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    plan, _ = load_plan(scene_id, args.version)
    print(shot_plan_lib.shot_plan_summary(plan))

    # Scene 的普通资源版本变化不使 Shot Plan 失效 (措辞润色不改变镜头), 但值得
    # 人在审核时知道上游动过。真正的失效策略等生产工作流成熟后再定。
    scene_path, _sense_path = locate(scene_id)
    scene = yaml.safe_load(draft.read(scene_path))
    if isinstance(scene, dict) and scene.get("version") != plan.get("scene_version"):
        print(
            f"\n⚠ source Scene version has changed; review this Shot Plan "
            f"(plan: v{plan.get('scene_version')}, scene: v{scene.get('version')})",
            file=sys.stderr,
        )


def cmd_list(_args: argparse.Namespace) -> None:
    base = shot_plans_dir()
    found = False
    if base.exists():
        for scene_dir in sorted(path for path in base.iterdir() if path.is_dir()):
            for version_dir in sorted(scene_dir.glob("v[0-9][0-9]")):
                path = version_dir / PLAN_FILE
                if not path.exists():
                    continue
                found = True
                plan = yaml.safe_load(draft.read(path))
                print(
                    f"  {scene_dir.name} {version_dir.name}: "
                    f"{len(plan.get('shots', []) or [])} shots / "
                    f"{plan.get('total_duration_hint')}s / "
                    f"scene v{plan.get('scene_version')} / "
                    f"sense rev{plan.get('sense_revision')}"
                )
    if not found:
        print("尚无 Shot Plan。")

    legacy = director_dir()
    if legacy.exists():
        for scene_dir in sorted(path for path in legacy.iterdir() if path.is_dir()):
            for version_dir in sorted(scene_dir.glob("v[0-9][0-9]")):
                if (version_dir / "director-prompt.yaml").exists():
                    print(
                        f"  {scene_dir.name} {version_dir.name}: "
                        "legacy-director-prompt"
                    )


def cmd_show_legacy(args: argparse.Namespace) -> None:
    """展示旧的 Director Prompt 原型产物 (不是 Shot Plan, 不是新主线权威)。"""
    scene_id = args.scene_id.strip()
    base = director_dir() / scene_id
    versions = sorted(base.glob("v[0-9][0-9]")) if base.exists() else []
    selected = (
        base / f"v{args.version:02d}" if args.version else (versions[-1] if versions else None)
    )
    path = selected / "director-prompt.yaml" if selected else None
    if path is None or not path.exists():
        sys.exit(f"'{scene_id}' 没有旧的 Director Prompt")
    document = yaml.safe_load(draft.read(path))
    print(f"=== {draft._rel(path)} (legacy Director Prompt 原型) ===")
    print(yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SceneLex Director — 语义节拍 → 可执行 Shot Plan"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    plan = sub.add_parser("plan", help="Scene + WordSense → Shot Plan (新版本目录)")
    plan.add_argument("scene_id")
    plan.set_defaults(func=cmd_plan)

    generate = sub.add_parser("generate", help="已弃用: plan 的兼容别名")
    generate.add_argument("scene_id")
    generate.add_argument("--profile", default=DEFAULT_PROFILE, help="已忽略")
    generate.set_defaults(func=cmd_generate)

    show = sub.add_parser("show", help="展示最新 Shot Plan (面向人工审核)")
    show.add_argument("scene_id")
    show.add_argument("--version", "-v", type=int)
    show.set_defaults(func=cmd_show)

    sub.add_parser("list", help="列出 Shot Plan 版本").set_defaults(func=cmd_list)

    legacy = sub.add_parser("show-legacy", help="展示旧 Director Prompt 原型产物")
    legacy.add_argument("scene_id")
    legacy.add_argument("--version", "-v", type=int)
    legacy.set_defaults(func=cmd_show_legacy)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
