#!/usr/bin/env python3
"""SceneLex Image Keyframes — 把 Keyframe Plan 的文字关键状态变成真实图片。

    Shot Plan → Keyframe Plan → **图片关键帧** → 人工语义审核

这是一条真实 vertical slice 的受控原型, 不是通用资产基础设施:

- 一张图片对应**一个 keyframe**, 不是一个 beat —— 所以这里不复用 legacy 的
  beat-based render 逻辑, 也不会去改写它;
- 提示词由 ``image_keyframe.compile_prompt`` 机械编译, 模型不参与导演;
- 没有 digest / SHA / 依赖 DAG / 自动 stale / 通用 asset ID / 各类 Bible。
  图片本身已经是具体资产, 这一轮不为将来的系统预埋抽象。

用法:
    python3 tools/image_keyframes.py prompts  reluctant-01-proto-01 --keyframe-plan-version 2
    python3 tools/image_keyframes.py generate reluctant-01-proto-01 --keyframe-plan-version 2
    python3 tools/image_keyframes.py generate reluctant-01-proto-01 --only shot-02-kf-03 --force
    python3 tools/image_keyframes.py review   reluctant-01-proto-01 --version 1
    python3 tools/image_keyframes.py validate reluctant-01-proto-01 --version 1
    python3 tools/image_keyframes.py show     reluctant-01-proto-01 --version 1
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import sys
from pathlib import Path

import yaml

import draft
import image_keyframe as image_lib
import keyframes as keyframe_cli

MANIFEST_FILE = "image-keyframe-manifest.yaml"
REVIEW_FILE = "review.html"
SCHEMA_FILE = "image-keyframe-manifest.schema.json"

# 整场共用一个 seed。这是本轮唯一的一致性手段 (配合 Shot Plan 的 cast/location/
# props 常量块) —— 本 PR 不建立 Character/Location/Style Bible, 等真实漂移问题
# 出现之后再决定需不需要那些结构。
# 关键帧用的工作流必须显式写死在这一层。``imagegen`` 默认读的是 legacy 的
# beat-image SDXL 工作流 —— 靠环境变量隐式选模型, 意味着同一条命令在不同终端
# 里会画出完全不同的东西, 而 manifest 事后无法分辨。第一次真跑就踩了这个坑。
DEFAULT_WORKFLOW = "tools/workflows/comfyui-zimage-keyframe.json"

DEFAULT_SEED = 704251
SEED_POLICY = "fixed-scene-seed (整场 9 帧共用一个 seed)"
REFERENCE_STRATEGY = (
    "无参考图。一致性 = 固定 seed + Shot Plan 的 cast/location/props 连续性描述"
    "常量块; 不使用 Character/Location/Style Bible。"
)


def image_keyframes_dir() -> Path:
    return draft.DRAFTS / "image-keyframes"


def _versions(scene_id: str) -> list[Path]:
    base = image_keyframes_dir() / scene_id
    return sorted(base.glob("v[0-9][0-9]")) if base.exists() else []


def _target(scene_id: str, version: int | None) -> tuple[Path, int]:
    if version is not None:
        return image_keyframes_dir() / scene_id / f"v{version:02d}", version
    existing = _versions(scene_id)
    if existing:
        return existing[-1], int(existing[-1].name[1:])
    return image_keyframes_dir() / scene_id / "v01", 1


def _resolve_plans(scene_id: str, plan_version: int | None) -> tuple[dict, dict]:
    """Keyframe Plan 与它显式锚定的那一版 Shot Plan。

    版本必须显式: 上游目录里 v01…v05 全部保留, 默认跟随"最新目录"会让图片在
    无人察觉时改换语义依据。
    """
    plan, shot_plan, path = keyframe_cli._resolve(scene_id, plan_version)
    errors = keyframe_cli._check(plan, shot_plan, path)
    if errors:
        print(f"\n⚠ 上游 Keyframe Plan 未通过校验, 不生成图片 ({draft._rel(path)}):",
              file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    return plan, shot_plan


def _load_manifest(directory: Path) -> dict | None:
    path = directory / MANIFEST_FILE
    if not path.exists():
        return None
    document = yaml.safe_load(draft.read(path))
    if not isinstance(document, dict):
        sys.exit(f"{draft._rel(path)} 的 YAML 根节点必须是对象")
    return document


def _write_manifest(directory: Path, manifest: dict) -> Path:
    path = directory / MANIFEST_FILE
    draft._atomic_write(
        path,
        yaml.safe_dump(manifest, allow_unicode=True, sort_keys=False, width=100),
    )
    return path


def _write_review(directory: Path, manifest: dict, plan: dict, shot_plan: dict) -> Path:
    path = directory / REVIEW_FILE
    draft._atomic_write(path, image_lib.review_html(manifest, plan, shot_plan))
    return path


def _write_prompts(directory: Path, plan: dict, shot_plan: dict) -> dict[str, dict]:
    """编译并落盘全部提示词; 返回 keyframe_id → {positive, negative}。"""
    shots = image_lib._shot_index(shot_plan)
    compiled: dict[str, dict] = {}
    for shot_id, keyframe in image_lib.planned_frames(plan):
        keyframe_id = keyframe.get("id")
        prompt = image_lib.compile_prompt(keyframe, shots.get(shot_id, {}), shot_plan)
        compiled[keyframe_id] = prompt
        draft._atomic_write(
            directory / image_lib.prompt_name(keyframe_id),
            image_lib.prompt_file_text(keyframe_id, prompt),
        )
    return compiled


def _check(manifest: dict, plan: dict, shot_plan: dict, directory: Path) -> list[str]:
    errors = draft.schema_check(
        manifest, draft.load_schema(SCHEMA_FILE), MANIFEST_FILE
    )
    errors += [
        f"  ✗ {MANIFEST_FILE} {issue}"
        for issue in image_lib.validate_manifest(manifest, plan, shot_plan)
    ]
    errors += [
        f"  ✗ {MANIFEST_FILE} {issue}"
        for issue in image_lib.missing_files(manifest, directory)
    ]
    return errors


# ---------------------------------------------------------------- 子命令

def cmd_prompts(args: argparse.Namespace) -> None:
    """只编译提示词, 不调用图像模型 —— 提示词本身要能被单独审。"""
    scene_id = args.scene_id.strip()
    plan, shot_plan = _resolve_plans(scene_id, args.keyframe_plan_version)
    directory, _version = _target(scene_id, args.version)
    compiled = _write_prompts(directory, plan, shot_plan)
    print(f"✓ {len(compiled)} 条提示词已写入 {draft._rel(directory / 'prompts')}")
    if args.print:
        for keyframe_id, prompt in compiled.items():
            print(f"\n{'=' * 70}\n{keyframe_id}\n{'=' * 70}")
            print(prompt["positive"])


def cmd_generate(args: argparse.Namespace) -> None:
    workflow = Path(args.workflow)
    if not workflow.is_absolute():
        workflow = draft.ROOT / workflow
    if not workflow.exists():
        sys.exit(f"工作流不存在: {args.workflow}")
    os.environ["SCENELEX_IMG_WORKFLOW"] = str(workflow)

    import imagegen

    scene_id = args.scene_id.strip()
    plan, shot_plan = _resolve_plans(scene_id, args.keyframe_plan_version)
    directory, version = _target(scene_id, args.version)
    (directory / "images").mkdir(parents=True, exist_ok=True)
    (directory / "prompts").mkdir(parents=True, exist_ok=True)

    compiled = _write_prompts(directory, plan, shot_plan)
    previous = _load_manifest(directory)
    wanted = set(args.only or [])
    unknown = wanted - set(compiled)
    if unknown:
        sys.exit(f"未知关键帧: {', '.join(sorted(unknown))}")

    generated: list[str] = []
    skipped: list[str] = []
    failures: list[str] = []
    traces: dict[str, dict] = {}
    for keyframe_id, prompt in compiled.items():
        if wanted and keyframe_id not in wanted:
            continue
        target = directory / image_lib.image_name(keyframe_id)
        if target.exists() and target.stat().st_size and not args.force:
            skipped.append(keyframe_id)
            continue
        print(f"… 生成 {keyframe_id}", flush=True)
        try:
            data, trace = imagegen.generate(
                prompt["positive"], prompt["negative"], seed=args.seed
            )
        except Exception as error:  # noqa: BLE001 —— 生成失败必须留下痕迹, 不是崩溃
            failures.append(f"{keyframe_id}: {error}")
            print(f"  ✗ {error}", file=sys.stderr)
            continue
        target.write_bytes(data)
        traces[keyframe_id] = trace
        generated.append(keyframe_id)
        print(f"  ✓ {draft._rel(target)}  ({len(data) // 1024} KB)")

    sample = next(iter(traces.values()), None)
    manifest = image_lib.build_manifest(
        plan, shot_plan,
        version=version,
        generated_at=(previous or {}).get("generation", {}).get("generated_at")
        or dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        provider=args.provider,
        model=(sample or {}).get("model")
        or (previous or {}).get("generation", {}).get("model", "unknown"),
        workflow=(sample or {}).get("workflow")
        or (previous or {}).get("generation", {}).get("workflow", imagegen.workflow_name()),
        seed=args.seed,
        seed_policy=SEED_POLICY,
        reference_strategy=REFERENCE_STRATEGY,
        notes=args.notes or (previous or {}).get("generation", {}).get("notes", ""),
        previous=previous,
    )
    for frame in manifest["frames"]:
        keyframe_id = frame["keyframe_id"]
        if keyframe_id in traces:
            frame["seed"] = traces[keyframe_id]["seed"]
            frame["status"] = "regenerated" if previous else "generated"
        elif not (directory / frame["image"]).exists():
            frame["status"] = "blocked"

    manifest_path = _write_manifest(directory, manifest)
    review_path = _write_review(directory, manifest, plan, shot_plan)
    print(f"\n✓ manifest → {draft._rel(manifest_path)}")
    print(f"✓ review   → {draft._rel(review_path)}")
    print(f"  生成 {len(generated)} / 跳过 {len(skipped)} / 失败 {len(failures)}")
    for failure in failures:
        print(f"  ✗ {failure}", file=sys.stderr)
    if failures:
        print("\nGENERATION BLOCKED —— 未取得完整的真实图片, "
              "不得据此给出 READY FOR VIDEO MOTION PROTOTYPE。", file=sys.stderr)
        sys.exit(1)
    print(f"\n{image_lib.REVIEW_LAYER}\n{image_lib.REVIEW_NOT}")


def cmd_review(args: argparse.Namespace) -> None:
    """从 manifest + 上游计划确定性重建审核页; 不触碰 manifest, 不重生成图片。"""
    scene_id = args.scene_id.strip()
    directory, _version = _target(scene_id, args.version)
    manifest = _load_manifest(directory)
    if manifest is None:
        sys.exit(f"找不到 {draft._rel(directory / MANIFEST_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id, (manifest.get("keyframe_plan_ref") or {}).get("version")
    )
    path = _write_review(directory, manifest, plan, shot_plan)
    print(f"✓ 审核页已写入 {draft._rel(path)} (浏览器直接打开)")
    print(f"\n{image_lib.REVIEW_LAYER}\n{image_lib.REVIEW_NOT}")


def cmd_validate(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    directory, _version = _target(scene_id, args.version)
    manifest = _load_manifest(directory)
    if manifest is None:
        sys.exit(f"找不到 {draft._rel(directory / MANIFEST_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id, (manifest.get("keyframe_plan_ref") or {}).get("version")
    )
    errors = _check(manifest, plan, shot_plan, directory)
    if errors:
        print(f"\n⚠ {len(errors)} 处问题 ({draft._rel(directory / MANIFEST_FILE)}):",
              file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    print(f"✓ {draft._rel(directory / MANIFEST_FILE)} 通过 schema、绑定、"
          "覆盖、唯一性与文件存在性校验。")


def cmd_show(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    directory, _version = _target(scene_id, args.version)
    manifest = _load_manifest(directory)
    if manifest is None:
        sys.exit(f"找不到 {draft._rel(directory / MANIFEST_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id, (manifest.get("keyframe_plan_ref") or {}).get("version")
    )
    print(image_lib.manifest_summary(manifest, plan))
    errors = _check(manifest, plan, shot_plan, directory)
    print(f"\nValidation: {'PASS' if not errors else f'{len(errors)} 处问题'}")
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        sys.exit(1)


def cmd_list(_args: argparse.Namespace) -> None:
    base = image_keyframes_dir()
    found = False
    if base.exists():
        for scene_dir in sorted(path for path in base.iterdir() if path.is_dir()):
            for version_dir in sorted(scene_dir.glob("v[0-9][0-9]")):
                path = version_dir / MANIFEST_FILE
                if not path.exists():
                    continue
                found = True
                manifest = yaml.safe_load(draft.read(path))
                generation = manifest.get("generation") or {}
                print(
                    f"  {scene_dir.name} {version_dir.name}: "
                    f"{len(manifest.get('frames', []) or [])} frames / "
                    f"keyframe plan v"
                    f"{(manifest.get('keyframe_plan_ref') or {}).get('version')} / "
                    f"{generation.get('model')}"
                )
    if not found:
        print("尚无图片关键帧。")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SceneLex Image Keyframes — Keyframe Plan → 真实图片 → 语义审核"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    def add(name: str, help_text: str, func) -> argparse.ArgumentParser:
        command = sub.add_parser(name, help=help_text)
        command.add_argument("scene_id")
        command.add_argument("--version", "-v", type=int,
                             help="图片关键帧版本目录 (默认最新, 没有则 v01)")
        command.set_defaults(func=func)
        return command

    prompts = add("prompts", "只编译提示词, 不调用图像模型", cmd_prompts)
    prompts.add_argument("--keyframe-plan-version", type=int)
    prompts.add_argument("--print", action="store_true", help="同时打印正提示词")

    generate = add("generate", "生成真实图片并写 manifest 与审核页", cmd_generate)
    generate.add_argument("--keyframe-plan-version", type=int)
    generate.add_argument("--only", nargs="+", metavar="KEYFRAME_ID",
                          help="只重生成这些关键帧")
    generate.add_argument("--force", action="store_true", help="覆盖已存在的图片")
    generate.add_argument("--workflow", default=DEFAULT_WORKFLOW,
                          help="ComfyUI API 工作流 JSON (默认 Z-Image Turbo 关键帧工作流)")
    generate.add_argument("--seed", type=int, default=DEFAULT_SEED)
    generate.add_argument("--provider", default="comfyui-local")
    generate.add_argument("--notes", default="")

    add("review", "确定性重建单文件审核页", cmd_review)
    add("validate", "校验 manifest 的绑定、覆盖、唯一性与文件存在性", cmd_validate)
    add("show", "面向人工审核的展开", cmd_show)
    sub.add_parser("list", help="列出图片关键帧版本").set_defaults(func=cmd_list)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
