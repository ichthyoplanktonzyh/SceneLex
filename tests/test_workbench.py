import pytest
from fastapi import HTTPException

import workbench


def test_draft_path_guard_rejects_published_and_traversal():
    with pytest.raises(HTTPException) as exc:
        workbench._resolve_draft_path("data/senses/messy-01.yaml")
    assert exc.value.status_code == 403
    with pytest.raises(HTTPException) as exc:
        workbench._resolve_draft_path("data/drafts/../../schema/x.yaml")
    assert exc.value.status_code == 403


def test_draft_path_guard_accepts_real_draft(tmp_path, monkeypatch):
    drafts = tmp_path / "data" / "drafts" / "senses"
    drafts.mkdir(parents=True)
    (drafts / "test-01.yaml").write_text("id: test-01\n")
    monkeypatch.setattr(workbench, "ROOT", tmp_path)
    p = workbench._resolve_draft_path("data/drafts/senses/test-01.yaml")
    assert p.name == "test-01.yaml"


def test_env_file_parser(tmp_path, monkeypatch):
    (tmp_path / ".env").write_text(
        "# comment\nexport A=1\nB='two'\nexport C=\"three\"\nnoise\n"
    )
    monkeypatch.setattr(workbench, "ROOT", tmp_path)
    assert workbench._load_env_file() == {"A": "1", "B": "two", "C": "three"}
