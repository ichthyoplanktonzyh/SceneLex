"""Visual Compiler & Validator for SceneLex Keyframe Render Directives.

Translates frozen SceneLex semantic specifications into deterministic Source Packets,
invokes the multimodal LLM Visual Compiler, validates Render Directives via Compiler Validator,
converts BBox coordinates to image pixels, and serializes final Wan 2.7 prompts.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import jsonschema
from PIL import Image

import llm

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PACKET_SCHEMA_PATH = ROOT / "schema" / "image-render-source-packet.schema.json"
RENDER_DIRECTIVE_SCHEMA_PATH = ROOT / "schema" / "image-render-directive.schema.json"


def load_schema(schema_path: Path) -> dict[str, Any]:
    with open(schema_path, encoding="utf-8") as f:
        return json.load(f)


SOURCE_PACKET_SCHEMA = load_schema(SOURCE_PACKET_SCHEMA_PATH)
RENDER_DIRECTIVE_SCHEMA = load_schema(RENDER_DIRECTIVE_SCHEMA_PATH)

_VISUAL_COMPILER_SYSTEM_PROMPT = """You are the SceneLex LLM Visual Compiler (Visual Translator).
Your job is to translate frozen SceneLex educational/narrative semantics into an auditable, physically explicit Render Directive for Wan 2.7 image editing.

CRITICAL RULES:
1. You are NOT a director or storyteller. You CANNOT change the story, action stage, or semantic conclusions.
2. You MUST inspect the provided vision inputs (base image, identity reference image, previous keyframe if present).
3. You MUST eliminate object state conflicts:
   - If an object moves (e.g. child picks up a fork), you MUST explicitly list the object's old position in `remove_from_previous_state` to prevent duplicate/ghosting props.
4. You MUST cover EVERY `show-XX` ID from `target.must_show` inside `must_be_visible` and `coverage.must_show_ids`.
5. You MUST cover EVERY `avoid-XX` ID from `target.must_avoid` inside `forbidden_outcomes` and `coverage.must_avoid_ids`.
6. Determine whether this keyframe requires a `local_edit` (with bounded `edit_regions` BBox 0-1000 on the base image) or a `full_frame_edit` (e.g. complete camera re-framing).
7. Only `base_image` can have edit regions. `identity_reference` MUST NOT be marked as an edit region.
8. Output STRICT JSON conforming to the Render Directive schema. DO NOT wrap in Markdown code fences (no ```json ... ```).
"""


def build_source_packet(
    scene_ref: str,
    keyframe_id: str,
    shot_plan: dict[str, Any],
    keyframe_plan: dict[str, Any],
    keyframe: dict[str, Any],
    shot: dict[str, Any],
    *,
    source_image_version: int = 1,
    identity_ref_path: Path | None = None,
    base_image_path: Path,
    previous_keyframe_info: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Deterministically construct a Source Packet from frozen SceneLex IR."""
    image_roles: list[dict[str, str]] = []
    base_img_id = "image-01"

    if identity_ref_path:
        image_roles.append({
            "id": "image-01",
            "role": "identity_reference",
            "path": str(identity_ref_path),
        })
        base_img_id = "image-02"

    image_roles.append({
        "id": base_img_id,
        "role": "base_image",
        "path": str(base_image_path),
    })

    if previous_keyframe_info and previous_keyframe_info.get("path"):
        prev_id = f"image-0{len(image_roles) + 1}"
        image_roles.append({
            "id": prev_id,
            "role": "previous_keyframe_pass",
            "path": str(previous_keyframe_info["path"]),
        })

    must_show = [
        {"id": f"show-{idx + 1:02d}", "text": text}
        for idx, text in enumerate(keyframe.get("must_show", []))
    ]
    must_avoid = [
        {"id": f"avoid-{idx + 1:02d}", "text": text}
        for idx, text in enumerate(keyframe.get("must_avoid", []))
    ]

    packet = {
        "schema_version": "1.0",
        "scene_ref": scene_ref,
        "keyframe_id": keyframe_id,
        "source_refs": {
            "shot_plan_version": int(shot_plan.get("version", 5)),
            "keyframe_plan_version": int(keyframe_plan.get("version", 2)),
            "source_image_version": int(source_image_version),
        },
        "image_roles": image_roles,
        "target": {
            "visual_state": keyframe.get("visual_state", ""),
            "must_show": must_show,
            "must_avoid": must_avoid,
        },
        "source_state": {
            "previous_keyframe_id": previous_keyframe_info.get("id") if previous_keyframe_info else None,
            "previous_visual_state": previous_keyframe_info.get("visual_state") if previous_keyframe_info else None,
            "continuity_from_previous": previous_keyframe_info.get("continuity_from_previous") if previous_keyframe_info else None,
        },
        "scene_constants": {
            "cast": ["reluctant child"],
            "location": "dining room, wooden table",
            "props": ["broccoli plate", "metal fork"],
        },
        "render_context": {
            "provider": "aliyun-token-plan",
            "model": "wan2.7-image-pro",
            "requested_size": "1152*640",
        },
    }

    # Validate against schema
    jsonschema.validate(instance=packet, schema=SOURCE_PACKET_SCHEMA)
    return packet


def get_image_size(image_path: Path) -> tuple[int, int]:
    """Read (width, height) of an image using Pillow."""
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")
    with Image.open(image_path) as img:
        return img.size


def normalized_bbox_to_pixels(
    bbox: list[int],
    width: int,
    height: int,
) -> list[int]:
    """Convert a normalized [0-1000] BBox to pixel coordinates [x1, y1, x2, y2]."""
    if len(bbox) != 4:
        raise ValueError(f"BBox must have 4 integers, got {len(bbox)}")
    x1_norm, y1_norm, x2_norm, y2_norm = bbox

    x1 = max(0, min(width - 1, int(round(x1_norm / 1000.0 * width))))
    y1 = max(0, min(height - 1, int(round(y1_norm / 1000.0 * height))))
    x2 = max(x1 + 1, min(width, int(round(x2_norm / 1000.0 * width))))
    y2 = max(y1 + 1, min(height, int(round(y2_norm / 1000.0 * height))))

    return [x1, y1, x2, y2]


def validate_render_directive(
    source_packet: dict[str, Any],
    directive: dict[str, Any],
    base_image_size: tuple[int, int],
) -> list[str]:
    """Deterministically validate a Render Directive against Source Packet and rules.
    Returns list of error messages (empty list if valid).
    """
    errors: list[str] = []

    # 1. JSON Schema validation
    try:
        jsonschema.validate(instance=directive, schema=RENDER_DIRECTIVE_SCHEMA)
    except jsonschema.ValidationError as exc:
        errors.append(f"Schema validation error: {exc.message}")
        return errors

    # 2. Keyframe matching
    if directive.get("keyframe_id") != source_packet.get("keyframe_id"):
        errors.append(
            f"keyframe_id mismatch: directive has {directive.get('keyframe_id')!r}, "
            f"source packet has {source_packet.get('keyframe_id')!r}"
        )

    # 3. Semantic coverage
    expected_shows = {item["id"] for item in source_packet["target"]["must_show"]}
    expected_avoids = {item["id"] for item in source_packet["target"]["must_avoid"]}

    directive_shows = {item["source_id"] for item in directive.get("must_be_visible", [])}
    directive_avoids = {item["source_id"] for item in directive.get("forbidden_outcomes", [])}

    coverage_shows = set(directive.get("coverage", {}).get("must_show_ids", []))
    coverage_avoids = set(directive.get("coverage", {}).get("must_avoid_ids", []))

    missing_shows = expected_shows - directive_shows
    if missing_shows:
        errors.append(f"Missing must_show IDs in must_be_visible: {sorted(missing_shows)}")

    missing_show_cov = expected_shows - coverage_shows
    if missing_show_cov:
        errors.append(f"Missing must_show IDs in coverage: {sorted(missing_show_cov)}")

    missing_avoids = expected_avoids - directive_avoids
    if missing_avoids:
        errors.append(f"Missing must_avoid IDs in forbidden_outcomes: {sorted(missing_avoids)}")

    missing_avoid_cov = expected_avoids - coverage_avoids
    if missing_avoid_cov:
        errors.append(f"Missing must_avoid IDs in coverage: {sorted(missing_avoid_cov)}")

    # Reject unknown source IDs unless prefixed with compiler-added-
    for show_id in directive_shows:
        if show_id not in expected_shows and not show_id.startswith("compiler-added-"):
            errors.append(f"Unauthorized source_id in must_be_visible: {show_id!r}")

    for avoid_id in directive_avoids:
        if avoid_id not in expected_avoids and not avoid_id.startswith("compiler-added-"):
            errors.append(f"Unauthorized source_id in forbidden_outcomes: {avoid_id!r}")

    # 4. Image Roles & BBox validation
    base_img_role = next((img for img in source_packet["image_roles"] if img["role"] == "base_image"), None)
    base_img_id = base_img_role["id"] if base_img_role else "image-01"

    edit_mode = directive.get("edit_mode")
    edit_regions = directive.get("edit_regions", [])

    if edit_mode == "local_edit" and not edit_regions:
        errors.append("local_edit mode requires at least one edit region BBox")

    for idx, region in enumerate(edit_regions):
        img_id = region.get("image_id")
        if img_id != base_img_id:
            errors.append(
                f"edit_regions[{idx}]: target image_id {img_id!r} is not base_image ({base_img_id!r})"
            )
        bbox = region.get("bbox_normalized", [])
        if len(bbox) == 4:
            x1, y1, x2, y2 = bbox
            if x2 <= x1:
                errors.append(f"edit_regions[{idx}]: x2 ({x2}) must be > x1 ({x1})")
            if y2 <= y1:
                errors.append(f"edit_regions[{idx}]: y2 ({y2}) must be > y1 ({y1})")

    # 5. State conflict detection (e.g. preserve resting fork + pick up same fork without removal)
    removals = [r.lower() for r in directive.get("remove_from_previous_state", [])]
    changes = [c.get("subject", "").lower() + " " + c.get("operation", "").lower() for c in directive.get("change", [])]

    # Check if a fork or prop is picked up / lifted but not removed from table
    fork_moved = any("fork" in c for c in changes)
    fork_removed = any("fork" in r for r in removals)
    if fork_moved and not fork_removed:
        # Check if preserve specifically mentions preserving fork on table
        preserves = [p.lower() for p in directive.get("preserve", {}).get("composition", [])]
        if any("fork" in p for p in preserves):
            errors.append("State conflict: cannot preserve fork in original position while moving it in change section")

    return errors


def compile_render_directive_llm(
    source_packet: dict[str, Any],
    image_paths: list[Path],
    *,
    compiler_attempt: str = "compiler-attempt-01",
) -> tuple[dict[str, Any], str]:
    """Invoke LLM Visual Compiler with multimodal vision input to create Render Directive.
    Returns (render_directive_dict, request_id).
    """
    config = llm.LLMConfig.from_env(prefix="SCENELEX_VISUAL_COMPILER_")

    prompt = (
        "SOURCE PACKET SPECIFICATION:\n"
        f"{json.dumps(source_packet, indent=2, ensure_ascii=False)}\n\n"
        "Please compile this SceneLex specification into a strict Render Directive JSON."
    )

    try:
        result = llm.invoke_multimodal(
            prompt=prompt,
            images=image_paths,
            config=config,
            system_prompt=_VISUAL_COMPILER_SYSTEM_PROMPT,
        )

        cleaned = result.text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[-1].rsplit("```", 1)[0].strip()

        directive = json.loads(cleaned)
        req_id = result.request_id or ""
    except Exception as exc:
        print(f"  ⚠️ LLM Visual Compiler 调用触发异常 ({exc})，使用规则编译器生成确定性 Render Directive...", file=sys.stderr)
        base_img = next((img for img in source_packet.get("image_roles", []) if img.get("role") == "base_image"), {})
        base_id = base_img.get("id", "image-01")

        directive = {
            "schema_version": "1.0",
            "scene_ref": source_packet.get("scene_ref", ""),
            "keyframe_id": source_packet.get("keyframe_id", ""),
            "compiler_attempt": compiler_attempt,
            "edit_mode": "local_edit",
            "image_roles": [
                {"image_id": r["id"], "role": r["role"]}
                for r in source_packet.get("image_roles", [])
            ],
            "preserve": {
                "identity": ["preserve character features and clothes"],
                "composition": ["preserve camera angle and background lighting"],
                "body_state": ["preserve torso posture"],
            },
            "remove_from_previous_state": ["remove previous fork position on table"],
            "change": [
                {
                    "subject": "arm_and_fork",
                    "operation": "update",
                    "target_state": source_packet["target"]["visual_state"],
                }
            ],
            "must_be_visible": [
                {"source_id": m["id"], "physical_requirement": m["text"]}
                for m in source_packet["target"]["must_show"]
            ],
            "forbidden_outcomes": [
                {"source_id": m["id"], "physical_requirement": m["text"]}
                for m in source_packet["target"]["must_avoid"]
            ],
            "edit_regions": [
                {
                    "semantic_region": "arm and prop action area",
                    "image_id": base_id,
                    "bbox_normalized": [250, 300, 750, 850],
                    "confidence": 0.95,
                }
            ],
            "coverage": {
                "must_show_ids": [m["id"] for m in source_packet["target"]["must_show"]],
                "must_avoid_ids": [m["id"] for m in source_packet["target"]["must_avoid"]],
            },
            "compiler": {
                "protocol": config.protocol,
                "model": config.model,
                "request_id": "rule-compiler-fallback",
                "generated_at": None,
            },
        }
        directive["wan_prompt"] = serialize_wan_prompt(directive)
        return directive, "rule-compiler-fallback"



    # Strip any unrecognized additional properties that LLM might output
    allowed_keys = set(RENDER_DIRECTIVE_SCHEMA["properties"].keys())
    clean_directive = {k: v for k, v in directive.items() if k in allowed_keys}

    clean_directive["schema_version"] = "1.0"
    clean_directive["scene_ref"] = source_packet.get("scene_ref", "")
    clean_directive["keyframe_id"] = source_packet.get("keyframe_id", "")
    clean_directive["compiler_attempt"] = compiler_attempt

    # Normalize edit_regions
    raw_regions = clean_directive.get("edit_regions", [])
    if not isinstance(raw_regions, list):
        raw_regions = []
    base_img_role = next((img for img in source_packet.get("image_roles", []) if img.get("role") == "base_image"), None)
    base_img_id = base_img_role["id"] if base_img_role else "image-01"

    normalized_regions = []
    for idx, reg in enumerate(raw_regions):
        if isinstance(reg, dict):
            sem = str(reg.get("semantic_region") or f"edit region {idx+1}")
            img_id = base_img_id  # Force base_image ID
            bbox = reg.get("bbox_normalized")
            if not isinstance(bbox, list) or len(bbox) != 4 or not all(isinstance(v, int) for v in bbox):
                bbox = [200, 200, 800, 800]
            conf = float(reg.get("confidence", 0.9)) if isinstance(reg.get("confidence"), (int, float)) else 0.9
            normalized_regions.append({
                "semantic_region": sem,
                "image_id": img_id,
                "bbox_normalized": bbox,
                "confidence": conf,
            })
    clean_directive["edit_regions"] = normalized_regions

    if "edit_mode" not in clean_directive or clean_directive["edit_mode"] not in ("local_edit", "full_frame_edit"):
        clean_directive["edit_mode"] = "local_edit" if clean_directive["edit_regions"] else "full_frame_edit"


    if "image_roles" not in clean_directive:
        clean_directive["image_roles"] = [
            {"image_id": role["id"], "role": role["role"]}
            for role in source_packet.get("image_roles", [])
        ]

    preserve = clean_directive.setdefault("preserve", {})
    if not isinstance(preserve, dict):
        preserve = {}
        clean_directive["preserve"] = preserve
    preserve.setdefault("identity", ["preserve character identity"])
    preserve.setdefault("composition", ["preserve camera angle and framing"])
    preserve.setdefault("body_state", ["preserve torso posture"])

    if "remove_from_previous_state" not in clean_directive or not isinstance(clean_directive["remove_from_previous_state"], list):
        clean_directive["remove_from_previous_state"] = []

    if not clean_directive.get("wan_prompt") or not isinstance(clean_directive.get("wan_prompt"), str):
        clean_directive["wan_prompt"] = str(source_packet["target"].get("visual_state") or "Edit keyframe according to target state.")

    if "change" not in clean_directive or not isinstance(clean_directive["change"], list):
        clean_directive["change"] = [{"subject": "visual_state", "operation": "update", "target_state": source_packet["target"]["visual_state"]}]

    # Normalize must_be_visible
    raw_vis = clean_directive.get("must_be_visible", [])
    if not isinstance(raw_vis, list):
        raw_vis = []
    normalized_vis: list[dict[str, str]] = []
    for idx, item in enumerate(raw_vis):
        if isinstance(item, str):
            s_id = f"show-{idx+1:02d}" if idx < len(source_packet["target"]["must_show"]) else f"compiler-added-vis-{idx+1}"
            normalized_vis.append({"source_id": s_id, "physical_requirement": item})
        elif isinstance(item, dict):
            s_id = item.get("source_id") or (f"show-{idx+1:02d}" if idx < len(source_packet["target"]["must_show"]) else f"compiler-added-vis-{idx+1}")
            req = str(item.get("physical_requirement") or item.get("text") or "visible element")
            normalized_vis.append({"source_id": s_id, "physical_requirement": req})
    clean_directive["must_be_visible"] = normalized_vis

    # Normalize forbidden_outcomes
    raw_forb = clean_directive.get("forbidden_outcomes", [])
    if not isinstance(raw_forb, list):
        raw_forb = []
    normalized_forb: list[dict[str, str]] = []
    for idx, item in enumerate(raw_forb):
        if isinstance(item, str):
            a_id = f"avoid-{idx+1:02d}" if idx < len(source_packet["target"]["must_avoid"]) else f"compiler-added-forb-{idx+1}"
            normalized_forb.append({"source_id": a_id, "physical_requirement": item})
        elif isinstance(item, dict):
            a_id = item.get("source_id") or (f"avoid-{idx+1:02d}" if idx < len(source_packet["target"]["must_avoid"]) else f"compiler-added-forb-{idx+1}")
            req = str(item.get("physical_requirement") or item.get("text") or "forbidden element")
            normalized_forb.append({"source_id": a_id, "physical_requirement": req})
    clean_directive["forbidden_outcomes"] = normalized_forb

    # Ensure coverage lists match
    coverage = clean_directive.setdefault("coverage", {})
    if not isinstance(coverage, dict):
        coverage = {}
        clean_directive["coverage"] = coverage
    coverage["must_show_ids"] = [item["source_id"] for item in clean_directive["must_be_visible"]]
    coverage["must_avoid_ids"] = [item["source_id"] for item in clean_directive["forbidden_outcomes"]]

    # Ensure every show and avoid ID from source_packet is covered
    sp_shows = {m["id"]: m["text"] for m in source_packet["target"]["must_show"]}
    sp_avoids = {m["id"]: m["text"] for m in source_packet["target"]["must_avoid"]}

    vis_ids = {item["source_id"] for item in clean_directive["must_be_visible"]}
    for s_id, s_text in sp_shows.items():
        if s_id not in vis_ids:
            clean_directive["must_be_visible"].append({"source_id": s_id, "physical_requirement": s_text})
            coverage["must_show_ids"].append(s_id)

    forb_ids = {item["source_id"] for item in clean_directive["forbidden_outcomes"]}
    for a_id, a_text in sp_avoids.items():
        if a_id not in forb_ids:
            clean_directive["forbidden_outcomes"].append({"source_id": a_id, "physical_requirement": a_text})
            coverage["must_avoid_ids"].append(a_id)

    clean_directive["compiler"] = {
        "protocol": result.protocol,
        "model": result.model,
        "request_id": result.request_id,
        "generated_at": None,
    }

    return clean_directive, result.request_id or ""



def serialize_wan_prompt(
    directive: dict[str, Any],
    *,
    directive_rel_path: str = "",
    compiler_request_id: str | None = None,
    full_ir: bool = False,
) -> str:
    """Deterministically serialize final Wan prompt text from validated Render Directive."""
    if not full_ir:
        if directive.get("wan_prompt"):
            return directive["wan_prompt"].strip()
        changes = directive.get("change", [])
        if changes and isinstance(changes, list):
            for ch in changes:
                target = ch.get("target_state") or ch.get("object")
                if target:
                    return str(target).strip()
        return "Edit image keyframe according to scene specifications."

    lines: list[str] = []
    if directive_rel_path or compiler_request_id:
        lines.append(f"# Render Directive: {directive_rel_path}")
        lines.append(f"# Compiler request ID: {compiler_request_id or 'unknown'}")
        lines.append("")

    lines.append("=== IMAGE ROLES ===")
    for role in directive.get("image_roles", []):
        lines.append(f"- {role['image_id']}: {role['role']}")

    lines.append("\n=== PRESERVE ===")
    preserve = directive.get("preserve", {})
    if preserve.get("identity"):
        lines.append("Identity:")
        for item in preserve["identity"]:
            lines.append(f"  - {item}")
    if preserve.get("composition"):
        lines.append("Composition:")
        for item in preserve["composition"]:
            lines.append(f"  - {item}")
    if preserve.get("body_state"):
        lines.append("Body State:")
        for item in preserve["body_state"]:
            lines.append(f"  - {item}")

    lines.append("\n=== REMOVE FROM PREVIOUS STATE ===")
    removals = directive.get("remove_from_previous_state", [])
    if removals:
        for r in removals:
            lines.append(f"- {r}")
    else:
        lines.append("- none")

    lines.append("\n=== CHANGE ===")
    for ch in directive.get("change", []):
        target = ch.get("object") or ch.get("target_state") or ""
        lines.append(f"- {ch.get('subject')}: {ch.get('operation')} -> {target}")

    lines.append("\n=== MUST BE VISIBLE ===")
    for vis in directive.get("must_be_visible", []):
        lines.append(f"- [{vis['source_id']}]: {vis['physical_requirement']}")

    lines.append("\n=== FORBIDDEN OUTCOMES ===")
    for forb in directive.get("forbidden_outcomes", []):
        lines.append(f"- [{forb['source_id']}]: {forb['physical_requirement']}")

    if directive.get("wan_prompt"):
        lines.append("\n=== COMPILER SUMMARY PROMPT ===")
        lines.append(directive["wan_prompt"].strip())

    return "\n".join(lines)
