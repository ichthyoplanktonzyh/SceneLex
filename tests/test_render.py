import json
import shutil
from argparse import Namespace
from pathlib import Path

import pytest
import yaml
from jsonschema import Draft202012Validator

import draft
import imagegen
import llm
import render

REPO_ROOT = Path(draft.__file__).resolve().parent.parent


VALID_PLAN = """```yaml
schema_version: "1.0"
scene_ref: test-01-proto-01
spec_version: 1
version: 1
status: draft
characters:
  - id: boy
    description: "A 14-year-old boy with short black hair, oversized gray hoodie"
setting:
  description: "A cozy modern living room with a beige sofa and a TV"
beats:
  - beat: 1
    prompt: "{setting} {char:boy} sits cross-legged on the sofa playing a video game, leaning forward, excited expression, medium shot"
    negative: "standing up, bored expression"
    audio:
      type: sfx
      text: "video game sound effects"
    duration: 4
```"""


def _env(tmp_path, monkeypatch):
    drafts = tmp_path / "data" / "drafts"
    (tmp_path / "schema").mkdir()
    shutil.copy(REPO_ROOT / "schema" / "render-plan.schema.json",
                tmp_path / "schema" / "render-plan.schema.json")
    (tmp_path / "data" / "senses").mkdir(parents=True)
    scene_dir = tmp_path / "data" / "scenes" / "test-01"
    scene_dir.mkdir(parents=True)
    (tmp_path / "data" / "senses" / "test-01.yaml").write_text(
        'schema_version: "1.0"\nstatus: reviewed\nid: test-01\n',
        encoding="utf-8",
    )
    (scene_dir / "test-01-proto-01.yaml").write_text(
        'schema_version: "1.0"\nversion: 1\nstatus: reviewed\n'
        "id: test-01-proto-01\n"
        "storyboard:\n  - beat: 1\n    visual: 男孩打游戏\n    purpose: 建立动机\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    return drafts


def test_render_schemas_are_valid_jsonschema():
    for name in ("render-plan.schema.json", "render-manifest.schema.json"):
        schema = json.loads(
            (draft.ROOT / "schema" / name).read_text("utf-8")
        )
        Draft202012Validator.check_schema(schema)


def test_plan_writes_versioned_file_with_forced_fields(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID_PLAN)
    render.cmd_plan(Namespace(scene_id="test-01-proto-01"))
    out = drafts / "renders" / "test-01-proto-01" / "v01" / "render-plan.yaml"
    assert out.exists()
    doc = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert doc["scene_ref"] == "test-01-proto-01"
    assert doc["version"] == 1
    assert doc["spec_version"] == 1


def test_plan_versions_never_overwrite(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID_PLAN)
    render.cmd_plan(Namespace(scene_id="test-01-proto-01"))
    render.cmd_plan(Namespace(scene_id="test-01-proto-01"))
    base = drafts / "renders" / "test-01-proto-01"
    assert (base / "v01" / "render-plan.yaml").exists()
    assert (base / "v02" / "render-plan.yaml").exists()
    assert yaml.safe_load(
        (base / "v02" / "render-plan.yaml").read_text(encoding="utf-8")
    )["version"] == 2


def test_plan_with_unknown_character_exits_nonzero(tmp_path, monkeypatch):
    _env(tmp_path, monkeypatch)
    bad = VALID_PLAN.replace("{char:boy}", "{char:ghost}")
    monkeypatch.setattr(llm, "generate", lambda prompt: bad)
    with pytest.raises(SystemExit):
        render.cmd_plan(Namespace(scene_id="test-01-proto-01"))


def test_next_version_spans_gaps(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    (drafts / "renders" / "test-01-proto-01" / "v01").mkdir(parents=True)
    (drafts / "renders" / "test-01-proto-01" / "v03").mkdir()
    assert render.next_version("test-01-proto-01") == 4


def test_expand_prompt_substitutes_cards():
    out = render.expand_prompt(
        "{setting} {char:boy} waves, close-up shot",
        {"boy": "a boy in a red shirt"},
        "a sunny park",
    )
    assert out == "a sunny park a boy in a red shirt waves, close-up shot"


def test_normalize_plan_strips_null_optionals():
    plan = {"beats": [{
        "beat": 1, "prompt": "x", "negative": None,
        "audio": {"type": "sfx", "text": "bang", "voice_hint": None},
        "duration": 3,
    }]}
    render.normalize_plan(plan)
    assert plan["beats"][0]["negative"] == ""
    assert "voice_hint" not in plan["beats"][0]["audio"]


def test_imagegen_finds_nodes_by_sampler_links():
    wf = json.loads((REPO_ROOT / "tools" / "workflows"
                     / "comfyui-text2image.json").read_text("utf-8"))
    assert imagegen.find_nodes(wf) == ("3", "6", "7")


def test_imagegen_prepare_injects_prompt_and_seed():
    wf = json.loads((REPO_ROOT / "tools" / "workflows"
                     / "comfyui-text2image.json").read_text("utf-8"))
    out = imagegen.prepare_workflow(wf, "POS", "NEG", 42)
    assert out["6"]["inputs"]["text"] == "POS"
    assert out["7"]["inputs"]["text"] == "NEG"
    assert out["3"]["inputs"]["seed"] == 42
    assert wf["3"]["inputs"]["seed"] != 42  # 模板不被修改


def test_render_writes_assets_and_valid_manifest(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    shutil.copy(REPO_ROOT / "schema" / "render-manifest.schema.json",
                tmp_path / "schema" / "render-manifest.schema.json")
    monkeypatch.setattr(llm, "generate", lambda prompt: VALID_PLAN)
    render.cmd_plan(Namespace(scene_id="test-01-proto-01"))
    monkeypatch.setattr(
        imagegen, "generate",
        lambda pos, neg, seed=None: (b"PNGDATA", {
            "seed": 7, "model": "test-model", "workflow": "wf.json"}),
    )
    render.cmd_render(Namespace(scene_id="test-01-proto-01",
                                version=None, beat=None, count=2))
    vdir = drafts / "renders" / "test-01-proto-01" / "v01"
    assert (vdir / "beat-01-a.png").read_bytes() == b"PNGDATA"
    assert (vdir / "beat-01-b.png").exists()
    manifest = yaml.safe_load((vdir / "render-manifest.yaml").read_text("utf-8"))
    assert manifest["renderer"]["image"]["model"] == "test-model"
    assert [i["file"] for i in manifest["beats"][0]["images"]] \
        == ["beat-01-a.png", "beat-01-b.png"]
    validator = Draft202012Validator(json.loads(
        (tmp_path / "schema" / "render-manifest.schema.json").read_text("utf-8")))
    assert not list(validator.iter_errors(manifest))


def test_plan_issues_flags_beat_mismatch():
    plan = {
        "characters": [{"id": "boy", "description": "x"}],
        "beats": [{"beat": 1, "prompt": "a", "negative": ""}],
    }
    scene = {"storyboard": [{"beat": 1}, {"beat": 2}]}
    issues = render.plan_issues(plan, scene)
    assert any("beat 序列" in i for i in issues)
