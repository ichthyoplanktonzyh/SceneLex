#!/usr/bin/env python3
"""Wan 2.7 状态编辑实验的领域库。

职责边界:

- compile_edit_instruction() 是纯机械拼装: 输入全部来自已冻结的上游字段
  (Keyframe Plan 的 visual_state / must_show / must_avoid,
   Shot Plan 的 composition / camera / cast / location / props)。
  编译器不重新决定故事、动作阶段、道具状态或角色身份。
  不调用 LLM 改写提示词。

- 提示词结构固定:
    IMAGE ROLES
    PRESERVE EXACTLY
    CHANGE ONLY
    TARGET FROZEN STATE
    MUST BE VISIBLE
    FORBIDDEN OUTCOMES
    NO TEACHING PACKAGING

- must_avoid 进入 FORBIDDEN OUTCOMES (自然语言编辑指令)。
  Wan 2.7 不支持独立 negative_prompt, 所以审核报告里明确写:
  "must_avoid was expressed in the natural-language edit instruction
   and remained an explicit human review checklist;
   it was not a separate sampler-level negative prompt."

- 这一层只回答一个问题: Token Plan wan2.7-image-pro 能否通过图片编辑
  准确执行 Keyframe Plan 被冻结的状态。
  它不回答运动、节奏、剪辑、音频或最终学习效果。

安全约束:
  API Key、Base64、Authorization Header、远程临时 URL 均不得出现在
  此模块的任何输出 (YAML、HTML、日志、异常信息)。
"""

from __future__ import annotations

import html
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent

SCHEMA_VERSION = "1.0"
STATUS_DRAFT = "draft"

# 审核层级标注 (出现在 review.html 顶部和每个 target)
REVIEW_LAYER = "WAN 2.7 CLOUD IMAGE STATE-EDIT REVIEW"
REVIEW_NOT_FULL = "NOT FULL IMAGE-KEYFRAME REVIEW"
REVIEW_NOT_VIDEO = "NOT VIDEO MOTION REVIEW"

# Gate 枚举
API_GATE_VALUES = ("pending", "pass", "blocked")
SEMANTIC_GATE_VALUES = ("pending", "pass", "revision_required", "not_run")

# 每个 attempt 的状态枚举
ATTEMPT_STATUS_VALUES = ("generated", "failed", "pending")

# 人工审核维度
REVIEW_DIMS = (
    "semantic_readability",
    "state_fidelity",
    "character_consistency",
    "prop_continuity",
    "composition",
)
VERDICT_VALUES = ("pending", "pass", "weak", "fail")

# 跨镜连续性人工核对清单 (与 image_keyframe.py 保持一致)
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

# 四张诊断帧的 keyframe ID (顺序严格)
DIAGNOSTIC_KEYFRAME_IDS = (
    "shot-02-kf-03",
    "shot-02-kf-04",
    "shot-03-kf-01",
    "shot-03-kf-03",
)

# 画面里不得出现教学包装
NO_TEACHING_PACKAGING = (
    "The image contains no words, letters, subtitles, captions, definitions, "
    "vocabulary labels, narration text, speech bubbles or interface overlays. "
    "Do not show the word 'reluctant' or any other vocabulary label in the image."
)

# shot-02-kf-04 → shot-03-kf-01 是本轮验证跨镜连续性的切点
CROSS_SHOT_PAIR = ("shot-02-kf-04", "shot-03-kf-01")


# ------------------------------------------------------------------ 工具函数

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
    """cast / location / props 的连续性描述 —— 整场共用的常量块。"""
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


# ---------------------------------------------------------- 编辑指令编译

def compile_edit_instruction(
    keyframe: dict,
    shot: dict,
    shot_plan: dict,
    *,
    identity_ref: Path | None,
    base_image: Path,
) -> str:
    """编译编辑指令 —— 纯机械拼装，确定性，不调用 LLM。

    结构固定:
        IMAGE ROLES
        PRESERVE EXACTLY
        CHANGE ONLY
        TARGET FROZEN STATE
        MUST BE VISIBLE
        FORBIDDEN OUTCOMES
        NO TEACHING PACKAGING

    visual_state 和 must_show 逐项进入正文。
    must_avoid 进入 FORBIDDEN OUTCOMES。
    不添加上游不存在的新剧情。
    不让模型重新设计构图、改变角色服装或道具。
    """
    composition = shot.get("composition") or {}
    camera = shot.get("camera") or {}

    # IMAGE ROLES
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

    # PRESERVE EXACTLY — 来自 Shot Plan cast / location / props 常量块 + 构图
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

    # CHANGE ONLY — 来自 visual_state 的动作描述
    visual_state = _text(keyframe.get("visual_state"))
    # 从 visual_state 中提取"变化"部分作为 CHANGE ONLY
    # 保持原文，不重新解释
    change_text = visual_state

    # TARGET FROZEN STATE — 来自 must_show (被冻结的结果状态)
    shows = _lines(keyframe.get("must_show"))
    state_text = _join(shows) if shows else visual_state

    # FORBIDDEN OUTCOMES — 来自 must_avoid
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

    # MUST BE VISIBLE — 同 must_show
    if shows:
        sections.append(f"MUST BE CLEARLY VISIBLE\n\n{_join(shows)}")

    sections.append(f"FORBIDDEN OUTCOMES\n\n{forbidden_text}")
    sections.append(f"NO TEACHING PACKAGING\n\n{NO_TEACHING_PACKAGING}")

    return "\n\n".join(sections)


def prompt_file_text(keyframe_id: str, attempt_id: str, instruction: str) -> str:
    """写进 prompts/*.txt 的内容 —— 提示词是可审计产物。"""
    return (
        f"# {keyframe_id} / {attempt_id}\n"
        "# 由 Keyframe Plan 与 Shot Plan 机械编译; 不要手工改这里, 改上游。\n"
        "# Wan 2.7 不支持独立 negative_prompt: must_avoid 在 FORBIDDEN OUTCOMES 节以\n"
        "# 自然语言形式出现，并作为人工审核清单。\n\n"
        "=== EDIT INSTRUCTION ===\n"
        f"{instruction}\n"
    )


# ---------------------------------------------------------- manifest 构建

def blank_attempt_review() -> dict:
    return {dim: "pending" for dim in REVIEW_DIMS} | {"notes": []}


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
    version: int,
    scene_id: str,
    identity_reference_image: str | None,
    identity_reference_rationale: str | None,
    primary_model: str = "wan2.7-image-pro",
    fallback_model: str = "wan2.7-image",
    requested_size: str = "1152*640",
) -> dict:
    """构造 edit-run.yaml 初始结构。"""
    shot_plan_ref = plan.get("shot_plan_ref") or {}
    targets = []
    for kf_id in DIAGNOSTIC_KEYFRAME_IDS:
        target = blank_target(kf_id)
        # 从 source_keyframe_manifest 找到对应的基础图
        for frame in source_keyframe_manifest.get("frames", []) or []:
            if frame.get("keyframe_id") == kf_id:
                target["source_image"] = frame.get("image")
                break
        target["identity_reference"] = identity_reference_image
        targets.append(target)

    return {
        "schema_version": SCHEMA_VERSION,
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


# ---------------------------------------------------------- manifest 校验

def validate_edit_run(
    run_doc: dict,
    plan: dict,
    shot_plan: dict,
) -> list[str]:
    """检查 edit-run 的绑定、gate 枚举、keyframe ID、selected_attempt 存在性。"""
    issues: list[str] = []

    # gate 枚举
    api_gate = run_doc.get("api_gate")
    if api_gate not in API_GATE_VALUES:
        issues.append(
            f"api_gate {api_gate!r} 不在允许范围 {API_GATE_VALUES}"
        )
    sem_gate = run_doc.get("semantic_gate")
    if sem_gate not in SEMANTIC_GATE_VALUES:
        issues.append(
            f"semantic_gate {sem_gate!r} 不在允许范围 {SEMANTIC_GATE_VALUES}"
        )

    # scope 必须是 experiment-local
    ir = run_doc.get("identity_reference") or {}
    if ir.get("scope") not in (None, "experiment-local"):
        issues.append(
            "identity_reference.scope 必须是 'experiment-local'"
        )

    # shot_plan_ref 绑定 v05
    sp_ref = run_doc.get("shot_plan_ref") or {}
    if sp_ref.get("version") != 5:
        issues.append(
            f"shot_plan_ref.version 应为 5, 实际为 {sp_ref.get('version')}"
        )

    # keyframe_plan_ref 绑定 v02
    kp_ref = run_doc.get("keyframe_plan_ref") or {}
    if kp_ref.get("version") != 2:
        issues.append(
            f"keyframe_plan_ref.version 应为 2, 实际为 {kp_ref.get('version')}"
        )

    # source_image_keyframe_ref 绑定 v01
    src_ref = run_doc.get("source_image_keyframe_ref") or {}
    if src_ref.get("version") != 1:
        issues.append(
            f"source_image_keyframe_ref.version 应为 1, 实际为 {src_ref.get('version')}"
        )

    # 四个诊断 keyframe ID 正确
    target_ids = [t.get("keyframe_id") for t in run_doc.get("targets", []) or []]
    for expected_id in DIAGNOSTIC_KEYFRAME_IDS:
        if expected_id not in target_ids:
            issues.append(f"缺少诊断帧 {expected_id}")

    # selected_attempt 必须存在于 attempts 中
    for target in run_doc.get("targets", []) or []:
        kf_id = target.get("keyframe_id", "?")
        selected = target.get("selected_attempt")
        if selected is not None:
            attempt_ids = [
                a.get("attempt") for a in target.get("attempts", []) or []
            ]
            if selected not in attempt_ids:
                issues.append(
                    f"{kf_id}: selected_attempt={selected!r} "
                    f"不在 attempts 列表中 {attempt_ids}"
                )

    # 禁止字段检查（YAML 序列化后字符串搜索）
    run_text = yaml.safe_dump(run_doc, allow_unicode=True)
    for forbidden in ("Authorization:", "sk-sp-", "data:image/"):
        if forbidden in run_text:
            issues.append(
                f"edit-run YAML 含有禁止内容 {forbidden!r} "
                f"(API Key / Base64 / Authorization Header)"
            )

    return issues


# ---------------------------------------------------------------- 审核页

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
"""


def _esc(value: object) -> str:
    return html.escape("" if value is None else str(value))


def _verdict_span(value: str | None) -> str:
    v = value or "pending"
    return f"<span class='v {_esc(v)}'>{_esc(v)}</span>"


def _gate_class(gate: str | None) -> str:
    if gate == "pass":
        return "gate-pass"
    if gate == "blocked":
        return "gate-block"
    if gate == "revision_required":
        return "gate-rev"
    return "gate-pend"


def review_html(
    run_doc: dict,
    plan: dict,
    shot_plan: dict,
    *,
    images_rel_base: str = "images",
) -> str:
    """单文件审核页: 无外部 CDN、无服务器, 浏览器直接打开。确定性重建。

    图片以相对路径引用, 不嵌入 base64。
    不调用 API, 不修改 YAML, 不泄漏 API Key / Base64 / URL。
    """
    shots = _shot_index(shot_plan)

    # 按 keyframe_id 索引 target 和 keyframe
    targets_by_id: dict[str, dict] = {
        t.get("keyframe_id"): t
        for t in run_doc.get("targets", []) or []
    }
    # Keyframe 信息
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

    body: list[str] = [
        f"<h1>{_esc(run_doc.get('scene_ref'))} — Wan 2.7 状态编辑实验 "
        f"v{run_doc.get('version', 0):02d}</h1>",
        f"<div class='sub'>Shot Plan v{(run_doc.get('shot_plan_ref') or {}).get('version')}"
        f" · Keyframe Plan v{(run_doc.get('keyframe_plan_ref') or {}).get('version')}"
        f" · Source Image Keyframes v{(run_doc.get('source_image_keyframe_ref') or {}).get('version')}"
        f" · {_esc(gen.get('primary_model'))}"
        f" · {_esc(gen.get('endpoint_kind'))}</div>",
        "<div class='warn'>"
        f"<b>{_esc(REVIEW_LAYER)}</b>"
        f"<b>{_esc(REVIEW_NOT_FULL)}</b>"
        f"<b>{_esc(REVIEW_NOT_VIDEO)}</b>"
        "本页只审核 Token Plan Wan 2.7 图片编辑能力，不是完整九帧审核，也不是视频运动审核。"
        "<br>即使四张全部通过，最多只能写: READY FOR FULL WAN 2.7 IMAGE-KEYFRAME REGENERATION。"
        "<br>不能写: READY FOR VIDEO MOTION PROTOTYPE。"
        "</div>",
        "<div class='note'>"
        "must_avoid 以自然语言形式出现在 FORBIDDEN OUTCOMES 节。"
        "Wan 2.7 不支持独立 negative_prompt；must_avoid 仍是人工审核清单，"
        "不是采样器级约束。"
        "</div>",
    ]

    # 身份参考图信息
    if ir.get("image"):
        body.append(
            f"<div class='note'>身份参考图: <code>{_esc(ir.get('image'))}</code>"
            f" · 用途: {_esc(ir.get('rationale', '')[:200])}"
            f" · scope: {_esc(ir.get('scope'))}</div>"
        )

    # 各诊断帧
    for kf_id in DIAGNOSTIC_KEYFRAME_IDS:
        target = targets_by_id.get(kf_id, {})
        kf = kf_index.get(kf_id, {})
        shot = shots.get(kf_shot.get(kf_id, ""), {})
        shows = kf.get("must_show") or []
        avoids = kf.get("must_avoid") or []
        attempts = target.get("attempts") or []
        selected = target.get("selected_attempt")

        # 找选中的 attempt
        selected_attempt = None
        for att in attempts:
            if att.get("attempt") == selected:
                selected_attempt = att
                break

        body.append("<div class='section'>")
        body.append(
            f"<h2><span class='target-id'>{_esc(kf_id)}</span>"
            f"<span> · {_esc(kf.get('semantic_purpose', '')[:100])}</span></h2>"
        )
        body.append("<div class='target'>")

        # 图片区: 身份参考 / 基础图 / 候选输出
        body.append("<div class='images'>")
        if ir.get("image"):
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>身份参考图 (experiment-local)</figcaption>"
                f"<img src='{_esc(ir['image'])}' alt='identity-ref' loading='lazy'>"
                "</figure></div>"
            )
        if target.get("source_image"):
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>基础输入图 ({_esc(target.get('source_image'))})</figcaption>"
                f"<img src='{_esc(target['source_image'])}' alt='source' loading='lazy'>"
                "</figure></div>"
            )
        if selected_attempt:
            img_path = selected_attempt.get("image", "")
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>候选输出 (attempt {_esc(selected)})</figcaption>"
                + (
                    f"<img src='{_esc(img_path)}' alt='{_esc(kf_id)}' loading='lazy'>"
                    if img_path
                    else "<div class='missing'>图片未生成</div>"
                )
                + "</figure></div>"
            )
        elif attempts:
            # 显示最后一次 attempt
            last_att = attempts[-1]
            img_path = last_att.get("image", "")
            body.append(
                f"<div class='imgbox'><figure>"
                f"<figcaption>最后一次 attempt (attempt {_esc(last_att.get('attempt'))})</figcaption>"
                + (
                    f"<img src='{_esc(img_path)}' alt='{_esc(kf_id)}' loading='lazy'>"
                    if img_path
                    else "<div class='missing'>图片未生成</div>"
                )
                + "</figure></div>"
            )
        else:
            body.append("<div class='imgbox'><div class='missing'>尚未生成</div></div>")
        body.append("</div>")  # .images

        # 元数据
        for att in attempts:
            review = att.get("review") or {}
            notes_html = "".join(
                f"<li>{_esc(n)}</li>" for n in review.get("notes") or []
            )
            body.append(
                f"<div class='meta'>attempt={_esc(att.get('attempt'))}"
                f" · model={_esc(att.get('model'))}"
                f" · seed={_esc(att.get('seed'))}"
                f" · request_id={_esc(att.get('request_id'))}"
                f" · status={_esc(att.get('status'))}</div>"
                + "<div class='verdicts'>"
                + "".join(
                    "<span class='v {cls}'>{label}: {val}</span>".format(
                        cls=_esc(review.get(dim, "pending")),
                        label=_esc(dim.replace("_", " ")),
                        val=_esc(review.get(dim, "pending")),
                    )
                    for dim in REVIEW_DIMS
                )
                + "</div>"
                + (f"<ul class='notes-list'>{notes_html}</ul>" if notes_html else "")
            )

        # 语义说明
        shows_html = "".join(f"<li>{_esc(s)}</li>" for s in shows)
        avoids_html = "".join(f"<li>{_esc(a)}</li>" for a in avoids)
        body.append(
            f"<div class='why'><b>Semantic purpose:</b> {_esc(kf.get('semantic_purpose'))}</div>"
            f"<div class='why'><b>Visual state:</b> {_esc(kf.get('visual_state'))}</div>"
            f"<div class='why'><b>Must show</b></div><ul>{shows_html}</ul>"
            f"<div class='why'><b>Must avoid (→ FORBIDDEN OUTCOMES)</b></div>"
            f"<ul class='avoid'>{avoids_html}</ul>"
        )

        body.append("</div>")  # .target
        body.append("</div>")  # .section

    # 跨镜连续性区域
    body.append("<div class='section'>")
    up_id, down_id = CROSS_SHOT_PAIR
    body.append(
        f"<h2>跨镜连续性对<span>{_esc(up_id)} → {_esc(down_id)} · "
        "两帧的动作状态和道具状态必须相同，构图可以更紧</span></h2>"
    )
    body.append("<div class='pair'>")
    for pair_id in CROSS_SHOT_PAIR:
        target = targets_by_id.get(pair_id, {})
        selected = target.get("selected_attempt")
        img_path = ""
        for att in target.get("attempts") or []:
            if att.get("attempt") == selected:
                img_path = att.get("image", "")
                break
        body.append(
            f"<figure><figcaption>{_esc(pair_id)}</figcaption>"
            + (
                f"<img src='{_esc(img_path)}' alt='{_esc(pair_id)}'>"
                if img_path
                else "<div class='missing'>尚未生成</div>"
            )
            + "</figure>"
        )
    body.append("</div>")  # .pair
    body.append(
        "<table class='checks'>"
        + "".join(
            f"<tr><td>{_esc(check)}</td><td>逐项人工核对</td></tr>"
            for check in CONTINUITY_CHECKS
        )
        + "</table>"
    )
    body.append("</div>")  # .section

    # Gate 总结
    body.append(
        f"<div class='gate-box {_gate_class(api_gate)}'>"
        f"api_gate: {_esc(api_gate)}</div>"
        f"<div class='gate-box {_gate_class(sem_gate)}' style='margin-top:8px'>"
        f"semantic_gate: {_esc(sem_gate)}</div>"
    )

    return (
        "<!DOCTYPE html>\n<html lang='zh'>\n<head>\n<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        f"<title>{_esc(run_doc.get('scene_ref'))} Wan 2.7 edit review</title>\n"
        f"<style>{_STYLE}</style>\n</head>\n<body>\n"
        + "\n".join(body)
        + "\n</body>\n</html>\n"
    )
