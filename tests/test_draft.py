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
