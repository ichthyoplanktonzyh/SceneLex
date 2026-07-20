"""词典用例的文本归一化。

kaikki 的 examples 是对象而不是字符串, 而 evidence snapshot / evidence digest /
inventory 提示词消费的都是句子本身。这层归一化一旦回退, 整条
Inventory → WordSense 链路会在 evidence snapshot 的 schema 校验处断掉。
"""

from unittest import mock

import dictionary


def test_object_examples_become_their_text():
    examples = [
        {"text": "She was reluctant to lend him the money",
         "bold_text_offsets": [[8, 17]], "type": "example"},
        {"text": "Surprisingly, our new dog is a reluctant ball-retriever.",
         "bold_text_offsets": [[31, 40]], "type": "example"},
    ]
    assert dictionary._example_texts(examples) == [
        "She was reluctant to lend him the money",
        "Surprisingly, our new dog is a reluctant ball-retriever.",
    ]


def test_plain_string_examples_still_accepted():
    """早期条目与测试 fixture 直接就是字符串, 不能因为归一化被丢掉。"""
    assert dictionary._example_texts(["a bare string"]) == ["a bare string"]


def test_examples_without_text_are_dropped_not_rendered():
    """没有 text 的对象没有可用证据; 保留它会把 dict 塞进字符串数组。"""
    assert dictionary._example_texts(
        [{"type": "quotation", "ref": "somewhere"}, {"text": "kept"}]
    ) == ["kept"]


def test_whitespace_is_collapsed():
    assert dictionary._example_texts(
        [{"text": "  wrapped\n  across   lines  "}]
    ) == ["wrapped across lines"]


def test_non_mapping_non_string_entries_are_ignored():
    assert dictionary._example_texts([None, 42, {"text": "kept"}]) == ["kept"]


def test_teachable_senses_emit_only_strings():
    """归一化必须发生在 teachable_senses 里, 这样两个下游消费者都拿到字符串。"""
    entry = {
        "pos": "adj",
        "senses": [{
            "glosses": ["Not wanting to take some action; unwilling."],
            "examples": [
                {"text": "She was reluctant to lend him the money",
                 "type": "example"},
            ],
        }],
    }
    with mock.patch.object(dictionary, "fetch", return_value=[entry]):
        senses = dictionary.teachable_senses("reluctant")

    assert [type(example) for example in senses[0]["examples"]] == [str]


def test_filtered_entries_examples_are_strings():
    """get_filtered_entries 直接喂给 evidence snapshot 的 schema 校验。"""
    entry = {
        "pos": "adj",
        "senses": [{
            "glosses": ["Not wanting to take some action; unwilling."],
            "examples": [{"text": "She was reluctant to lend him the money"}],
        }],
    }
    with mock.patch.object(dictionary, "fetch", return_value=[entry]):
        entries = dictionary.get_filtered_entries("reluctant")

    assert entries[0]["examples"] == ["She was reluctant to lend him the money"]
