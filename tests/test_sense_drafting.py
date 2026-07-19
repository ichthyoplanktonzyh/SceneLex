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


# ------------------------------------------------ 身份漂移: 拒绝, 而不是覆盖

def _assert_drift(env, sense_id, field_hint):
    """断言起草因 identity drift 失败, 且原始输出被保留、逐项报出 expected/actual。"""
    with pytest.raises(draft.SenseDraftError) as exc:
        _draft_sense(env, sense_id)
    message = str(exc.value)
    assert "identity drift" in message
    assert field_hint in message
    assert "expected" in message and "actual" in message
    assert (env.senses / f"_invalid-{sense_id}-identity-drift.yaml").exists()
    assert not (env.senses / f"{sense_id}.yaml").exists()
    return message


@pytest.mark.parametrize("field,value,hint", [
    ("id", "slow-99", "id"),
    ("word", "fast", "word (lemma)"),
    ("pos", "noun", "pos"),
])
def test_wrong_identity_field_is_drift_not_silent_overwrite(
    env, monkeypatch, field, value, hint
):
    def mutate(sense_id, doc):
        doc[field] = value
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    message = _assert_drift(env, "slow-02", hint)
    assert repr(value) in message


def test_wrong_causative_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["semantic_identity"]["causative"] = True
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "semantic_identity.causative")


def test_wrong_valency_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["semantic_identity"]["valency"] = "transitive"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "semantic_identity.valency")


@pytest.mark.parametrize("field", [
    "semantic_type", "dimension", "change_of_state",
])
def test_wrong_semantic_identity_subfields_are_drift(env, monkeypatch, field):
    def mutate(sense_id, doc):
        doc["semantic_identity"][field] = "totally-different"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", f"semantic_identity.{field}")


def test_added_source_entry_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory_source_entries"].append("slow-dict-003")
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "inventory_source_entries")


def test_dropped_source_entry_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory_source_entries"] = []
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "inventory_source_entries")


def test_source_entry_order_alone_is_not_drift(env, monkeypatch):
    """集合一致即可; 顺序不是身份。"""
    inventory_doc = inventory.load_approved_inventory("slow")
    sense = inventory.find_inventory_sense(inventory_doc, "slow-01")
    assert inventory.detect_identity_drift(
        {"inventory_source_entries": list(reversed(sense["source_entries"]))},
        inventory_doc, sense,
    ) == []


def test_identity_drift_does_not_overwrite_existing_valid_draft(env, monkeypatch):
    env.senses.mkdir(parents=True)
    existing = env.senses / "slow-02.yaml"
    original = "id: slow-02\n# 已审阅过的旧草稿\n"
    existing.write_text(original, encoding="utf-8")

    def mutate(sense_id, doc):
        doc["pos"] = "noun"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError):
        _draft_sense(env, "slow-02", force=True)
    assert existing.read_text(encoding="utf-8") == original
    assert (env.senses / "_invalid-slow-02-identity-drift.yaml").exists()


def test_identity_drift_saves_raw_model_output(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["pos"] = "noun"
        doc["sense_label"] = "模型按错误义项写的标签"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(draft.SenseDraftError):
        _draft_sense(env, "slow-02")
    saved = _load(env.senses / "_invalid-slow-02-identity-drift.yaml")
    # 保存的是模型原样输出, 不是被程序改写过的版本
    assert saved["pos"] == "noun"
    assert saved["sense_label"] == "模型按错误义项写的标签"


def test_cli_exits_nonzero_on_identity_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["pos"] = "noun"
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    with pytest.raises(SystemExit) as exc:
        draft.cmd_sense(Namespace(target="slow-02", force=False, num=None,
                                  legacy_dictionary_index=False))
    assert exc.value.code != 0
    assert "identity drift" in str(exc.value)


# ------------------------------------- 省略机器字段: 由程序补全, 不算漂移

def test_omitted_machine_fields_are_filled_in(env, monkeypatch):
    """模型没写的机器字段是簿记, 不是它对词义的判断, 补全即可。"""
    def mutate(sense_id, doc):
        for field in ("inventory", "semantic_identity",
                      "inventory_source_entries", "schema_version"):
            doc.pop(field, None)
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))

    assert written["schema_version"] == "1.1"
    assert written["semantic_identity"]["valency"] == "intransitive"
    assert written["semantic_identity"]["causative"] is False
    assert written["inventory_source_entries"] == ["slow-dict-002"]
    assert written["inventory"]["sense_id"] == "slow-02"


def test_omitted_identity_scalars_are_filled_in(env, monkeypatch):
    def mutate(sense_id, doc):
        for field in ("id", "word", "pos"):
            doc.pop(field, None)
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert (written["id"], written["word"], written["pos"]) == (
        "slow-02", "slow", "verb")


# ------------------------- 显式 null 是表态, 不是沉默

def test_explicit_null_dimension_is_drift_when_inventory_has_value(env, monkeypatch):
    """Inventory 说 rate, 模型说 null: 这是冲突, 不能被静默补回 rate。"""
    def mutate(sense_id, doc):
        doc["semantic_identity"]["dimension"] = None
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    message = _assert_drift(env, "slow-02", "semantic_identity.dimension")
    assert "'rate'" in message and "None" in message


def test_explicit_null_valency_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["semantic_identity"]["valency"] = None
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "semantic_identity.valency")


@pytest.mark.parametrize("field", [
    "semantic_type", "change_of_state", "causative",
])
def test_explicit_null_in_other_identity_fields_is_drift(env, monkeypatch, field):
    def mutate(sense_id, doc):
        doc["semantic_identity"][field] = None
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", f"semantic_identity.{field}")


def test_explicit_null_dimension_matches_null_inventory():
    """Inventory 本身就是 null 时, 模型写 null 是一致的, 不是 drift。"""
    inventory_sense = {
        "id": "x-01", "lemma": "x", "pos": "noun",
        "semantic_signature": {
            "semantic_type": "entity", "dimension": None,
            "change_of_state": False, "causative": False, "valency": "n/a",
        },
        "source_entries": ["x-dict-001"],
    }
    raw = {"semantic_identity": {"dimension": None}}
    assert inventory.detect_identity_drift(raw, {"word": "x"}, inventory_sense) == []


def test_missing_dimension_key_is_still_filled_in(env, monkeypatch):
    """key 不存在 = 模型没表态, 由程序补全。"""
    def mutate(sense_id, doc):
        doc["semantic_identity"].pop("dimension")
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["semantic_identity"]["dimension"] == "rate"


def test_explicit_null_top_level_identity_field_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["pos"] = None
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "pos")


def test_null_source_entries_is_drift(env, monkeypatch):
    def mutate(sense_id, doc):
        doc["inventory_source_entries"] = None
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "inventory_source_entries")


def test_duplicate_source_entries_are_rejected_by_schema():
    """集合比较对重复条目不敏感, 由 schema 的 uniqueItems 兜底。"""
    doc = _sense_fixture("slow-02")
    doc["inventory_source_entries"] = ["slow-dict-002", "slow-dict-002"]
    errors = draft.schema_check(
        doc, draft.load_schema("word-sense.schema.json"), "slow-02.yaml"
    )
    assert any("inventory_source_entries" in e for e in errors)


def test_partially_omitted_semantic_identity_is_filled_in(env, monkeypatch):
    """写对了一半、另一半没写, 不算冲突。"""
    def mutate(sense_id, doc):
        doc["semantic_identity"] = {"valency": "intransitive"}
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["semantic_identity"]["semantic_type"] == "state_change"
    assert written["semantic_identity"]["dimension"] == "rate"


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


# ------------------------------------------------- 语义契约修订 (semantic_revision)

def test_new_sense_starts_at_semantic_revision_one(env, monkeypatch):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    written = _load(_draft_sense(env, "slow-02"))
    assert written["semantic_revision"] == 1


def test_omitted_semantic_revision_is_filled_in(env, monkeypatch):
    def mutate(sense_id, doc):
        doc.pop("semantic_revision")
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    written = _load(_draft_sense(env, "slow-02"))
    assert written["semantic_revision"] == 1


def test_wrong_semantic_revision_is_drift(env, monkeypatch):
    """模型不能自己决定这份语义契约是第几版。"""
    def mutate(sense_id, doc):
        doc["semantic_revision"] = 3
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    message = _assert_drift(env, "slow-02", "semantic_revision")
    assert "3" in message


def test_boolean_semantic_revision_is_drift(env, monkeypatch):
    """True == 1 在 Python 里成立, 但 true 不是版本号。"""
    def mutate(sense_id, doc):
        doc["semantic_revision"] = True
    _stub_llm(monkeypatch, _responder_from_fixtures(mutate))
    _assert_drift(env, "slow-02", "semantic_revision")


def test_all_senses_of_a_word_start_at_revision_one(env, monkeypatch):
    _stub_llm(monkeypatch, _responder_from_fixtures())
    draft.cmd_senses(Namespace(word="slow", force=False, workers=1))
    for sense_id in ("slow-01", "slow-02", "slow-03"):
        assert _load(env.senses / f"{sense_id}.yaml")["semantic_revision"] == 1


def test_schema_requires_semantic_revision_for_11(env):
    doc = _sense_fixture("slow-02")
    doc.pop("semantic_revision")
    errors = draft.schema_check(
        doc, draft.load_schema("word-sense.schema.json"), "slow-02.yaml"
    )
    assert any("semantic_revision" in message for message in errors)


def test_schema_rejects_boolean_semantic_revision(env):
    doc = _sense_fixture("slow-02")
    doc["semantic_revision"] = True
    errors = draft.schema_check(
        doc, draft.load_schema("word-sense.schema.json"), "slow-02.yaml"
    )
    assert any("semantic_revision" in message for message in errors)


def test_schema_does_not_require_semantic_revision_for_legacy_10(env):
    """1.0 是 inventory 层之前的历史资源, 不参与语义修订绑定。"""
    doc = _sense_fixture("slow-02")
    doc["schema_version"] = "1.0"
    for field in ("semantic_revision", "inventory", "semantic_identity",
                  "inventory_source_entries"):
        doc.pop(field, None)
    errors = draft.schema_check(
        doc, draft.load_schema("word-sense.schema.json"), "slow-02.yaml"
    )
    assert errors == []
