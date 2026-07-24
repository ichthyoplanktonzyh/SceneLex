#!/usr/bin/env python3
"""Wan 2.7 状态编辑实验的领域库 (v02 Visual Compiler 与 多模态 VLM 审核链路)。

职责边界:
- SceneLex IR 是语义权威
- LLM Visual Compiler 是视觉翻译器 (产生结构化 Render Directive)
- Compiler Validator 是确定性验证器 (校验 Schema、语义全覆盖、无状态冲突、BBox 合法)
- Wan 2.7 Prompt Serializer 是确定性 Prompt 序列化器
- Wan 2.7 是渲染执行器
- VLM 是多模态辅助审核器 (仅提供 suggested_verdict)
- Human 决定最终 semantic_gate
"""

from __future__ import annotations

import html
import json
import os
import sys
from pathlib import Path
from typing import Any

import jsonschema
import yaml

import image_render_compiler as compiler_lib

ROOT = Path(__file__).resolve().parent.parent

SCHEMA_VERSION_V10 = "1.0"
SCHEMA_VERSION_V11 = "1.1"
STATUS_DRAFT = "draft"

# 审核层级标注
REVIEW_LAYER = "WAN 2.7 CLOUD IMAGE STATE-EDIT REVIEW"
REVIEW_NOT_FULL = "NOT FULL IMAGE-KEYFRAME REVIEW"
REVIEW_NOT_VIDEO = "NOT VIDEO MOTION REVIEW"

# Gate 枚举
API_GATE_VALUES = ("pending", "pass", "blocked")
SEMANTIC_GATE_VALUES = ("pending", "pass", "revision_required", "not_run")
VLM_SUGGESTED_VALUES = ("pending", "pass", "revision_required", None)

# 每个 attempt 的状态枚举
ATTEMPT_STATUS_VALUES = ("generated", "failed", "pending")

# 审核维度
REVIEW_DIMS = (
    "semantic_readability",
    "state_fidelity",
    "character_consistency",
    "prop_continuity",
    "composition",
)
VERDICT_VALUES = ("pending", "pass", "weak", "fail")

# 跨镜连续性人工核对清单
CONTINUITY_CHECKS = (
    "same child identity",
    "same clothing",
    "same right hand on fork",
    "same fork orientation",
    "same fork position near plate",
    "tines not inserted into food",
    "same torso recline",
    "same gaze direction",
    "same screen direction",
    "same plate position",
    "same food arrangement",
    "mother still at left",
    "mother touching nothing",
)

# 四张诊断帧的 keyframe ID
DIAGNOSTIC_KEYFRAME_IDS = (
    "shot-02-kf-03",
    "shot-02-kf-04",
    "shot-03-kf-01",
    "shot-03-kf-03",
)

NO_TEACHING_PACKAGING = (
    "The image contains no words, letters, subtitles, captions, definitions, "
    "vocabulary labels, narration text, speech bubbles or interface overlays. "
    "Do not show the word 'reluctant' or any other vocabulary label in the image."
)

CROSS_SHOT_PAIR = ("shot-02-kf-04", "shot-03-kf-01")


def _text(value: object) -> str:
    return value.strip() if isinstance(value, str) else ""


def _lines(values: object) -> list[str]:
    if not isinstance(values, list):
        return []
    return [_text(item) for item in values if _text(item)]


def _join(values: list[str]) -> str:
    return " ".join(
        v if v.endswith((".", "!", "?")) else v + "." for v in values
    )


def _shot_index(shot_plan: dict) -> dict[str, dict]:
    return {
        shot.get("id"): shot
        for shot in shot_plan.get("shots", []) or []
        if isinstance(shot, dict)
    }


def _continuity_block(shot_plan: dict) -> str:
    parts: list[str] = []
    cast = [
        f"{entry.get('id')} ({entry.get('role')}) — "
        f"{_text(entry.get('continuity_description'))}"
        for entry in shot_plan.get("cast", []) or []
        if isinstance(entry, dict)
    ]
    if cast:
        parts.append("CAST — " + " ".join(cast))
    location = shot_plan.get("location")
    if isinstance(location, dict):
        parts.append("LOCATION — " + _text(location.get("continuity_description")))
    props = [
        f"{entry.get('id')} — {_text(entry.get('continuity_description'))}"
        for entry in shot_plan.get("props", []) or []
        if isinstance(entry, dict)
    ]
    if props:
        parts.append("PROPS — " + " ".join(props))
    return "\n\n".join(p for p in parts if p.strip(" —"))


def compile_edit_instruction(
    keyframe: dict,
    shot: dict,
    shot_plan: dict,
    *,
    identity_ref: Path | None = None,
    base_image: Path | None = None,
) -> str:
    """机械拼装 Context (供 Source Packet 与兼容层使用)。"""
    composition = shot.get("composition") or {}
    camera = shot.get("camera") or {}

    if identity_ref is not None and identity_ref != base_image:
        roles_text = (
            "Image 1 is an experiment-local identity reference for the child. "
            "Image 2 is the base frame to edit. "
            "The output must preserve the composition and aspect ratio of Image 2."
        )
    else:
        roles_text = (
            "Image 1 is the base frame to edit. "
            "The output must preserve the composition and aspect ratio of Image 1."
        )

    framing = " ".join(
        v for v in (
            f"{_text(composition.get('shot_size'))}, "
            f"{_text(composition.get('angle'))} angle.",
            _text(composition.get("focal_subject")),
            _text(composition.get("staging")),
            f"Camera {_text(camera.get('movement'))}.",
        )
        if v.strip(" .,")
    )
    continuity = _continuity_block(shot_plan)
    preserve_parts = []
    if framing.strip(" .,"):
        preserve_parts.append(f"Preserve the framing: {framing}")
    if continuity.strip():
        preserve_parts.append(continuity)
    preserve_text = "\n\n".join(preserve_parts) if preserve_parts else (
        "Preserve the same child identity, facial features, age, hairstyle, "
        "clothing, mother, dining table, plate, broccoli, fork, visual style, "
        "lighting, screen direction and camera position."
    )

    visual_state = _text(keyframe.get("visual_state"))
    change_text = visual_state
    shows = _lines(keyframe.get("must_show"))
    state_text = _join(shows) if shows else visual_state
    avoids = _lines(keyframe.get("must_avoid"))
    forbidden_text = _join(avoids) if avoids else (
        "Do not show subtitles, labels, speech bubbles, UI or teaching overlays."
    )

    sections = [
        f"IMAGE ROLES\n\n{roles_text}",
        f"PRESERVE EXACTLY\n\n{preserve_text}",
        f"CHANGE ONLY\n\n{change_text}",
        f"TARGET FROZEN STATE\n\n{state_text}",
    ]

    if shows:
        sections.append(f"MUST BE CLEARLY VISIBLE\n\n{_join(shows)}")

    sections.append(f"FORBIDDEN OUTCOMES\n\n{forbidden_text}")
    sections.append(f"NO TEACHING PACKAGING\n\n{NO_TEACHING_PACKAGING}")

    return "\n\n".join(sections)


def blank_verdict_set() -> dict[str, str]:
    return {dim: "pending" for dim in REVIEW_DIMS}


def blank_attempt_review() -> dict[str, Any]:
    """v1.0 schema 兼容用 review 对象。"""
    return {dim: "pending" for dim in REVIEW_DIMS} | {"notes": []}


def blank_reviews_v11() -> dict[str, Any]:
    """v1.1 schema 用 reviews 对象。"""
    return {
        "vlm": {
            "status": "pending",
            "protocol": None,
            "model": None,
            "request_id": None,
            "generated_at": None,
            "suggested_verdict": "pending",
            "verdicts": blank_verdict_set(),
            "findings": [],
            "notes": [],
        },
        "human": {
            "status": "pending",
            "reviewer": None,
            "reviewed_at": None,
            "verdicts": blank_verdict_set(),
            "notes": [],
        },
    }


def blank_target(keyframe_id: str) -> dict:
    return {
        "keyframe_id": keyframe_id,
        "source_image": None,
        "identity_reference": None,
        "attempts": [],
        "selected_attempt": None,
    }


def build_edit_run(
    plan: dict,
    shot_plan: dict,
    source_keyframe_manifest: dict,
    *,
    version: int = 2,
    scene_id: str = "reluctant-01-proto-01",
    identity_reference_image: str | None = None,
    identity_reference_rationale: str | None = None,
    primary_model: str = "wan2.7-image-pro",
    fallback_model: str = "wan2.7-image",
    requested_size: str = "1152*640",
) -> dict:
    """构造 edit-run.yaml 初始结构。"""
    schema_ver = SCHEMA_VERSION_V11 if version >= 2 else SCHEMA_VERSION_V10
    shot_plan_ref = plan.get("shot_plan_ref") or {}
    targets = []

    src_version = source_keyframe_manifest.get("version", 1)
    src_dir = f"data/drafts/image-keyframes/{scene_id}/v{src_version:02d}"

    for kf_id in DIAGNOSTIC_KEYFRAME_IDS:
        target = blank_target(kf_id)
        for frame in source_keyframe_manifest.get("frames", []) or []:
            if frame.get("keyframe_id") == kf_id:
                img_rel = frame.get("image")
                if img_rel and not img_rel.startswith("data/"):
                    img_rel = f"{src_dir}/{img_rel}"
                target["source_image"] = img_rel
                break
        target["identity_reference"] = identity_reference_image
        targets.append(target)


    return {
        "schema_version": schema_ver,
        "version": version,
        "status": STATUS_DRAFT,
        "scene_ref": scene_id,
        "shot_plan_ref": {
            "scene_id": shot_plan_ref.get("scene_id") or scene_id,
            "version": shot_plan_ref.get("version"),
        },
        "keyframe_plan_ref": {
            "scene_id": plan.get("scene_ref") or scene_id,
            "version": plan.get("version"),
        },
        "source_image_keyframe_ref": {
            "scene_id": source_keyframe_manifest.get("scene_ref") or scene_id,
            "version": source_keyframe_manifest.get("version"),
        },
        "api_gate": "pending",
        "semantic_gate": "pending",
        "generation": {
            "protocol": "aliyun-token-plan",
            "endpoint_kind": "token-plan-beijing",
            "primary_model": primary_model,
            "fallback_model": fallback_model,
            "requested_size": requested_size,
            "watermark": False,
            "generated_at": None,
        },
        "identity_reference": {
            "image": identity_reference_image,
            "rationale": identity_reference_rationale,
            "scope": "experiment-local",
        },
        "targets": targets,
    }


_VLM_SYSTEM_PROMPT = """You are an automated VLM (Vision Language Model) Advisory Evaluator for keyframe generation.
Analyze the generated keyframe against the base image and reference image.

Target Visual State: {visual_state}
Must Show Requirements: {must_show}
Must Avoid Requirements: {must_avoid}

Evaluate strictly for:
1. semantic_readability (pass/weak/fail)
2. state_fidelity (pass/weak/fail)
3. character_consistency (pass/weak/fail)
4. prop_continuity (pass/weak/fail)
5. composition (pass/weak/fail)

Check for ghosting artifacts (e.g. duplicate fork on table), bad hand anatomy, character drift, or unwanted expressions.

Output JSON format strictly:
{
  "verdicts": {
    "semantic_readability": "pass|weak|fail",
    "state_fidelity": "pass|weak|fail",
    "character_consistency": "pass|weak|fail",
    "prop_continuity": "pass|weak|fail",
    "composition": "pass|weak|fail"
  },
  "suggested_verdict": "pass|revision_required",
  "findings": [
    {
      "criterion_id": "show-01",
      "verdict": "pass|weak|fail",
      "evidence": "..."
    }
  ],
  "notes": ["note 1..."]
}"""


def review_keyframe_vlm(
    output_image_path: Path,
    base_image_path: Path,
    identity_ref_path: Path | None,
    keyframe: dict[str, Any],
    *,
    previous_pass_path: Path | None = None,
) -> dict[str, Any]:
    """Invoke Multimodal VLM Advisory Reviewer on generated keyframe image.
    Returns reviews.vlm dict for schema v1.1.
    """
    import llm
    input_images = []
    if identity_ref_path and identity_ref_path.exists():
        input_images.append(identity_ref_path)
    if base_image_path and base_image_path.exists():
        input_images.append(base_image_path)
    if previous_pass_path and previous_pass_path.exists():
        input_images.append(previous_pass_path)
    input_images.append(output_image_path)

    shows_str = json.dumps(keyframe.get("must_show", []), ensure_ascii=False)
    avoids_str = json.dumps(keyframe.get("must_avoid", []), ensure_ascii=False)

    sys_prompt = _VLM_SYSTEM_PROMPT.format(
        visual_state=keyframe.get("visual_state", ""),
        must_show=shows_str,
        must_avoid=avoids_str,
    )

    prompt = (
        f"Please evaluate generated keyframe image {output_image_path.name} "
        "against base image and target criteria."
    )

    vlm_config = llm.LLMConfig.from_env(prefix="SCENELEX_VLM_REVIEW_")

    try:
        result = llm.invoke_multimodal(
            prompt=prompt,
            images=input_images,
            config=vlm_config,
            system_prompt=sys_prompt,
        )
        cleaned = result.text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
        doc = json.loads(cleaned)

        verdicts = doc.get("verdicts") or blank_verdict_set()
        findings = doc.get("findings") or []
        notes = doc.get("notes") or []
        suggested = doc.get("suggested_verdict") or "revision_required"

        return {
            "status": "completed",
            "protocol": result.protocol,
            "model": result.model,
            "request_id": result.request_id,
            "generated_at": None,
            "suggested_verdict": suggested,
            "verdicts": verdicts,
            "findings": findings,
            "notes": notes,
        }
    except Exception as exc:
        print(f"⚠ VLM Reviewer call failed/skipped: {exc}", file=sys.stderr)
        return {
            "status": "failed",
            "protocol": getattr(vlm_config, "protocol", None),
            "model": getattr(vlm_config, "model", None),
            "request_id": None,
            "generated_at": None,
            "suggested_verdict": "revision_required",
            "verdicts": blank_verdict_set(),
            "findings": [],
            "notes": [f"VLM review execution error: {exc}"],
        }


def validate_edit_run(
    run_doc: dict,
    plan: dict,
    shot_plan: dict,
) -> list[str]:
    """Validate edit-run document against schema v1.0 or v1.1."""
    issues: list[str] = []
    schema_ver = str(run_doc.get("schema_version"))

    # Load appropriate schema
    schema_path = (
        ROOT / "schema" / "image-keyframe-edit-run-v1.1.schema.json"
        if schema_ver == "1.1"
        else ROOT / "schema" / "image-keyframe-edit-run.schema.json"
    )

    if schema_path.exists():
        with open(schema_path, encoding="utf-8") as f:
            schema = json.load(f)
        try:
            jsonschema.validate(instance=run_doc, schema=schema)
        except jsonschema.ValidationError as exc:
            issues.append(f"JSON Schema error: {exc.message}")

    api_gate = run_doc.get("api_gate")
    if api_gate not in API_GATE_VALUES:
        issues.append(f"api_gate {api_gate!r} 不在允许范围 {API_GATE_VALUES}")

    sem_gate = run_doc.get("semantic_gate")
    if sem_gate not in SEMANTIC_GATE_VALUES:
        issues.append(f"semantic_gate {sem_gate!r} 不在允许范围 {SEMANTIC_GATE_VALUES}")

    ir = run_doc.get("identity_reference") or {}
    if ir.get("scope") not in (None, "experiment-local"):
        issues.append("identity_reference.scope 必须是 'experiment-local'")

    sp_ref = run_doc.get("shot_plan_ref") or {}
    if sp_ref.get("version") != 5:
        issues.append(f"shot_plan_ref.version 应为 5, 实际为 {sp_ref.get('version')}")

    kp_ref = run_doc.get("keyframe_plan_ref") or {}
    if kp_ref.get("version") != 2:
        issues.append(f"keyframe_plan_ref.version 应为 2, 实际为 {kp_ref.get('version')}")

    src_ref = run_doc.get("source_image_keyframe_ref") or {}
    if src_ref.get("version") != 1:
        issues.append(f"source_image_keyframe_ref.version 应为 1, 实际为 {src_ref.get('version')}")


    for target in run_doc.get("targets", []) or []:
        kf_id = target.get("keyframe_id", "?")
        selected = target.get("selected_attempt")
        if selected is not None:
            attempt_ids = [a.get("attempt") for a in target.get("attempts", []) or []]
            if selected not in attempt_ids:
                issues.append(
                    f"{kf_id}: selected_attempt={selected!r} 不在 attempts 列表中 {attempt_ids}"
                )

    run_text = yaml.safe_dump(run_doc, allow_unicode=True)
    for forbidden in ("Authorization:", "sk-sp-", "data:image/"):
        if forbidden in run_text:
            issues.append(
                f"edit-run YAML 含有禁止内容 {forbidden!r} (API Key / Base64 / Authorization Header)"
            )

    return issues


_STYLE = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin: 0; padding: 24px; font: 15px/1.55 -apple-system, "Helvetica Neue",
       "PingFang SC", "Microsoft YaHei", sans-serif; background: #14161a; color: #e8eaed; }
h1 { font-size: 19px; margin: 0 0 4px; }
.sub { color: #9aa0a6; font-size: 13px; margin-bottom: 16px; }
.warn { border: 1px solid #b3541e; background: #2a1a0d; color: #ffb782;
        padding: 12px 14px; border-radius: 6px; margin-bottom: 18px; font-size: 13px; }
.warn b { display: block; letter-spacing: .04em; margin-bottom: 4px; color: #ffd0a3; font-size: 14px; }
.note { border: 1px solid #2d4a6e; background: #0d1e30; color: #a8caf0;
        padding: 10px 14px; border-radius: 6px; margin-bottom: 14px; font-size: 12px; }
.section { border-top: 2px solid #3a4048; margin-top: 24px; padding-top: 12px; }
.section h2 { font-size: 15px; margin: 0 0 12px; }
.section h2 span { color: #9aa0a6; font-weight: 400; font-size: 13px; margin-left: 8px; }
.target { background: #1b1f25; border: 1px solid #333940; border-radius: 6px;
          padding: 16px; margin-bottom: 16px; }
.target-id { font-family: ui-monospace, Menlo, monospace; font-size: 13px; color: #7aa2f7;
             margin-bottom: 10px; }
.images { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 12px; }
.imgbox { flex: 1 1 300px; }
.imgbox figcaption { font-size: 11px; color: #9aa0a6; margin-bottom: 4px;
                     font-family: ui-monospace, Menlo, monospace; }
.imgbox img { width: 100%; border-radius: 4px; display: block; background: #0e1013; }
.missing { border: 1px dashed #b3541e; color: #ffb782; padding: 24px; text-align: center;
           border-radius: 4px; font-size: 13px; }
.meta { font-size: 12px; color: #9aa0a6; margin-bottom: 10px; font-family: ui-monospace, Menlo, monospace; }
.why { font-size: 12.5px; color: #9aa0a6; margin-top: 10px; }
.why b { color: #b8c0cc; font-weight: 600; }
ul { margin: 4px 0 0; padding-left: 18px; font-size: 12.5px; color: #9aa0a6; }
ul.avoid { color: #d99a9a; }
.verdicts { margin-top: 10px; font-size: 12px; }
.v { display: inline-block; padding: 1px 7px; border-radius: 10px; margin-right: 5px;
     background: #2d3440; color: #b8c0cc; }
.v.pass { background: #1d3324; color: #93d3a6; }
.v.weak { background: #38310f; color: #e2c86a; }
.v.fail { background: #3a1e1e; color: #f09a9a; }
.v.pending { background: #2d3440; color: #7f868e; }
.notes-list { font-size: 12px; color: #cdd2d8; margin-top: 6px; padding-left: 18px; }
.pair { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 12px; }
.pair figure { flex: 1 1 380px; margin: 0; }
.pair img { width: 100%; border-radius: 4px; display: block; }
.pair figcaption { font-family: ui-monospace, Menlo, monospace; font-size: 12px;
                   color: #7aa2f7; margin-bottom: 6px; }
table.checks { border-collapse: collapse; margin-top: 12px; font-size: 12.5px; }
table.checks td { border: 1px solid #333940; padding: 4px 10px; color: #b8c0cc; }
table.checks td:first-child { color: #9aa0a6; }
.gate-box { margin-top: 20px; padding: 12px 16px; border-radius: 6px;
            font-size: 14px; font-weight: 600; letter-spacing: .03em; }
.gate-pass { background: #1d3324; color: #93d3a6; border: 1px solid #2a5c38; }
.gate-block { background: #3a1e1e; color: #f09a9a; border: 1px solid #6e2828; }
.gate-rev { background: #38310f; color: #e2c86a; border: 1px solid #6a5a12; }
.gate-pend { background: #2d3440; color: #9aa0a6; border: 1px solid #3a4048; }
.code-block { background: #0d1015; border: 1px solid #282e36; padding: 10px; border-radius: 4px;
              font-family: ui-monospace, Menlo, monospace; font-size: 11px; white-space: pre-wrap; margin-top: 6px; color: #a6acb8; }
"""


def _esc(value: object) -> str:
    return html.escape("" if value is None else str(value))


def _rel_path(asset_path_str: str | None, base_dir: Path) -> str:
    if not asset_path_str:
        return ""
    path = Path(asset_path_str)
    if not path.is_absolute():
        path = ROOT / path
    try:
        return os.path.relpath(path, base_dir)
    except Exception:
        return asset_path_str


def review_html(
    run_doc: dict,
    plan: dict,
    shot_plan: dict,
    *,
    review_dir: Path | None = None,
) -> str:
    """Generate browser-viewable review.html with relative asset paths and VLM vs Human separation."""
    base_dir = review_dir or (ROOT / "data" / "drafts" / "image-keyframe-edits" / run_doc.get("scene_ref", "reluctant-01-proto-01") / f"v{run_doc.get('version', 2):02d}")
    shots = _shot_index(shot_plan)

    targets_by_id: dict[str, dict] = {
        t.get("keyframe_id"): t
        for t in run_doc.get("targets", []) or []
    }

    kf_index: dict[str, dict] = {}
    kf_shot: dict[str, str] = {}
    for entry in plan.get("shots", []) or []:
        shot_id = entry.get("shot_id")
        for kf in entry.get("keyframes", []) or []:
            if isinstance(kf, dict):
                kf_id = kf.get("id")
                kf_index[kf_id] = kf
                kf_shot[kf_id] = shot_id

    gen = run_doc.get("generation") or {}
    ir = run_doc.get("identity_reference") or {}
    api_gate = run_doc.get("api_gate", "pending")
    sem_gate = run_doc.get("semantic_gate", "pending")
    schema_ver = run_doc.get("schema_version", "1.0")

    body: list[str] = [
        f"<h1>{_esc(run_doc.get('scene_ref'))} — Wan 2.7 Visual Compiler & Review Pipeline "
        f"v{run_doc.get('version', 0):02d} (Schema {schema_ver})</h1>",
        f"<div class='sub'>Shot Plan v{(run_doc.get('shot_plan_ref') or {}).get('version')}"
        f" · Keyframe Plan v{(run_doc.get('keyframe_plan_ref') or {}).get('version')}"
        f" · Source Image Keyframes v{(run_doc.get('source_image_keyframe_ref') or {}).get('version')}"
        f" · {_esc(gen.get('primary_model'))}</div>",
        "<div class='warn'>"
        f"<b>{_esc(REVIEW_LAYER)}</b>"
        f"<b>{_esc(REVIEW_NOT_FULL)}</b>"
        f"<b>{_esc(REVIEW_NOT_VIDEO)}</b>"
        "本页审核 LLM Visual Compiler 与 Wan 2.7 状态编辑成果及 VLM 辅助评估。"
        "</div>",
    ]

    ir_img_rel = _rel_path(ir.get("image"), base_dir) if ir.get("image") else None
    if ir_img_rel:
        body.append(
            f"<div class='note'>身份参考图: <code>{_esc(ir_img_rel)}</code>"
            f" · 用途: {_esc(ir.get('rationale', '')[:200])}</div>"
        )

    for kf_id in DIAGNOSTIC_KEYFRAME_IDS:
        target = targets_by_id.get(kf_id, {})
        kf = kf_index.get(kf_id, {})
        shows = kf.get("must_show") or []
        avoids = kf.get("must_avoid") or []
        attempts = target.get("attempts") or []
        selected = target.get("selected_attempt")

        selected_attempt = None
        for att in attempts:
            if att.get("attempt") == selected:
                selected_attempt = att
                break
        if not selected_attempt and attempts:
            selected_attempt = attempts[-1]

        body.append("<div class='section'>")
        body.append(
            f"<h2><span class='target-id'>{_esc(kf_id)}</span>"
            f"<span> · {_esc(kf.get('semantic_purpose', '')[:100])}</span></h2>"
        )
        body.append("<div class='target'>")

        body.append("<div class='images'>")
        if ir_img_rel:
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>身份参考图</figcaption>"
                f"<img src='{_esc(ir_img_rel)}' alt='identity-ref' loading='lazy'>"
                "</figure></div>"
            )

        src_rel = _rel_path(target.get("source_image"), base_dir)
        if src_rel:
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>基础输入图 ({_esc(src_rel)})</figcaption>"
                f"<img src='{_esc(src_rel)}' alt='source' loading='lazy'>"
                "</figure></div>"
            )

        if selected_attempt:
            cand_rel = _rel_path(selected_attempt.get("image"), base_dir)
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>候选输出 ({_esc(selected_attempt.get('attempt'))})</figcaption>"
                + (
                    f"<img src='{_esc(cand_rel)}' alt='{_esc(kf_id)}' loading='lazy'>"
                    if cand_rel
                    else "<div class='missing'>图片未生成</div>"
                )
                + "</figure></div>"
            )
        else:
            body.append("<div class='imgbox'><div class='missing'>尚未生成</div></div>")
        body.append("</div>")

        if selected_attempt:
            att = selected_attempt
            directive_ref = att.get("render_directive_ref") or {}
            directive_rel = _rel_path(directive_ref.get("path"), base_dir) if directive_ref.get("path") else ""

            body.append(
                f"<div class='meta'>Attempt: {_esc(att.get('attempt'))}"
                f" · Status: {_esc(att.get('status'))}"
                f" · Request ID: {_esc(att.get('request_id'))}"
                f" · Directive: {_esc(directive_rel)}</div>"
            )

            prompt_text = att.get("prompt", "")
            if prompt_text:
                body.append(
                    f"<div class='why'><b>Wan Serialized Prompt:</b></div>"
                    f"<div class='code-block'>{_esc(prompt_text[:800])}</div>"
                )

            bbox_list = att.get("bbox_list")
            if bbox_list:
                body.append(
                    f"<div class='meta'>BBox List: {_esc(json.dumps(bbox_list))}</div>"
                )

            # Support both v1.0 review and v1.1 reviews
            reviews = att.get("reviews") or {}
            vlm_rev = reviews.get("vlm") or {}
            human_rev = reviews.get("human") or {}

            # Support v1.0 fallback
            legacy_rev = att.get("review") or {}
            if legacy_rev and not human_rev.get("verdicts"):
                human_rev = {"status": "completed", "verdicts": legacy_rev, "notes": legacy_rev.get("notes", [])}

            if vlm_rev:
                vlm_v = vlm_rev.get("verdicts") or {}
                body.append(
                    f"<div class='why'><b>VLM Advisory Review</b> (Suggested: <code>{_esc(vlm_rev.get('suggested_verdict'))}</code>, Request ID: {_esc(vlm_rev.get('request_id'))}):</div>"
                    + "<div class='verdicts'>"
                    + "".join(
                        f"<span class='v {_esc(vlm_v.get(dim, 'pending'))}'>vlm.{_esc(dim)}: {_esc(vlm_v.get(dim, 'pending'))}</span>"
                        for dim in REVIEW_DIMS
                    )
                    + "</div>"
                )

            if human_rev:
                hum_v = human_rev.get("verdicts") or {}
                body.append(
                    f"<div class='why'><b>Human Final Review Gate</b> (Status: <code>{_esc(human_rev.get('status'))}</code>):</div>"
                    + "<div class='verdicts'>"
                    + "".join(
                        f"<span class='v {_esc(hum_v.get(dim, 'pending'))}'>human.{_esc(dim)}: {_esc(hum_v.get(dim, 'pending'))}</span>"
                        for dim in REVIEW_DIMS
                    )
                    + "</div>"
                )

        shows_html = "".join(f"<li>{_esc(s)}</li>" for s in shows)
        avoids_html = "".join(f"<li>{_esc(a)}</li>" for a in avoids)
        body.append(
            f"<div class='why'><b>Semantic purpose:</b> {_esc(kf.get('semantic_purpose'))}</div>"
            f"<div class='why'><b>Visual state:</b> {_esc(kf.get('visual_state'))}</div>"
            f"<div class='why'><b>Must show</b></div><ul>{shows_html}</ul>"
            f"<div class='why'><b>Must avoid (→ FORBIDDEN OUTCOMES)</b></div>"
            f"<ul class='avoid'>{avoids_html}</ul>"
        )

        body.append("</div></div>")

    # 跨镜区域
    body.append("<div class='section'>")
    body.append(f"<h2>跨镜连续性对<span>{_esc(CROSS_SHOT_PAIR[0])} → {_esc(CROSS_SHOT_PAIR[1])}</span></h2>")
    body.append("<div class='pair'>")
    for pair_id in CROSS_SHOT_PAIR:
        target = targets_by_id.get(pair_id, {})
        selected = target.get("selected_attempt")
        img_rel = ""
        for att in target.get("attempts") or []:
            if att.get("attempt") == selected:
                img_rel = _rel_path(att.get("image"), base_dir)
                break
        body.append(
            f"<figure><figcaption>{_esc(pair_id)}</figcaption>"
            + (
                f"<img src='{_esc(img_rel)}' alt='{_esc(pair_id)}'>"
                if img_rel
                else "<div class='missing'>尚未生成</div>"
            )
            + "</figure>"
        )
    body.append("</div>")
    body.append(
        "<table class='checks'>"
        + "".join(f"<tr><td>{_esc(check)}</td><td>逐项人工核对</td></tr>" for check in CONTINUITY_CHECKS)
        + "</table></div>"
    )

    def _gate_class(gate: str | None) -> str:
        if gate == "pass":
            return "gate-pass"
        if gate == "blocked":
            return "gate-block"
        if gate == "revision_required":
            return "gate-rev"
        return "gate-pend"

    body.append(
        f"<div class='gate-box {_gate_class(api_gate)}'>api_gate: {_esc(api_gate)}</div>"
        f"<div class='gate-box {_gate_class(sem_gate)}' style='margin-top:8px'>semantic_gate (Human): {_esc(sem_gate)}</div>"
    )

    return (
        "<!DOCTYPE html>\n<html lang='zh'>\n<head>\n<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        f"<title>{_esc(run_doc.get('scene_ref'))} Wan 2.7 Visual Compiler review</title>\n"
        f"<style>{_STYLE}</style>\n</head>\n<body>\n"
        + "\n".join(body)
        + "\n</body>\n</html>\n"
    )
