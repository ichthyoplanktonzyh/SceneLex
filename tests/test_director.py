"""Director: SceneSpec 语义节拍 → 可执行 Shot Plan。"""

import shutil
from argparse import Namespace

import pytest
import yaml

import director
import draft
import llm


REPO_ROOT = draft.ROOT

SHOTS = """
title: Taking Out the Trash — Shot Plan
cast:
  - id: boy
    role: focal_character
    continuity_description: A teenage boy in a gray hoodie.
location:
  id: living-room
  continuity_description: A small living room with a low sofa and a TV.
props:
  - id: trash-bag
    continuity_description: A tied white kitchen trash bag.
shots:
  - id: shot-01
    source_beats: [1]
    narrative_function: establish_trigger
    semantic_function: 建立外部要求
    duration_hint: 3.0
    visual_start:
      description: The boy sits cross-legged on the sofa with a controller.
      character_states:
        - character: boy
          state: seated, leaning toward the screen
    trigger:
      description: A trash bag is set down beside his feet.
    action:
      description: His hands stop moving and he glances down at the bag.
    visual_end:
      description: The boy sits still, controller lowered to his knees.
      character_states:
        - character: boy
          state: seated, controller resting on knees
    composition:
      shot_size: medium_wide
      angle: eye_level
      focal_subject: the boy and the trash bag
      staging: Boy on the right of frame, bag in the near foreground.
    camera:
      movement: static
      motivation: Keep the request and the subject in one frame.
    semantic_evidence:
      must_show:
        - The request is aimed at this boy.
      must_avoid:
        - The boy looking pleased about the task.
    audio:
      mode: sfx
      sfx:
        - video game音效
      purpose: Mark what he would rather keep doing.
    continuity:
      enters_from_previous: null
      exits_to_next: Boy stays seated, bag at his feet.
  - id: shot-02
    source_beats: [1, 2]
    narrative_function: show_resistance
    semantic_function: 抗拒外化与迟缓行动
    duration_hint: 4.0
    visual_start:
      description: The boy sits still with the controller on his knees.
      character_states:
        - character: boy
          state: seated, shoulders dropping
    trigger:
      description: The bag stays untouched at his feet.
    action:
      description: He exhales, sets the controller down slowly and lifts the bag with two fingers.
    visual_end:
      description: The boy stands holding the bag at arm's length, head turned back toward the screen.
      character_states:
        - character: boy
          state: standing, torso turned back toward the sofa
    composition:
      shot_size: medium
      angle: three_quarter
      focal_subject: the boy's face and hands
      staging: Boy fills the right of frame, the screen glows behind him.
    camera:
      movement: push_in
      motivation: Tighten on the hesitation as the action begins.
    semantic_evidence:
      must_show:
        - The action begins despite visible resistance.
      must_avoid:
        - Eager or energetic movement.
    audio:
      mode: silence
      purpose: Let the slowness carry the meaning.
    continuity:
      enters_from_previous: Same seat and posture as the end of shot-01.
      exits_to_next: null
"""

VALID = f"```yaml{SHOTS}```"


def setup_env(tmp_path, monkeypatch, *, scene_schema_version="1.1",
              scene_revision=1, sense_schema_version="1.1", sense_revision=1,
              write_sense=True):
    drafts = tmp_path / "data" / "drafts"
    (tmp_path / "schema").mkdir()
    shutil.copy(
        REPO_ROOT / "schema" / "shot-plan.schema.json",
        tmp_path / "schema" / "shot-plan.schema.json",
    )
    prompt_dir = tmp_path / "prompts"
    prompt_dir.mkdir(parents=True)
    shutil.copy(REPO_ROOT / "prompts" / "shot-plan.md", prompt_dir / "shot-plan.md")

    sense_dir = tmp_path / "data" / "senses"
    scene_dir = tmp_path / "data" / "scenes" / "test-01"
    sense_dir.mkdir(parents=True)
    scene_dir.mkdir(parents=True)
    if write_sense:
        sense = {"schema_version": sense_schema_version, "id": "test-01",
                 "version": 1}
        if sense_revision is not None:
            sense["semantic_revision"] = sense_revision
        (sense_dir / "test-01.yaml").write_text(
            yaml.safe_dump(sense, sort_keys=False), encoding="utf-8"
        )
    scene = {
        "schema_version": scene_schema_version,
        "version": 3,
        "status": "reviewed",
        "id": "test-01-proto-01",
        "sense_ref": "test-01",
        "storyboard": [
            {"beat": 1, "visual": "收到任务", "purpose": "建立压力"},
            {"beat": 2, "visual": "缓慢行动", "purpose": "外化抗拒"},
        ],
    }
    if scene_revision is not None:
        scene["sense_revision"] = scene_revision
    (scene_dir / "test-01-proto-01.yaml").write_text(
        yaml.safe_dump(scene, allow_unicode=True, sort_keys=False), encoding="utf-8"
    )
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    monkeypatch.setattr(draft, "PROMPTS", prompt_dir)
    return drafts


def plan_args():
    return Namespace(scene_id="test-01-proto-01")


def never_called(prompt):
    raise AssertionError("LLM 不应被调用")


def load(drafts, version=1):
    path = (drafts / "shot-plans" / "test-01-proto-01" / f"v{version:02d}"
            / "shot-plan.yaml")
    return yaml.safe_load(path.read_text("utf-8"))


# ------------------------------------------------------------ 上游要求

def test_plan_reads_scene_and_sense_and_calls_llm(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    seen = {}

    def fake(prompt):
        seen["prompt"] = prompt
        return VALID

    monkeypatch.setattr(llm, "generate", fake)
    director.cmd_plan(plan_args())
    assert "test-01-proto-01" in seen["prompt"]
    assert "storyboard" in seen["prompt"]
    assert "semantic_revision" in seen["prompt"]
    assert load(drafts)["scene_ref"] == "test-01-proto-01"


def test_legacy_scene_fails_before_calling_the_model(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch, scene_schema_version="1.0",
              scene_revision=None)
    monkeypatch.setattr(llm, "generate", never_called)
    with pytest.raises(SystemExit) as exc:
        director.cmd_plan(plan_args())
    assert "LEGACY" in str(exc.value)


def test_needs_review_scene_fails_before_calling_the_model(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch, scene_revision=1, sense_revision=2)
    monkeypatch.setattr(llm, "generate", never_called)
    with pytest.raises(SystemExit) as exc:
        director.cmd_plan(plan_args())
    assert "NEEDS_REVIEW" in str(exc.value)


def test_missing_wordsense_fails(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch, write_sense=False)
    monkeypatch.setattr(llm, "generate", never_called)
    with pytest.raises(SystemExit) as exc:
        director.cmd_plan(plan_args())
    assert "找不到义项" in str(exc.value)


def test_legacy_wordsense_fails(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch, sense_schema_version="1.0",
              sense_revision=None)
    monkeypatch.setattr(llm, "generate", never_called)
    with pytest.raises(SystemExit) as exc:
        director.cmd_plan(plan_args())
    assert "INVALID" in str(exc.value)


# ------------------------------------------------------- 权威字段与漂移

def test_omitted_authoritative_fields_are_written_by_the_tool(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_plan(plan_args())
    plan = load(drafts)
    assert plan["schema_version"] == "1.0"
    assert plan["version"] == 1
    assert plan["status"] == "draft"
    assert plan["id"] == "test-01-proto-01-shot-plan-01"
    assert plan["scene_ref"] == "test-01-proto-01"
    assert plan["scene_version"] == 3
    assert plan["sense_ref"] == "test-01"
    assert plan["sense_revision"] == 1
    assert plan["total_duration_hint"] == 7.0


@pytest.mark.parametrize("line", [
    "scene_ref: messy-01-proto-01",
    "scene_version: 9",
    "sense_ref: messy-01",
    "sense_revision: 4",
])
def test_explicitly_wrong_identity_field_fails_and_writes_nothing(
    tmp_path, monkeypatch, line
):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: f"```yaml\n{line}{SHOTS}```")
    with pytest.raises(SystemExit) as exc:
        director.cmd_plan(plan_args())
    assert director.shot_plan_lib.IDENTITY_DRIFT_KEYWORD in str(exc.value)
    base = drafts / "shot-plans" / "test-01-proto-01"
    assert not (base / "v01").exists()
    assert (base / "_invalid-shot-plan.yaml").exists()


def test_invalid_plan_is_not_written_to_the_normal_path(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    # beat 2 无人覆盖: 结构校验失败, 正常路径不得出现文件。
    broken = VALID.replace("source_beats: [1, 2]", "source_beats: [1]")
    monkeypatch.setattr(llm, "generate", lambda prompt: broken)
    with pytest.raises(SystemExit):
        director.cmd_plan(plan_args())
    base = drafts / "shot-plans" / "test-01-proto-01"
    assert not (base / "v01").exists()
    assert (base / "_invalid-shot-plan.yaml").exists()


def test_unparsable_output_goes_to_a_side_file(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: "```yaml\nshots: [ unclosed\n```")
    with pytest.raises(SystemExit):
        director.cmd_plan(plan_args())
    base = drafts / "shot-plans" / "test-01-proto-01"
    assert (base / "_unparsed-shot-plan.txt").exists()
    assert not (base / "v01").exists()


# ------------------------------------------------------------ 版本与展示

def test_second_plan_writes_v02_without_overwriting(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_plan(plan_args())
    director.cmd_plan(plan_args())
    assert load(drafts, 1)["version"] == 1
    assert load(drafts, 2)["version"] == 2
    assert load(drafts, 2)["id"] == "test-01-proto-01-shot-plan-02"


def test_show_defaults_to_latest_and_can_select_a_version(
    tmp_path, monkeypatch, capsys
):
    setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_plan(plan_args())
    director.cmd_plan(plan_args())
    capsys.readouterr()

    director.cmd_show(Namespace(scene_id="test-01-proto-01", version=None))
    assert "Shot Plan v02" in capsys.readouterr().out

    director.cmd_show(Namespace(scene_id="test-01-proto-01", version=1))
    out = capsys.readouterr().out
    assert "Shot Plan v01" in out
    assert "shot-01" in out and "beats [1]" in out
    assert "Must show:" in out


def test_show_warns_when_the_scene_version_moved(tmp_path, monkeypatch, capsys):
    tmp = tmp_path
    setup_env(tmp, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_plan(plan_args())
    scene_path = tmp / "data" / "scenes" / "test-01" / "test-01-proto-01.yaml"
    scene = yaml.safe_load(scene_path.read_text("utf-8"))
    scene["version"] = 4
    scene_path.write_text(yaml.safe_dump(scene, allow_unicode=True, sort_keys=False),
                          encoding="utf-8")
    capsys.readouterr()
    director.cmd_show(Namespace(scene_id="test-01-proto-01", version=None))
    assert "source Scene version has changed" in capsys.readouterr().err


def test_show_without_any_plan_exits(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch)
    with pytest.raises(SystemExit):
        director.cmd_show(Namespace(scene_id="test-01-proto-01", version=None))


def test_list_reports_shots_duration_and_upstream(tmp_path, monkeypatch, capsys):
    setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_plan(plan_args())
    capsys.readouterr()
    director.cmd_list(Namespace())
    out = capsys.readouterr().out
    assert "test-01-proto-01 v01: 2 shots / 7.0s / scene v3 / sense rev1" in out


def test_list_marks_legacy_director_prompts_separately(tmp_path, monkeypatch, capsys):
    drafts = setup_env(tmp_path, monkeypatch)
    legacy = drafts / "director" / "test-01-proto-01" / "v01"
    legacy.mkdir(parents=True)
    (legacy / "director-prompt.yaml").write_text("strategy: direct_t2v\n",
                                                 encoding="utf-8")
    director.cmd_list(Namespace())
    out = capsys.readouterr().out
    assert "尚无 Shot Plan" in out
    assert "legacy-director-prompt" in out


# ------------------------------------------------------------ 兼容别名

def test_generate_is_a_deprecated_alias_for_plan(tmp_path, monkeypatch, capsys):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    director.cmd_generate(Namespace(scene_id="test-01-proto-01",
                                    profile="wan2.2-ti2v-5b"))
    captured = capsys.readouterr()
    assert "已弃用" in captured.err
    assert "--profile" in captured.err
    assert load(drafts)["scene_ref"] == "test-01-proto-01"
    # 旧的 director-prompt.yaml 不再生成
    assert not (drafts / "director").exists()
