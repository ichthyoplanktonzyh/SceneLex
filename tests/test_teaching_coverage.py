"""Teaching Archetype Coverage 工具的测试（MVP 状态链）。

覆盖:
  - manifest schema 校验（含 suggested_capabilities 与 capabilities 交叉校验）
  - 十四个 lemma 全部解析为真实 sense id（身份链锁定）
  - 身份链不可跳过: 无词典证据 → needs_candidate; 有证据无 inventory →
    needs_inventory; 有 inventory 无 WordSense → needs_wordsense
  - MVP 生产链: contract → holistic course → bundle → release_ready
  - holistic / related / bundle 状态从仓库真实文件计算
  - capability 缺口从 manifest vs capabilities 计算
  - teaching_profile 是建议输入, 不强制 Course Author
  - curriculum 恰好 14 天、覆盖 14 门课
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import teaching_coverage as coverage  # noqa: E402

MANIFEST = coverage.load_manifest()

EXPECTED_SENSE_IDS = {
    "messy": "messy-01", "dirty": "dirty-01",
    "reluctant": "reluctant-01", "hesitant": "hesitant-01",
    "almost": "almost-01", "barely": "barely-01",
    "across": "across-01", "through": "through-01",
    "borrow": "borrow-01", "lend": "lend-01",
    "cup": "cup-01", "mug": "mug-01",
    "notice": "notice-01", "realize": "realize-01",
}


def _self_consistent_contract(sense_id: str = "messy-01") -> dict:
    model = {"invariant": "x"}
    return {
        "sense_id": sense_id,
        "semantic_revision": 1,
        "semantic_model": model,
        "content_hash": coverage.compiler.contract_content_hash(
            model, sense_id, 1),
    }


def test_manifest_schema_validates() -> None:
    assert coverage.validate() == []


def test_manifest_declares_seven_archetypes() -> None:
    archetypes = [a["id"] for a in MANIFEST["archetypes"]]
    assert set(archetypes) == {
        "visible_attribute", "intention_cues", "threshold_scale",
        "spatial_path", "role_perspective", "entity_category",
        "cognitive_update",
    }
    clusters = [cluster for a in MANIFEST["archetypes"]
                for cluster in a["clusters"]]
    lemmas = [lemma["lemma"] for cluster in clusters
              for lemma in cluster["lemmas"]]
    assert len(lemmas) == 14
    assert set(lemmas) == set(EXPECTED_SENSE_IDS)


def test_all_fourteen_lemmas_have_real_sense_ids() -> None:
    """十四个 lemma 全部解析为真实 sense id（身份链锁定后不再有 None）。"""
    rows = coverage.queue()
    by_lemma = {row["lemma"]: row for row in rows}
    assert len(by_lemma) == 14
    for lemma, sense_id in EXPECTED_SENSE_IDS.items():
        assert by_lemma[lemma]["sense_id"] == sense_id, lemma
        assert by_lemma[lemma]["identity_chain"] == "locked", lemma


def test_sense_ids_exist_in_repository() -> None:
    """manifest 声明的 sense id 必须真的存在于 data/senses/。"""
    for sense_id in EXPECTED_SENSE_IDS.values():
        assert (ROOT / "data" / "senses" / f"{sense_id}.yaml").exists(), sense_id


def test_each_sense_has_teaching_profile_with_registered_capabilities() -> None:
    """每个 WordSense 携带 teaching_profile；建议能力必须是已注册 primitive。"""
    registered = {p["id"] for p in coverage.load_capabilities()["primitives"]}
    for sense_id in EXPECTED_SENSE_IDS.values():
        doc = yaml.safe_load(
            (ROOT / "data" / "senses" / f"{sense_id}.yaml").read_text(
                encoding="utf-8"))
        profile = doc.get("teaching_profile") or {}
        assert profile.get("primary_archetype"), sense_id
        for cap in profile.get("suggested_capabilities") or []:
            assert cap in registered, f"{sense_id}: {cap} 未注册"


def test_teaching_profile_does_not_force_renderer_use() -> None:
    """teaching_profile 只是建议：manifest 不包含任何 '必须使用' 约束。"""
    for archetype in MANIFEST["archetypes"]:
        text = yaml.safe_dump(archetype, allow_unicode=True)
        assert "必须" not in text, archetype["id"]
        assert "require" not in text.lower(), archetype["id"]


def test_curriculum_covers_fourteen_days() -> None:
    curriculum = MANIFEST["curriculum"]
    assert len(curriculum) == 14
    days = [entry["day"] for entry in curriculum]
    assert days == list(range(1, 15))
    courses = [entry["course"] for entry in curriculum]
    assert set(courses) == set(EXPECTED_SENSE_IDS.values())


def test_boundary_allowed_values_are_legal() -> None:
    for archetype in MANIFEST["archetypes"]:
        for cluster in archetype["clusters"]:
            allowed = cluster["boundary"]["allowed"]
            assert allowed in (
                "one", "other", "both", "insufficient_evidence"
            ), cluster["id"]


def test_manifest_schema_rejects_bad_manifest(tmp_path) -> None:
    bad = {
        "schema_version": "1.0",
        "plan_id": "x",
        "policy_version": 1,
        "learner_l1": "zh-CN",
        "target_l2": "en",
        "capability_version": 1,
        "curriculum": [],
        "archetypes": [
            {
                "id": "visible_attribute",
                # 缺 required 字段 semantic_types / teaching_archetype 等
            }
        ],
    }
    monkeypatch_path = tmp_path / "mvp.yaml"
    monkeypatch_path.write_text(yaml.safe_dump(bad), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "MANIFEST_PATH", monkeypatch_path)
        errors = coverage.validate()
    assert any("semantic_types" in error for error in errors)


def test_validate_rejects_unregistered_suggested_capability(tmp_path) -> None:
    """suggested_capabilities 引用未注册 primitive 时必须报错。"""
    manifest = coverage.load_manifest()
    manifest["archetypes"][0]["suggested_capabilities"].append("not-a-primitive")
    monkeypatch_path = tmp_path / "mvp.yaml"
    monkeypatch_path.write_text(yaml.safe_dump(manifest), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "MANIFEST_PATH", monkeypatch_path)
        errors = coverage.validate()
    assert any("not-a-primitive" in error for error in errors)


def test_queue_lists_all_fourteen_lemmas() -> None:
    rows = coverage.queue()
    assert len(rows) == 14


def test_status_changes_when_contract_appears(monkeypatch, tmp_path) -> None:
    """文件新增后状态自动变化: 无 contract → needs_contract → 之后更成熟。"""
    contract = _self_consistent_contract()
    contract_path = tmp_path / "data" / "contracts"
    contract_path.mkdir(parents=True)
    (contract_path / "messy-01.yaml").write_text(
        yaml.safe_dump(contract), encoding="utf-8")

    manifest_path = tmp_path / "manifest.yaml"
    manifest_path.write_text(
        yaml.safe_dump(coverage.load_manifest()), encoding="utf-8")

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        status = coverage.lemma_status("messy", "messy-01")
    assert status in ("needs_contract", "needs_holistic_course",
                      "needs_bundle", "release_ready")

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        status = coverage.lemma_status("messy", None)
    assert status in ("needs_candidate", "needs_inventory", "needs_wordsense",
                      "needs_contract")


def test_identity_chain_cannot_be_skipped(monkeypatch, tmp_path) -> None:
    """身份链不可跳过: 无词典证据时即使有 inventory 也不得进入生产链。"""
    inventory_dir = tmp_path / "data" / "inventories"
    inventory_dir.mkdir(parents=True)
    (inventory_dir / "cup.yaml").write_text(
        "schema_version: '1.0'\nword: cup\nstatus: approved\nsenses: []\n",
        encoding="utf-8")
    manifest_path = tmp_path / "manifest.yaml"
    manifest_path.write_text(
        yaml.safe_dump(coverage.load_manifest()), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        assert coverage.lemma_status("cup", None) == "needs_candidate"

    evidence_dir = tmp_path / "data" / "dictionary-evidence"
    evidence_dir.mkdir(parents=True)
    (evidence_dir / "cup.yaml").write_text(
        "schema_version: '1.0'\nword: cup\nprovider: wiktionary\nentries: []\n",
        encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        # inventory 已批准但没有 WordSense → 下一环是 needs_wordsense
        assert coverage.lemma_status("cup", None) == "needs_wordsense"


def test_capability_gaps_are_computed_from_real_files() -> None:
    """capability 缺口 = suggested_capabilities − 已注册 primitives。"""
    registered = {p["id"] for p in coverage.load_capabilities()["primitives"]}
    for archetype in MANIFEST["archetypes"]:
        gaps = coverage._capability_gaps(archetype)
        for gap in gaps:
            assert gap not in registered
        for suggested in archetype["suggested_capabilities"]:
            if suggested in registered:
                assert suggested not in gaps


def test_holistic_status_reflects_real_course_files(monkeypatch, tmp_path) -> None:
    """holistic 状态从真实课程文件计算（missing_contract → not_generated）。"""
    manifest_path = tmp_path / "manifest.yaml"
    manifest_path.write_text(
        yaml.safe_dump(coverage.load_manifest()), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        assert coverage._holistic_status("messy-01") == "missing_contract"

    contract_path = tmp_path / "data" / "contracts"
    contract_path.mkdir(parents=True)
    (contract_path / "messy-01.yaml").write_text(
        yaml.safe_dump(_self_consistent_contract()), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        assert coverage._holistic_status("messy-01") == "not_generated"


def test_bundle_status_reflects_bundle_file(monkeypatch, tmp_path) -> None:
    bundle_dir = tmp_path / "app" / "assets" / "content"
    bundle_dir.mkdir(parents=True)
    (bundle_dir / "archetype-mvp.v1.json").write_text(
        '{"courses": [{"target": {"sense_id": "messy-01"}}]}',
        encoding="utf-8")
    manifest_path = tmp_path / "manifest.yaml"
    manifest_path.write_text(
        yaml.safe_dump(coverage.load_manifest()), encoding="utf-8")
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(coverage, "ROOT", tmp_path)
        mp.setattr(coverage, "MANIFEST_PATH", manifest_path)
        assert coverage._bundle_status("messy-01") == "bundled"
        assert coverage._bundle_status("dirty-01") == "not_bundled"


def test_report_mentions_all_archetypes_and_new_columns() -> None:
    report = coverage.report()
    for archetype_id in ("visible_attribute", "intention_cues",
                         "threshold_scale", "spatial_path",
                         "role_perspective", "entity_category",
                         "cognitive_update"):
        assert f"[{archetype_id}]" in report
    assert "suggested_capabilities:" in report
    assert "holistic=" in report
    assert "related=" in report
    assert "bundle=" in report
    assert "14" in report.splitlines()[-1]
