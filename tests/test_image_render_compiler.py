import json
from pathlib import Path
from unittest import mock

import pytest

import tools.image_render_compiler as compiler


@pytest.fixture
def sample_source_packet():
    return {
        "schema_version": "1.0",
        "scene_ref": "reluctant-01-proto-01",
        "keyframe_id": "shot-02-kf-04",
        "source_refs": {
            "shot_plan_version": 5,
            "keyframe_plan_version": 2,
            "source_image_version": 1,
        },
        "image_roles": [
            {"id": "image-01", "role": "identity_reference", "path": "path/ref.png"},
            {"id": "image-02", "role": "base_image", "path": "path/base.png"},
        ],
        "target": {
            "visual_state": "hand reaches for fork",
            "must_show": [
                {"id": "show-01", "text": "hand on fork"},
                {"id": "show-02", "text": "reclined torso"},
            ],
            "must_avoid": [
                {"id": "avoid-01", "text": "duplicate fork"},
                {"id": "avoid-02", "text": "eager smile"},
            ],
        },
        "source_state": {
            "previous_keyframe_id": "shot-02-kf-03",
            "previous_visual_state": "hand beside plate",
            "continuity_from_previous": "keep reclined posture",
        },
        "scene_constants": {
            "cast": ["reluctant child"],
            "location": "dining room",
            "props": ["broccoli plate", "metal fork"],
        },
        "render_context": {
            "provider": "aliyun-token-plan",
            "model": "wan2.7-image-pro",
            "requested_size": "1152*640",
        },
    }


@pytest.fixture
def sample_render_directive():
    return {
        "schema_version": "1.0",
        "scene_ref": "reluctant-01-proto-01",
        "keyframe_id": "shot-02-kf-04",
        "compiler_attempt": "compiler-attempt-01",
        "edit_mode": "local_edit",
        "image_roles": [
            {"image_id": "image-01", "role": "identity_reference"},
            {"image_id": "image-02", "role": "base_image"},
        ],
        "preserve": {
            "identity": ["same child face"],
            "composition": ["same camera angle"],
            "body_state": ["shoulders against chair back"],
        },
        "remove_from_previous_state": ["the fork at its original resting position on the table"],
        "change": [
            {"subject": "child.right_hand", "operation": "close_around", "object": "fork"},
            {"subject": "fork", "operation": "lift", "target_state": "above table"},
        ],
        "must_be_visible": [
            {"source_id": "show-01", "physical_requirement": "hand closes on fork"},
            {"source_id": "show-02", "physical_requirement": "torso remains reclined"},
        ],
        "forbidden_outcomes": [
            {"source_id": "avoid-01", "physical_requirement": "no duplicate fork on table"},
            {"source_id": "avoid-02", "physical_requirement": "no smiling expression"},
        ],
        "edit_regions": [
            {
                "semantic_region": "right hand and fork",
                "image_id": "image-02",
                "bbox_normalized": [520, 410, 880, 780],
                "confidence": 0.85,
            }
        ],
        "wan_prompt": "Preserve child identity, lift fork while removing original fork on table.",
        "coverage": {
            "must_show_ids": ["show-01", "show-02"],
            "must_avoid_ids": ["avoid-01", "avoid-02"],
        },
        "compiler": {
            "protocol": "openai-chat",
            "model": "gpt-4o",
            "request_id": "req-compiler-1",
            "generated_at": None,
        },
    }


def test_normalized_bbox_to_pixels():
    bbox = [500, 250, 750, 500]  # 50% width, 25% height to 75% width, 50% height
    pixels = compiler.normalized_bbox_to_pixels(bbox, 1152, 640)
    assert pixels == [576, 160, 864, 320]

    # Clamping & min size
    pixels_edge = compiler.normalized_bbox_to_pixels([0, 0, 0, 0], 1152, 640)
    assert pixels_edge == [0, 0, 1, 1]


def test_compiler_validator_passes(sample_source_packet, sample_render_directive):
    errors = compiler.validate_render_directive(
        sample_source_packet, sample_render_directive, (1152, 640)
    )
    assert errors == []


def test_compiler_validator_detects_missing_coverage(sample_source_packet, sample_render_directive):
    sample_render_directive["must_be_visible"] = [
        {"source_id": "show-01", "physical_requirement": "hand closes on fork"}
    ]
    errors = compiler.validate_render_directive(
        sample_source_packet, sample_render_directive, (1152, 640)
    )
    assert any("show-02" in err for err in errors)


def test_compiler_validator_detects_unauthorized_source_id(sample_source_packet, sample_render_directive):
    sample_render_directive["must_be_visible"].append(
        {"source_id": "show-99", "physical_requirement": "fake show"}
    )
    errors = compiler.validate_render_directive(
        sample_source_packet, sample_render_directive, (1152, 640)
    )
    assert any("Unauthorized source_id" in err for err in errors)


def test_compiler_validator_allows_compiler_added_ids(sample_source_packet, sample_render_directive):
    sample_render_directive["must_be_visible"].append(
        {"source_id": "compiler-added-technical-constraint", "physical_requirement": "remove ghosting"}
    )
    errors = compiler.validate_render_directive(
        sample_source_packet, sample_render_directive, (1152, 640)
    )
    assert errors == []


def test_compiler_validator_detects_state_conflict(sample_source_packet, sample_render_directive):
    sample_render_directive["remove_from_previous_state"] = []
    sample_render_directive["preserve"]["composition"].append("preserve original fork on table")
    errors = compiler.validate_render_directive(
        sample_source_packet, sample_render_directive, (1152, 640)
    )
    assert any("State conflict" in err for err in errors)


def test_wan_prompt_serializer(sample_render_directive):
    text = compiler.serialize_wan_prompt(
        sample_render_directive,
        directive_rel_path="compiler/shot-02-kf-04/directive.yaml",
        compiler_request_id="req-123",
        full_ir=True,
    )
    assert "# Render Directive: compiler/shot-02-kf-04/directive.yaml" in text
    assert "# Compiler request ID: req-123" in text
    assert "=== IMAGE ROLES ===" in text
    assert "=== PRESERVE ===" in text
    assert "=== REMOVE FROM PREVIOUS STATE ===" in text
    assert "=== CHANGE ===" in text
    assert "=== MUST BE VISIBLE ===" in text
    assert "=== FORBIDDEN OUTCOMES ===" in text
