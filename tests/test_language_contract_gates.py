"""Learning Presentation Language Contract v1 确定性语言门的专项测试。

所有程序都是内存构造的合规中文程序 (zh-CN → en), 不依赖旧 fixture 迁移
状态, 直接覆盖合同的关键闸门:
  - L2 leakage (目标词、常见词形、相邻词; 复习场景)
  - Surface language compliance (成段英语)
  - L1 label leakage (minimal gloss 复制、已知 L1 标签)
  - Stage consistency (symbol binding 首次 L2、grounding 必须含目标 L2、
    locale 一致性、scaffold_level)
  - Boundary 语言规则 (中文场景 + L2 lemma 选项)
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import experience_compiler as compiler  # noqa: E402

SHA_EMPTY = "sha256:" + "0" * 64
ROOT = Path(__file__).resolve().parent.parent


def real_contract(sense_id: str) -> tuple[str, dict] | None:
    """从 data/contracts 读取真实 contract (content_hash, semantic_model);
    contract 缺失返回 None (测试环境缺少该数据时回退内存模型)。"""
    path = ROOT / "data" / "contracts" / f"{sense_id}.yaml"
    if not path.exists():
        return None
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    return doc.get("content_hash"), doc.get("semantic_model")


def _gate_record(names: tuple[str, ...]) -> dict:
    return {
        "passed": True,
        "dimensions": [
            {"name": name, "verdict": "pass", "note": "ok"}
            for name in names
        ],
    }


def _metadata(source_hash: str | None = None) -> dict:
    return {
        "compiler_version": compiler.COMPILER_VERSION,
        "prompt_versions": {
            stage: "v2" for stage in compiler.STAGES
        },
        "generated_at": "2026-08-15T00:00:00Z",
        "source_semantic_revision": 1,
        "source_contract_hash": source_hash or SHA_EMPTY,
        "model_provider": "fake",
        "model_name": "fake-model",
        "request_ids": [],
        "asset_gates": {
            asset_type: _gate_record(dims)
            for asset_type, dims in compiler.ASSET_GATE_DIMENSIONS.items()
        },
        "quality_gate": _gate_record(tuple(
            f"{asset_type}.{dim}"
            for asset_type in compiler.ASSET_TYPES
            for dim in compiler.ASSET_GATE_DIMENSIONS[asset_type]
        )),
    }


def zh_compliant_program() -> dict:
    """合同合规的中文 messy 程序: 绑定前全中文、reveal 首次 L2、grounding 含 L2。

    semantic_model 与 source_contract_hash 优先取真实 contract (迁移后的
    data/contracts/messy-01.yaml); contract 缺失时回退内存最小模型。
    """
    semantic_model = _fallback_semantic_model()
    source_hash = SHA_EMPTY
    first_misc = "misc-1"

    program = {
        "schema_version": "1.0",
        "program_id": "messy-test-program",
        "program_version": 1,
        "status": "reviewed",
        "language_policy": {
            "policy_version": 1, "learner_l1": "zh-CN", "target_l2": "en",
        },
        "target": {
            "sense_id": "messy-01", "lemma": "messy", "pos": "adjective",
            "ipa": "/\u02c8mesi/", "locale_l1": "zh",
        },
        "semantic_model": semantic_model,
        "units": [
            {
                "id": "unit-1", "sequence": 1, "role": "anchor",
                "hypothesis_target": None,
                "preserved_variables": ["surface", "room"],
                "changed_variables": ["placement", "orientation"],
                "semantic_spec": {
                    "judgment": "本单元目标是 messy", "placement": "displaced",
                    "orientation": "displaced",
                },
                "experience": {
                    "episode": "晚饭后的书桌上，笔记本斜躺在键盘上，"
                               "马克杯倒扣在显示器前，笔散落在桌角。",
                    "observable_evidence": [
                        "笔记本斜躺在键盘上，压住了按键",
                        "马克杯倒扣在显示器前",
                        "笔散落在桌角",
                    ],
                    "surface_dimensions": [
                        {"name": "placement", "baseline": "每件物品在通常位置",
                         "deviation": "笔记本在键盘上、杯子倒扣"},
                    ],
                },
                "interaction": {
                    "question": "这张书桌的状态和平时一样吗？",
                    "answers": [
                        {"id": "a1", "text": "不一样，物品离开了通常位置",
                         "is_correct": True, "feedback": "物品大多不在原位。"},
                        {"id": "a2", "text": "一样，一切照旧",
                         "is_correct": False, "feedback": "物品明显错位了。"},
                    ],
                },
            },
            {
                "id": "unit-2", "sequence": 2, "role": "variation",
                "hypothesis_target": first_misc,
                "preserved_variables": ["room", "surface"],
                "changed_variables": ["clutter", "objects"],
                "semantic_spec": {
                    "judgment": "客厅正例是否仍成立", "clutter": "yes",
                    "objects": "scattered",
                },
                "experience": {
                    "episode": "客厅里积木洒了一地，靠垫从扶手上滑落，"
                               "遥控器被零食袋压住。",
                    "observable_evidence": ["积木洒了一地", "靠垫滑落到地面"],
                    "surface_dimensions": [
                        {"name": "clutter", "baseline": "物品各归其位",
                         "deviation": "积木和靠垫都离开了位置"},
                    ],
                },
                "interaction": {
                    "question": "客厅的状态和书桌是同一类吗？",
                    "answers": [
                        {"id": "a1", "text": "是，都是物品错位",
                         "is_correct": True, "feedback": "位置秩序被破坏。"},
                        {"id": "a2", "text": "不是", "is_correct": False,
                         "feedback": "同样是位置错位。"},
                    ],
                },
            },
            {
                "id": "unit-3", "sequence": 3, "role": "transfer",
                "hypothesis_target": None,
                "preserved_variables": ["room"],
                "changed_variables": ["clutter", "setting"],
                "semantic_spec": {
                    "judgment": "客厅转移是否仍成立", "clutter": "yes",
                    "setting": "living_room",
                },
                "experience": {
                    "episode": "客厅里积木洒了一地，靠垫从扶手上滑落，"
                               "遥控器被零食袋压住。",
                    "observable_evidence": ["积木洒了一地", "靠垫滑落到地面"],
                    "surface_dimensions": [
                        {"name": "clutter", "baseline": "物品各归其位",
                         "deviation": "积木和靠垫都离开了位置"},
                        {"name": "setting", "baseline": "卧室客厅同质",
                         "deviation": "从卧室换到客厅"},
                    ],
                },
                "interaction": {
                    "question": "客厅的状态和书桌是同一类吗？",
                    "answers": [
                        {"id": "a1", "text": "是，都是物品错位",
                         "is_correct": True, "feedback": "位置秩序被破坏。"},
                        {"id": "a2", "text": "不是", "is_correct": False,
                         "feedback": "同样是位置错位。"},
                    ],
                },
            },
        ],
        "symbol_binding": {
            "reveal": {
                "l2_word": "messy", "ipa": "/\u02c8mesi/",
                "presentation": "刚才你看到的状态，就用这个词命名：messy。",
            },
            "minimal_l1_gloss": "凌乱",
        },
        "grounding": {
            "source_experience_id": "unit-1",
            "l2_realization": "The desk looks messy after dinner.",
            "constructions": ["messy [noun]"],
            "collocations": ["messy room"],
        },
        "review_pool": [
            {
                "id": f"review-{index}",
                "semantic_spec": {"judgment": f"新场景 {index} 是否仍成立"},
                "experience": {
                    "episode": _REVIEW_SCENES[index - 1],
                    "observable_evidence": [_REVIEW_EVIDENCE[index - 1]],
                    "surface_dimensions": [
                        {"name": "placement", "baseline": "物品归位",
                         "deviation": "物品离开通常位置"},
                    ],
                },
            }
            for index in range(1, 7)
        ],
        "metadata": _metadata(source_hash),
    }
    return program


_REVIEW_SCENES = (
    "厨房操作台上，面粉袋敞着口，调味瓶横七竖八地倒在台面上。",
    "卧室里枕头掉在床下，被子堆成一团，拖鞋一只在门边一只在窗下。",
    "教室后排，椅子翻倒在过道里，课本散在两张桌子之间。",
    "玄关处鞋子横七竖八，雨伞倒在鞋柜旁，钥匙混在门口的篮子里。",
    "玩具房里积木、蜡笔和小汽车混在地毯上，收纳盒空着倒在墙角。",
    "书架前几本书横搭在竖放的书上，文件夹从架子上探出一半。",
)

_REVIEW_EVIDENCE = (
    "面粉袋敞着口，面粉洒在台面上",
    "枕头掉在床下，被子堆成一团",
    "椅子翻倒在过道里，课本散在桌间",
    "鞋子横七竖八，雨伞倒地",
    "玩具混在地毯上，收纳盒空着",
    "书横搭在竖放的书上，文件夹探出",
)


def _fallback_semantic_model() -> dict:
    return {
        "invariant": "物品离开通常位置，位置秩序被破坏。",
        "necessary_conditions": ["物品不在通常位置", "存在可感知的位置错位"],
        "non_entailments": ["位置错位不蕴涵表面有污物"],
        "typical_correlates": ["东西散在桌上", "椅子翻倒"],
        "misconceptions": [
            {"id": "misc-1", "description": "把 messy 与 dirty 混为一谈",
             "correction": "检查位置秩序与表面污物两条独立维度"}
        ],
        "l1_interference": ["中文‘乱’也覆盖散乱与不整洁"],
    }


def errors_of(program: dict, **kwargs) -> list[compiler.Diagnostic]:
    kwargs.setdefault("skip_contract_link", True)
    return compiler.validate_program(program, **kwargs)


def messages(program: dict, **kwargs) -> list[str]:
    return [d.message for d in errors_of(program, **kwargs)]


# --------------------------------------------------------------------------- #
# 1. zh-CN pre-binding 中文内容通过
# --------------------------------------------------------------------------- #

def test_zh_compliant_program_passes_all_language_gates():
    assert messages(zh_compliant_program()) == []


# --------------------------------------------------------------------------- #
# 2. pre-binding 英文段落失败
# --------------------------------------------------------------------------- #

def test_english_passage_in_pre_binding_is_blocked():
    program = zh_compliant_program()
    program["units"][0]["experience"]["episode"] = (
        "After dinner, the notebook lies across the keyboard and the mug is "
        "turned upside down in front of the monitor."
    )
    result = messages(program)
    assert any("成段英语" in message for message in result)


def test_english_passage_in_review_scene_is_blocked():
    program = zh_compliant_program()
    program["review_pool"][0]["experience"]["episode"] = (
        "The flour bag sits open on the counter and the bottles lie on their "
        "sides."
    )
    assert any("成段英语" in message for message in messages(program))


# --------------------------------------------------------------------------- #
# 3. pre-binding 出现目标 lemma 失败
# --------------------------------------------------------------------------- #

def test_target_lemma_in_pre_binding_is_blocked():
    program = zh_compliant_program()
    program["units"][0]["experience"]["episode"] += " 这很 messy。"
    result = messages(program)
    assert any("目标 L2 词 'messy'" in message for message in result)


# --------------------------------------------------------------------------- #
# 4. pre-binding 出现目标词常见词形失败
# --------------------------------------------------------------------------- #

def test_target_derived_form_in_pre_binding_is_blocked():
    program = zh_compliant_program()
    program["units"][1]["interaction"]["question"] = "桌上是 messier 的状态吗？"
    assert any("目标 L2 词 'messy'" in message for message in messages(program))


# --------------------------------------------------------------------------- #
# 5. pre-binding 原样出现 minimal L1 gloss 失败
# --------------------------------------------------------------------------- #

def test_minimal_gloss_copied_into_pre_binding_is_blocked():
    program = zh_compliant_program()
    program["units"][0]["interaction"]["answers"][0]["feedback"] = "凌乱"
    assert any("minimal_l1_gloss" in message for message in messages(program))


# --------------------------------------------------------------------------- #
# 6. pre-binding 原样出现已知 L1 confusable 失败
# --------------------------------------------------------------------------- #

def test_l1_label_in_answer_text_is_blocked():
    program = zh_compliant_program()
    program["units"][0]["interaction"]["answers"][0]["text"] = "凌乱"
    assert any("L1 标签" in message for message in messages(program))


def test_l1_definition_sentence_in_episode_is_blocked():
    program = zh_compliant_program()
    program["units"][0]["experience"]["episode"] = "房间很凌乱，就是东西乱放。"
    assert any("L1 标签" in message for message in messages(program))


def test_l1_label_in_review_scene_definition_is_blocked():
    program = zh_compliant_program()
    program["review_pool"][0]["experience"]["episode"] = "厨房很凌乱"
    assert any("L1 标签" in message for message in messages(program))


# --------------------------------------------------------------------------- #
# 7. symbol binding 首次出现目标 L2 (合规程序通过, 不一致失败)
# --------------------------------------------------------------------------- #

def test_reveal_word_must_match_target_lemma():
    program = zh_compliant_program()
    program["symbol_binding"]["reveal"]["l2_word"] = "untidy"
    assert any("symbol_binding 必须首次展示目标 L2" in message
               for message in messages(program))


# --------------------------------------------------------------------------- #
# 8. grounding 未包含合法目标 L2 失败
# --------------------------------------------------------------------------- #

def test_grounding_without_target_l2_is_blocked():
    program = zh_compliant_program()
    program["grounding"]["l2_realization"] = "The desk is untidy tonight."
    assert any("grounding 必须实际包含目标 L2" in message
               for message in messages(program))


def test_grounding_with_derived_form_passes():
    program = zh_compliant_program()
    program["grounding"]["l2_realization"] = "The desk looks messier than before."
    assert messages(program) == []


# --------------------------------------------------------------------------- #
# 9/10. Boundary 语言规则
# --------------------------------------------------------------------------- #

def zh_boundary() -> dict:
    hash_a = (real_contract("dirty-01") or (SHA_EMPTY, None))[0]
    hash_b = (real_contract("messy-01") or (SHA_EMPTY, None))[0]
    return {
        "schema_version": "1.0",
        "boundary_id": "dirty-01__messy-01",
        "sense_a": "dirty-01",
        "sense_b": "messy-01",
        "status": "draft",
        "language_policy": {
            "policy_version": 1, "learner_l1": "zh-CN", "target_l2": "en",
        },
        "diagnostic_dimension": {
            "dimension": "偏离的来源",
            "sense_a_value": "外来污物附着",
            "sense_b_value": "位置秩序错位",
            "description": "沿偏离来源对比。",
        },
        "minimal_pairs": [
            {
                "id": "pair-1", "correct_sense": "messy-01",
                "experience": {
                    "episode": "午休后的办公室，文件散在桌上，"
                               "椅子歪在过道里，但桌面没有灰尘。",
                    "observable_evidence": ["文件散在桌上，椅子歪在过道里"],
                    "surface_dimensions": [
                        {"name": "placement", "baseline": "物品归位",
                         "deviation": "文件散着、椅子歪着"},
                    ],
                },
                "interaction": {
                    "question": "这个办公室的状态更符合哪个词？",
                    "answers": [
                        {"id": "a1", "text": "dirty", "is_correct": False,
                         "feedback": "桌面上没有外来污物，不是 dirty。"},
                        {"id": "a2", "text": "messy", "is_correct": True,
                         "feedback": "物品错位而表面干净，是 messy。"},
                    ],
                },
                "explanation": {
                    "correct": "物品离开了通常位置，表面没有污物。",
                    "other": "没有污物附着，不是表面不洁。",
                },
            },
            {
                "id": "pair-2", "correct_sense": "dirty-01",
                "experience": {
                    "episode": "水槽边，盘子上的油渍和残渣清晰可见，"
                               "碗筷整齐地码在沥水架上。",
                    "observable_evidence": ["盘子上有油渍和残渣"],
                    "surface_dimensions": [
                        {"name": "contamination", "baseline": "表面洁净",
                         "deviation": "油渍附着在表面"},
                    ],
                },
                "interaction": {
                    "question": "这个厨房的状态更符合哪个词？",
                    "answers": [
                        {"id": "a1", "text": "dirty", "is_correct": True,
                         "feedback": "表面附着油渍，需要清洗。"},
                        {"id": "a2", "text": "messy", "is_correct": False,
                         "feedback": "物品摆放整齐，没有错位。"},
                    ],
                },
                "explanation": {
                    "correct": "表面附着外来污物。",
                    "other": "物品整齐，没有秩序问题。",
                },
            },
        ],
        "gate": {
            "passed": True,
            "dimensions": [
                {"name": name, "verdict": "pass", "note": "ok"}
                for name in compiler.BOUNDARY_GATE_DIMENSIONS
            ],
        },
        "metadata": {
            "compiler_version": compiler.COMPILER_VERSION,
            "prompt_versions": {"boundary_producer": "v2",
                                "quality_gate": "v2"},
            "generated_at": "2026-08-15T00:00:00Z",
            "contract_a_hash": hash_a,
            "contract_b_hash": hash_b,
            "model_provider": "fake",
            "model_name": "fake-model",
            "request_ids": [],
        },
    }


def boundary_messages(pkg: dict) -> list[str]:
    return [d.message for d in compiler.validate_boundary_package(pkg)]


def test_boundary_zh_scene_with_l2_lemmas_passes():
    assert boundary_messages(zh_boundary()) == []


def test_boundary_english_explanation_is_blocked():
    pkg = zh_boundary()
    pkg["minimal_pairs"][0]["explanation"]["correct"] = (
        "The items are out of place because nothing is on its usual spot."
    )
    assert any("成段英语" in message for message in boundary_messages(pkg))


def test_boundary_english_answer_option_is_blocked():
    pkg = zh_boundary()
    pkg["minimal_pairs"][0]["interaction"]["answers"][0]["text"] = (
        "It is dirty because of stains on the surface"
    )
    assert any("必须是已绑定 sense 的合法 L2 符号" in message
               for message in boundary_messages(pkg))


def test_boundary_scene_with_target_lemma_is_blocked():
    pkg = zh_boundary()
    pkg["minimal_pairs"][1]["experience"]["episode"] += " 这很 messy。"
    assert any("boundary 场景出现 L2 词 'messy'" in message
               for message in boundary_messages(pkg))


def test_boundary_missing_both_option_lemmas_is_blocked():
    pkg = zh_boundary()
    pkg["minimal_pairs"][0]["interaction"]["answers"] = [
        {"id": "a1", "text": "dirty", "is_correct": False, "feedback": "x"},
        {"id": "a2", "text": "dirty", "is_correct": True, "feedback": "y"},
    ]
    assert any("必须同时包含两个义项的 L2 符号" in message
               for message in boundary_messages(pkg))


def test_boundary_l1_label_in_question_is_blocked():
    pkg = zh_boundary()
    pkg["minimal_pairs"][0]["interaction"]["question"] = "这个状态很凌乱吗？"
    assert any("L1 标签" in message for message in boundary_messages(pkg))


# --------------------------------------------------------------------------- #
# 11. language policy 与 target 不一致失败
# --------------------------------------------------------------------------- #

def test_locale_l1_mismatch_is_blocked():
    program = zh_compliant_program()
    program["target"]["locale_l1"] = "en"
    assert any("locale_l1" in message and "不一致" in message
               for message in messages(program))


# --------------------------------------------------------------------------- #
# 12. 旧 fixture 兼容/迁移行为明确
# --------------------------------------------------------------------------- #

def test_legacy_program_without_language_policy_is_rejected():
    program = zh_compliant_program()
    del program["language_policy"]
    result = messages(program)
    assert any("language_policy" in message for message in result)
    assert any("'language_policy' is a required property" in message
               for message in result)


# --------------------------------------------------------------------------- #
# 13. 语言政策 stale 资产被拒 (compiler v2 能力保持)
# --------------------------------------------------------------------------- #

def test_legacy_asset_without_language_policy_is_stale(monkeypatch, tmp_path):
    contract = {
        "content_hash": SHA_EMPTY,
        "semantic_model": {"invariant": "x"},
    }
    asset = {
        "contract_hash": SHA_EMPTY,
        "metadata": {},
    }
    monkeypatch.setattr(compiler, "asset_path", lambda sense_id, at: tmp_path / "a.yaml")
    with pytest.raises(compiler.CompileError) as exc_info:
        compiler._ensure_asset_current(asset, contract, "concept", "messy-01")
    assert "语言政策" in str(exc_info.value)


def test_asset_with_matching_language_policy_is_current(monkeypatch, tmp_path):
    contract = {"content_hash": SHA_EMPTY, "semantic_model": {"invariant": "x"}}
    asset = {
        "contract_hash": SHA_EMPTY,
        "metadata": {"language_policy": {"policy_version": 1,
                                         "learner_l1": "zh-CN",
                                         "target_l2": "en"}},
    }
    monkeypatch.setattr(compiler, "asset_path", lambda sense_id, at: tmp_path / "a.yaml")
    compiler._ensure_asset_current(asset, contract, "concept", "messy-01")


# --------------------------------------------------------------------------- #
# 14. scaffold_level 一致性
# --------------------------------------------------------------------------- #

def test_review_scaffold_level_must_be_legal():
    program = zh_compliant_program()
    program["review_pool"][0]["scaffold_level"] = "post_binding"
    diagnostics = errors_of(program)
    assert any(
        "scaffold_level" in d.path or "not one of" in d.message
        for d in diagnostics
    )


def test_review_scaffold_level_pre_binding_is_blocked():
    program = zh_compliant_program()
    program["review_pool"][0]["scaffold_level"] = "pre_binding"
    assert any("复习池不可能是 pre_binding" in message
               for message in messages(program))


def test_review_scaffold_level_early_post_binding_passes():
    program = zh_compliant_program()
    program["review_pool"][0]["scaffold_level"] = "early_post_binding"
    assert messages(program) == []
