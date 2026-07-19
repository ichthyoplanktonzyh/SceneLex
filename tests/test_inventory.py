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


# --------------------------------------------------------------- CLI: draft

def test_draft_rejects_existing_file_without_force(tmp_path, monkeypatch):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
    drafts_dir.mkdir(parents=True)
    existing = drafts_dir / "slow.yaml"
    existing.write_text("word: slow\n", encoding="utf-8")

    with pytest.raises(SystemExit):
        inventory.cmd_draft(Namespace(word="slow", force=False))

    assert existing.read_text(encoding="utf-8") == "word: slow\n"


def test_invalid_llm_yaml_does_not_overwrite_existing_draft(tmp_path, monkeypatch):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
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


def test_draft_writes_valid_inventory_on_success(tmp_path, monkeypatch):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
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


def test_draft_rejects_llm_output_that_fails_content_validation(tmp_path, monkeypatch):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
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


# ------------------------------------------------------------ CLI: validate

def test_validate_command_passes_on_fixture_draft(tmp_path, monkeypatch, capsys):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
    monkeypatch.setattr(inventory, "INVENTORIES", tmp_path / "inventories_official")
    drafts_dir.mkdir(parents=True)
    (drafts_dir / "slow.yaml").write_text(
        FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )
    monkeypatch.setattr(inventory.dictionary, "get_filtered_entries",
                         lambda w: list(SLOW_ENTRIES))

    inventory.cmd_validate(Namespace(word="slow"))
    assert "PASS" in capsys.readouterr().out


def test_validate_command_fails_on_broken_inventory(tmp_path, monkeypatch):
    drafts_dir = tmp_path / "inventories"
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", drafts_dir)
    monkeypatch.setattr(inventory, "INVENTORIES", tmp_path / "inventories_official")
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
