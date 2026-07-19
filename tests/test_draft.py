from argparse import Namespace
from types import SimpleNamespace
from unittest import mock

import pytest
import yaml

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


def test_type_strategy_reads_matching_fragment(tmp_path, monkeypatch):
    strategies = tmp_path / "prompts" / "scene-strategies"
    strategies.mkdir(parents=True)
    (strategies / "attribute.md").write_text("attribute 策略\n", encoding="utf-8")
    sense = tmp_path / "test-01.yaml"
    sense.write_text("semantic_type: attribute\n", encoding="utf-8")
    monkeypatch.setattr(draft, "PROMPTS", tmp_path / "prompts")
    assert draft.type_strategy(sense) == "attribute 策略"


def test_type_strategy_falls_back_when_fragment_missing(tmp_path, monkeypatch):
    monkeypatch.setattr(draft, "PROMPTS", tmp_path / "prompts")
    sense = tmp_path / "test-01.yaml"
    sense.write_text("semantic_type: causal_logic\n", encoding="utf-8")
    assert "causal_logic" in draft.type_strategy(sense)


def test_every_semantic_type_has_strategy_fragment():
    import json
    schema = json.loads(
        (draft.ROOT / "schema" / "word-sense.schema.json").read_text("utf-8")
    )
    for t in schema["properties"]["semantic_type"]["enum"]:
        path = draft.ROOT / "prompts" / "scene-strategies" / f"{t}.md"
        assert path.exists(), f"semantic_type '{t}' 缺少场景表达策略片段"


def _batch_env(tmp_path, monkeypatch):
    monkeypatch.setattr(draft, "ROOT", tmp_path)
    monkeypatch.setattr(draft, "DRAFTS", tmp_path / "data" / "drafts")
    monkeypatch.setattr(
        draft, "BATCH_STATE", tmp_path / "data" / "drafts" / "batch-state.json"
    )
    # batch 现在按 approved Sense Inventory 枚举任务, 不再按 Wiktionary 条目数。
    import inventory
    monkeypatch.setattr(
        inventory, "load_approved_inventory",
        lambda word: {"word": word, "senses": [{"id": f"{word}-01"}]},
    )


def test_batch_runs_both_stages_and_cleans_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (True, "ok")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=False, concurrency=1))
    assert calls == [("sense", "nearly-01"), ("scenes", "nearly-01")]
    assert not draft.BATCH_STATE.exists()


def test_batch_enumerates_inventory_senses_not_dictionary_entries(
    tmp_path, monkeypatch
):
    """词典有几条不再决定生成几个 SceneLex sense ID。"""
    _batch_env(tmp_path, monkeypatch)
    import dictionary
    import inventory
    monkeypatch.setattr(
        inventory, "load_approved_inventory",
        lambda word: {"word": word,
                      "senses": [{"id": f"{word}-01"}, {"id": f"{word}-02"}]},
    )

    def _must_not_be_called(word):
        raise AssertionError("batch 不得再按词典义项数枚举任务")

    monkeypatch.setattr(dictionary, "sense_count", _must_not_be_called)
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (True, "ok")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=True, concurrency=1))
    assert sorted(calls) == [("sense", "nearly-01"), ("sense", "nearly-02")]


def test_batch_skips_words_without_approved_inventory(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    import inventory

    def _no_inventory(word):
        raise inventory.InventoryError(f"No approved Sense Inventory for '{word}'")

    monkeypatch.setattr(inventory, "load_approved_inventory", _no_inventory)
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (True, "ok"),
    )
    with pytest.raises(SystemExit):
        draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                                  sleep=0, senses_only=True, concurrency=1))


def test_batch_failed_sense_skips_scenes_and_keeps_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
    calls = []
    monkeypatch.setattr(
        draft, "_run_stage",
        lambda stage, retries, sleep: (calls.append(tuple(stage)) or (False, "boom")),
    )
    draft.cmd_batch(Namespace(words=["nearly"], count=1, retries=0,
                              sleep=0, senses_only=False, concurrency=1))
    assert calls == [("sense", "nearly-01")]
    assert draft.BATCH_STATE.exists()


def test_batch_resumes_from_recorded_state(tmp_path, monkeypatch):
    _batch_env(tmp_path, monkeypatch)
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


# ------------------------------------------- 场景 → 词义语义修订绑定

SCENE_ABBR = draft.SCENE_ABBR


def _scene_doc(sense_id, scene_type, index=1, revision=1):
    """一份 schema 合法的场景输出, 供 LLM 桩返回。"""
    doc = {
        "schema_version": "1.1",
        "version": 1,
        "status": "draft",
        "id": f"{sense_id}-{SCENE_ABBR[scene_type]}-{index:02d}",
        "sense_ref": sense_id,
        "sense_revision": revision,
        "scene_type": scene_type,
        "title": f"{scene_type} 场景",
        "synopsis": "一段用于测试的场景概要。",
        "surface": {
            "domain": f"domain-{scene_type}",
            "participant_type": "adult",
            "setting": f"setting-{scene_type}-{index}",
        },
        "storyboard": [
            {"beat": 1, "visual": "画面一", "purpose": "建立情境"},
            {"beat": 2, "visual": "画面二", "audio": None, "purpose": "呈现证据"},
        ],
        "learning_tasks": [
            {"type": "scene_recognition", "prompt": "哪个场景符合该义项?"}
        ],
    }
    if scene_type in ("contrast", "boundary", "counterexample"):
        doc["contrast_target"] = "slow-03"
        doc["contrast_relation"] = "different_sense"
    if scene_type == "transfer":
        doc["transfer_dimensions"] = ["domain", "participant"]
    return doc


def _sense_doc(schema_version="1.1", semantic_revision=1):
    doc = {
        "schema_version": schema_version,
        "language": "en",
        "version": 1,
        "status": "reviewed",
        "id": "slow-02",
        "word": "slow",
        "pos": "verb",
        "sense_label": "自身速率下降",
        "semantic_type": "state_change",
        "semantic_skeleton": {"core": "实体自身速率下降"},
        "conditions": {"required": ["速率下降可观察"]},
    }
    if semantic_revision is not None:
        doc["semantic_revision"] = semantic_revision
    return doc


@pytest.fixture
def scene_env(tmp_path, monkeypatch):
    """草稿区重定向到 tmp_path; 词义规格放在草稿区, LLM 被桩替换。"""
    drafts = tmp_path / "drafts"
    (drafts / "senses").mkdir(parents=True)
    monkeypatch.setattr(draft, "DRAFTS", drafts)
    return SimpleNamespace(
        drafts=drafts,
        scenes=drafts / "scenes" / "slow-02",
        write_sense=lambda doc: (drafts / "senses" / "slow-02.yaml").write_text(
            yaml.safe_dump(doc, allow_unicode=True, sort_keys=False),
            encoding="utf-8",
        ),
    )


def _stub_scene_llm(monkeypatch, blocks):
    """把 llm.generate 换成桩; blocks 是要返回的场景文档列表。"""
    prompts = []

    def fake_generate(prompt, config=None):
        prompts.append(prompt)
        docs = blocks(prompt) if callable(blocks) else blocks
        return "\n".join(
            f"```yaml\n{yaml.safe_dump(doc, allow_unicode=True, sort_keys=False)}```"
            for doc in docs
        )

    monkeypatch.setattr(draft.llm, "generate", fake_generate)
    return prompts


def _full_group(mutate=None):
    docs = [_scene_doc("slow-02", scene_type) for scene_type in draft.SCENE_ORDER]
    if mutate:
        for doc in docs:
            mutate(doc)
    return docs


def _load(path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_drafted_scenes_bind_current_semantic_revision(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(semantic_revision=3))
    _stub_scene_llm(monkeypatch, _full_group(
        lambda doc: doc.update(sense_revision=3)
    ))
    draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))

    written = sorted(scene_env.scenes.glob("*.yaml"))
    assert len(written) == 5
    for path in written:
        doc = _load(path)
        assert doc["schema_version"] == "1.1"
        assert doc["sense_ref"] == "slow-02"
        assert doc["sense_revision"] == 3


def test_omitted_scene_dependency_fields_are_filled_in(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(semantic_revision=2))

    def drop(doc):
        for field in ("schema_version", "sense_ref", "sense_revision"):
            doc.pop(field)

    _stub_scene_llm(monkeypatch, _full_group(drop))
    draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    doc = _load(scene_env.scenes / "slow-02-proto-01.yaml")
    assert (doc["schema_version"], doc["sense_ref"], doc["sense_revision"]) == (
        "1.1", "slow-02", 2
    )


def test_legacy_sense_cannot_seed_new_scenes(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(schema_version="1.0", semantic_revision=None))
    prompts = _stub_scene_llm(monkeypatch, _full_group())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    assert "1.0" in str(exc.value)
    assert prompts == []                      # 失败发生在调用模型之前
    assert not scene_env.scenes.exists()


def test_sense_without_semantic_revision_cannot_seed_new_scenes(
    scene_env, monkeypatch
):
    scene_env.write_sense(_sense_doc(semantic_revision=None))
    prompts = _stub_scene_llm(monkeypatch, _full_group())
    with pytest.raises(SystemExit) as exc:
        draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    assert "semantic_revision" in str(exc.value)
    assert prompts == []


def test_boolean_semantic_revision_cannot_seed_new_scenes(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(semantic_revision=True))
    prompts = _stub_scene_llm(monkeypatch, _full_group())
    with pytest.raises(SystemExit):
        draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    assert prompts == []


@pytest.mark.parametrize("field,value", [
    ("sense_ref", "slow-03"),
    ("sense_revision", 1),
    ("schema_version", "1.0"),
])
def test_wrong_scene_dependency_field_is_drift(scene_env, monkeypatch, field, value):
    scene_env.write_sense(_sense_doc(semantic_revision=2))
    _stub_scene_llm(monkeypatch, _full_group(
        lambda doc: doc.update({"sense_revision": 2, field: value})
    ))
    draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))

    # 漂移的块进旁路文件, 正常草稿路径一个都不写
    assert not list(scene_env.scenes.glob("slow-02-*.yaml"))
    dumped = list(scene_env.scenes.glob("_invalid-*dependency-drift.yaml"))
    assert len(dumped) == 5


def test_scene_dependency_drift_keeps_existing_draft_intact(scene_env, monkeypatch, capsys):
    scene_env.write_sense(_sense_doc(semantic_revision=2))
    scene_env.scenes.mkdir(parents=True)
    existing = scene_env.scenes / "slow-02-proto-01.yaml"
    original = "id: slow-02-proto-01\n# 已审阅过的旧草稿\n"
    existing.write_text(original, encoding="utf-8")

    _stub_scene_llm(monkeypatch, _full_group(
        lambda doc: doc.update(sense_revision=1)
    ))
    draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    assert existing.read_text(encoding="utf-8") == original
    assert "scene dependency drift" in capsys.readouterr().err


def test_scene_add_binds_the_same_revision(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(semantic_revision=4))
    scene_env.scenes.mkdir(parents=True)
    (scene_env.scenes / "slow-02-proto-01.yaml").write_text(
        yaml.safe_dump(_scene_doc("slow-02", "prototype", revision=4),
                       allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    added = _scene_doc("slow-02", "prototype", index=2, revision=4)
    added.pop("sense_revision")
    _stub_scene_llm(monkeypatch, [added])

    draft.cmd_scenes(Namespace(sense_id="slow-02", add="prototype"))
    doc = _load(scene_env.scenes / "slow-02-proto-02.yaml")
    assert doc["sense_revision"] == 4 and doc["schema_version"] == "1.1"


def test_scene_add_rejects_wrong_revision(scene_env, monkeypatch):
    scene_env.write_sense(_sense_doc(semantic_revision=4))
    added = _scene_doc("slow-02", "prototype", revision=1)
    _stub_scene_llm(monkeypatch, [added])
    with pytest.raises(SystemExit) as exc:
        draft.cmd_scenes(Namespace(sense_id="slow-02", add="prototype"))
    assert "scene dependency drift" in str(exc.value)
    assert not (scene_env.scenes / "slow-02-proto-01.yaml").exists()


def test_schema_invalid_scene_never_reaches_normal_draft_path(
    scene_env, monkeypatch
):
    scene_env.write_sense(_sense_doc())

    def break_storyboard(doc):
        if doc["scene_type"] == "contrast":
            doc["storyboard"] = []

    _stub_scene_llm(monkeypatch, _full_group(break_storyboard))
    draft.cmd_scenes(Namespace(sense_id="slow-02", add=None))
    assert not (scene_env.scenes / "slow-02-contrast-01.yaml").exists()
    assert (scene_env.scenes / "_invalid-slow-02-contrast-01.yaml").exists()
    assert (scene_env.scenes / "slow-02-proto-01.yaml").exists()
