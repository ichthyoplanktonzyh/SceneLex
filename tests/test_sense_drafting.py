"""Inventory-driven WordSense 起草。

模型调用一律用桩替换, 目录一律重定向到 tmp_path: 测试不发网络请求, 不调用
真实 LLM, 也不写入仓库真实数据。
"""

from argparse import Namespace
from pathlib import Path

import pytest
import yaml

import draft
import inventory

FIXTURES = Path(__file__).parent / "fixtures"
APPROVED_FIXTURE = FIXTURES / "inventories" / "approved-slow.yaml"
EVIDENCE_FIXTURE = FIXTURES / "dictionary-evidence" / "slow.yaml"


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _sense_fixture(sense_id: str) -> dict:
    return _load(FIXTURES / "senses" / f"{sense_id}.yaml")


@pytest.fixture
def env(tmp_path, monkeypatch):
    """approved inventory + evidence 就位, LLM 与词典均被桩替换。"""
    official = tmp_path / "inventories"
    official_evidence = tmp_path / "dictionary-evidence"
    drafts = tmp_path / "data" / "drafts"
    monkeypatch.setattr(inventory, "INVENTORIES", official)
    monkeypatch.setattr(inventory, "EVIDENCE", official_evidence)
    monkeypatch.setattr(inventory, "DRAFTS_INVENTORIES", tmp_path / "drafts-inv")
    monkeypatch.setattr(inventory, "DRAFTS_EVIDENCE", tmp_path / "drafts-ev")
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    monkeypatch.setattr(draft, "LEGACY_SENSES", drafts / "legacy-senses")

    official.mkdir(parents=True)
    official_evidence.mkdir(parents=True)
    (official / "slow.yaml").write_text(
        APPROVED_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )
    (official_evidence / "slow.yaml").write_text(
        EVIDENCE_FIXTURE.read_text(encoding="utf-8"), encoding="utf-8"
    )

    def _must_not_fetch(word, refresh=False):
        raise AssertionError("起草阶段不应发起实时 Wiktionary 抓取")

    import dictionary
    monkeypatch.setattr(dictionary, "get_filtered_entries", _must_not_fetch)
    monkeypatch.setattr(dictionary, "teachable_senses", _must_not_fetch)

    return Namespace(drafts=drafts, senses=drafts / "senses",
                     official=official, official_evidence=official_evidence)


def _stub_llm(monkeypatch, responder):
    """把 llm.generate 换成桩, 并记录每次收到的提示词。"""
    prompts: list[str] = []

    def fake_generate(prompt, config=None):
        prompts.append(prompt)
        result = responder(prompt) if callable(responder) else responder
        return f"```yaml\n{result}\n```"

    monkeypatch.setattr(draft.llm, "generate", fake_generate)
    return prompts


def _yaml_of(doc: dict) -> str:
    return yaml.safe_dump(doc, allow_unicode=True, sort_keys=False)


def _responder_from_fixtures(mutate=None):
    """按提示词里出现的 sense ID 返回对应的合法 fixture 输出。"""
    def respond(prompt: str) -> str:
        for sense_id in ("slow-01", "slow-02", "slow-03"):
            if f"`{sense_id}.yaml`" in prompt:
                doc = _sense_fixture(sense_id)
                if mutate:
                    doc = mutate(sense_id, doc) or doc
                return _yaml_of(doc)
        raise AssertionError(f"提示词中找不到已知的 sense ID:\n{prompt[:400]}")
    return respond


def _draft_sense(env, sense_id, force=False):
    inventory_doc = inventory.load_approved_inventory("slow")
    entries = inventory.load_approved_evidence_entries("slow")
    return draft.draft_one_sense(sense_id, inventory_doc, entries, force=force)


# ------------------------------------------------------------- 单 sense 起草

def test_sense_is_looked_up_in_approved_inventory(env, monkeypatch):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    draft.cmd_sense(Namespace(target="slow-02", force=False, num=None,
                              legacy_dictionary_index=False))
    written = _load(env.senses / "slow-02.yaml")
    assert written["id"] == "slow-02"
    assert written["schema_version"] == "1.1"


def test_unknown_sense_id_fails_and_lists_available(env, monkeypatch, capsys):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_sense(Namespace(target="slow-09", force=False, num=None,
                                  legacy_dictionary_index=False))
    message = str(exc.value)
    assert "slow-01" in message and "slow-02" in message and "slow-03" in message
    assert not (env.senses / "slow-09.yaml").exists()


def test_missing_approved_inventory_fails_with_guidance(env, monkeypatch):
    (env.official / "slow.yaml").unlink()
    _stub_llm(monkeypatch, _responder_from_fixtures())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_sense(Namespace(target="slow-02", force=False, num=None,
                                  legacy_dictionary_index=False))
    assert "No approved Sense Inventory" in str(exc.value)


def test_prompt_carries_all_senses_and_locked_relations(env, monkeypatch):
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    _draft_sense(env, "slow-02")
    prompt = prompts[0]
    # ALL_SENSES: 三个 sense 的摘要都必须在场
    for sense_id in ("slow-01", "slow-02", "slow-03"):
        assert sense_id in prompt
    assert "ALL_SENSES" in prompt and "CURRENT_SENSE" in prompt
    # LOCKED_RELATIONS 必须显式标注方向
    assert "causative_alternation" in prompt
    assert "outgoing" in prompt


def test_prompt_includes_only_own_source_entries_in_full(env, monkeypatch):
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    _draft_sense(env, "slow-02")
    prompt = prompts[0]
    assert "Traffic slowed near the exit." in prompt          # 自己的证据, 全文
    assert "The driver slowed the car." not in prompt          # 他人的证据, 只给摘要
    assert "slow-dict-003" in prompt                           # 但 ID 仍可见


# ------------------------------------------------ 模型不得改变锁定身份

@pytest.mark.parametrize("field,value", [
    ("id", "slow-99"),
    ("word", "fast"),
    ("pos", "noun"),
])
def test_model_cannot_change_locked_identity_fields(env, monkeypatch, field, value):
    def mutate(sense_id, doc):
        doc[field] = value
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    out = _draft_sense(env, "slow-02")
    written = _load(out)
    expected = {"id": "slow-02", "word": "slow", "pos": "verb"}[field]
    assert written[field] == expected


def test_model_cannot_change_semantic_identity(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["semantic_identity"]["causative"] = True
        doc["semantic_identity"]["valency"] = "transitive"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["semantic_identity"]["causative"] is False
    assert written["semantic_identity"]["valency"] == "intransitive"


def test_model_cannot_add_source_entry(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory_source_entries"].append("slow-dict-003")
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["inventory_source_entries"] == ["slow-dict-002"]


def test_model_cannot_drop_source_entry(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory_source_entries"] = []
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["inventory_source_entries"] == ["slow-dict-002"]


def test_inventory_provenance_is_written_correctly(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory"]["version"] = 99
        doc["inventory"]["identity_digest"] = "sha256:" + "0" * 64
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))

    inventory_doc = inventory.load_approved_inventory("slow")
    inventory_sense = inventory.find_inventory_sense(inventory_doc, "slow-02")
    assert written["inventory"] == {
        "word": "slow",
        "version": 1,
        "evidence_digest": inventory_doc["source"]["evidence_digest"],
        "sense_id": "slow-02",
        "identity_digest": inventory.compute_identity_digest(inventory_sense),
    }


def test_identity_digest_matches_locked_fields(env, monkeypatch):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    written = _load(_draft_sense(env, "slow-02"))
    payload = inventory.identity_payload(
        inventory.find_inventory_sense(
            inventory.load_approved_inventory("slow"), "slow-02"
        )
    )
    assert payload == {
        "id": "slow-02",
        "lemma": "slow",
        "pos": "verb",
        "semantic_signature": {
            "semantic_type": "state_change",
            "dimension": "rate",
            "change_of_state": True,
            "causative": False,
            "valency": "intransitive",
        },
    }
    assert written["inventory"]["identity_digest"].startswith("sha256:")


# --------------------------------------------------- 跨义项引用必须真实

def test_boundary_pointing_at_unknown_sense_fails(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["relations"]["boundaries"][0]["target"] = "slow-07"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, "slow-02")
    assert "slow-07" in str(exc.value)
    assert (env.senses / "_invalid-slow-02.yaml").exists()
    assert not (env.senses / "slow-02.yaml").exists()


def test_excluded_alternative_pointing_at_unknown_sense_fails(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["conditions"]["excluded"][0]["alternative"] = "slow-08"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, "slow-02")
    assert "slow-08" in str(exc.value)


def test_boundary_cannot_reverse_an_inventory_relation(env, monkeypatch):
    """Inventory 记录 slow-02 → slow-03; 反向声称同一 relation 必须被拒。"""
    inventory_doc = inventory.load_approved_inventory("slow")
    inventory_sense = inventory.find_inventory_sense(inventory_doc, "slow-03")
    doc = _sense_fixture("slow-03")
    doc["relations"]["boundaries"][0]["relation"] = "causative_alternation"
    errors = inventory.validate_sense_against_inventory(
        doc, inventory_doc, inventory_sense
    )
    assert any("方向" in message for message in errors)


def test_self_reference_in_boundary_is_rejected(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["relations"]["boundaries"][0]["target"] = "slow-02"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, "slow-02")
    assert "自身" in str(exc.value)


# ------------------------------------------------------------- 写入安全

def test_inventory_conflict_is_saved_to_conflict_file(env, monkeypatch):
    conflict = _yaml_of({
        "generation_status": "inventory_conflict",
        "sense_id": "slow-02",
        "issues": [{"field": "semantic_signature.valency",
                    "message": "证据显示该义项必须带宾语"}],
    })
    _stub_llm(monkeypatch, conflict)
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, "slow-02")
    assert (env.senses / "_conflict-slow-02.yaml").exists()
    assert not (env.senses / "slow-02.yaml").exists()
    assert "证据显示该义项必须带宾语" in str(exc.value)


def test_unparsable_yaml_does_not_overwrite_existing_draft(env, monkeypatch):
    env.senses.mkdir(parents=True)
    existing = env.senses / "slow-02.yaml"
    existing.write_text("id: slow-02\n# 已审阅过的旧草稿\n", encoding="utf-8")

    _stub_llm(monkeypatch, "key: [unterminated\n")
    with pytest.raises(draft.SenseDraftError):
        _draft_sense(env, "slow-02", force=True)
    assert existing.read_text(encoding="utf-8") == "id: slow-02\n# 已审阅过的旧草稿\n"
    assert (env.senses / "_unparsed-slow-02.yaml").exists()


def test_identity_failure_does_not_overwrite_existing_draft(env, monkeypatch):
    env.senses.mkdir(parents=True)
    existing = env.senses / "slow-02.yaml"
    existing.write_text("id: slow-02\n# 已审阅过的旧草稿\n", encoding="utf-8")

    def mutate(sense_id, doc):
        doc["relations"]["boundaries"][0]["target"] = "slow-07"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError):
        _draft_sense(env, "slow-02", force=True)
    assert existing.read_text(encoding="utf-8") == "id: slow-02\n# 已审阅过的旧草稿\n"


def test_existing_draft_is_not_overwritten_without_force(env, monkeypatch):
    env.senses.mkdir(parents=True)
    (env.senses / "slow-02.yaml").write_text("id: slow-02\n", encoding="utf-8")
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, "slow-02")
    assert "--force" in str(exc.value)
    assert prompts == []  # 拒绝发生在调用模型之前


def test_force_replaces_existing_draft_on_success(env, monkeypatch):
    env.senses.mkdir(parents=True)
    (env.senses / "slow-02.yaml").write_text("id: slow-02\n", encoding="utf-8")
    _stub_llm(monkeypatch, _responder_from_fixtures())
    written = _load(_draft_sense(env, "slow-02", force=True))
    assert written["sense_label"] == "自身速率下降"


# --------------------------------------------------------------- 整词起草

def test_senses_command_enumerates_inventory_not_dictionary(env, monkeypatch, capsys):
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    draft.cmd_senses(Namespace(word="slow", force=False, workers=1))
    assert len(prompts) == 3
    for sense_id in ("slow-01", "slow-02", "slow-03"):
        assert (env.senses / f"{sense_id}.yaml").exists()
    out = capsys.readouterr().out
    assert "slow-01 PASS" in out and "slow-03 PASS" in out


def test_every_task_receives_full_all_senses(env, monkeypatch):
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    draft.cmd_senses(Namespace(word="slow", force=False, workers=1))
    for prompt in prompts:
        for sense_id in ("slow-01", "slow-02", "slow-03"):
            assert sense_id in prompt


def test_partial_failure_keeps_successful_drafts_and_exits_nonzero(
    env, monkeypatch, capsys
):
    def mutate(sense_id, doc):
        if sense_id == "slow-03":
            doc["relations"]["boundaries"][0]["target"] = "slow-07"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))

    with pytest.raises(SystemExit) as exc:
        draft.cmd_senses(Namespace(word="slow", force=False, workers=1))
    assert exc.value.code != 0
    assert (env.senses / "slow-01.yaml").exists()
    assert (env.senses / "slow-02.yaml").exists()
    assert not (env.senses / "slow-03.yaml").exists()
    out = capsys.readouterr().out
    assert "slow-01 PASS" in out and "slow-03 FAILED" in out


def test_workers_argument_runs_all_senses(env, monkeypatch):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    draft.cmd_senses(Namespace(word="slow", force=False, workers=3))
    for sense_id in ("slow-01", "slow-02", "slow-03"):
        assert (env.senses / f"{sense_id}.yaml").exists()


def test_senses_without_approved_inventory_fails(env, monkeypatch):
    (env.official / "slow.yaml").unlink()
    _stub_llm(monkeypatch, _responder_from_fixtures())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_senses(Namespace(word="slow", force=False, workers=1))
    assert "No approved Sense Inventory" in str(exc.value)


# ----------------------------------------------------------------- legacy

def test_legacy_num_path_is_refused_by_default(env, monkeypatch):
    prompts = _stub_llm(monkeypatch, _responder_from_fixtures())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_sense(Namespace(target="slow", num="03", force=False,
                                  legacy_dictionary_index=False))
    message = str(exc.value)
    assert "deprecated" in message
    assert "tools/inventory.py approve slow" in message
    assert prompts == []
    assert not (env.senses / "slow-03.yaml").exists()


def test_legacy_switch_writes_outside_normal_draft_area(env, monkeypatch):
    _stub_llm(monkeypatch, "id: slow-03\nnote: legacy experiment\n")
    import dictionary
    monkeypatch.setattr(dictionary, "prompt_block", lambda w, n=None: "(stub)")
    monkeypatch.setattr(dictionary, "sense_count", lambda w: 8)

    draft.cmd_sense(Namespace(target="slow", num="03", force=False,
                              legacy_dictionary_index=True))
    assert (env.drafts / "legacy-senses" / "slow-03.yaml").exists()
    assert not (env.senses / "slow-03.yaml").exists()


def test_bare_word_without_num_is_also_refused(env, monkeypatch):
    with pytest.raises(SystemExit) as exc:
        draft.cmd_sense(Namespace(target="slow", num=None, force=False,
                                  legacy_dictionary_index=False))
    assert "deprecated" in str(exc.value)
