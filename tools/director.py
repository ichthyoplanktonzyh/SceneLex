#!/usr/bin/env python3
"""SceneLex Director — 语义场景到视频模型提示词的轻量中间层。

Director 读取正式或草稿 WordSense + SceneSpec，并依据一个轻量视频能力
profile，输出可直接提交给视频模型的 prompt。它不生成视频，也不建立复杂制片状态。

用法:
    python3 tools/director.py generate reluctant-01-proto-01
    python3 tools/director.py generate reluctant-01-proto-01 --profile wan2.2-ti2v-5b
    python3 tools/director.py show reluctant-01-proto-01
    python3 tools/director.py list
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

import draft
import llm


SCENE_ID = re.compile(
    r"^([a-z][a-z_]*-\d{2})-(proto|contrast|counter|boundary|transfer)-\d{2}$"
)
PROFILE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
DEFAULT_PROFILE = "generic-video"


def director_dir() -> Path:
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
    base = director_dir() / scene_id
    taken = [
        int(path.name[1:])
        for path in base.glob("v[0-9][0-9]")
        if path.is_dir()
    ] if base.exists() else []
    return max(taken, default=0) + 1


def load_style() -> tuple[str, str]:
    path = draft.PROMPTS / "render-style.yaml"
    if not path.exists():
        sys.exit("找不到全局渲染风格 prompts/render-style.yaml")
    document = yaml.safe_load(draft.read(path)) or {}
    style_id = document.get("id")
    instruction = document.get("director_instruction")
    if not isinstance(style_id, str) or not PROFILE_ID.fullmatch(style_id):
        sys.exit("render-style.yaml 缺少合法 id")
    if not isinstance(instruction, str) or not instruction.strip():
        sys.exit("render-style.yaml 缺少 director_instruction")
    return style_id, instruction.strip()


def prompt_issues(document: dict, scene: dict) -> list[str]:
    """Schema 外的轻量覆盖检查，不评判提示词创意。"""
    issues: list[str] = []
    source_beats = {
        beat
        for clip in document.get("video_prompts", [])
        for beat in clip.get("source_beats", [])
    }
    expected = {beat.get("beat") for beat in scene.get("storyboard", [])}
    missing = sorted(beat for beat in expected - source_beats if beat is not None)
    unknown = sorted(beat for beat in source_beats - expected if beat is not None)
    if missing:
        issues.append(f"未覆盖 storyboard beats: {missing}")
    if unknown:
        issues.append(f"引用不存在的 storyboard beats: {unknown}")

    prompts = document.get("video_prompts", [])
    strategy = document.get("strategy")
    if strategy == "split_clips" and len(prompts) < 2:
        issues.append("split_clips 至少需要两个 video_prompts")
    if strategy != "split_clips" and len(prompts) != 1:
        issues.append(f"{strategy} 应只输出一个 video prompt")
    if strategy == "image_guided_i2v" and any(
        not clip.get("image_prompt") for clip in prompts
    ):
        issues.append("image_guided_i2v 的每个 clip 必须提供 image_prompt")
    if document.get("style") == "pixar-3d":
        for clip in prompts:
            if "pixar" not in clip.get("prompt", "").lower():
                issues.append(f"{clip.get('id')} video prompt 缺少 Pixar-style 风格锚点")
            image_prompt = clip.get("image_prompt")
            if image_prompt and "pixar" not in image_prompt.lower():
                issues.append(f"{clip.get('id')} image prompt 缺少 Pixar-style 风格锚点")
    return issues


def cmd_generate(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    profile = args.profile.strip()
    scene_path, sense_path = locate(scene_id)
    scene = yaml.safe_load(draft.read(scene_path))
    style_id, style_instruction = load_style()

    template = draft.read(draft.PROMPTS / "director.md")
    prompt = (
        template
        .replace("{{PROFILE}}", draft.read(profile_path(profile)))
        .replace("{{STYLE}}", style_instruction)
        .replace("{{SCHEMA}}", draft.read(draft.ROOT / "schema" / "director-prompt.schema.json"))
        .replace("{{SENSE}}", draft.read(sense_path))
        .replace("{{SCENE}}", draft.read(scene_path))
        .replace("{{SCENE_ID}}", scene_id)
    )

    print(f"→ Director 编译 '{scene_id}' ({profile}) ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = draft.extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("Director 未返回 YAML 内容")
    try:
        document = yaml.safe_load(blocks[0])
    except yaml.YAMLError as exc:
        dump = director_dir() / scene_id / "_unparsed-director.txt"
        dump.parent.mkdir(parents=True, exist_ok=True)
        dump.write_text(blocks[0], encoding="utf-8")
        sys.exit(f"YAML 解析失败，原文已存 {dump.relative_to(draft.ROOT)}:\n{exc}")
    if not isinstance(document, dict):
        sys.exit("Director YAML 根节点必须是对象")

    version = next_version(scene_id)
    document["schema_version"] = "1.0"
    document["scene_ref"] = scene_id
    document["spec_version"] = int(scene.get("version", 1))
    document["version"] = version
    document["status"] = "draft"
    document["profile"] = profile
    document["style"] = style_id

    out_dir = director_dir() / scene_id / f"v{version:02d}"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / "director-prompt.yaml"
    out.write_text(
        yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100),
        encoding="utf-8",
    )
    print(f"✓ Director Prompt 已写入 {out.relative_to(draft.ROOT)}")

    errors = draft.schema_check(
        document, draft.load_schema("director-prompt.schema.json"), out.name
    )
    errors += [f"  ✗ {out.name} {issue}" for issue in prompt_issues(document, scene)]
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    print(f"✓ 校验通过。查看: python3 tools/director.py show {scene_id}")


def load_latest(scene_id: str, version: int | None = None) -> tuple[dict, int]:
    selected = version or next_version(scene_id) - 1
    if selected < 1:
        sys.exit(f"'{scene_id}' 还没有 Director Prompt")
    path = director_dir() / scene_id / f"v{selected:02d}" / "director-prompt.yaml"
    if not path.exists():
        sys.exit(f"版本 v{selected:02d} 没有 director-prompt.yaml")
    return yaml.safe_load(draft.read(path)), selected


def cmd_show(args: argparse.Namespace) -> None:
    document, version = load_latest(args.scene_id.strip(), args.version)
    print(
        f"=== {document['scene_ref']} v{version:02d} | "
        f"{document['profile']} | {document['style']} | {document['strategy']} ==="
    )
    if document.get("director_note"):
        print(f"\n{document['director_note']}")
    for clip in document["video_prompts"]:
        print(f"\n--- {clip['id']} | {clip['duration_hint']}s | beats {clip['source_beats']} ---")
        if clip.get("image_prompt"):
            print(f"image    | {clip['image_prompt']}")
        print(f"video    | {clip['prompt']}")
        if clip.get("negative_prompt"):
            print(f"negative | {clip['negative_prompt']}")
    guardrails = document["semantic_guardrails"]
    print("\n必须看见:")
    for item in guardrails["must_show"]:
        print(f"  + {item}")
    print("绝不能误画:")
    for item in guardrails["must_avoid"]:
        print(f"  - {item}")


def cmd_list(_args: argparse.Namespace) -> None:
    base = director_dir()
    if not base.exists():
        print("尚无 Director Prompt。")
        return
    found = False
    for scene_dir in sorted(path for path in base.iterdir() if path.is_dir()):
        for version_dir in sorted(scene_dir.glob("v[0-9][0-9]")):
            path = version_dir / "director-prompt.yaml"
            if not path.exists():
                continue
            found = True
            document = yaml.safe_load(draft.read(path))
            print(
                f"  {scene_dir.name} {version_dir.name}: "
                f"{document.get('profile', '?')} / {document.get('strategy', '?')}"
            )
    if not found:
        print("尚无 Director Prompt。")


def main() -> None:
    parser = argparse.ArgumentParser(description="SceneLex Director Agent")
    sub = parser.add_subparsers(dest="cmd", required=True)

    generate = sub.add_parser("generate", help="语义场景 → 视频提示词")
    generate.add_argument("scene_id")
    generate.add_argument("--profile", default=DEFAULT_PROFILE)
    generate.set_defaults(func=cmd_generate)

    show = sub.add_parser("show", help="显示最新 Director Prompt")
    show.add_argument("scene_id")
    show.add_argument("--version", "-v", type=int)
    show.set_defaults(func=cmd_show)

    sub.add_parser("list", help="列出 Director Prompt").set_defaults(func=cmd_list)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
