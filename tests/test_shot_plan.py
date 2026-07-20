"""Shot Plan 契约测试: schema、Beat→Shot 映射、时长与 visual-first。"""

import copy
import json

import pytest
import yaml
from jsonschema import Draft202012Validator

import draft
import shot_plan


REPO_ROOT = draft.ROOT
FIXTURE = REPO_ROOT / "tests" / "fixtures" / "shot-plan-valid.yaml"

SCENE = {
    "schema_version": "1.1",
    "version": 1,
    "id": "reluctant-01-proto-01",
    "sense_ref": "reluctant-01",
    "sense_revision": 1,
    "storyboard": [{"beat": 1}, {"beat": 2}, {"beat": 3}],
}
SENSE = {"schema_version": "1.1", "id": "reluctant-01", "semantic_revision": 1}


@pytest.fixture
def validator():
    return Draft202012Validator(
        json.loads((REPO_ROOT / "schema" / "shot-plan.schema.json").read_text("utf-8"))
    )


@pytest.fixture
def plan():
    return yaml.safe_load(FIXTURE.read_text("utf-8"))


def errors(validator, doc):
    return list(validator.iter_errors(doc))


# ------------------------------------------------------------------ A. schema

def test_schema_is_valid_jsonschema(validator):
    Draft202012Validator.check_schema(validator.schema)


def test_fixture_passes_schema_and_semantic_checks(validator, plan):
    assert not errors(validator, plan)
    assert shot_plan.validate_shot_plan(plan, SCENE) == []
    assert shot_plan.shot_plan_warnings(plan) == []


@pytest.mark.parametrize("field", ["scene_ref", "sense_revision", "scene_version",
                                   "sense_ref", "total_duration_hint", "shots"])
def test_missing_top_level_field_fails_schema(validator, plan, field):
    del plan[field]
    assert errors(validator, plan)


@pytest.mark.parametrize("field", ["source_beats", "visual_start", "trigger",
                                   "action", "visual_end", "composition",
                                   "camera", "semantic_evidence", "audio",
                                   "continuity"])
def test_missing_shot_field_fails_schema(validator, plan, field):
    del plan["shots"][0][field]
    assert errors(validator, plan)


def test_invalid_shot_size_fails_schema(validator, plan):
    plan["shots"][0]["composition"]["shot_size"] = "super_duper_wide"
    assert errors(validator, plan)


def test_invalid_camera_movement_fails_schema(validator, plan):
    plan["shots"][0]["camera"]["movement"] = "drone_flyover"
    assert errors(validator, plan)


def test_invalid_narrative_function_fails_schema(validator, plan):
    plan["shots"][0]["narrative_function"] = "make_it_cool"
    assert errors(validator, plan)


def test_duration_below_one_fails_schema(validator, plan):
    plan["shots"][0]["duration_hint"] = 0.5
    assert errors(validator, plan)


def test_duration_above_eight_fails_schema(validator, plan):
    plan["shots"][0]["duration_hint"] = 9.0
    assert errors(validator, plan)


def test_invalid_audio_mode_fails_schema(validator, plan):
    plan["shots"][0]["audio"]["mode"] = "voiceover_narration"
    assert errors(validator, plan)


def test_boolean_is_not_a_valid_source_beat(validator, plan):
    plan["shots"][0]["source_beats"] = [True]
    assert errors(validator, plan)


def test_boolean_is_not_a_valid_duration(validator, plan):
    plan["shots"][0]["duration_hint"] = True
    assert errors(validator, plan)


def test_style_and_model_fields_are_rejected(validator, plan):
    """Shot Plan 保持风格中立与模型中立: 多余字段直接失败。"""
    plan["style"] = "pixar-3d"
    assert errors(validator, plan)
    del plan["style"]
    plan["shots"][0]["prompt"] = "Pixar-style 3D animated short..."
    assert errors(validator, plan)


# ------------------------------------------------- B. Beat → Shot 映射

def one_shot(beats, index=1, **overrides):
    """从 fixture 借一个结构完整的镜头, 只改映射相关字段。"""
    base = copy.deepcopy(yaml.safe_load(FIXTURE.read_text("utf-8"))["shots"][0])
    base["id"] = shot_plan.SHOT_ID.format(index)
    base["source_beats"] = beats
    base.update(overrides)
    return base


def make_plan(shots):
    plan = yaml.safe_load(FIXTURE.read_text("utf-8"))
    plan["shots"] = shots
    plan["total_duration_hint"] = shot_plan.sum_shot_durations(plan)
    return plan


def test_one_beat_per_shot_is_valid():
    plan = make_plan([one_shot([1], 1), one_shot([2], 2), one_shot([3], 3)])
    assert shot_plan.validate_shot_plan(plan, SCENE) == []


def test_multiple_beats_merged_into_one_shot_is_valid():
    plan = make_plan([one_shot([1, 2, 3], 1)])
    assert shot_plan.validate_shot_plan(plan, SCENE) == []


def test_one_beat_referenced_by_multiple_shots_is_valid():
    plan = make_plan([one_shot([1, 2], 1), one_shot([2, 3], 2)])
    assert shot_plan.validate_shot_plan(plan, SCENE) == []


def test_shot_count_need_not_equal_beat_count():
    """3 beats → 2 shots 与 3 beats → 4 shots 都合法。"""
    assert shot_plan.validate_shot_plan(
        make_plan([one_shot([1, 2], 1), one_shot([3], 2)]), SCENE
    ) == []
    assert shot_plan.validate_shot_plan(
        make_plan([one_shot([1], 1), one_shot([1], 2),
                   one_shot([2], 3), one_shot([3], 4)]), SCENE
    ) == []


def test_uncovered_scene_beat_fails():
    plan = make_plan([one_shot([1, 2], 1)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("未被任何镜头覆盖" in issue and "[3]" in issue for issue in issues)


def test_unknown_beat_reference_fails():
    plan = make_plan([one_shot([1, 2], 1), one_shot([3, 9], 2)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("不存在的 beat" in issue for issue in issues)


def test_non_sequential_shot_ids_fail():
    plan = make_plan([one_shot([1, 2], 1), one_shot([3], 3)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("连续编号" in issue for issue in issues)


def test_unsorted_source_beats_fail():
    plan = make_plan([one_shot([2, 1], 1), one_shot([3], 2)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("升序" in issue for issue in issues)


def test_shot_order_reversing_the_beat_timeline_fails():
    plan = make_plan([one_shot([3], 1), one_shot([1, 2], 2)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("逆转了 beat 时间线" in issue for issue in issues)


def test_state_fields_must_not_be_empty():
    shot = one_shot([1, 2, 3], 1)
    shot["action"]["description"] = "   "
    issues = shot_plan.validate_shot_plan(make_plan([shot]), SCENE)
    assert any("action.description" in issue for issue in issues)


def test_middle_shot_needs_at_least_one_continuity_side():
    shots = [one_shot([1], 1), one_shot([2], 2), one_shot([3], 3)]
    shots[1]["continuity"] = {"enters_from_previous": None, "exits_to_next": None}
    issues = shot_plan.validate_shot_plan(make_plan(shots), SCENE)
    assert any("中间镜头" in issue for issue in issues)


# ------------------------------------------------------------- C. duration

def test_two_to_five_seconds_produces_no_warning():
    plan = make_plan([one_shot([1, 2], 1, duration_hint=2.0),
                      one_shot([3], 2, duration_hint=5.0)])
    assert shot_plan.validate_shot_plan(plan, SCENE) == []
    assert shot_plan.shot_plan_warnings(plan) == []


def test_over_five_seconds_warns_but_passes():
    plan = make_plan([one_shot([1, 2], 1, duration_hint=6.0),
                      one_shot([3], 2, duration_hint=4.0)])
    assert shot_plan.validate_shot_plan(plan, SCENE) == []
    assert any("超过生产目标" in w for w in shot_plan.shot_plan_warnings(plan))


def test_over_eight_seconds_fails():
    plan = make_plan([one_shot([1, 2, 3], 1, duration_hint=9.0)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("超过 8.0s" in issue for issue in issues)


def test_under_one_second_fails():
    plan = make_plan([one_shot([1, 2, 3], 1, duration_hint=0.5)])
    issues = shot_plan.validate_shot_plan(plan, SCENE)
    assert any("短于" in issue for issue in issues)


def test_total_duration_must_match_the_sum():
    plan = make_plan([one_shot([1, 2], 1, duration_hint=3.0),
                      one_shot([3], 2, duration_hint=4.0)])
    assert plan["total_duration_hint"] == 7.0
    assert shot_plan.validate_shot_plan(plan, SCENE) == []
    plan["total_duration_hint"] = 12.0
    assert any("不一致" in issue
               for issue in shot_plan.validate_shot_plan(plan, SCENE))


def test_omitted_total_duration_is_computed_by_the_tool():
    plan = make_plan([one_shot([1, 2], 1, duration_hint=3.0),
                      one_shot([3], 2, duration_hint=4.5)])
    del plan["total_duration_hint"]
    assert shot_plan.check_shot_plan_identity(
        plan, scene=SCENE, sense=SENSE, version=1) == []
    shot_plan.apply_authoritative_fields(plan, scene=SCENE, sense=SENSE, version=1)
    assert plan["total_duration_hint"] == 7.5


def test_explicitly_wrong_total_duration_is_identity_drift():
    plan = make_plan([one_shot([1, 2], 1, duration_hint=3.0),
                      one_shot([3], 2, duration_hint=4.0)])
    plan["total_duration_hint"] = 20.0
    drift = shot_plan.check_shot_plan_identity(
        plan, scene=SCENE, sense=SENSE, version=1)
    assert any("total_duration_hint" in item for item in drift)


# ------------------------------------------------------------ 身份字段

def test_omitted_authoritative_fields_are_filled_in():
    plan = make_plan([one_shot([1, 2, 3], 1)])
    for field in ("schema_version", "version", "status", "id", "scene_ref",
                  "scene_version", "sense_ref", "sense_revision"):
        plan.pop(field, None)
    assert shot_plan.check_shot_plan_identity(
        plan, scene=SCENE, sense=SENSE, version=2) == []
    shot_plan.apply_authoritative_fields(plan, scene=SCENE, sense=SENSE, version=2)
    assert plan["id"] == "reluctant-01-proto-01-shot-plan-02"
    assert plan["version"] == 2
    assert plan["status"] == "draft"
    assert plan["scene_ref"] == "reluctant-01-proto-01"
    assert plan["scene_version"] == 1
    assert plan["sense_ref"] == "reluctant-01"
    assert plan["sense_revision"] == 1


@pytest.mark.parametrize("field,value", [
    ("scene_ref", "messy-01-proto-01"),
    ("scene_version", 7),
    ("sense_ref", "messy-01"),
    ("sense_revision", 3),
    ("version", 99),
    ("status", "published"),
    ("id", "messy-01-proto-01-shot-plan-01"),
    ("schema_version", "2.0"),
])
def test_explicitly_wrong_authoritative_field_is_drift(field, value):
    plan = make_plan([one_shot([1, 2, 3], 1)])
    plan[field] = value
    drift = shot_plan.check_shot_plan_identity(
        plan, scene=SCENE, sense=SENSE, version=1)
    assert any(field in item for item in drift)


# ------------------------------------------------------- E. visual-first

def test_silence_and_optional_dialogue_are_valid():
    for audio in ({"mode": "silence"},
                  {"mode": "optional_dialogue",
                   "dialogue": {"speaker": "teacher", "text": "You're next."},
                   "purpose": "Clarify the request."}):
        plan = make_plan([one_shot([1, 2, 3], 1, audio=audio)])
        assert shot_plan.validate_shot_plan(plan, SCENE) == []


def test_required_dialogue_without_dialogue_fails(validator):
    audio = {"mode": "required_dialogue", "purpose": "The line performs the act."}
    plan = make_plan([one_shot([1, 2, 3], 1, audio=audio)])
    assert errors(validator, plan)
    assert any("speaker" in issue
               for issue in shot_plan.validate_shot_plan(plan, SCENE))


def test_required_dialogue_without_purpose_fails(validator):
    audio = {"mode": "required_dialogue",
             "dialogue": {"speaker": "teacher", "text": "You're next."}}
    plan = make_plan([one_shot([1, 2, 3], 1, audio=audio)])
    assert errors(validator, plan)
    assert any("为何画面本身不足以成立" in issue
               for issue in shot_plan.validate_shot_plan(plan, SCENE))


def test_required_dialogue_still_needs_visual_evidence():
    audio = {"mode": "required_dialogue",
             "dialogue": {"speaker": "teacher", "text": "You're next."},
             "purpose": "The utterance itself is the speech act being taught."}
    shot = one_shot([1, 2, 3], 1, audio=audio)
    shot["semantic_evidence"]["must_show"] = []
    issues = shot_plan.validate_shot_plan(make_plan([shot]), SCENE)
    assert any("独立于台词的 must_show" in issue for issue in issues)


def test_dialogue_text_is_free_text_not_an_enum(validator):
    """台词属于内容, 不进入任何语言固定的 schema 枚举。"""
    audio = {"mode": "optional_dialogue",
             "dialogue": {"speaker": "先生", "text": "次はあなたです。"},
             "purpose": "Clarify the request."}
    plan = make_plan([one_shot([1, 2, 3], 1, audio=audio)])
    assert not errors(validator, plan)


# ------------------------------------------------------------------ summary

def test_summary_is_human_readable(plan):
    text = shot_plan.shot_plan_summary(plan)
    assert "Shot Plan v01" in text
    assert "shot-01" in text and "beats [1, 2]" in text
    assert "Must show:" in text and "Must avoid:" in text
