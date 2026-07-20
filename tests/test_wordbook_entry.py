"""词目条目的标量序列化。

write_word_entry 手写 YAML 以保留字段顺序。用 f-string 插值标量会把
schema_version 的 "1.0" 写成裸 1.0, 读回来是 float, 与 word-entry.schema.json
的字符串常量对不上 —— promote 的发布前全量校验会因此整体失败。
"""

import yaml

import wordbook


def test_version_like_string_stays_a_string():
    assert wordbook._scalar_line("schema_version", "1.0") == "schema_version: '1.0'"


def test_yaml_boolean_lookalikes_stay_strings():
    """裸 yes/no/on/off 会被 YAML 解析成布尔值。"""
    assert yaml.safe_load(wordbook._scalar_line("word", "no")) == {"word": "no"}


def test_integers_stay_unquoted():
    assert wordbook._scalar_line("version", 3) == "version: 3"


def test_lists_render_inline():
    assert wordbook._scalar_line("pos", ["adjective"]) == "pos: [adjective]"


def test_written_entry_round_trips_as_valid_yaml(tmp_path, monkeypatch):
    monkeypatch.setattr(wordbook, "ENTRY_DIR", tmp_path)
    wordbook.write_word_entry("reluctant", {
        "schema_version": "1.0",
        "version": 1,
        "word": "reluctant",
        "pos": ["adjective"],
        "frequency": {"rank": 9349, "band": "low"},
        "senses": [{
            "id": "reluctant-01",
            "pos": "adjective",
            "sense_label": "不情愿的",
            "definition": "Unwilling to perform an available action.",
            "status": "reviewed",
            "scene_count": 5,
        }],
    })

    document = yaml.safe_load((tmp_path / "reluctant.yaml").read_text())

    # schema_version 必须是字符串, 不是 float 1.0。
    assert document["schema_version"] == "1.0"
    assert isinstance(document["schema_version"], str)
    assert document["pos"] == ["adjective"]
    assert document["frequency"]["rank"] == 9349
    assert document["senses"][0]["id"] == "reluctant-01"


def test_written_entry_passes_word_entry_schema(tmp_path, monkeypatch):
    """真正的回归判据: 产物能通过 promote 所用的同一份 schema。"""
    import draft

    monkeypatch.setattr(wordbook, "ENTRY_DIR", tmp_path)
    wordbook.write_word_entry("reluctant", {
        "schema_version": "1.0",
        "version": 1,
        "word": "reluctant",
        "senses": [{
            "id": "reluctant-01",
            "pos": "adjective",
            "sense_label": "不情愿的",
            "definition": "Unwilling to perform an available action.",
            "status": "reviewed",
            "scene_count": 5,
        }],
    })

    document = yaml.safe_load((tmp_path / "reluctant.yaml").read_text())
    errors = draft.schema_check(
        document, draft.load_schema("word-entry.schema.json"), "reluctant.yaml"
    )
    assert errors == []
