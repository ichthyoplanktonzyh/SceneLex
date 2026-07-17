from argparse import Namespace
from types import SimpleNamespace
from unittest import mock

import pytest

import draft


def test_mark_reviewed_preserves_document_text():
    source = "schema_version: \"1.0\"\nstatus: draft\nid: test-01\n"
    assert draft._mark_reviewed(source) == (
        "schema_version: \"1.0\"\nstatus: reviewed\nid: test-01\n"
    )


def test_mark_reviewed_rejects_missing_status():
    with pytest.raises(ValueError):
        draft._mark_reviewed("id: test-01\n")


def test_failed_preflight_does_not_move_draft(tmp_path, monkeypatch):
    root = tmp_path
    drafts = root / "data" / "drafts"
    (root / "data" / "senses").mkdir(parents=True)
    (root / "data" / "scenes").mkdir()
    (drafts / "senses").mkdir(parents=True)
    candidate = drafts / "senses" / "test-01.yaml"
    candidate.write_text('schema_version: "1.0"\nstatus: draft\nid: test-01\n')
    monkeypatch.setattr(draft, "ROOT", root)
    monkeypatch.setattr(draft, "DRAFTS", drafts)

    with mock.patch(
        "draft.subprocess.run", return_value=SimpleNamespace(returncode=1)
    ), pytest.raises(SystemExit):
        draft.cmd_promote(Namespace(id="test-01"))

    assert candidate.exists()
    assert not (root / "data" / "senses" / "test-01.yaml").exists()


def test_promote_rejects_path_like_identifier():
    with pytest.raises(SystemExit):
        draft.cmd_promote(Namespace(id="../escape-01"))


def test_next_scene_id_spans_published_and_drafts(tmp_path, monkeypatch):
    published = tmp_path / "data" / "scenes" / "test-01"
    drafts = tmp_path / "data" / "drafts" / "scenes" / "test-01"
    published.mkdir(parents=True)
    drafts.mkdir(parents=True)
    (published / "test-01-proto-01.yaml").write_text("id: test-01-proto-01\n")
    (drafts / "test-01-proto-02.yaml").write_text("id: test-01-proto-02\n")
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", tmp_path / "data" / "drafts")
    assert draft.next_scene_id("test-01", "prototype") == "test-01-proto-03"
    assert draft.next_scene_id("test-01", "transfer") == "test-01-transfer-01"


def _batch_env(tmp_path, monkeypatch):
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", tmp_path / "data" / "drafts")
    monkeypatch.setattr(
        draft, "BATCH_STATE", tmp_path / "data" / "drafts" / "batch-state.json"
    )


def test_batch_runs_both_stages_and_cleans_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    import dictionary
    monkeypatch.setattr(dictionary, "sense_count", lambda w: 1)
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (True, "ok")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=False, concurrency=1))
    assert calls == [("sense", "nearly", "--num", "01"), ("scenes", "nearly-01")]
    assert not draft.BATCH_STATE.exists()


def test_batch_failed_sense_skips_scenes_and_keeps_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    import dictionary
    monkeypatch.setattr(dictionary, "sense_count", lambda w: 1)
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (False, "boom")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=False, concurrency=1))
    assert calls == [("sense", "nearly", "--num", "01")]
    assert draft.BATCH_STATE.exists()


def test_batch_resumes_from_recorded_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    import dictionary
    monkeypatch.setattr(dictionary, "sense_count", lambda w: 1)
    draft.BATCH_STATE.parent.mkdir(parents=True)
    draft.BATCH_STATE.write_text('{"nearly": {"senses": {"01": "done"}}}')
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (True, "ok")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=False, concurrency=1))
    assert calls == [("scenes", "nearly-01")]
