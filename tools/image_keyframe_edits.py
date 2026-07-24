#!/usr/bin/env python3
"""SceneLex Image Keyframe Edits — Token Plan Wan 2.7 状态编辑实验 CLI。

这一层只回答一个问题:
    Token Plan 的 wan2.7-image-pro 能否通过图片编辑和多图参考,
    准确执行 reluctant 场景最困难的四个冻结视觉状态？

两层结论:
    api_gate:     pass | blocked
    semantic_gate: pass | revision_required | not_run

产物落在:
    data/drafts/image-keyframe-edits/{scene_id}/v{NN}/
      edit-run.yaml
      review.html
      prompts/
      images/

用法:
    python3 tools/image_keyframe_edits.py smoke \\
        reluctant-01-proto-01 \\
        --source-image-version 1 --version 1

    python3 tools/image_keyframe_edits.py generate \\
        reluctant-01-proto-01 \\
        --keyframe-plan-version 2 --source-image-version 1 --version 1 \\
        --only shot-02-kf-03

    python3 tools/image_keyframe_edits.py review  reluctant-01-proto-01 --version 1
    python3 tools/image_keyframe_edits.py validate reluctant-01-proto-01 --version 1
    python3 tools/image_keyframe_edits.py show    reluctant-01-proto-01 --version 1

安全约束:
    SCENELEX_ALIYUN_TOKEN_PLAN_KEY 只读取不输出。
    edit-run.yaml、review.html、prompts/ 均不含 API Key / Base64 / 临时 URL。
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import draft
import image_keyframe_edit as edit_lib
import keyframes as keyframe_cli

EDIT_RUN_FILE = "edit-run.yaml"
REVIEW_FILE = "review.html"

DEFAULT_SEED = 704251
DEFAULT_MODEL = "wan2.7-image-pro"
DEFAULT_SIZE = "1152*640"

# smoke test 使用的微小编辑指令
_SMOKE_INSTRUCTION = (
    "Keep the same child, clothing, dining table, plate, fork, lighting, "
    "visual style and camera framing.\n\n"
    "Make only one visible change: "
    "move the child's torso slightly backward until the shoulders rest "
    "against the chair back.\n\n"
    "Keep both hands on the table. "
    "Do not move the fork or the plate."
)

# 身份参考图选择说明（人工选定 shot-02-kf-02 作为整轮实验统一参考）
_DEFAULT_IDENTITY_RATIONALE = (
    "shot-02-kf-02: 孩子脸部最清楚、服装最完整、没有严重畸形、姿态最接近预期。"
    "作为整轮实验统一的身份参考图。scope=experiment-local，"
    "不是正式 Character Asset。"
)


def _edits_dir() -> Path:
    return ROOT / "data" / "drafts" / "image-keyframe-edits"


def _versions(scene_id: str) -> list[Path]:
    base = _edits_dir() / scene_id
    return sorted(base.glob("v[0-9][0-9]")) if base.exists() else []


def _target_dir(scene_id: str, version: int | None) -> tuple[Path, int]:
    if version is not None:
        return _edits_dir() / scene_id / f"v{version:02d}", version
    existing = _versions(scene_id)
    if existing:
        return existing[-1], int(existing[-1].name[1:])
    return _edits_dir() / scene_id / "v01", 1


def _load_edit_run(directory: Path) -> dict | None:
    path = directory / EDIT_RUN_FILE
    if not path.exists():
        return None
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(doc, dict):
        sys.exit(f"{path.relative_to(ROOT)} 的 YAML 根节点必须是对象")
    return doc


def _write_edit_run(directory: Path, run_doc: dict) -> Path:
    path = directory / EDIT_RUN_FILE
    draft._atomic_write(
        path,
        yaml.safe_dump(run_doc, allow_unicode=True, sort_keys=False, width=100),
    )
    return path


def _write_review(directory: Path, run_doc: dict, plan: dict, shot_plan: dict) -> Path:
    path = directory / REVIEW_FILE
    draft._atomic_write(path, edit_lib.review_html(run_doc, plan, shot_plan))
    return path


def _resolve_plans(scene_id: str, plan_version: int | None) -> tuple[dict, dict]:
    """载入 Keyframe Plan 及其锚定的 Shot Plan，并校验。"""
    plan, shot_plan, path = keyframe_cli._resolve(scene_id, plan_version)
    errors = keyframe_cli._check(plan, shot_plan, path)
    if errors:
        print(
            f"\n⚠ 上游 Keyframe Plan 未通过校验 ({draft._rel(path)}):",
            file=sys.stderr,
        )
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    return plan, shot_plan


def _load_source_manifest(scene_id: str, version: int) -> dict:
    """载入 image-keyframes v01 manifest 作为基础图来源。"""
    path = (
        ROOT
        / "data"
        / "drafts"
        / "image-keyframes"
        / scene_id
        / f"v{version:02d}"
        / "image-keyframe-manifest.yaml"
    )
    if not path.exists():
        sys.exit(f"找不到基础图 manifest: {draft._rel(path)}")
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(doc, dict):
        sys.exit(f"{draft._rel(path)} 的 YAML 根节点必须是对象")
    return doc


def _source_image_path(scene_id: str, source_version: int, relative_path: str) -> Path:
    return (
        ROOT
        / "data"
        / "drafts"
        / "image-keyframes"
        / scene_id
        / f"v{source_version:02d}"
        / relative_path
    )


# ---------------------------------------------------------------- smoke test

def cmd_smoke(args: argparse.Namespace) -> None:
    """最小 smoke test: 提交一张图 + 微小编辑，验证 Token Plan 接受图片输入。

    判定条件:
        - HTTP 成功 + request_id 存在 + 图片 URL 存在
        - 立即下载成功，内容非空，是有效图片
        - 写入实验目录

    api_gate: pass → 继续四帧
    api_gate: blocked → 只记录错误，不切换 Endpoint/Key
    """
    import imagegen

    os.environ["SCENELEX_IMG_PROTOCOL"] = "aliyun-token-plan"
    if args.model:
        os.environ["SCENELEX_IMG_MODEL"] = args.model
    if args.size:
        os.environ["SCENELEX_IMG_SIZE"] = args.size

    scene_id = args.scene_id.strip()
    source_version = args.source_image_version
    directory, version = _target_dir(scene_id, args.version)
    (directory / "images").mkdir(parents=True, exist_ok=True)
    (directory / "prompts").mkdir(parents=True, exist_ok=True)

    # 使用 shot-02-kf-02 作为 smoke 输入图
    source_manifest = _load_source_manifest(scene_id, source_version)
    smoke_img_rel = "images/shot-02-kf-02.png"
    smoke_img = _source_image_path(scene_id, source_version, smoke_img_rel)
    if not smoke_img.exists():
        sys.exit(f"smoke 输入图不存在: {draft._rel(smoke_img)}")

    seed = args.seed or DEFAULT_SEED
    model = args.model or DEFAULT_MODEL

    # 写入 prompt 文件
    prompt_path = directory / "prompts" / "smoke-attempt-01.txt"
    prompt_path.write_text(
        f"# smoke test\n# 输入图: {smoke_img_rel}\n\n"
        "=== EDIT INSTRUCTION ===\n"
        f"{_SMOKE_INSTRUCTION}\n",
        encoding="utf-8",
    )

    print(f"… smoke test: {draft._rel(smoke_img)}")
    print(f"  model={model}  seed={seed}  size={args.size or DEFAULT_SIZE}")

    try:
        img_bytes, trace = imagegen.edit(
            _SMOKE_INSTRUCTION,
            [smoke_img],
            model=model,
            size=args.size or DEFAULT_SIZE,
            seed=seed,
        )
    except Exception as exc:  # noqa: BLE001
        # api_gate: blocked — 记录去敏后错误，不切换 Endpoint/Key
        err_msg = str(exc)
        # 确保不泄漏 Key（截断并过滤）
        safe_msg = err_msg[:400].replace(
            os.environ.get("SCENELEX_ALIYUN_TOKEN_PLAN_KEY", "NOKEY"), "***"
        )
        print(f"  ✗ Token Plan 图片编辑失败: {safe_msg}", file=sys.stderr)
        print("\napi_gate: blocked", file=sys.stderr)
        print("semantic_gate: not_run", file=sys.stderr)
        print("\nTOKEN PLAN IMAGE EDITING BLOCKED", file=sys.stderr)

        # 更新 edit-run
        run_doc = _load_edit_run(directory) or edit_lib.build_edit_run(
            {}, {}, source_manifest,
            version=version,
            scene_id=scene_id,
            identity_reference_image=None,
            identity_reference_rationale=None,
        )
        run_doc["api_gate"] = "blocked"
        run_doc["semantic_gate"] = "not_run"
        run_doc.setdefault("smoke_test", {})
        run_doc["smoke_test"] = {
            "status": "blocked",
            "http_status": _extract_http_status(err_msg),
            "message": safe_msg,
        }
        _write_edit_run(directory, run_doc)
        sys.exit(1)

    # smoke 成功
    out_path = directory / "images" / "smoke-attempt-01.png"
    out_path.write_bytes(img_bytes)

    print(f"  ✓ 下载成功 {len(img_bytes) // 1024} KB → {draft._rel(out_path)}")
    print(f"  request_id: {trace.get('request_id')}")
    print(f"  model: {trace.get('model')}")
    print(f"  actual_size: {trace.get('actual_size')}")
    print("\napi_gate: pass")
    print("→ 继续运行 generate 命令生成四张诊断帧")

    # 更新 edit-run
    run_doc = _load_edit_run(directory) or edit_lib.build_edit_run(
        _resolve_plans(scene_id, args.keyframe_plan_version)[0],
        _resolve_plans(scene_id, args.keyframe_plan_version)[1],
        source_manifest,
        version=version,
        scene_id=scene_id,
        identity_reference_image=None,
        identity_reference_rationale=None,
    )
    run_doc["api_gate"] = "pass"
    run_doc.setdefault("smoke_test", {})
    run_doc["smoke_test"] = {
        "status": "pass",
        "request_id": trace.get("request_id"),
        "model": trace.get("model"),
        "actual_size": trace.get("actual_size"),
        "image": str(out_path.relative_to(directory)),
    }
    _write_edit_run(directory, run_doc)
    print(f"\n✓ edit-run → {draft._rel(directory / EDIT_RUN_FILE)}")


def _extract_http_status(err_msg: str) -> int | None:
    """从错误信息中提取 HTTP 状态码（不泄漏其他信息）。"""
    import re
    m = re.search(r"HTTP (\d{3})", err_msg)
    return int(m.group(1)) if m else None


# ---------------------------------------------------------------- generate

def cmd_generate(args: argparse.Namespace) -> None:
    """生成四张诊断帧（或 --only 指定的帧）。

    严格按顺序: shot-02-kf-03 → kf-04 → shot-03-kf-01 → kf-03。
    每帧最多2次，全局最多10次。
    只有 api_gate=pass 时才应调用此命令（smoke test 先跑）。
    """
    import imagegen

    os.environ["SCENELEX_IMG_PROTOCOL"] = "aliyun-token-plan"

    scene_id = args.scene_id.strip()
    source_version = args.source_image_version
    directory, version = _target_dir(scene_id, args.version)
    (directory / "images").mkdir(parents=True, exist_ok=True)
    (directory / "prompts").mkdir(parents=True, exist_ok=True)

    plan, shot_plan = _resolve_plans(scene_id, args.keyframe_plan_version)
    source_manifest = _load_source_manifest(scene_id, source_version)

    # 载入或初始化 edit-run
    run_doc = _load_edit_run(directory)
    if run_doc is None:
        print("⚠ 找不到 edit-run.yaml，正在初始化…", file=sys.stderr)
        run_doc = edit_lib.build_edit_run(
            plan, shot_plan, source_manifest,
            version=version,
            scene_id=scene_id,
            identity_reference_image=None,
            identity_reference_rationale=None,
        )

    # 决定身份参考图 (默认 shot-02-kf-02 作为整轮统一参考)
    identity_ref_rel = args.identity_ref or "images/shot-02-kf-02.png"
    identity_ref_path = _source_image_path(scene_id, source_version, identity_ref_rel)
    if not identity_ref_path.exists():
        sys.exit(f"身份参考图不存在: {draft._rel(identity_ref_path)}")

    if run_doc.get("identity_reference", {}).get("image") is None:
        run_doc["identity_reference"] = {
            "image": str(identity_ref_path.relative_to(ROOT)),
            "rationale": args.identity_rationale or _DEFAULT_IDENTITY_RATIONALE,
            "scope": "experiment-local",
        }

    # 确定要生成的帧
    wanted = set(args.only or [])
    if wanted:
        unknown = wanted - set(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)
        if unknown:
            sys.exit(f"未知关键帧: {', '.join(sorted(unknown))}")
    else:
        wanted = set(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)

    # 构建 shot 索引
    shots = edit_lib._shot_index(shot_plan)
    kf_to_shot: dict[str, str] = {}
    kf_index: dict[str, dict] = {}
    for entry in plan.get("shots", []) or []:
        shot_id = entry.get("shot_id")
        for kf in entry.get("keyframes", []) or []:
            if isinstance(kf, dict):
                kf_id = kf.get("id")
                kf_index[kf_id] = kf
                kf_to_shot[kf_id] = shot_id

    targets_by_id = {
        t.get("keyframe_id"): t
        for t in run_doc.get("targets", []) or []
    }

    seed = args.seed or DEFAULT_SEED
    model = args.model or DEFAULT_MODEL
    size = args.size or DEFAULT_SIZE

    total_api_calls = 0
    MAX_TOTAL = 10
    MAX_PER_FRAME = 2

    # 按顺序处理
    for kf_id in edit_lib.DIAGNOSTIC_KEYFRAME_IDS:
        if kf_id not in wanted:
            continue
        if total_api_calls >= MAX_TOTAL:
            print(f"⚠ 已达到全局调用上限 {MAX_TOTAL} 次，停止", file=sys.stderr)
            break

        target = targets_by_id.get(kf_id)
        if target is None:
            print(f"⚠ 找不到 target {kf_id}，跳过", file=sys.stderr)
            continue

        existing_attempts = target.get("attempts") or []
        if len(existing_attempts) >= MAX_PER_FRAME and not args.force:
            print(f"  ↷ {kf_id}: 已有 {len(existing_attempts)} 次 attempt，跳过 (用 --force 覆盖)")
            continue

        kf = kf_index.get(kf_id, {})
        shot_id = kf_to_shot.get(kf_id, "")
        shot = shots.get(shot_id, {})

        # 确定基础图
        # shot-02-kf-04 的基础图是前一帧的云端输出
        # shot-03-kf-01 的基础图是 shot-02-kf-04 的云端输出
        base_image_path = _determine_base_image(
            kf_id, target, targets_by_id, scene_id, source_version, directory
        )
        if base_image_path is None:
            print(
                f"  ✗ {kf_id}: 找不到基础图 (上一帧可能未生成)，跳过",
                file=sys.stderr,
            )
            continue

        # 编译编辑指令
        attempt_num = len(existing_attempts) + 1
        attempt_id = f"attempt-{attempt_num:02d}"
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, shot_plan,
            identity_ref=identity_ref_path,
            base_image=base_image_path,
        )

        prompt_filename = f"{kf_id}-{attempt_id}.txt"
        prompt_path = directory / "prompts" / prompt_filename
        prompt_path.write_text(
            edit_lib.prompt_file_text(kf_id, attempt_id, instruction),
            encoding="utf-8",
        )

        # 构造输入图片列表
        if identity_ref_path != base_image_path:
            input_images = [identity_ref_path, base_image_path]
        else:
            input_images = [base_image_path]

        # bbox（可选）
        bbox_list_arg = None
        if args.bbox:
            # 格式: "x1,y1,x2,y2" 或 "x1,y1,x2,y2;x1,y1,x2,y2"
            try:
                bbox_list_arg = _parse_bbox(args.bbox, len(input_images))
            except ValueError as exc:
                sys.exit(f"--bbox 格式错误: {exc}")

        print(f"… 生成 {kf_id} (attempt {attempt_num})", flush=True)
        print(f"  基础图: {draft._rel(base_image_path)}")
        print(f"  输入图片: {len(input_images)} 张")

        total_api_calls += 1
        out_img_filename = f"{kf_id}-{attempt_id}.png"
        out_img_path = directory / "images" / out_img_filename

        attempt_record: dict = {
            "attempt": attempt_id,
            "model": model,
            "prompt": f"prompts/{prompt_filename}",
            "image": None,
            "request_id": None,
            "seed": seed,
            "bbox_list": bbox_list_arg,
            "status": "pending",
            "review": edit_lib.blank_attempt_review(),
        }

        try:
            img_bytes, trace = imagegen.edit(
                instruction,
                input_images,
                model=model,
                size=size,
                seed=seed,
                bbox_list=bbox_list_arg,
            )
        except Exception as exc:  # noqa: BLE001
            err_msg = str(exc)
            safe_msg = err_msg[:400].replace(
                os.environ.get("SCENELEX_ALIYUN_TOKEN_PLAN_KEY", "NOKEY"), "***"
            )
            print(f"  ✗ 生成失败: {safe_msg}", file=sys.stderr)
            attempt_record["status"] = "failed"
            attempt_record["error"] = {
                "http_status": _extract_http_status(err_msg),
                "message": safe_msg,
            }
            target.setdefault("attempts", []).append(attempt_record)
            _write_edit_run(directory, run_doc)
            continue

        out_img_path.write_bytes(img_bytes)
        attempt_record["image"] = f"images/{out_img_filename}"
        attempt_record["request_id"] = trace.get("request_id")
        attempt_record["status"] = "generated"
        target.setdefault("attempts", []).append(attempt_record)

        print(f"  ✓ {draft._rel(out_img_path)} ({len(img_bytes) // 1024} KB)")
        print(f"  request_id: {trace.get('request_id')}")

        _write_edit_run(directory, run_doc)

    # 更新 generated_at
    if run_doc.get("generation", {}).get("generated_at") is None:
        run_doc["generation"]["generated_at"] = (
            dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
        )
        _write_edit_run(directory, run_doc)

    review_path = _write_review(directory, run_doc, plan, shot_plan)
    print(f"\n✓ edit-run → {draft._rel(directory / EDIT_RUN_FILE)}")
    print(f"✓ review   → {draft._rel(review_path)}")
    print(f"  API 调用次数: {total_api_calls}/{MAX_TOTAL}")
    print(f"\n{edit_lib.REVIEW_LAYER}")
    print(edit_lib.REVIEW_NOT_FULL)
    print(edit_lib.REVIEW_NOT_VIDEO)


def _determine_base_image(
    kf_id: str,
    target: dict,
    targets_by_id: dict,
    scene_id: str,
    source_version: int,
    experiment_dir: Path,
) -> Path | None:
    """根据指令决定基础图来源。

    - shot-02-kf-03: v01/images/shot-02-kf-02.png (上一帧的 v01 图片)
    - shot-02-kf-04: shot-02-kf-03 的云端输出
    - shot-03-kf-01: shot-02-kf-04 的云端输出
    - shot-03-kf-03: v01/images/shot-03-kf-02.png
    """
    upstream_map = {
        "shot-02-kf-03": ("v01", "images/shot-02-kf-02.png"),
        "shot-02-kf-04": ("experiment", "shot-02-kf-03"),
        "shot-03-kf-01": ("experiment", "shot-02-kf-04"),
        "shot-03-kf-03": ("v01", "images/shot-03-kf-02.png"),
    }
    if kf_id not in upstream_map:
        return None

    source_type, source_ref = upstream_map[kf_id]
    if source_type == "v01":
        path = (
            ROOT
            / "data"
            / "drafts"
            / "image-keyframes"
            / scene_id
            / f"v{source_version:02d}"
            / source_ref
        )
        return path if path.exists() else None

    # experiment: 从上游诊断帧的选中 attempt 取图
    upstream_target = targets_by_id.get(source_ref, {})
    selected = upstream_target.get("selected_attempt")
    if selected:
        for att in upstream_target.get("attempts") or []:
            if att.get("attempt") == selected and att.get("image"):
                p = experiment_dir / att["image"]
                return p if p.exists() else None
    # 若未选中，取最后一次 generated 状态的 attempt
    for att in reversed(upstream_target.get("attempts") or []):
        if att.get("status") == "generated" and att.get("image"):
            p = experiment_dir / att["image"]
            if p.exists():
                return p
    return None


def _parse_bbox(bbox_str: str, image_count: int) -> list[list[list[int]]]:
    """解析 --bbox 参数为 bbox_list 结构。

    格式（针对最后一张输入图）:
        "x1,y1,x2,y2"
    """
    coords = [int(v.strip()) for v in bbox_str.split(",")]
    if len(coords) != 4:
        raise ValueError(f"需要 4 个整数 x1,y1,x2,y2，收到 {len(coords)} 个")
    x1, y1, x2, y2 = coords
    if x2 <= x1:
        raise ValueError(f"x2 ({x2}) 必须大于 x1 ({x1})")
    if y2 <= y1:
        raise ValueError(f"y2 ({y2}) 必须大于 y1 ({y1})")
    # bbox 作用在最后一张输入图（基础图）
    result: list[list[list[int]]] = [[] for _ in range(image_count)]
    result[-1] = [[x1, y1, x2, y2]]
    return result


# ---------------------------------------------------------------- review

def cmd_review(args: argparse.Namespace) -> None:
    """确定性重建 review.html。不调用 API，不修改 YAML，不清空人工审核。"""
    scene_id = args.scene_id.strip()
    directory, _ = _target_dir(scene_id, args.version)
    run_doc = _load_edit_run(directory)
    if run_doc is None:
        sys.exit(f"找不到 {draft._rel(directory / EDIT_RUN_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id,
        (run_doc.get("keyframe_plan_ref") or {}).get("version"),
    )
    path = _write_review(directory, run_doc, plan, shot_plan)
    print(f"✓ 审核页已写入 {draft._rel(path)} (浏览器直接打开)")
    print(f"\n{edit_lib.REVIEW_LAYER}")
    print(edit_lib.REVIEW_NOT_FULL)
    print(edit_lib.REVIEW_NOT_VIDEO)


# ---------------------------------------------------------------- validate

def cmd_validate(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    directory, _ = _target_dir(scene_id, args.version)
    run_doc = _load_edit_run(directory)
    if run_doc is None:
        sys.exit(f"找不到 {draft._rel(directory / EDIT_RUN_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id,
        (run_doc.get("keyframe_plan_ref") or {}).get("version"),
    )
    issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
    if issues:
        print(f"\n⚠ {len(issues)} 处问题:", file=sys.stderr)
        for issue in issues:
            print(f"  ✗ {issue}", file=sys.stderr)
        sys.exit(1)
    print(f"✓ {draft._rel(directory / EDIT_RUN_FILE)} 通过 gate 枚举、绑定、keyframe ID 与 selected_attempt 校验。")


# ---------------------------------------------------------------- show

def cmd_show(args: argparse.Namespace) -> None:
    scene_id = args.scene_id.strip()
    directory, _ = _target_dir(scene_id, args.version)
    run_doc = _load_edit_run(directory)
    if run_doc is None:
        sys.exit(f"找不到 {draft._rel(directory / EDIT_RUN_FILE)}")
    plan, shot_plan = _resolve_plans(
        scene_id,
        (run_doc.get("keyframe_plan_ref") or {}).get("version"),
    )

    gen = run_doc.get("generation") or {}
    ir = run_doc.get("identity_reference") or {}
    print(f"{scene_id} — Wan 2.7 状态编辑实验 v{run_doc.get('version', '?'):02d}")
    print(f"  shot_plan_ref    : v{(run_doc.get('shot_plan_ref') or {}).get('version')}")
    print(f"  keyframe_plan_ref: v{(run_doc.get('keyframe_plan_ref') or {}).get('version')}")
    print(f"  source_kf_ref    : v{(run_doc.get('source_image_keyframe_ref') or {}).get('version')}")
    print(f"  api_gate         : {run_doc.get('api_gate')}")
    print(f"  semantic_gate    : {run_doc.get('semantic_gate')}")
    print(f"  model            : {gen.get('primary_model')}")
    print(f"  endpoint         : {gen.get('endpoint_kind')}")
    print(f"  identity_ref     : {ir.get('image')} (scope={ir.get('scope')})")
    print()
    for target in run_doc.get("targets", []) or []:
        kf_id = target.get("keyframe_id")
        selected = target.get("selected_attempt")
        attempts = target.get("attempts") or []
        print(f"  {kf_id}:")
        print(f"    selected: {selected}")
        for att in attempts:
            review = att.get("review") or {}
            verdict_str = " | ".join(
                f"{d.replace('_', ' ')}={review.get(d, 'pending')}"
                for d in edit_lib.REVIEW_DIMS
            )
            print(f"    [{att.get('attempt')}] {att.get('status')} "
                  f"seed={att.get('seed')} request_id={att.get('request_id')}")
            print(f"      {verdict_str}")
    print()
    issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
    print(f"Validation: {'PASS' if not issues else f'{len(issues)} 处问题'}")
    for issue in issues:
        print(f"  ✗ {issue}", file=sys.stderr)
    if issues:
        sys.exit(1)


# ---------------------------------------------------------------- main

def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "SceneLex Image Keyframe Edits — "
            "Token Plan Wan 2.7 状态编辑实验"
        )
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    def add_common(p: argparse.ArgumentParser) -> None:
        p.add_argument("scene_id")
        p.add_argument("--version", "-v", type=int,
                       help="实验版本目录 (默认最新, 没有则 v01)")

    # smoke
    smoke_p = sub.add_parser("smoke", help="最小 smoke test: 验证 Token Plan 接受图片输入")
    add_common(smoke_p)
    smoke_p.add_argument("--source-image-version", type=int, default=1)
    smoke_p.add_argument("--keyframe-plan-version", type=int)
    smoke_p.add_argument("--model")
    smoke_p.add_argument("--seed", type=int)
    smoke_p.add_argument("--size")
    smoke_p.set_defaults(func=cmd_smoke)

    # generate
    gen_p = sub.add_parser("generate", help="生成四张诊断帧 (或 --only 指定的帧)")
    add_common(gen_p)
    gen_p.add_argument("--keyframe-plan-version", type=int)
    gen_p.add_argument("--source-image-version", type=int, default=1)
    gen_p.add_argument("--only", nargs="+", metavar="KEYFRAME_ID")
    gen_p.add_argument("--force", action="store_true",
                       help="覆盖已有 attempt (不覆盖 v01/ 图片)")
    gen_p.add_argument("--model")
    gen_p.add_argument("--seed", type=int)
    gen_p.add_argument("--size")
    gen_p.add_argument("--attempt", type=int,
                       help="尝试编号 (默认续接上次)")
    gen_p.add_argument("--bbox",
                       help="最后一张输入图的 bbox: x1,y1,x2,y2")
    gen_p.add_argument("--identity-ref",
                       help="身份参考图相对路径 (默认 images/shot-02-kf-02.png)")
    gen_p.add_argument("--identity-rationale",
                       help="身份参考图选择理由")
    gen_p.set_defaults(func=cmd_generate)

    # review
    rev_p = sub.add_parser("review", help="确定性重建 review.html")
    add_common(rev_p)
    rev_p.set_defaults(func=cmd_review)

    # validate
    val_p = sub.add_parser("validate", help="校验 edit-run.yaml")
    add_common(val_p)
    val_p.set_defaults(func=cmd_validate)

    # show
    show_p = sub.add_parser("show", help="人工阅读友好展开")
    add_common(show_p)
    show_p.set_defaults(func=cmd_show)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
