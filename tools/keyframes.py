#!/usr/bin/env python3
"""SceneLex Keyframes — 把一条 Shot Plan 变成可审核的关键帧与静态 animatic。

    Shot Plan → Keyframe Plan → Animatic (timeline + preview) → 人工审核

这是一个受控原型, 不是通用关键帧平台:

- 只读 Shot Plan, **不**读 legacy Director Prompt, 也**不**读 legacy Render Plan;
- 不调用任何 LLM, 不调用图像/视频模型, 不产生二进制资产;
- 第一份 Keyframe Plan 由人工按真实内容选帧写成, 本工具负责校验、时间轴、
  预览与展示 (人工种子 + 确定性保存)。因此这里没有 ``plan`` 子命令 —— 让模型
  自动给每个镜头凑五张关键帧, 正是这个原型要避免的东西。

用法:
    python3 tools/keyframes.py validate reluctant-01-proto-01
    python3 tools/keyframes.py show     reluctant-01-proto-01
    python3 tools/keyframes.py animatic reluctant-01-proto-01
    python3 tools/keyframes.py list
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

import director
import draft
import keyframe_plan as keyframe_lib

PLAN_FILE = "keyframe-plan.yaml"
MANIFEST_FILE = "animatic.yaml"
PREVIEW_FILE = "animatic.html"


def keyframe_plans_dir() -> Path:
    return draft.DRAFTS / "keyframe-plans"


def _versions(scene_id: str) -> list[Path]:
    base = keyframe_plans_dir() / scene_id
    return sorted(base.glob("v[0-9][0-9]")) if base.exists() else []


def load_keyframe_plan(scene_id: str, version: int | None) -> tuple[dict, Path]:
    versions = _versions(scene_id)
    if version is not None:
        selected = keyframe_plans_dir() / scene_id / f"v{version:02d}"
    elif versions:
        selected = versions[-1]
    else:
        sys.exit(
            f"'{scene_id}' 还没有 Keyframe Plan; "
            f"预期路径 {draft._rel(keyframe_plans_dir() / scene_id)}/vNN/{PLAN_FILE}"
        )
    path = selected / PLAN_FILE
    if not path.exists():
        sys.exit(f"找不到 {draft._rel(path)}")
    document = yaml.safe_load(draft.read(path))
    if not isinstance(document, dict):
        sys.exit(f"{draft._rel(path)} 的 YAML 根节点必须是对象")
    return document, path


def load_shot_plan(scene_id: str, version: int) -> dict:
    """按显式版本读取 Shot Plan。

    ``data/drafts/shot-plans/`` 下的版本目录都是草稿, 且历史版本一律保留, 所以
    下游必须**显式**说明自己锚定的是哪一版, 而不是默默跟着"最新目录"漂移。
    """
    path = director.shot_plans_dir() / scene_id / f"v{version:02d}" / director.PLAN_FILE
    if not path.exists():
        available = [p.name for p in sorted(
            (director.shot_plans_dir() / scene_id).glob("v[0-9][0-9]")
        )] if (director.shot_plans_dir() / scene_id).exists() else []
        sys.exit(
            f"引用的 Shot Plan v{version:02d} 不存在 ({draft._rel(path)}); "
            f"现有版本: {', '.join(available) or '无'}"
        )
    document = yaml.safe_load(draft.read(path))
    if not isinstance(document, dict):
        sys.exit(f"{draft._rel(path)} 的 YAML 根节点必须是对象")
    return document


def _resolve(scene_id: str, version: int | None) -> tuple[dict, dict, Path]:
    """Keyframe Plan + 它显式引用的那一版 Shot Plan。"""
    # 场景必须真实存在 (locate 在找不到时退出)。
    director.locate(scene_id)
    plan, path = load_keyframe_plan(scene_id, version)
    reference = plan.get("shot_plan_ref")
    if not isinstance(reference, dict) or not isinstance(reference.get("version"), int):
        sys.exit(f"{draft._rel(path)} 缺少可解析的 shot_plan_ref.version")
    shot_plan = load_shot_plan(
        reference.get("scene_id") or scene_id, reference["version"]
    )
    return plan, shot_plan, path


def _check(plan: dict, shot_plan: dict, path: Path) -> list[str]:
    errors = draft.schema_check(
        plan, draft.load_schema("keyframe-plan.schema.json"), PLAN_FILE
    )
    errors += [
        f"  ✗ {PLAN_FILE} {issue}"
        for issue in keyframe_lib.validate_keyframe_plan(plan, shot_plan)
    ]
    if errors:
        return errors
    manifest = keyframe_lib.build_animatic(plan, shot_plan)
    return [
        f"  ✗ {MANIFEST_FILE} {issue}"
        for issue in keyframe_lib.validate_animatic(manifest, plan, shot_plan)
    ]


# ---------------------------------------------------------------- 子命令

def cmd_validate(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    plan, shot_plan, path = _resolve(scene_id, args.version)
    errors = _check(plan, shot_plan, path)
    if errors:
        print(f"\n⚠ {len(errors)} 处问题 ({draft._rel(path)}):", file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    print(f"✓ {draft._rel(path)} 通过 schema、绑定、时序与 animatic 校验。")


def cmd_show(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    plan, shot_plan, path = _resolve(scene_id, args.version)
    manifest = keyframe_lib.build_animatic(plan, shot_plan)
    print(keyframe_lib.keyframe_plan_summary(plan, shot_plan, manifest))

    preview = path.parent / PREVIEW_FILE
    print("")
    print(f"Animatic manifest: {draft._rel(path.parent / MANIFEST_FILE)}")
    print(
        f"Animatic preview:  {draft._rel(preview)}"
        + ("" if preview.exists() else "  (尚未生成: keyframes.py animatic)")
    )
    errors = _check(plan, shot_plan, path)
    print(f"Validation: {'PASS' if not errors else f'{len(errors)} 处问题'}")
    print(f"\n{keyframe_lib.PLACEHOLDER_WARNING}")
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        sys.exit(1)


def cmd_animatic(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    plan, shot_plan, path = _resolve(scene_id, args.version)
    errors = _check(plan, shot_plan, path)
    if errors:
        print(f"\n⚠ {len(errors)} 处问题, 未生成 animatic:", file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    manifest = keyframe_lib.build_animatic(plan, shot_plan)
    manifest_path = path.parent / MANIFEST_FILE
    draft._atomic_write(
        manifest_path,
        yaml.safe_dump(manifest, allow_unicode=True, sort_keys=False, width=100),
    )
    preview_path = path.parent / PREVIEW_FILE
    draft._atomic_write(
        preview_path, keyframe_lib.animatic_html(plan, shot_plan, manifest)
    )
    print(f"✓ 时间轴已写入 {draft._rel(manifest_path)}")
    print(f"✓ 预览已写入 {draft._rel(preview_path)} (浏览器直接打开)")
    print(f"  总时长 {manifest['total_duration_seconds']}s / "
          f"{len(manifest['entries'])} 关键帧 / {len(manifest['shots'])} 镜头")
    print(f"\n{keyframe_lib.PLACEHOLDER_WARNING}")


def cmd_list(_args: argparse.Namespace) -> None:
    base = keyframe_plans_dir()
    found = False
    if base.exists():
        for scene_dir in sorted(path for path in base.iterdir() if path.is_dir()):
            for version_dir in sorted(scene_dir.glob("v[0-9][0-9]")):
                path = version_dir / PLAN_FILE
                if not path.exists():
                    continue
                found = True
                plan = yaml.safe_load(draft.read(path))
                reference = plan.get("shot_plan_ref") or {}
                print(
                    f"  {scene_dir.name} {version_dir.name}: "
                    f"{len(keyframe_lib.keyframes(plan))} keyframes / "
                    f"{len(plan.get('shots', []) or [])} shots / "
                    f"shot plan v{reference.get('version')}"
                )
    if not found:
        print("尚无 Keyframe Plan。")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SceneLex Keyframes — Shot Plan → Keyframe Plan → 静态 animatic"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    for name, help_text, func in (
        ("validate", "校验 Keyframe Plan 与它的 animatic 时间轴", cmd_validate),
        ("show", "面向人工审核的展开", cmd_show),
        ("animatic", "确定性生成时间轴与单文件 HTML 预览", cmd_animatic),
    ):
        command = sub.add_parser(name, help=help_text)
        command.add_argument("scene_id")
        command.add_argument("--version", "-v", type=int, help="Keyframe Plan 版本")
        command.set_defaults(func=func)

    sub.add_parser("list", help="列出 Keyframe Plan 版本").set_defaults(func=cmd_list)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
