from argparse import Namespace
from types import SimpleNamespace
from unittest import mock

import pytest
import yaml

import draft
import llm
import review


GOOD_OUTPUT = """```yaml
dimensions:
  language_accuracy: pass
  semantic_conditions: pass
  observability: pass
  neighbor_discrimination: pass
  audio_visual_timing: pass
  l1_insight: pass
  transferability: pass
  licensing: pass
issues: []
summary: 证据组结构完整, 可以进入正式库。
```"""

FAIL_OUTPUT = """```yaml
dimensions:
  language_accuracy: pass
  semantic_conditions: pass
  observability: pass
  neighbor_discrimination: pass
  audio_visual_timing: pass
  l1_insight: pass
  transferability: pass
  licensing: pass
issues:
  - file: test-01-proto-01.yaml
    dimension: observability
    severity: major
    note: beat 3 用台词直述心理。
    suggestion: 改为行为外化。
summary: 原型场景违反外化要求。
```"""


def _env(tmp_path, monkeypatch):
    drafts = tmp_path / "data" / "drafts"
    (tmp_path / "data" / "senses").mkdir(parents=True)
    (tmp_path / "data" / "scenes").mkdir()
    (drafts / "senses").mkdir(parents=True)
    (drafts / "scenes" / "test-01").mkdir(parents=True)
    (drafts / "senses" / "test-01.yaml").write_text(
        'schema_version: "1.0"\nstatus: draft\nid: test-01\n'
        "semantic_type: attribute\n",
        encoding="utf-8",
    )
    (drafts / "scenes" / "test-01" / "test-01-proto-01.yaml").write_text(
        'schema_version: "1.0"\nstatus: draft\nid: test-01-proto-01\n',
        encoding="utf-8",
    )
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    return drafts


def test_review_pass_writes_record_with_digest(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: GOOD_OUTPUT)
    verdict, path = review.run_review("test-01")
    assert verdict == "pass"
    record = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert record["verdict"] == "pass"
    assert record["content_digest"] == review.content_digest([
        drafts / "senses" / "test-01.yaml",
        drafts / "scenes" / "test-01" / "test-01-proto-01.yaml",
    ])
    assert record["files"] == ["test-01.yaml", "test-01-proto-01.yaml"]


def test_review_major_issue_forces_fail_verdict(tmp_path, monkeypatch):
    _env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: FAIL_OUTPUT)
    verdict, path = review.run_review("test-01")
    assert verdict == "fail"
    record = yaml.safe_load(path.read_text(encoding="utf-8"))
    # major 问题必须把对应维度归一为 fail, 即便模型自报 pass
    assert record["dimensions"]["observability"] == "fail"


def test_review_malformed_output_saves_raw_and_exits(tmp_path, monkeypatch):
    _env(tmp_path, monkeypatch)
    monkeypatch.setattr(llm, "generate", lambda prompt: "```yaml\nfoo: bar\n```")
    with pytest.raises(SystemExit):
        review.run_review("test-01")
    assert (review.reviews_dir() / "_unparsed-test-01.txt").exists()


def test_promote_without_review_proceeds(tmp_path, monkeypatch):
    """审核是可选参考: 无记录时 promote 照常走到发布前校验。"""
    _env(tmp_path, monkeypatch)
    with mock.patch(
        "draft.subprocess.run", return_value=SimpleNamespace(returncode=1)
    ), pytest.raises(SystemExit, match="发布前校验失败"):
        draft.cmd_promote(Namespace(id="test-01"))


def test_promote_stale_review_not_archived(tmp_path, monkeypatch):
    """过期记录不阻塞 promote, 但也不随资源归档。"""
    _env(tmp_path, monkeypatch)
    review.reviews_dir().mkdir(parents=True)
    review.record_path("test-01").write_text(
        yaml.safe_dump({"verdict": "pass", "content_digest": "stale"}),
        encoding="utf-8",
    )
    with mock.patch(
        "draft.subprocess.run", return_value=SimpleNamespace(returncode=0)
    ), pytest.raises(SystemExit) as exc:
        draft.cmd_promote(Namespace(id="test-01"))
    assert exc.value.code == 0
    assert (tmp_path / "data" / "senses" / "test-01.yaml").exists()
    assert review.record_path("test-01").exists()
    assert not (tmp_path / "data" / "reviews").exists()


def test_promote_failed_review_proceeds_and_archives(tmp_path, monkeypatch):
    """未通过的审核也不阻塞; 指纹匹配的记录照样归档 (记录模型说了什么)。"""
    drafts = _env(tmp_path, monkeypatch)
    reviewed = [
        drafts / "senses" / "test-01.yaml",
        drafts / "scenes" / "test-01" / "test-01-proto-01.yaml",
    ]
    review.reviews_dir().mkdir(parents=True)
    review.record_path("test-01").write_text(
        yaml.safe_dump({
            "verdict": "fail",
            "content_digest": review.content_digest(reviewed),
        }),
        encoding="utf-8",
    )
    with mock.patch(
        "draft.subprocess.run", return_value=SimpleNamespace(returncode=0)
    ), pytest.raises(SystemExit) as exc:
        draft.cmd_promote(Namespace(id="test-01"))
    assert exc.value.code == 0
    assert not review.record_path("test-01").exists()
    assert len(list((tmp_path / "data" / "reviews").glob("test-01-*.yaml"))) == 1


def test_promote_with_passing_review_archives_record(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    reviewed = [
        drafts / "senses" / "test-01.yaml",
        drafts / "scenes" / "test-01" / "test-01-proto-01.yaml",
    ]
    review.reviews_dir().mkdir(parents=True)
    review.record_path("test-01").write_text(
        yaml.safe_dump({
            "verdict": "pass",
            "content_digest": review.content_digest(reviewed),
        }),
        encoding="utf-8",
    )
    with mock.patch(
        "draft.subprocess.run", return_value=SimpleNamespace(returncode=0)
    ), pytest.raises(SystemExit) as exc:
        draft.cmd_promote(Namespace(id="test-01"))
    assert exc.value.code == 0
    assert (tmp_path / "data" / "senses" / "test-01.yaml").exists()
    assert not review.record_path("test-01").exists()
    archived = list((tmp_path / "data" / "reviews").glob("test-01-*.yaml"))
    assert len(archived) == 1


def test_promote_rejects_unparsed_leftovers(tmp_path, monkeypatch):
    drafts = _env(tmp_path, monkeypatch)
    (drafts / "scenes" / "test-01" / "_unparsed-2.yaml").write_text(
        "broken", encoding="utf-8"
    )
    with pytest.raises(SystemExit, match="未解析残骸"):
        draft.cmd_promote(Namespace(id="test-01"))
