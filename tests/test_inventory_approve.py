"""Sense Inventory 的 approve 状态流与 approved inventory 只读加载接口。

所有测试都在 tmp_path 中重定向目录, 不触碰仓库真实数据, 不发网络请求。
"""

from argparse import Namespace
from pathlib import Path

import pytest
import yaml

import inventory

FIXTURES = Path(__file__).parent / "fixtures"
APPROVED_FIXTURE = FIXTURES / "inventories" / "approved-slow.yaml"
EVIDENCE_FIXTURE = FIXTURES / "dictionary-evidence" / "slow.yaml"


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _entries() -> list[dict]:
    return _load(EVIDENCE_FIXTURE)["entries"]


@pytest.fixture
def dirs(tmp_path, monkeypatch):
    """把四个 inventory 目录全部重定向到 tmp_path。"""
    paths = Namespace(
        drafts=tmp_path / "drafts" / "inventories",
        drafts_evidence=tmp_path / "drafts" / "dictionary-evidence",
        official=tmp_path / "inventories",
        official_evidence=tmp_path / "dictionary-evidence",
    )
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", paths.drafts)
    monkeypatch.setattr(inventory, "DRAFTS_EVIDENCE", paths.drafts_evidence)
    monkeypatch.setattr(inventory, "INVENTORIES", paths.official)
    monkeypatch.setattr(inventory, "EVIDENCE", paths.official_evidence)

    def _must_not_fetch(word, refresh=False):
        raise AssertionError("approve/load 阶段不应发起实时词典抓取")

    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries", _must_not_fetch)
    return paths


def _write(path: Path, doc: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(yaml.safe_dump(doc, allow_unicode=True, sort_keys=False),
                    encoding="utf-8")


def _seed_draft(dirs, status="reviewed", **overrides) -> dict:
    doc = _load(APPROVED_FIXTURE)
    doc["status"] = status
    doc.update(overrides)
    _write(dirs.drafts / "slow.yaml", doc)
    _write(dirs.drafts_evidence / "slow.yaml", _load(EVIDENCE_FIXTURE))
    return doc


def _seed_approved(dirs, **overrides) -> dict:
    doc = _load(APPROVED_FIXTURE)
    doc.update(overrides)
    _write(dirs.official / "slow.yaml", doc)
    _write(dirs.official_evidence / "slow.yaml", _load(EVIDENCE_FIXTURE))
    return doc


# ------------------------------------------------------------ mark-reviewed

def test_mark_reviewed_promotes_draft_status(dirs):
    _seed_draft(dirs, status="draft")
    inventory.cmd_mark_reviewed(Namespace(word="slow"))
    assert _load(dirs.drafts / "slow.yaml")["status"] == "reviewed"


def test_mark_reviewed_does_not_touch_evidence_snapshot(dirs):
    _seed_draft(dirs, status="draft")
    before = (dirs.drafts_evidence / "slow.yaml").read_text(encoding="utf-8")
    inventory.cmd_mark_reviewed(Namespace(word="slow"))
    assert (dirs.drafts_evidence / "slow.yaml").read_text(encoding="utf-8") == before


def test_mark_reviewed_rejects_invalid_draft(dirs):
    doc = _seed_draft(dirs, status="draft")
    doc["deferred_entries"] = []  # slow-dict-004 变成未处理条目
    _write(dirs.drafts / "slow.yaml", doc)
    with pytest.raises(SystemExit):
        inventory.cmd_mark_reviewed(Namespace(word="slow"))
    assert _load(dirs.drafts / "slow.yaml")["status"] == "draft"


# ------------------------------------------------------------------ approve

def test_approve_rejects_draft_status(dirs):
    _seed_draft(dirs, status="draft")
    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=False))
    assert not (dirs.official / "slow.yaml").exists()
    assert not (dirs.official_evidence / "slow.yaml").exists()


def test_approve_accepts_reviewed_status_and_writes_both_files(dirs):
    _seed_draft(dirs, status="reviewed")
    inventory.cmd_approve(Namespace(word="slow", force=False))

    approved = _load(dirs.official / "slow.yaml")
    assert approved["status"] == "approved"
    assert [s["id"] for s in approved["senses"]] == ["slow-01", "slow-02", "slow-03"]

    snapshot = _load(dirs.official_evidence / "slow.yaml")
    assert [e["entry_id"] for e in snapshot["entries"]] == [
        e["entry_id"] for e in _entries()
    ]


def test_approve_sets_status_programmatically(dirs):
    """草稿里即使写了别的 status, 正式库也必须是 approved。"""
    doc = _seed_draft(dirs, status="reviewed")
    assert doc["status"] == "reviewed"
    inventory.cmd_approve(Namespace(word="slow", force=False))
    assert _load(dirs.official / "slow.yaml")["status"] == "approved"
    # draft 不被删除, 便于审计
    assert (dirs.drafts / "slow.yaml").exists()


def test_approve_keeps_draft_for_audit(dirs):
    _seed_draft(dirs, status="reviewed")
    before = (dirs.drafts / "slow.yaml").read_text(encoding="utf-8")
    inventory.cmd_approve(Namespace(word="slow", force=False))
    assert (dirs.drafts / "slow.yaml").read_text(encoding="utf-8") == before


def test_approve_fails_when_evidence_digest_mismatches(dirs):
    doc = _seed_draft(dirs, status="reviewed")
    doc["source"]["evidence_digest"] = "sha256:" + "0" * 64
    _write(dirs.drafts / "slow.yaml", doc)
    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=False))
    assert not (dirs.official / "slow.yaml").exists()


def test_approve_fails_without_evidence_snapshot(dirs):
    _seed_draft(dirs, status="reviewed")
    (dirs.drafts_evidence / "slow.yaml").unlink()
    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=False))


def test_approve_refuses_to_overwrite_existing_without_force(dirs):
    _seed_approved(dirs)
    _seed_draft(dirs, status="reviewed")
    before = (dirs.official / "slow.yaml").read_text(encoding="utf-8")
    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=False))
    assert (dirs.official / "slow.yaml").read_text(encoding="utf-8") == before


def test_force_reapprove_without_identity_change_succeeds(dirs):
    _seed_approved(dirs)
    doc = _seed_draft(dirs, status="reviewed")
    # 只润色自由文本, 锁定身份不变
    doc["senses"][1]["label_zh"] = "自身放慢 (措辞润色)"
    _write(dirs.drafts / "slow.yaml", doc)
    inventory.cmd_approve(Namespace(word="slow", force=True))
    assert _load(dirs.official / "slow.yaml")["senses"][1]["label_zh"] == \
        "自身放慢 (措辞润色)"


def test_force_fails_when_identity_changes_without_version_bump(dirs):
    _seed_approved(dirs)
    doc = _seed_draft(dirs, status="reviewed")
    doc["senses"][1]["semantic_signature"]["valency"] = "transitive"
    _write(dirs.drafts / "slow.yaml", doc)

    before = (dirs.official / "slow.yaml").read_text(encoding="utf-8")
    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=True))
    assert (dirs.official / "slow.yaml").read_text(encoding="utf-8") == before


def test_force_allows_identity_change_when_version_increases(dirs, capsys):
    _seed_approved(dirs)
    doc = _seed_draft(dirs, status="reviewed")
    doc["senses"][1]["semantic_signature"]["valency"] = "transitive"
    doc["inventory_version"] = 2
    _write(dirs.drafts / "slow.yaml", doc)

    inventory.cmd_approve(Namespace(word="slow", force=True))
    approved = _load(dirs.official / "slow.yaml")
    assert approved["inventory_version"] == 2
    assert approved["senses"][1]["semantic_signature"]["valency"] == "transitive"
    assert "身份被改写" in capsys.readouterr().err


def test_failed_approve_leaves_previous_official_files_intact(dirs):
    _seed_approved(dirs)
    inventory_before = (dirs.official / "slow.yaml").read_text(encoding="utf-8")
    evidence_before = (dirs.official_evidence / "slow.yaml").read_text(encoding="utf-8")

    doc = _seed_draft(dirs, status="reviewed")
    doc["senses"][2]["id"] = "slow-07"  # 编号不连续, 草稿校验失败
    _write(dirs.drafts / "slow.yaml", doc)

    with pytest.raises(SystemExit):
        inventory.cmd_approve(Namespace(word="slow", force=True))
    assert (dirs.official / "slow.yaml").read_text(encoding="utf-8") == inventory_before
    assert (dirs.official_evidence / "slow.yaml").read_text(encoding="utf-8") == \
        evidence_before


# ------------------------------------------------------- load_approved_*

def test_loader_fails_when_only_a_draft_exists(dirs):
    _seed_draft(dirs, status="reviewed")
    with pytest.raises(inventory.InventoryError) as exc:
        inventory.load_approved_inventory("slow")
    assert "No approved Sense Inventory for 'slow'" in str(exc.value)


def test_loader_never_falls_back_to_draft_content(dirs):
    """draft 里有 slow-04 也不会被看见: loader 只读正式目录。"""
    doc = _load(APPROVED_FIXTURE)
    doc["status"] = "reviewed"
    _write(dirs.drafts / "slow.yaml", doc)
    _write(dirs.drafts_evidence / "slow.yaml", _load(EVIDENCE_FIXTURE))
    _seed_approved(dirs)
    loaded = inventory.load_approved_inventory("slow")
    assert loaded["status"] == "approved"


def test_loader_rejects_non_approved_status(dirs):
    _seed_approved(dirs, status="reviewed")
    with pytest.raises(inventory.InventoryError) as exc:
        inventory.load_approved_inventory("slow")
    assert "status" in str(exc.value)


def test_loader_requires_official_evidence_snapshot(dirs):
    _seed_approved(dirs)
    (dirs.official_evidence / "slow.yaml").unlink()
    with pytest.raises(inventory.InventoryError) as exc:
        inventory.load_approved_inventory("slow")
    assert "evidence snapshot" in str(exc.value)


def test_loader_rejects_digest_mismatch(dirs):
    _seed_approved(dirs)
    snapshot = _load(EVIDENCE_FIXTURE)
    snapshot["entries"][0]["gloss"] = "A silently drifted gloss."
    _write(dirs.official_evidence / "slow.yaml", snapshot)
    with pytest.raises(inventory.InventoryError) as exc:
        inventory.load_approved_inventory("slow")
    assert "evidence digest 不一致" in str(exc.value)


def test_loader_rejects_content_validation_failure(dirs):
    doc = _load(APPROVED_FIXTURE)
    doc["deferred_entries"] = []
    _seed_approved(dirs)
    _write(dirs.official / "slow.yaml", doc)
    with pytest.raises(inventory.InventoryError):
        inventory.load_approved_inventory("slow")


def test_loader_succeeds_on_valid_approved_inventory(dirs):
    _seed_approved(dirs)
    loaded = inventory.load_approved_inventory("slow")
    assert loaded["word"] == "slow"
    assert inventory.inventory_sense_ids(loaded) == [
        "slow-01", "slow-02", "slow-03"
    ]
    # dirs fixture 已把实时抓取替换成断言失败的桩; 能走到这里即证明未触网。
    assert len(inventory.load_approved_evidence_entries("slow")) == 4


# ------------------------------------------------------------ identity digest

def test_identity_digest_is_stable_and_ignores_free_text():
    doc = _load(APPROVED_FIXTURE)
    sense = inventory.find_inventory_sense(doc, "slow-02")
    before = inventory.compute_identity_digest(sense)

    polished = dict(sense)
    polished["label_zh"] = "换一个说法"
    polished["definition"] = "A completely rewritten but equivalent definition."
    polished["decision"] = {"type": "keep", "reason": "重写理由"}
    assert inventory.compute_identity_digest(polished) == before


def test_identity_digest_changes_with_semantic_signature():
    doc = _load(APPROVED_FIXTURE)
    sense = dict(inventory.find_inventory_sense(doc, "slow-02"))
    before = inventory.compute_identity_digest(sense)
    sense["semantic_signature"] = dict(sense["semantic_signature"])
    sense["semantic_signature"]["causative"] = True
    assert inventory.compute_identity_digest(sense) != before


def test_identity_digest_is_prefixed_sha256():
    doc = _load(APPROVED_FIXTURE)
    digest = inventory.compute_identity_digest(
        inventory.find_inventory_sense(doc, "slow-01")
    )
    assert digest.startswith("sha256:")
    assert len(digest) == len("sha256:") + 64
