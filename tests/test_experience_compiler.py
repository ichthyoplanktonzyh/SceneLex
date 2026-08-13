"""Experience Compiler v1 的回归测试。

所有主要测试都穿过 Compiler 的对外 interface (compile_experience_program /
validate_program / run_regression), 断言最终可观察行为; 模型调用全部使用纯内存
fake adapter, 测试路径不触网。
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

import experience_compiler as compiler
from experience_compiler import CompileError, LLMCall, run_regression
from experience_compiler import llm_adapter

ROOT = Path(__file__).resolve().parent.parent
FIXTURES_DIR = ROOT / "tests" / "fixtures" / "experience-programs"

_STAGE_MARKERS = {
    "semantic_planner": "# Experience Compiler — Semantic Planner\n",
    "program_planner": "# Experience Compiler — Experience Program Planner\n",
    "surface_generator": "# Experience Compiler — Surface Experience Generator\n",
    "quality_gate": "# Experience Compiler — Semantic Critic / Quality Gate\n",
}

FIXTURE_IDS = ("reluctant-01", "messy-01", "almost-01", "dirty-01")


def load_fixture(sense_id: str) -> dict:
    return yaml.safe_load(
        (FIXTURES_DIR / f"{sense_id}.yaml").read_text(encoding="utf-8")
    )


class FakeAdapter:
    """纯内存 fake adapter: 按阶段标记分派预构造响应, 记录调用顺序。"""

    def __init__(self, responses: dict[str, dict]):
        self.responses = responses
        self.calls: list[str] = []

    def __call__(self, prompt: str) -> LLMCall:
        for stage, marker in _STAGE_MARKERS.items():
            if marker in prompt:
                self.calls.append(stage)
                return LLMCall(
                    text=json.dumps(self.responses[stage], ensure_ascii=False),
                    provider="fake",
                    model="fake-model",
                    request_id=f"req-{stage}",
                )
        raise AssertionError(f"fake adapter 无法识别阶段: {prompt[:80]!r}")


def stage_responses(program: dict) -> dict[str, dict]:
    """把一份完整程序拆回四阶段的响应, 供 fake adapter 回放。"""
    return {
        "semantic_planner": program["semantic_model"],
        "program_planner": {
            "units": [
                {key: unit[key] for key in (
                    "id", "role", "hypothesis_target", "preserved_variables",
                    "changed_variables", "semantic_spec",
                )}
                for unit in program["units"]
            ],
            "grounding": {
                key: program["grounding"][key]
                for key in ("source_experience_id", "constructions", "collocations")
            },
            "review_pool": [
                {"id": item["id"], "semantic_spec": item["semantic_spec"]}
                for item in program["review_pool"]
            ],
            "symbol_binding_plan": {"presentation_plan": "绑定计划"},
        },
        "surface_generator": {
            "units": [
                {"id": unit["id"], "experience": unit["experience"],
                 "interaction": unit["interaction"]}
                for unit in program["units"]
            ],
            "symbol_binding": program["symbol_binding"],
            "grounding": {"l2_realization": program["grounding"]["l2_realization"]},
            "review_pool": [
                {"id": item["id"], "experience": item["experience"]}
                for item in program["review_pool"]
            ],
        },
        "quality_gate": program["metadata"]["quality_gate"],
    }


def compiled_from_fixture(sense_id: str, adapter: FakeAdapter) -> dict:
    fixture = load_fixture(sense_id)
    return compiler.compile_experience_program(
        sense_id, adapter=adapter, program_version=1
    ), fixture


# --------------------------------------------------------------------------- #
# 完整四阶段编译 (fake adapter)
# --------------------------------------------------------------------------- #

def test_fake_adapter_drives_full_four_stage_compile():
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    program = compiler.compile_experience_program(
        "reluctant-01", adapter=adapter
    )

    assert program["schema_version"] == "1.0"
    assert program["program_id"] == "reluctant-01-program"
    assert program["program_version"] == 1
    assert program["status"] == "draft"
    assert program["target"]["sense_id"] == "reluctant-01"
    assert program["target"]["lemma"] == "reluctant"
    assert program["metadata"]["source_semantic_revision"] == 2
    assert program["metadata"]["model_provider"] == "fake"
    assert program["metadata"]["model_name"] == "fake-model"
    assert program["metadata"]["request_ids"] == [
        "req-semantic_planner", "req-program_planner",
        "req-surface_generator", "req-quality_gate",
    ]
    assert program["metadata"]["quality_gate"]["passed"] is True
    assert program["units"] == fixture["units"]
    assert program["review_pool"] == fixture["review_pool"]
    assert program["semantic_model"] == fixture["semantic_model"]
    assert compiler.validate_program(program) == []


def test_stage_call_order_is_semantic_then_program_then_surface_then_critic():
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert adapter.calls == [
        "semantic_planner", "program_planner", "surface_generator", "quality_gate",
    ]


def test_all_four_fixtures_compile_through_the_interface():
    for sense_id in FIXTURE_IDS:
        fixture = load_fixture(sense_id)
        adapter = FakeAdapter(stage_responses(fixture))
        program = compiler.compile_experience_program(sense_id, adapter=adapter)
        assert compiler.validate_program(program) == []


# --------------------------------------------------------------------------- #
# Schema validation 与聚合 diagnostics
# --------------------------------------------------------------------------- #

def test_schema_validation_failure_is_aggregated_with_paths():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    unit = responses["surface_generator"]["units"][0]
    del unit["interaction"]["answers"][0]["is_correct"]
    del responses["surface_generator"]["units"][0]["experience"]["episode"]
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    diagnostics = exc_info.value.diagnostics
    assert len(diagnostics) >= 2
    paths = {diagnostic.path for diagnostic in diagnostics}
    messages = " | ".join(d.message for d in diagnostics)
    assert any("interaction" in path and "answers" in path for path in paths)
    assert "episode" in messages
    assert all(diagnostic.stage == compiler.DETERMINISTIC_STAGE
               for diagnostic in diagnostics)


def test_malformed_llm_output_reports_the_failing_stage():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["program_planner"] = {"units": []}  # 缺 grounding/review_pool
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert exc_info.value.diagnostics[0].stage == "program_planner"
    assert exc_info.value.diagnostics[0].path == "plan"


def test_non_json_llm_output_reports_the_failing_stage():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["surface_generator"] = "I cannot produce JSON today."
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert exc_info.value.diagnostics[0].stage == "surface_generator"


def test_multiple_rule_violations_aggregate_into_one_error():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["program_planner"]["units"][0]["hypothesis_target"] = "ghost-misc"
    responses["program_planner"]["grounding"]["source_experience_id"] = "ghost-unit"
    responses["surface_generator"]["review_pool"][0]["experience"]["episode"] = (
        fixture["units"][0]["experience"]["episode"]
    )
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "ghost-misc" in messages          # hypothesis_target 悬空
    assert "ghost-unit" in messages          # grounding 引用不存在
    assert "重新播放首学故事" in messages     # review novelty
    assert len(exc_info.value.diagnostics) >= 3


# --------------------------------------------------------------------------- #
# 泄漏与质量门拦截
# --------------------------------------------------------------------------- #

def test_target_word_leakage_in_surface_is_blocked():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["experience"]["episode"] += (
        " He was reluctant to do it."
    )
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "目标 L2 词 'reluctant'" in messages


def test_neighbor_symbol_leakage_is_blocked():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["interaction"]["question"] += (
        " Was he unwilling?"
    )
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "相邻 L2 词 'unwilling'" in messages


def test_definition_leakage_flagged_by_critic_is_blocked():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    for item in responses["quality_gate"]["dimensions"]:
        if item["name"] == "definition_leakage":
            item["verdict"] = "fail"
            item["note"] = "unit-1 的 episode 直接定义了词义"
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert "Semantic Quality Gate 未通过" in str(exc_info.value)
    assert exc_info.value.diagnostics[0].stage == "quality_gate"
    assert "definition_leakage" in exc_info.value.diagnostics[0].message


def test_critic_failure_never_returns_a_program():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    for item in responses["quality_gate"]["dimensions"]:
        item["verdict"] = "fail"
    adapter = FakeAdapter(responses)

    with pytest.raises(CompileError):
        compiler.compile_experience_program("reluctant-01", adapter=adapter)


# --------------------------------------------------------------------------- #
# 引用完整性与确定性规则 (直接走 validate_program, 即 compile 内部同一校验)
# --------------------------------------------------------------------------- #

def test_misconception_coverage_is_enforced():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    units = [dict(unit) for unit in program["units"]]
    for unit in units:
        unit["hypothesis_target"] = None
    program["units"] = units

    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "未被任何 hypothesis_target 覆盖" in messages


def test_sequence_and_grounding_reference_integrity():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    program["grounding"] = dict(program["grounding"])
    program["grounding"]["source_experience_id"] = "no-such-unit"

    diagnostics = compiler.validate_program(program)
    assert any("source_experience_id" in d.path for d in diagnostics)

    swapped = dict(fixture)
    units = [dict(unit) for unit in swapped["units"]]
    units[0]["sequence"] = 5
    swapped["units"] = units
    diagnostics = compiler.validate_program(swapped)
    assert any("sequence 应为 1" in d.message for d in diagnostics)


def test_review_novelty_is_enforced():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    program["review_pool"] = [
        {"id": "review-x", "semantic_spec": {"judgment": "x"},
         "experience": fixture["units"][0]["experience"]}
    ]
    diagnostics = compiler.validate_program(program)
    assert any("重新播放首学故事" in d.message for d in diagnostics)


def test_transfer_must_change_at_least_two_dimensions():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    units = [dict(unit) for unit in program["units"]]
    for unit in units:
        if unit["role"] == "transfer":
            unit["changed_variables"] = ["domain"]
            unit["experience"] = dict(unit["experience"])
            unit["experience"]["surface_dimensions"] = [
                unit["experience"]["surface_dimensions"][0]
            ]
    program["units"] = units

    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "至少改变两个表面维度" in messages


def test_anchor_and_pre_reveal_transfer_are_required():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    units = [dict(unit) for unit in program["units"]]
    for unit in units:
        unit["role"] = "variation"
    program["units"] = units

    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "至少存在一个 anchor" in messages
    assert "揭示前 concept transfer" in messages


# --------------------------------------------------------------------------- #
# 人工发布权: 编译器只能产出 draft
# --------------------------------------------------------------------------- #

def test_compiler_has_no_status_parameter():
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    with pytest.raises(TypeError):
        compiler.compile_experience_program(
            "reluctant-01", adapter=adapter, status="reviewed")
    with pytest.raises(TypeError):
        compiler.compile_experience_program(
            "reluctant-01", adapter=adapter, status="published")


def test_compiler_output_is_always_draft():
    for sense_id in FIXTURE_IDS:
        fixture = load_fixture(sense_id)
        adapter = FakeAdapter(stage_responses(fixture))
        program = compiler.compile_experience_program(sense_id, adapter=adapter)
        assert program["status"] == "draft"


def test_compile_cli_has_no_status_flag():
    with pytest.raises(SystemExit):
        compiler.main(["compile", "reluctant-01", "--status", "published"])


def test_draft_fixtures_can_still_carry_reviewed_status_in_contract():
    # Contract 保留 reviewed/published, 供未来人工 promotion 流程使用 (schema 枚举)。
    program = load_fixture("reluctant-01")
    program["status"] = "reviewed"
    assert compiler.validate_program(program) == []


# --------------------------------------------------------------------------- #
# 九维 Semantic Quality Gate
# --------------------------------------------------------------------------- #

def _gate_response(fixture: dict, dimensions=None, scores=None) -> dict:
    gate = dict(stage_responses(fixture)["quality_gate"])
    if dimensions is not None:
        gate["dimensions"] = dimensions
    if scores is not None:
        gate["scores"] = scores
    return gate


def test_gate_missing_dimension_is_compile_error():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    gate = dict(responses["quality_gate"])
    gate["dimensions"] = gate["dimensions"][:-1]  # 缺一个维度
    responses["quality_gate"] = gate
    adapter = FakeAdapter(responses)
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    diagnostics = exc_info.value.diagnostics
    assert diagnostics[0].stage == "quality_gate"
    assert "缺失" in diagnostics[0].message


def test_gate_duplicate_dimension_is_compile_error():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    gate = dict(responses["quality_gate"])
    gate["dimensions"] = gate["dimensions"] + [gate["dimensions"][0]]
    responses["quality_gate"] = gate
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=FakeAdapter(responses))
    assert "重复" in exc_info.value.diagnostics[0].message


def test_gate_unknown_dimension_is_compile_error():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    gate = dict(responses["quality_gate"])
    gate["dimensions"] = gate["dimensions"][:-1] + [
        {"name": "made_up_dimension", "verdict": "pass", "note": "n"}
    ]
    responses["quality_gate"] = gate
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=FakeAdapter(responses))
    assert "未知" in exc_info.value.diagnostics[0].message


def test_gate_single_dimension_is_compile_error():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    gate = dict(responses["quality_gate"])
    gate["dimensions"] = [gate["dimensions"][0]]
    responses["quality_gate"] = gate
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=FakeAdapter(responses))
    assert "恰好包含九个维度" in exc_info.value.diagnostics[0].message


def test_gate_passed_is_derived_from_verdicts():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    gate = dict(responses["quality_gate"])
    gate["passed"] = True  # 尝试伪造 passed; 系统必须按 verdict 重算
    gate["dimensions"] = gate["dimensions"][:-1] + [
        {"name": "cognitive_noise", "verdict": "fail", "note": "noise"}
    ]
    responses["quality_gate"] = gate
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=FakeAdapter(responses))
    assert "Semantic Quality Gate 未通过" in str(exc_info.value)


def test_validate_rejects_passed_true_with_fail_verdict():
    program = load_fixture("reluctant-01")
    program["metadata"] = dict(program["metadata"])
    program["metadata"]["quality_gate"] = dict(program["metadata"]["quality_gate"])
    gate = program["metadata"]["quality_gate"]
    gate["passed"] = True
    gate["dimensions"] = [
        dict(item) for item in gate["dimensions"]
    ]
    gate["dimensions"][0]["verdict"] = "fail"
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "passed 与 verdict 不一致" in messages


def test_validate_rejects_incomplete_gate_dimensions():
    program = load_fixture("reluctant-01")
    gate = program["metadata"]["quality_gate"]
    gate["dimensions"] = gate["dimensions"][:-1]
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "九个维度" in messages


def test_validate_rejects_duplicate_gate_dimensions():
    program = load_fixture("reluctant-01")
    gate = program["metadata"]["quality_gate"]
    gate["dimensions"] = gate["dimensions"] + [dict(gate["dimensions"][0])]
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "重复" in messages


def test_validate_accepts_gate_without_scores():
    program = load_fixture("reluctant-01")
    gate = program["metadata"]["quality_gate"]
    del gate["scores"]
    assert compiler.validate_program(program) == []


# --------------------------------------------------------------------------- #
# WordSense 权威绑定
# --------------------------------------------------------------------------- #

def test_validate_rejects_unknown_sense_id():
    program = load_fixture("reluctant-01")
    program["target"] = dict(program["target"])
    program["target"]["sense_id"] = "ghost-01"
    diagnostics = compiler.validate_program(program)
    assert any("ghost-01" in d.path for d in diagnostics)
    assert any("文件缺失" in d.message for d in diagnostics)


def test_validate_rejects_lemma_mismatch():
    program = load_fixture("reluctant-01")
    program["target"] = dict(program["target"])
    program["target"]["lemma"] = "resistant"
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "word 不一致" in messages


def test_validate_rejects_pos_mismatch():
    program = load_fixture("reluctant-01")
    program["target"] = dict(program["target"])
    program["target"]["pos"] = "verb"
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "pos 不一致" in messages


def test_validate_rejects_wrong_semantic_revision():
    program = load_fixture("reluctant-01")
    program["metadata"] = dict(program["metadata"])
    program["metadata"]["source_semantic_revision"] = 1  # reluctant 绑定 revision 2
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "semantic_revision" in messages and "应为 2" in messages


def test_legacy_senses_bind_to_revision_one():
    # almost/messy/dirty 三个旧 sense 没有 semantic_revision, 统一按 1 处理。
    for sense_id in ("almost-01", "messy-01", "dirty-01"):
        program = load_fixture(sense_id)
        assert program["metadata"]["source_semantic_revision"] == 1
        assert compiler.validate_program(program) == []


def test_compile_binds_revision_two_for_reluctant():
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    program = compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert program["metadata"]["source_semantic_revision"] == 2


# --------------------------------------------------------------------------- #
# 确定性结构门
# --------------------------------------------------------------------------- #

def test_preserved_and_changed_variables_must_not_overlap():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    units = [dict(unit) for unit in program["units"]]
    units[0]["preserved_variables"] = list(units[0]["changed_variables"])
    program["units"] = units
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "不得重叠" in messages


def test_changed_variable_without_surface_grounding_is_blocked():
    fixture = load_fixture("reluctant-01")
    program = dict(fixture)
    units = [dict(unit) for unit in program["units"]]
    units[0]["changed_variables"] = ["ghost_variable"]
    program["units"] = units
    diagnostics = compiler.validate_program(program)
    messages = " | ".join(d.message for d in diagnostics)
    assert "ghost_variable" in messages and "表面层落地" in messages


def test_each_interaction_must_have_exactly_one_correct_answer():
    fixture = load_fixture("reluctant-01")
    for set_correct in (lambda answers: answers[0].__setitem__("is_correct", False),
                        lambda answers: answers[1].__setitem__("is_correct", True)):
        program = dict(fixture)
        units = [dict(unit) for unit in program["units"]]
        units[0]["interaction"] = {
            "question": units[0]["interaction"]["question"],
            "answers": [dict(a) for a in units[0]["interaction"]["answers"]],
        }
        set_correct(units[0]["interaction"]["answers"])
        program["units"] = units
        diagnostics = compiler.validate_program(program)
        messages = " | ".join(d.message for d in diagnostics)
        assert "恰好一个正确答案" in messages


def test_nested_structure_errors_are_compiler_errors_not_key_errors():
    fixture = load_fixture("reluctant-01")

    responses = stage_responses(fixture)
    responses["program_planner"] = {"units": "not-a-list", "grounding": {},
                                    "review_pool": [], "symbol_binding_plan": {}}
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01",
                                            adapter=FakeAdapter(responses))
    assert exc_info.value.diagnostics[0].stage == "program_planner"
    assert exc_info.value.diagnostics[0].path == "units"

    responses = stage_responses(fixture)
    del responses["surface_generator"]["units"][0]["id"]
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01",
                                            adapter=FakeAdapter(responses))
    assert exc_info.value.diagnostics[0].stage == "surface_generator"
    assert "id" in exc_info.value.diagnostics[0].path

    responses = stage_responses(fixture)
    responses["surface_generator"]["review_pool"][0]["id"] = "ghost-review"
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01",
                                            adapter=FakeAdapter(responses))
    assert exc_info.value.diagnostics[0].stage == "surface_generator"
    assert "ghost-review" in exc_info.value.diagnostics[0].message

    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["interaction"] = None
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01",
                                            adapter=FakeAdapter(responses))
    assert exc_info.value.diagnostics[0].stage == "surface_generator"


# --------------------------------------------------------------------------- #
# 阶段级一次重试
# --------------------------------------------------------------------------- #

class FlakyAdapter(FakeAdapter):
    """对指定阶段的前几次调用失败, 之后正常; 或按失败次数持续失败。"""

    def __init__(self, responses: dict[str, dict], fail_stage: str,
                 failures: int, failure_kind: str = "bad_json"):
        super().__init__(responses)
        self.fail_stage = fail_stage
        self.failures = failures
        self.failure_kind = failure_kind
        self.stage_hits: dict[str, int] = {}

    def __call__(self, prompt: str) -> LLMCall:
        stage = None
        for marker_stage, marker in _STAGE_MARKERS.items():
            if marker in prompt:
                stage = marker_stage
                break
        assert stage is not None, "fake adapter 无法识别阶段"
        self.calls.append(stage)
        self.stage_hits[stage] = self.stage_hits.get(stage, 0) + 1
        if stage == self.fail_stage and self.stage_hits[stage] <= self.failures:
            if self.failure_kind == "transport":
                raise llm_adapter.LLMResponseError(
                    f"模拟传输失败 (第 {self.stage_hits[stage]} 次)")
            return LLMCall(text="not json at all", provider="fake",
                           model="fake-model", request_id=f"req-{stage}-bad")
        return LLMCall(
            text=json.dumps(self.responses[stage], ensure_ascii=False),
            provider="fake", model="fake-model", request_id=f"req-{stage}",
        )


def test_retry_recovers_after_one_bad_output():
    fixture = load_fixture("reluctant-01")
    adapter = FlakyAdapter(stage_responses(fixture), fail_stage="surface_generator",
                           failures=1)
    program = compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert program["units"] == fixture["units"]
    assert adapter.calls.count("surface_generator") == 2  # 一次失败 + 一次修复
    assert len(adapter.calls) == 5


def test_retry_recovers_after_one_transport_failure():
    fixture = load_fixture("reluctant-01")
    adapter = FlakyAdapter(stage_responses(fixture), fail_stage="program_planner",
                           failures=1, failure_kind="transport")
    program = compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert program["units"] == fixture["units"]


def test_retry_fails_after_two_bad_outputs():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["program_planner"] = {"units": [], "grounding": {},
                                    "review_pool": [], "symbol_binding_plan": {}}
    adapter = FlakyAdapter(responses, fail_stage="program_planner", failures=2)
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    diagnostics = exc_info.value.diagnostics
    assert diagnostics[0].stage == "program_planner"
    assert diagnostics[0].path == "plan"
    assert adapter.calls.count("program_planner") == 2


def test_retry_fails_after_two_transport_failures():
    fixture = load_fixture("reluctant-01")
    adapter = FlakyAdapter(stage_responses(fixture), fail_stage="quality_gate",
                           failures=2, failure_kind="transport")
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert exc_info.value.diagnostics[0].stage == "quality_gate"
    assert "两次调用均失败" in str(exc_info.value)


def test_gate_verdict_fail_is_not_retried():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    for item in responses["quality_gate"]["dimensions"]:
        item["verdict"] = "fail"
    adapter = FakeAdapter(responses)
    with pytest.raises(CompileError):
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    assert adapter.calls.count("quality_gate") == 1  # 未重试


# --------------------------------------------------------------------------- #
# L2 泄漏: 派生形式
# --------------------------------------------------------------------------- #

def test_derived_form_of_neighbor_word_is_blocked():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["interaction"]["answers"][0][
        "feedback"] += " No unwillingness here."
    adapter = FakeAdapter(responses)
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "相邻 L2 词 'unwilling'" in messages


def test_derived_form_of_target_word_is_blocked():
    fixture = load_fixture("reluctant-01")
    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["interaction"]["question"] += (
        " Was he reluctant?"
    )
    adapter = FakeAdapter(responses)
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("reluctant-01", adapter=adapter)
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "目标 L2 词 'reluctant'" in messages


def test_fixture_has_no_unwillingness_in_learner_visible_content():
    fixture = load_fixture("reluctant-01")
    import re as _re
    for unit in fixture["units"]:
        text = " ".join(unit["experience"]["observable_evidence"]) + \
            unit["experience"]["episode"] + unit["interaction"]["question"]
        for answer in unit["interaction"]["answers"]:
            text += answer["text"] + answer["feedback"]
        assert "unwilling" not in text.lower(), unit["id"]
        assert _re.search(r"\breluctant", text.lower()) is None, unit["id"]


def test_prepositional_neighbor_words_are_not_blocked():
    # almost 的 confusable "about" 作为介词 (如 "true about ...") 不是语义近邻,
    # 不拦截; 但程度副词边界词 fully/completely/already 仍必须拦截。
    fixture = load_fixture("almost-01")
    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["interaction"]["question"] += (
        " What is true about the hiker's walk?"
    )
    program = compiler.compile_experience_program("almost-01", adapter=FakeAdapter(responses))
    assert compiler.validate_program(program) == []

    responses = stage_responses(fixture)
    responses["surface_generator"]["units"][0]["experience"]["episode"] += (
        " The jar is not completely empty."
    )
    with pytest.raises(CompileError) as exc_info:
        compiler.compile_experience_program("almost-01", adapter=FakeAdapter(responses))
    messages = " | ".join(d.message for d in exc_info.value.diagnostics)
    assert "相邻 L2 词 'completely'" in messages


# --------------------------------------------------------------------------- #
# 草稿版本与覆盖行为
# --------------------------------------------------------------------------- #

def _resolve_from_tmp(monkeypatch, tmp_path):
    drafts = tmp_path / "drafts" / "experience-programs"
    drafts.mkdir(parents=True)
    monkeypatch.setattr(compiler, "DRAFTS_DIR", drafts)
    return drafts


def test_default_output_version_dir_matches_program_version(monkeypatch, tmp_path):
    drafts = _resolve_from_tmp(monkeypatch, tmp_path)
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    program = compiler.compile_experience_program(
        "reluctant-01", adapter=adapter, program_version=3)
    output = drafts / "reluctant-01" / "v03" / "program.yaml"
    assert not output.exists()  # compile 不自动落盘
    compiler._dump_program(program, output)
    assert output.exists()
    assert compiler.validate_program_file(output) == []


def test_next_version_auto_increments(monkeypatch, tmp_path):
    drafts = _resolve_from_tmp(monkeypatch, tmp_path)
    (drafts / "reluctant-01" / "v01").mkdir(parents=True)
    (drafts / "reluctant-01" / "v02").mkdir()
    assert compiler._next_version("reluctant-01") == 3
    assert compiler._next_version("never-seen") == 1


def test_dump_refuses_to_overwrite(monkeypatch, tmp_path):
    drafts = _resolve_from_tmp(monkeypatch, tmp_path)
    fixture = load_fixture("reluctant-01")
    adapter = FakeAdapter(stage_responses(fixture))
    program = compiler.compile_experience_program(
        "reluctant-01", adapter=adapter, program_version=1)
    target = drafts / "reluctant-01" / "v01" / "program.yaml"
    compiler._dump_program(program, target)
    with pytest.raises(CompileError) as exc_info:
        compiler._dump_program(program, target)
    assert "禁止覆盖" in str(exc_info.value)


def test_explicit_output_must_stay_inside_drafts(monkeypatch, tmp_path):
    drafts = _resolve_from_tmp(monkeypatch, tmp_path)
    outside = tmp_path / "outside" / "program.yaml"
    with pytest.raises(CompileError) as exc_info:
        compiler._resolve_output("reluctant-01", 1, outside)
    assert "输出路径越界" in str(exc_info.value)
    assert "必须位于" in exc_info.value.diagnostics[0].message


def test_compile_cli_uses_auto_version_and_writes_vNN(monkeypatch, tmp_path,
                                                      capsys):
    drafts = _resolve_from_tmp(monkeypatch, tmp_path)
    fixture = load_fixture("reluctant-01")
    real_compile = compiler.compile_experience_program
    adapter = FakeAdapter(stage_responses(fixture))

    def fake_compile(sense_id, **kwargs):
        kwargs.pop("config", None)
        return real_compile(sense_id, adapter=adapter, **kwargs)

    monkeypatch.setattr(compiler, "compile_experience_program", fake_compile)
    monkeypatch.setattr(compiler.llm_adapter.LLMConfig, "from_env",
                        staticmethod(lambda: None))
    code = compiler.main(["compile", "reluctant-01"])
    assert code == 0
    written = drafts / "reluctant-01" / "v01" / "program.yaml"
    assert written.exists()
    code = compiler.main(["compile", "reluctant-01"])
    assert code == 0
    assert (drafts / "reluctant-01" / "v02" / "program.yaml").exists()
    assert (drafts / "reluctant-01" / "v01" / "program.yaml").exists()  # 未被覆盖


# --------------------------------------------------------------------------- #
# 四词 fixture 回归
# --------------------------------------------------------------------------- #

def test_four_word_regression_passes_offline():
    result = run_regression()
    assert result.passed, result.errors


def test_reluctant_fixture_varies_eventual_action_yes_and_no():
    program = load_fixture("reluctant-01")
    outcomes = {
        unit["semantic_spec"]["eventual_action"]
        for unit in program["units"]
        if unit["role"] in ("anchor", "variation")
    }
    assert outcomes == {"yes", "no"}
    assert not all(
        unit["semantic_spec"].get("eventual_action") == "yes"
        for unit in program["units"]
    )


def test_four_programs_have_distinct_structures():
    programs = [load_fixture(sense_id) for sense_id in FIXTURE_IDS]

    def signature(program: dict) -> tuple:
        units = program["units"]
        return (
            len(units),
            tuple(unit["role"] for unit in units),
            tuple(tuple(unit["changed_variables"]) for unit in units),
        )

    signatures = [signature(program) for program in programs]
    assert len(set(signatures)) == len(signatures), (
        "四个程序的 unit 数量 / role 组合 / 变量结构必须存在真实差异"
    )
    counts = {len(program["units"]) for program in programs}
    assert len(counts) >= 2, "不能全部是同一数量的单元"


def test_each_program_has_review_pool_distinct_from_units():
    for sense_id in FIXTURE_IDS:
        program = load_fixture(sense_id)
        unit_episodes = {
            unit["experience"]["episode"] for unit in program["units"]
        }
        for item in program["review_pool"]:
            assert item["experience"]["episode"] not in unit_episodes


# --------------------------------------------------------------------------- #
# CLI (完全离线命令)
# --------------------------------------------------------------------------- #

def test_validate_cli_passes_fixtures():
    for sense_id in FIXTURE_IDS:
        assert compiler.main(["validate", str(FIXTURES_DIR / f"{sense_id}.yaml")]) == 0


def test_regression_cli_is_offline_and_passes():
    assert compiler.main(["regression"]) == 0


def test_compile_cli_fails_cleanly_without_llm_config(monkeypatch):
    for key in list(compiler.llm_adapter.os.environ):
        if key.startswith("SCENELEX_LLM_"):
            monkeypatch.delenv(key)
    code = compiler.main(["compile", "reluctant-01"])
    assert code == 2
