from argparse import Namespace
from pathlib import Path

import pytest
import yaml

import draft
import inventory

FIXTURE = Path(__file__).parent / "fixtures" / "inventories" / "slow.yaml"

SLOW_ENTRIES = [
    {
        "entry_id": "slow-dict-001",
        "pos": "adjective",
        "gloss": "Moving or operating at a low rate.",
        "labels": [],
        "examples": ["He walked at a slow pace."],
    },
    {
        "entry_id": "slow-dict-002",
        "pos": "verb",
        "gloss": "To become slower.",
        "labels": ["intransitive"],
        "examples": ["Traffic slowed near the exit."],
    },
    {
        "entry_id": "slow-dict-003",
        "pos": "verb",
        "gloss": "To cause something to become slower.",
        "labels": ["transitive"],
        "examples": ["The driver slowed the car."],
    },
    {
        "entry_id": "slow-dict-004",
        "pos": "noun",
        "gloss": "A period of reduced activity.",
        "labels": ["rare"],
        "examples": [],
    },
]


def _load_fixture_doc():
    return yaml.safe_load(FIXTURE.read_text(encoding="utf-8"))


def _sense(id_, source_entries, decision_type="keep", definition="ok", reason="fine"):
    return {
        "id": id_,
        "definition": definition,
        "decision": {"type": decision_type, "reason": reason},
        "source_entries": source_entries,
    }


def _deferred(source_entry, reason="not stable"):
    return {"source_entry": source_entry, "reason": reason}


def _relation(source, target, distinction="axis"):
    return {"source": source, "target": target, "relation": "example",
            "distinction": distinction}


def _doc(senses=None, deferred=None, relations=None):
    return {
        "senses": senses or [],
        "deferred_entries": deferred or [],
        "relations": relations or [],
    }


def _entries(*ids):
    return [{"entry_id": i} for i in ids]


def _base_doc(word="slow", entries=None, **overrides):
    """身份字段全部一致的最小合法 doc, 供单独破坏某一个字段的测试使用。"""
    entries = entries if entries is not None else SLOW_ENTRIES
    doc = {
        "word": word,
        "language": "en",
        "source": {
            "provider": "wiktionary",
            "entry_count": len(entries),
            "evidence_digest": inventory.compute_evidence_digest(entries),
        },
        "senses": [],
        "deferred_entries": [],
        "relations": [],
    }
    doc.update(overrides)
    return doc


def test_get_filtered_entries_generates_stable_ids(monkeypatch):
    import dictionary
    monkeypatch.setattr(
        dictionary, "teachable_senses",
        lambda w, refresh=False: [
            {"pos": "adjective", "glosses": ["slow gloss"], "tags": [], "examples": []},
            {"pos": "verb", "glosses": ["speed down gloss"], "tags": ["transitive"],
             "examples": ["The driver slowed the car."]},
        ],
    )
    entries = dictionary.get_filtered_entries("slow")
    assert [e["entry_id"] for e in entries] == ["slow-dict-001", "slow-dict-002"]
    assert entries[1]["labels"] == ["transitive"]
    assert entries[1]["examples"] == ["The driver slowed the car."]


# ---------------------------------------------------------- schema + content

def test_fixture_passes_schema_and_content_validation():
    doc = _load_fixture_doc()
    validator = draft.load_schema(inventory.SCHEMA_NAME)
    assert list(validator.iter_errors(doc)) == []
    assert inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow") == []


def test_duplicate_sense_id_fails():
    doc = _doc(senses=[
        _sense("slow-01", ["slow-dict-001"]),
        _sense("slow-01", ["slow-dict-002"]),
    ])
    errors = inventory.validate_inventory_content(
        doc, _entries("slow-dict-001", "slow-dict-002"), "slow"
    )
    assert any("重复" in e for e in errors)


def test_id_lemma_prefix_mismatch_fails():
    doc = _doc(senses=[_sense("fast-01", ["slow-dict-001"])])
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert any("前缀" in e for e in errors)


def test_noncontiguous_numbering_fails():
    doc = _doc(senses=[
        _sense("slow-01", ["slow-dict-001"]),
        _sense("slow-03", ["slow-dict-002"]),
    ])
    errors = inventory.validate_inventory_content(
        doc, _entries("slow-dict-001", "slow-dict-002"), "slow"
    )
    assert any("编号不连续" in e for e in errors)


def test_relation_reference_to_missing_sense_fails():
    doc = _doc(
        senses=[_sense("slow-01", ["slow-dict-001"])],
        relations=[_relation("slow-01", "slow-02")],
    )
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert any("relation target" in e for e in errors)


def test_self_relation_fails():
    doc = _doc(
        senses=[_sense("slow-01", ["slow-dict-001"]),
                _sense("slow-02", ["slow-dict-002"])],
        relations=[_relation("slow-01", "slow-01")],
    )
    errors = inventory.validate_inventory_content(
        doc, _entries("slow-dict-001", "slow-dict-002"), "slow"
    )
    assert any("self relation" in e for e in errors)


def test_source_entry_not_in_dictionary_evidence_fails():
    doc = _doc(senses=[_sense("slow-01", ["slow-dict-999"])])
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert any("不存在于当前词典证据中" in e for e in errors)


def test_source_entry_used_and_deferred_conflicts():
    doc = _doc(
        senses=[_sense("slow-01", ["slow-dict-001"])],
        deferred=[_deferred("slow-dict-001")],
    )
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert any("同时被" in e for e in errors)


def test_duplicate_mapping_without_split_fails():
    doc = _doc(senses=[
        _sense("slow-01", ["slow-dict-001"], decision_type="keep"),
        _sense("slow-02", ["slow-dict-001"], decision_type="keep"),
    ])
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert any("并非全部标记" in e for e in errors)


def test_split_mapping_is_legal():
    doc = _doc(senses=[
        _sense("slow-01", ["slow-dict-001"], decision_type="split"),
        _sense("slow-02", ["slow-dict-001"], decision_type="split"),
    ])
    errors = inventory.validate_inventory_content(doc, _entries("slow-dict-001"), "slow")
    assert not any("并非全部标记" in e for e in errors)


def test_unhandled_dictionary_entry_fails():
    doc = _doc(senses=[_sense("slow-01", ["slow-dict-001"])])
    errors = inventory.validate_inventory_content(
        doc, _entries("slow-dict-001", "slow-dict-002"), "slow"
    )
    assert any("未被任何 sense 使用也未 deferred" in e for e in errors)


# ------------------------------------------------------ 顶层身份一致性校验

def test_toplevel_word_mismatch_fails():
    doc = _base_doc(word="fast")
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("顶层 word 不一致" in e for e in errors)


def test_sense_lemma_mismatch_fails():
    sense = _sense("slow-01", ["slow-dict-001"])
    sense["lemma"] = "fast"
    doc = _base_doc(senses=[sense])
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("lemma 不一致" in e for e in errors)


def test_source_provider_mismatch_fails():
    doc = _base_doc()
    doc["source"]["provider"] = "wordnet"
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("source.provider 不一致" in e for e in errors)


def test_source_entry_count_mismatch_fails():
    doc = _base_doc()
    doc["source"]["entry_count"] = 999
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("source.entry_count 不一致" in e for e in errors)


def test_source_evidence_digest_mismatch_fails():
    doc = _base_doc()
    doc["source"]["evidence_digest"] = "sha256:" + "0" * 64
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("source.evidence_digest 不一致" in e for e in errors)


def test_language_mismatch_fails():
    doc = _base_doc()
    doc["language"] = "fr"
    errors = inventory.validate_inventory_content(doc, SLOW_ENTRIES, "slow")
    assert any("language 不一致" in e for e in errors)


# --------------------------------------------------------- relation 去重

def test_same_pair_different_relation_types_are_legal():
    entries = _entries("slow-dict-001", "slow-dict-002")
    doc = _base_doc(
        entries=entries,
        senses=[_sense("slow-01", ["slow-dict-001"]),
                _sense("slow-02", ["slow-dict-002"])],
        relations=[
            {"source": "slow-01", "target": "slow-02",
             "relation": "state_change", "distinction": "A"},
            {"source": "slow-01", "target": "slow-02",
             "relation": "shared_dimension", "distinction": "B"},
        ],
    )
    errors = inventory.validate_inventory_content(doc, entries, "slow")
    assert not any("重复" in e for e in errors)


def test_same_pair_same_relation_type_duplicate_fails():
    entries = _entries("slow-dict-001", "slow-dict-002")
    doc = _base_doc(
        entries=entries,
        senses=[_sense("slow-01", ["slow-dict-001"]),
                _sense("slow-02", ["slow-dict-002"])],
        relations=[
            {"source": "slow-01", "target": "slow-02",
             "relation": "state_change", "distinction": "A"},
            {"source": "slow-01", "target": "slow-02",
             "relation": "state_change", "distinction": "B"},
        ],
    )
    errors = inventory.validate_inventory_content(doc, entries, "slow")
    assert any("重复" in e for e in errors)


# --------------------------------------------------------------- CLI: draft

def _patch_draft_dirs(monkeypatch, tmp_path):
    drafts_dir = tmp_path / "inventories"
    evidence_dir = tmp_path / "dictionary-evidence"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
    monkeypatch.setattr(inventory, "DRAFTS_EVIDENCE", evidence_dir)
    return drafts_dir, evidence_dir


def test_draft_rejects_existing_file_without_force(tmp_path, monkeypatch):
    drafts_dir, evidence_dir = _patch_draft_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    existing = drafts_dir / "slow.yaml"
    existing.write_text("word: slow\n", encoding="utf-8")

    with pytest.raises(SystemExit):
        inventory.cmd_draft(Namespace(word="slow", force=False))

    assert existing.read_text(encoding="utf-8") == "word: slow\n"
    assert not evidence_dir.exists()


def test_invalid_llm_yaml_does_not_overwrite_existing_draft(tmp_path, monkeypatch):
    drafts_dir, evidence_dir = _patch_draft_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    existing = drafts_dir / "slow.yaml"
    existing.write_text('schema_version: "1.0"\n', encoding="utf-8")

    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))
    monkeypatch.setattr(inventory.llm, "generate",
                         lambda prompt: "key: [unterminated\n")

    with pytest.raises(SystemExit):
        inventory.cmd_draft(Namespace(word="slow", force=True))

    assert existing.read_text(encoding="utf-8") == 'schema_version: "1.0"\n'
    assert (drafts_dir / "_unparsed-slow.yaml").exists()
    assert not (evidence_dir / "slow.yaml").exists()


def test_draft_writes_snapshot_and_inventory_together_on_success(tmp_path, monkeypatch):
    drafts_dir, evidence_dir = _patch_draft_dirs(monkeypatch, tmp_path)
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))
    fixture_text = FIXTURE.read_text(encoding="utf-8")
    monkeypatch.setattr(inventory.llm, "generate", lambda prompt: fixture_text)

    inventory.cmd_draft(Namespace(word="slow", force=False))

    out = drafts_dir / "slow.yaml"
    assert out.exists()
    doc = yaml.safe_load(out.read_text(encoding="utf-8"))
    assert doc["word"] == "slow"
    assert len(doc["senses"]) == 3

    evidence_out = evidence_dir / "slow.yaml"
    assert evidence_out.exists()
    evidence_doc = yaml.safe_load(evidence_out.read_text(encoding="utf-8"))
    assert [e["entry_id"] for e in evidence_doc["entries"]] == [
        e["entry_id"] for e in SLOW_ENTRIES
    ]
    # 覆盖后的机器字段必须与 evidence snapshot 内容互相一致。
    assert doc["source"]["entry_count"] == len(SLOW_ENTRIES)
    assert doc["source"]["evidence_digest"] == inventory.compute_evidence_digest(
        SLOW_ENTRIES
    )


def test_draft_rejects_llm_output_that_fails_content_validation(tmp_path, monkeypatch):
    drafts_dir, evidence_dir = _patch_draft_dirs(monkeypatch, tmp_path)
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))

    doc = _load_fixture_doc()
    # Break numbering continuity while keeping the document schema-valid.
    doc["senses"][1]["id"] = "slow-05"
    monkeypatch.setattr(inventory.llm, "generate",
                         lambda prompt: yaml.safe_dump(doc, allow_unicode=True))

    with pytest.raises(SystemExit):
        inventory.cmd_draft(Namespace(word="slow", force=False))

    assert not (drafts_dir / "slow.yaml").exists()
    assert (drafts_dir / "_unparsed-slow.yaml").exists()
    assert not (evidence_dir / "slow.yaml").exists()


def test_draft_failure_does_not_overwrite_existing_snapshot_or_inventory(
    tmp_path, monkeypatch
):
    """覆盖 PR 审查项 11+12: --force 起草失败时, 既有合法 inventory 也有既有
    合法 evidence snapshot, 二者都必须原样保留。"""
    drafts_dir, evidence_dir = _patch_draft_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True)

    existing_inventory = FIXTURE.read_text(encoding="utf-8")
    existing_evidence = yaml.safe_dump(
        inventory._build_evidence_doc("slow", SLOW_ENTRIES), allow_unicode=True
    )
    (drafts_dir / "slow.yaml").write_text(existing_inventory, encoding="utf-8")
    (evidence_dir / "slow.yaml").write_text(existing_evidence, encoding="utf-8")

    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))
    # Schema 合法, 但编号不连续, 应在任何文件被替换前失败。
    broken = _load_fixture_doc()
    broken["senses"][1]["id"] = "slow-05"
    monkeypatch.setattr(inventory.llm, "generate",
                         lambda prompt: yaml.safe_dump(broken, allow_unicode=True))

    with pytest.raises(SystemExit):
        inventory.cmd_draft(Namespace(word="slow", force=True))

    assert (drafts_dir / "slow.yaml").read_text(encoding="utf-8") == existing_inventory
    assert (evidence_dir / "slow.yaml").read_text(encoding="utf-8") == existing_evidence


# ------------------------------------------------------------ CLI: validate

def _patch_validate_dirs(monkeypatch, tmp_path):
    drafts_dir = tmp_path / "inventories"
    evidence_dir = tmp_path / "dictionary-evidence"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
    monkeypatch.setattr(inventory, "INVENTORIES", tmp_path / "inventories_official")
    monkeypatch.setattr(inventory, "DRAFTS_EVIDENCE", evidence_dir)
    return drafts_dir, evidence_dir


def test_validate_command_passes_on_fixture_draft(tmp_path, monkeypatch, capsys):
    drafts_dir, _ = _patch_validate_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    (drafts_dir / "slow.yaml").write_text(
        FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))

    inventory.cmd_validate(Namespace(word="slow"))
    assert "PASS" in capsys.readouterr().out


def test_validate_command_fails_on_broken_inventory(tmp_path, monkeypatch):
    drafts_dir, _ = _patch_validate_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)

    doc = _load_fixture_doc()
    doc["deferred_entries"] = []  # slow-dict-004 now unhandled
    (drafts_dir / "slow.yaml").write_text(
        yaml.safe_dump(doc, allow_unicode=True), encoding="utf-8"
    )
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))

    with pytest.raises(SystemExit):
        inventory.cmd_validate(Namespace(word="slow"))


def test_validate_uses_snapshot_and_never_calls_live_dictionary_fetch(
    tmp_path, monkeypatch
):
    drafts_dir, evidence_dir = _patch_validate_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True)
    (drafts_dir / "slow.yaml").write_text(
        FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )
    (evidence_dir / "slow.yaml").write_text(
        yaml.safe_dump(
            inventory._build_evidence_doc("slow", SLOW_ENTRIES), allow_unicode=True
        ),
        encoding="utf-8",
    )

    def _must_not_be_called(word):
        raise AssertionError("snapshot 存在时不应调用实时词典抓取 (不应发网络请求)")

    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries", _must_not_be_called)

    inventory.cmd_validate(Namespace(word="slow"))  # 不抛异常即通过


def test_validate_snapshot_survives_upstream_dictionary_drift(tmp_path, monkeypatch, capsys):
    """上游 get_filtered_entries() 内容改变后, 已保存的 snapshot 仍让旧
    entry_id 保持原有含义, 校验结果不受实时词典内容变化影响。"""
    drafts_dir, evidence_dir = _patch_validate_dirs(monkeypatch, tmp_path)
    drafts_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True)
    (drafts_dir / "slow.yaml").write_text(
        FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )
    (evidence_dir / "slow.yaml").write_text(
        yaml.safe_dump(
            inventory._build_evidence_doc("slow", SLOW_ENTRIES), allow_unicode=True
        ),
        encoding="utf-8",
    )

    drifted_entries = [
        {"entry_id": "slow-dict-001", "pos": "noun",
         "gloss": "A totally different, drifted meaning.",
         "labels": [], "examples": []},
    ]
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: drifted_entries)

    inventory.cmd_validate(Namespace(word="slow"))
    assert "PASS" in capsys.readouterr().out
