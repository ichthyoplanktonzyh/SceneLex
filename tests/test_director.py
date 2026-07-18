import json
import shutil
from argparse import Namespace

import pytest
import yaml
from jsonschema import Draft202012Validator

import director
import draft
import llm


REPO_ROOT = draft.ROOT

VALID = """```yaml
schema_version: "1.0"
scene_ref: ignored-01-proto-01
spec_version: 99
version: 99
status: draft
profile: ignored
style: ignored
strategy: direct_t2v
director_note: 一个连续镜头足以表达动作。
semantic_guardrails:
  must_show:
    - 明确任务和可见抗拒
  must_avoid:
    - 开心主动执行
video_prompts:
  - id: clip-01
    source_beats: [1, 2]
    duration_hint: 8
    prompt: "Pixar-style 3D animated short. A teenage boy keeps looking at his game, sighs, then slowly stands to carry out a trash bag."
    negative_prompt: "cheerful eager movement"
```"""


def setup_env(tmp_path, monkeypatch):
    drafts = tmp_path / "data" / "drafts"
    (tmp_path / "schema").mkdir()
    shutil.copy(
        REPO_ROOT / "schema" / "director-prompt.schema.json",
        tmp_path / "schema" / "director-prompt.schema.json",
    )
    prompt_dir = tmp_path / "prompts"
    (prompt_dir / "video-model-profiles").mkdir(parents=True)
    shutil.copy(REPO_ROOT / "prompts" / "director.md", prompt_dir / "director.md")
    shutil.copy(
        REPO_ROOT / "prompts" / "render-style.yaml",
        prompt_dir / "render-style.yaml",
    )
    shutil.copy(
        REPO_ROOT / "prompts" / "video-model-profiles" / "generic-video.md",
        prompt_dir / "video-model-profiles" / "generic-video.md",
    )
    sense_dir = tmp_path / "data" / "senses"
    scene_dir = tmp_path / "data" / "scenes" / "test-01"
    sense_dir.mkdir(parents=True)
    scene_dir.mkdir(parents=True)
    (sense_dir / "test-01.yaml").write_text(
        'schema_version: "1.0"\nid: test-01\nversion: 1\n', encoding="utf-8"
    )
    (scene_dir / "test-01-proto-01.yaml").write_text(
        'schema_version: "1.0"\nversion: 3\nid: test-01-proto-01\n'
        "storyboard:\n"
        "  - beat: 1\n    visual: 收到任务\n    purpose: 建立压力\n"
        "  - beat: 2\n    visual: 缓慢行动\n    purpose: 外化抗拒\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    monkeypatch.setattr(draft, "PROMPTS", prompt_dir)
    return drafts


def test_schema_is_valid_jsonschema():
    schema = json.loads(
        (REPO_ROOT / "schema" / "director-prompt.schema.json").read_text("utf-8")
    )
    Draft202012Validator.check_schema(schema)


def test_generate_writes_versioned_prompt_and_forces_metadata(tmp_path, monkeypatch):
    drafts = setup_env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID)
    args = Namespace(scene_id="test-01-proto-01", profile="generic-video")
    director.cmd_generate(args)
    director.cmd_generate(args)
    first = drafts / "director" / "test-01-proto-01" / "v01" / "director-prompt.yaml"
    second = drafts / "director" / "test-01-proto-01" / "v02" / "director-prompt.yaml"
    assert first.exists() and second.exists()
    document = yaml.safe_load(second.read_text("utf-8"))
    assert document["scene_ref"] == "test-01-proto-01"
    assert document["spec_version"] == 3
    assert document["version"] == 2
    assert document["profile"] == "generic-video"
    assert document["style"] == "pixar-3d"


def test_prompt_issues_requires_all_beats():
    document = yaml.safe_load(VALID.split("```yaml\n", 1)[1].rsplit("```", 1)[0])
    document["video_prompts"][0]["source_beats"] = [1]
    issues = director.prompt_issues(
        document, {"storyboard": [{"beat": 1}, {"beat": 2}]}
    )
    assert any("未覆盖" in issue for issue in issues)


def test_image_guided_strategy_requires_image_prompt():
    document = yaml.safe_load(VALID.split("```yaml\n", 1)[1].rsplit("```", 1)[0])
    document["strategy"] = "image_guided_i2v"
    issues = director.prompt_issues(
        document, {"storyboard": [{"beat": 1}, {"beat": 2}]}
    )
    assert any("image_prompt" in issue for issue in issues)


def test_pixar_style_anchor_is_required_in_prompt():
    document = yaml.safe_load(VALID.split("```yaml\n", 1)[1].rsplit("```", 1)[0])
    document["style"] = "pixar-3d"
    document["video_prompts"][0]["prompt"] = "A boy slowly carries a trash bag."
    issues = director.prompt_issues(
        document, {"storyboard": [{"beat": 1}, {"beat": 2}]}
    )
    assert any("Pixar-style" in issue for issue in issues)


def test_unknown_profile_exits(tmp_path, monkeypatch):
    setup_env(tmp_path, monkeypatch)
    with pytest.raises(SystemExit):
        director.profile_path("missing")
