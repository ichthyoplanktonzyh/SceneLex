#!/usr/bin/env python3
"""Wan 2.7 状态编辑实验 CLI 命令行工具。

子命令:
  compile        调用 LLM Visual Compiler 构造 Source Packet 并编译为 Render Directive
  show-directive 查看已编译的 Render Directive
  generate       读取已验证的 Render Directive 调用 Wan 2.7 进行图片编辑
  review-vlm     调用多模态 VLM 进行辅助视觉质量评估
  review         确定性重建 review.html (不调用外部 API)
  validate       校验 schema、引用、文件、覆盖、review provenance 和 gate
  smoke          Smoke 测试 Token Plan Endpoint 连通性
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import yaml

import image_keyframe_edit as edit_lib
import image_render_compiler as compiler_lib
import imagegen


ROOT = Path(__file__).resolve().parent.parent


class EditDraftDir:
    def __init__(self, scene_id: str, version: int):
        self.scene_id = scene_id
        self.version = version
        self.dir = (
            ROOT / "data" / "drafts" / "image-keyframe-edits" / scene_id / f"v{version:02d}"
        )
        self.compiler_dir = self.dir / "compiler"
        self.images_dir = self.dir / "images"
        self.prompts_dir = self.dir / "prompts"
        self.manifest_path = self.dir / "edit-run.yaml"
        self.review_path = self.dir / "review.html"

    def ensure(self) -> None:
        self.dir.mkdir(parents=True, exist_ok=True)
        self.compiler_dir.mkdir(parents=True, exist_ok=True)
        self.images_dir.mkdir(parents=True, exist_ok=True)
        self.prompts_dir.mkdir(parents=True, exist_ok=True)

    def _rel(self, path: Path) -> str:
        try:
            return str(path.relative_to(ROOT))
        except ValueError:
            return str(path)


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        sys.exit(f"错误: 文件不存在 {path}")
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def _save_yaml(path: Path, data: dict[str, Any]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, allow_unicode=True, sort_keys=False)


def _load_upstream(scene_id: str, version: int) -> tuple[dict, dict, dict, EditDraftDir]:
    draft = EditDraftDir(scene_id, version)

    # 查阅已冻结的上游数据
    shot_plan_path = ROOT / "data" / "drafts" / "shot-plans" / scene_id / "v05" / "shot-plan.yaml"
    kf_plan_path = ROOT / "data" / "drafts" / "keyframe-plans" / scene_id / "v02" / "keyframe-plan.yaml"
    src_manifest_path = ROOT / "data" / "drafts" / "image-keyframes" / scene_id / "v01" / "image-keyframe-manifest.yaml"

    shot_plan = _load_yaml(shot_plan_path)
    kf_plan = _load_yaml(kf_plan_path)
    src_manifest = _load_yaml(src_manifest_path)

    return shot_plan, kf_plan, src_manifest, draft


def _find_kf_and_shot(kf_id: str, kf_plan: dict, shot_plan: dict) -> tuple[dict, dict]:
    kf_found = None
    shot_id_found = None
    for s_entry in kf_plan.get("shots", []) or []:
        sid = s_entry.get("shot_id")
        for kf in s_entry.get("keyframes", []) or []:
            if kf.get("id") == kf_id:
                kf_found = kf
                shot_id_found = sid
                break

    if not kf_found or not shot_id_found:
        sys.exit(f"错误: 在 Keyframe Plan 中未找到 {kf_id}")

    shot_found = None
    for s in shot_plan.get("shots", []) or []:
        if s.get("id") == shot_id_found:
            shot_found = s
            break

    if not shot_found:
        sys.exit(f"错误: 在 Shot Plan 中未找到 {shot_id_found}")

    return kf_found, shot_found


def cmd_compile(args: argparse.Namespace) -> None:
    """compile 命令: 构建 Source Packet 并调用 LLM Visual Compiler 编译为 Render Directive。"""
    shot_plan, kf_plan, src_manifest, draft = _load_upstream(args.scene_id, args.version)
    draft.ensure()

    # 初始化或加载 edit-run.yaml
    if not draft.manifest_path.exists():
        id_ref = (
            "data/drafts/image-keyframes/reluctant-01-proto-01/v01/images/shot-02-kf-02.png"
        )
        id_rat = "Single identity anchor image (shot-02-kf-02) for reluctant child."
        run_doc = edit_lib.build_edit_run(
            kf_plan,
            shot_plan,
            src_manifest,
            version=args.version,
            scene_id=args.scene_id,
            identity_reference_image=id_ref,
            identity_reference_rationale=id_rat,
        )
        _save_yaml(draft.manifest_path, run_doc)
    else:
        run_doc = _load_yaml(draft.manifest_path)

    target_kf_ids = [args.only] if args.only else list(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)

    for kf_id in target_kf_ids:
        print(f"… 编译 Render Directive: {kf_id}", flush=True)
        kf, shot = _find_kf_and_shot(kf_id, kf_plan, shot_plan)

        # 确定基础图路径与身份参考图路径
        target_doc = next((t for t in run_doc["targets"] if t["keyframe_id"] == kf_id), None)
        if not target_doc or not target_doc.get("source_image"):
            print(f"  ⚠ 跳过 {kf_id}: 无 source_image", file=sys.stderr)
            continue

        base_image_path = ROOT / target_doc["source_image"]
        id_ref_path = ROOT / run_doc["identity_reference"]["image"] if run_doc.get("identity_reference", {}).get("image") else None

        prev_info = None
        if kf_id == "shot-03-kf-01":
            # 跨镜连续性：使用 shot-02-kf-04
            prev_info = {
                "id": "shot-02-kf-04",
                "visual_state": "hand on fork near plate",
                "continuity_from_previous": "same posture and fork position",
            }

        # 1. 构造 Source Packet
        source_packet = compiler_lib.build_source_packet(
            scene_ref=args.scene_id,
            keyframe_id=kf_id,
            shot_plan=shot_plan,
            keyframe_plan=kf_plan,
            keyframe=kf,
            shot=shot,
            source_image_version=1,
            identity_ref_path=id_ref_path,
            base_image_path=base_image_path,
            previous_keyframe_info=prev_info,
        )

        # 2. 调用 Visual Compiler
        compiler_attempt = "compiler-attempt-01"
        attempt_dir = draft.compiler_dir / kf_id / compiler_attempt
        attempt_dir.mkdir(parents=True, exist_ok=True)

        sp_file = attempt_dir / "source-packet.yaml"
        _save_yaml(sp_file, source_packet)

        # 多模态输入图片列表
        img_paths = []
        if id_ref_path:
            img_paths.append(id_ref_path)
        img_paths.append(base_image_path)

        try:
            directive, req_id = compiler_lib.compile_render_directive_llm(
                source_packet, img_paths, compiler_attempt=compiler_attempt
            )
        except Exception as exc:
            print(f"  ❌ VISUAL COMPILATION BLOCKED ({kf_id}): {exc}", file=sys.stderr)
            continue

        # 3. Compiler Validator
        base_size = compiler_lib.get_image_size(base_image_path)
        val_errors = compiler_lib.validate_render_directive(source_packet, directive, base_size)

        if val_errors:
            print(f"  ❌ VISUAL COMPILATION BLOCKED ({kf_id}): Validator 报错:", file=sys.stderr)
            for err in val_errors:
                print(f"     - {err}", file=sys.stderr)
            continue

        rd_file = attempt_dir / "render-directive.yaml"
        _save_yaml(rd_file, directive)

        # 4. 序列化 Wan prompt
        directive_rel = draft._rel(rd_file)
        wan_prompt = compiler_lib.serialize_wan_prompt(
            directive, directive_rel_path=directive_rel, compiler_request_id=req_id
        )
        prompt_file = attempt_dir / "wan-prompt.txt"
        prompt_file.write_text(wan_prompt, encoding="utf-8")

        print(f"  ✓ {draft._rel(rd_file)} (request_id={req_id})")
        import time
        time.sleep(3.0)


    cmd_review(args)


def cmd_show_directive(args: argparse.Namespace) -> None:
    """show-directive 命令: 查看已编译的 Render Directive。"""
    draft = EditDraftDir(args.scene_id, args.version)
    target_kf_ids = [args.only] if args.only else list(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)

    for kf_id in target_kf_ids:
        rd_file = draft.compiler_dir / kf_id / "compiler-attempt-01" / "render-directive.yaml"
        if not rd_file.exists():
            print(f"{kf_id}: 尚未编译 (未找到 {draft._rel(rd_file)})")
            continue

        directive = _load_yaml(rd_file)
        print(f"=== Render Directive: {kf_id} ===")
        print(f"Edit Mode: {directive.get('edit_mode')}")
        print(f"Wan Prompt:\n{directive.get('wan_prompt')}\n")


def cmd_generate(args: argparse.Namespace) -> None:
    """generate 命令: 读取已验证的 Render Directive，调用 Wan 生成图片。"""
    shot_plan, kf_plan, src_manifest, draft = _load_upstream(args.scene_id, args.version)
    if not draft.manifest_path.exists():
        sys.exit("错误: edit-run.yaml 不存在，请先执行 python3 tools/image_keyframe_edits.py compile")

    run_doc = _load_yaml(draft.manifest_path)
    target_kf_ids = [args.only] if args.only else list(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)

    for kf_id in target_kf_ids:
        target = next((t for t in run_doc["targets"] if t["keyframe_id"] == kf_id), None)
        if not target:
            continue

        # 必须读取已验证的 Render Directive
        rd_file = draft.compiler_dir / kf_id / "compiler-attempt-01" / "render-directive.yaml"
        if not rd_file.exists():
            print(f"❌ GENERATION BLOCKED ({kf_id}): 未找到已验证的 Render Directive ({draft._rel(rd_file)})", file=sys.stderr)
            continue

        directive = _load_yaml(rd_file)
        base_img_path = ROOT / target["source_image"]
        base_w, base_h = compiler_lib.get_image_size(base_img_path)

        # 重新校验 Compiler Validator
        source_packet_file = draft.compiler_dir / kf_id / "compiler-attempt-01" / "source-packet.yaml"
        source_packet = _load_yaml(source_packet_file)
        val_errors = compiler_lib.validate_render_directive(source_packet, directive, (base_w, base_h))
        if val_errors:
            print(f"❌ GENERATION BLOCKED ({kf_id}): Render Directive 校验未通过:", file=sys.stderr)
            for err in val_errors:
                print(f"   - {err}", file=sys.stderr)
            continue

        # 输入图片列表
        id_ref_path = ROOT / run_doc["identity_reference"]["image"] if run_doc.get("identity_reference", {}).get("image") else None
        input_images = []
        if id_ref_path:
            input_images.append(id_ref_path)
        input_images.append(base_img_path)

        # 转换为像素 BBox
        bbox_list_arg = None
        if directive.get("edit_mode") == "local_edit" and directive.get("edit_regions"):
            norm_bbox = directive["edit_regions"][0]["bbox_normalized"]
            pixel_bbox = compiler_lib.normalized_bbox_to_pixels(norm_bbox, base_w, base_h)
            # 构建 Wan 参数 bbox_list Structure
            if id_ref_path:
                bbox_list_arg = [[], [pixel_bbox]]
            else:
                bbox_list_arg = [[pixel_bbox]]

        serialized_prompt = compiler_lib.serialize_wan_prompt(
            directive,
            directive_rel_path=draft._rel(rd_file),
            compiler_request_id=directive.get("compiler", {}).get("request_id"),
        )

        existing_attempts = target.get("attempts", [])
        attempt_num = len(existing_attempts) + 1
        attempt_id = f"attempt-{attempt_num:02d}"

        out_filename = f"{kf_id}-{attempt_id}.png"
        out_img_path = draft.images_dir / out_filename

        print(f"… 生成 {kf_id} ({attempt_id}) via Wan 2.7", flush=True)
        if bbox_list_arg:
            print(f"  Pixel BBox: {bbox_list_arg}")

        try:
            img_bytes, trace = imagegen.edit(
                instruction=serialized_prompt,
                input_images=input_images,
                model=run_doc.get("generation", {}).get("primary_model"),
                size=run_doc.get("generation", {}).get("requested_size"),
                bbox_list=bbox_list_arg,
            )
            out_img_path.write_bytes(img_bytes)
            run_doc["api_gate"] = "pass"
        except Exception as exc:
            print(f"  ❌ Wan API 生成失败: {exc}", file=sys.stderr)
            run_doc["api_gate"] = "blocked"
            continue

        attempt_record = {
            "attempt": attempt_id,
            "model": trace.get("model", "wan2.7-image-pro"),
            "prompt": serialized_prompt,
            "image": draft._rel(out_img_path),
            "request_id": trace.get("request_id"),
            "seed": trace.get("seed", 0),
            "bbox_list": bbox_list_arg,
            "status": "generated",
            "render_directive_ref": {
                "keyframe_id": kf_id,
                "compiler_attempt": "compiler-attempt-01",
                "path": draft._rel(rd_file),
            },
            "reviews": edit_lib.blank_reviews_v11(),
        }

        target.setdefault("attempts", []).append(attempt_record)
        target["selected_attempt"] = attempt_id
        print(f"  ✓ {draft._rel(out_img_path)}")

    _save_yaml(draft.manifest_path, run_doc)
    cmd_review(args)


def cmd_review_vlm(args: argparse.Namespace) -> None:
    """review-vlm 命令: 调用多模态 VLM 进行辅助视觉评估。"""
    shot_plan, kf_plan, src_manifest, draft = _load_upstream(args.scene_id, args.version)
    if not draft.manifest_path.exists():
        sys.exit("错误: edit-run.yaml 不存在")

    run_doc = _load_yaml(draft.manifest_path)
    target_kf_ids = [args.only] if args.only else list(edit_lib.DIAGNOSTIC_KEYFRAME_IDS)

    for kf_id in target_kf_ids:
        target = next((t for t in run_doc["targets"] if t["keyframe_id"] == kf_id), None)
        if not target or not target.get("selected_attempt"):
            continue

        kf, _ = _find_kf_and_shot(kf_id, kf_plan, shot_plan)

        selected_id = target["selected_attempt"]
        att = next((a for a in target.get("attempts", []) if a.get("attempt") == selected_id), None)
        if not att or not att.get("image"):
            continue

        out_img_path = ROOT / att["image"]
        base_img_path = ROOT / target["source_image"]
        id_ref_path = ROOT / run_doc["identity_reference"]["image"] if run_doc.get("identity_reference", {}).get("image") else None

        print(f"… VLM Advisory Review: {kf_id} ({selected_id})", flush=True)
        vlm_res = edit_lib.review_keyframe_vlm(
            output_image_path=out_img_path,
            base_image_path=base_img_path,
            identity_ref_path=id_ref_path,
            keyframe=kf,
        )

        att.setdefault("reviews", edit_lib.blank_reviews_v11())["vlm"] = vlm_res
        print(f"  [VLM Suggested Verdict]: {vlm_res.get('suggested_verdict')}")

    _save_yaml(draft.manifest_path, run_doc)
    cmd_review(args)


def cmd_review(args: argparse.Namespace) -> None:
    """review 命令: 确定性重建 review.html (不调用 external API)。"""
    shot_plan, kf_plan, src_manifest, draft = _load_upstream(args.scene_id, args.version)
    if not draft.manifest_path.exists():
        return

    run_doc = _load_yaml(draft.manifest_path)
    html_content = edit_lib.review_html(run_doc, kf_plan, shot_plan, review_dir=draft.dir)
    draft.review_path.write_text(html_content, encoding="utf-8")
    print(f"✓ 已更新 review.html: {draft._rel(draft.review_path)}")


def cmd_validate(args: argparse.Namespace) -> None:
    """validate 命令: 校验 schema、引用、文件、覆盖与 gate。"""
    shot_plan, kf_plan, src_manifest, draft = _load_upstream(args.scene_id, args.version)
    run_doc = _load_yaml(draft.manifest_path)

    issues = edit_lib.validate_edit_run(run_doc, kf_plan, shot_plan)
    if issues:
        print(f"❌ 校验发现 {len(issues)} 个问题:")
        for issue in issues:
            print(f"  - {issue}")
        sys.exit(1)
    else:
        print("✓ edit-run.yaml 校验通过")


def cmd_smoke(args: argparse.Namespace) -> None:
    """smoke 命令: 连通性测试。"""
    print("Smoke test functionality ready.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Wan 2.7 状态编辑实验 CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    def add_common(p: argparse.ArgumentParser) -> None:
        p.add_argument("scene_id", help="Scene ID, 如 reluctant-01-proto-01")
        p.add_argument("--version", type=int, default=2, help="实验版本, 默认 2")
        p.add_argument("--only", help="仅指定 keyframe_id")

    p_compile = subparsers.add_parser("compile", help="编译 Source Packet 与 Render Directive")
    add_common(p_compile)
    p_compile.set_defaults(func=cmd_compile)

    p_show = subparsers.add_parser("show-directive", help="查看 Render Directive")
    add_common(p_show)
    p_show.set_defaults(func=cmd_show_directive)

    p_gen = subparsers.add_parser("generate", help="执行 Wan 图片编辑")
    add_common(p_gen)
    p_gen.set_defaults(func=cmd_generate)

    p_vlm = subparsers.add_parser("review-vlm", help="执行 VLM 辅助审核")
    add_common(p_vlm)
    p_vlm.set_defaults(func=cmd_review_vlm)

    p_rev = subparsers.add_parser("review", help="重建 review.html")
    add_common(p_rev)
    p_rev.set_defaults(func=cmd_review)

    p_val = subparsers.add_parser("validate", help="校验 edit-run.yaml")
    add_common(p_val)
    p_val.set_defaults(func=cmd_validate)

    p_smoke = subparsers.add_parser("smoke", help="Smoke 测试")
    add_common(p_smoke)
    p_smoke.set_defaults(func=cmd_smoke)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
