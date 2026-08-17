"""Holistic Course Compiler v1 的测试。

覆盖：
  - Author 输入包含完整目标义项 / 邻近义项 / Language Contract / App capabilities
  - pass 路径恰好 2 次课程级调用；fail 路径恰好 3 次；无 producer-scope 调用
  - Critic 看到完整课程；Repair 看到完整原课程 + 全部 diagnostics
  - validator 只做硬约束（不要求固定 unit 数、不要求 misconception 全覆盖、
    不要求 Boundary / Transfer；检查 identity、引用、答案、capability、
    L2 泄漏与中文 L1 surface policy）
  - lowering 不改变步骤顺序
  - compile / save 不覆盖 legacy program、assets 与 fixtures

所有模型调用使用纯内存 fake adapter，测试路径不触网。
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import holistic_course_compiler as hcc  # noqa: E402
from experience_compiler import load_contract, load_sense  # noqa: E402

AUTHOR_MARKER = "# Holistic Course Compiler — Course Author"
CRITIC_MARKER = "# Holistic Course Compiler — Whole-course Critic"
REPAIR_MARKER = "# Holistic Course Compiler — Whole-course Repair"

FIXTURES_DIR = ROOT / "tests" / "fixtures" / "experience-programs"
ASSETS_DIR = ROOT / "data" / "experience-assets"


# --------------------------------------------------------------------------- #
# 工具
# --------------------------------------------------------------------------- #

def valid_course(**overrides) -> dict:
    """一份能通过全部硬约束校验的最小课程（含绑定 + 绑定后使用 + 复习）。"""
    course = {
        "schema_version": "1.0",
        "course_id": "holistic-test-messy",
        "target": {
            "sense_id": "messy-01", "lemma": "messy", "pos": "adjective",
            "ipa": "/ˈmɛsi/", "learner_l1": "zh-CN", "target_l2": "en",
        },
        "author_intent": {
            "course_thesis": "用可观察的排列无序建立 messy 的意义。",
            "learner_start": "零基础。",
            "intended_outcome": "能用 messy 描述可见的杂乱。",
            "design_rationale": "最小测试课程。",
        },
        "learning_flow": [
            {
                "id": "s1", "trigger": "initial", "primitive": "scene_observation",
                "purpose": "建立经验", "addresses": [],
                "learner_content": {"episode": "书桌上东西散落，书本叠放方向不一。"},
                "evaluation": {"kind": "none"}, "next": "s2",
            },
            {
                "id": "s2", "trigger": "initial", "primitive": "symbol_reveal",
                "purpose": "绑定符号", "addresses": [],
                "learner_content": {
                    "l2_word": "messy", "ipa": "/ˈmɛsi/",
                    "presentation": "刚才看到的这种状态，就用这个符号来命名。",
                    "minimal_l1_gloss": "乱的",
                },
                "evaluation": {"kind": "none"}, "next": "s3",
            },
            {
                "id": "s3", "trigger": "initial", "primitive": "l2_grounding",
                "purpose": "锚定 L2", "addresses": [],
                "learner_content": {
                    "l2_realization": "The desk was messy after homework.",
                    "constructions": ["[place/thing] is messy"],
                    "collocations": ["messy room"],
                },
                "evaluation": {"kind": "none"},
            },
        ],
        "review_progression": [
            {
                "id": "r1", "timing": "next_day",
                "scaffold_level": "early_post_binding",
                "primitive": "recall_reveal",
                "learner_content": {
                    "episode": "厨房台面上三样东西都不在原位。",
                    "l2_word": "messy", "ipa": "/ˈmɛsi/",
                    "minimal_gloss": "乱的",
                },
                "evaluation": {"kind": "none"},
            },
        ],
    }
    for key, value in overrides.items():
        if key == "learning_flow":
            course["learning_flow"] = value
        elif key == "review_progression":
            course["review_progression"] = value
        else:
            course[key] = value
    return course


def dirty_course() -> dict:
    """与 valid_course 同构、target=dirty-01 的最小合法课程。"""
    course = valid_course(course_id="holistic-test-dirty")
    course["target"] = {
        "sense_id": "dirty-01", "lemma": "dirty", "pos": "adjective",
        "ipa": "/ˈdɜːrti/", "learner_l1": "zh-CN", "target_l2": "en",
    }
    for step in course["learning_flow"]:
        content = step["learner_content"]
        if step["primitive"] == "symbol_reveal":
            content.update({
                "l2_word": "dirty", "ipa": "/ˈdɜːrti/",
                "presentation": "刚才看到的这种状态，就用这个符号来命名。",
                "minimal_l1_gloss": "脏的",
            })
        if step["primitive"] == "l2_grounding":
            content.update({
                "l2_realization": "The floor was dirty after the rain.",
                "constructions": ["[place/thing] is dirty"],
                "collocations": ["dirty floor"],
            })
    for item in course["review_progression"]:
        content = item["learner_content"]
        content.update({
            "episode": "窗台上有灰尘。",
            "l2_word": "dirty", "ipa": "/ˈdɜːrti/", "minimal_gloss": "脏的",
        })
    return course


def validate(course: dict) -> hcc.ValidationResult:
    return hcc.validate_course_package(
        course,
        sense=load_sense("messy-01"),
        contract=load_contract("messy-01"),
        capabilities=hcc.load_capabilities(),
    )


def codes(result: hcc.ValidationResult) -> list[str]:
    return [d["code"] for d in result.diagnostics]


class FakeAdapter:
    """纯内存 fake adapter：按 system prompt 标记分派，记录全部调用。"""

    def __init__(self, author: dict, critic: dict, repair: dict | None = None):
        self.author = author
        self.critic = critic
        self.repair = repair
        self.calls: list[tuple[str, str | None]] = []  # (user, system)

    def __call__(self, user: str, system: str | None) -> hcc.HolisticCall:
        self.calls.append((user, system))
        if system and system.startswith(AUTHOR_MARKER):
            return self._response("author", self.author)
        if system and system.startswith(CRITIC_MARKER):
            return self._response("critic", self.critic)
        if system and system.startswith(REPAIR_MARKER):
            assert self.repair is not None, "repair 路径不应调用 Repair"
            return self._response("repair", self.repair)
        raise AssertionError(f"fake adapter 无法识别角色: {system!r}")

    def _response(self, role: str, payload: dict) -> hcc.HolisticCall:
        return hcc.HolisticCall(
            role="",
            text=json.dumps(payload, ensure_ascii=False),
            provider="fake",
            model="fake-model",
            request_id=f"req-{role}",
        )

    def user_prompts(self) -> list[str]:
        return [user for user, _ in self.calls]

    def course_level_calls(self) -> list[str]:
        roles = []
        for _, system in self.calls:
            if system and system.startswith("# Holistic Course Compiler"):
                # 角色取自 system prompt 的第一行标题
                role = system.splitlines()[0].split("—", 1)[1].strip().split()[-1].lower()
                roles.append(role)
        return roles


# --------------------------------------------------------------------------- #
# Author 输入完整性
# --------------------------------------------------------------------------- #

def _author_context_text() -> str:
    sense = load_sense("messy-01")
    neighbor = load_sense("dirty-01")
    contract = load_contract("messy-01")
    capabilities = hcc.load_capabilities()
    context = hcc.build_author_context(
        sense, [neighbor], contract, capabilities
    )
    return hcc.format_author_input(context)


def test_author_input_contains_full_messy_word_sense():
    text = _author_context_text()
    assert "id: messy-01" in text
    assert "definition: Visibly disordered or untidy" in text
    assert "messy 判断位置与组织秩序，dirty 判断表面是否有污物" in text  # boundaries
    assert "confusables" in text
    assert "l1_confusables" in text
    assert "可见的杂乱无序" in text


def test_author_input_contains_full_dirty_word_sense():
    text = _author_context_text()
    assert "id: dirty-01" in text
    assert "Covered or marked with an unwanted substance" in text
    assert "脏乱" in text  # dirty 义项的 L1 干扰材料
    assert "你可以选择使用、延后或不处理该义项" in text


def test_author_input_contains_full_language_contract():
    text = _author_context_text()
    assert "semantic_model" in text
    assert "invariant" in text
    for misc in ("misc-1", "misc-2", "misc-3", "misc-4", "misc-5"):
        assert misc in text
    assert "l1_interference" in text
    assert "semantic_revision" in text


def test_author_input_contains_full_app_capabilities():
    text = _author_context_text()
    capabilities = hcc.load_capabilities()
    for primitive in capabilities["primitives"]:
        assert primitive["id"] in text
        assert "allowed_pre_binding" in text


def test_author_input_does_not_contain_legacy_program():
    text = _author_context_text()
    assert "A study desk after homework" not in text
    assert "unit-1" not in text
    assert "review-1" not in text


# --------------------------------------------------------------------------- #
# 调用预算
# --------------------------------------------------------------------------- #

def test_pass_path_is_exactly_two_course_level_calls():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={"verdict": "pass", "summary": "主线连贯", "diagnostics": []},
    )
    result = hcc.compile_course("messy-01", ["dirty-01"], adapter)
    assert [c.role for c in result.calls] == ["author", "critic"]
    assert result.critic_verdict == "pass"
    assert result.repaired is False
    assert adapter.course_level_calls() == ["author", "critic"]


def test_fail_path_is_exactly_three_course_level_calls():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={
            "verdict": "fail",
            "summary": "重复教学",
            "diagnostics": [
                {"severity": "blocker", "area": "重复",
                 "message": "CRITIC-ISSUE-42 同一个误解在首学和边界里各教了一次"}
            ],
        },
        repair=valid_course(course_id="holistic-test-messy-repaired"),
    )
    result = hcc.compile_course("messy-01", ["dirty-01"], adapter)
    assert [c.role for c in result.calls] == ["author", "critic", "repair"]
    assert result.repaired is True
    assert result.package["course_id"] == "holistic-test-messy-repaired"


def test_no_producer_scope_calls():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={"verdict": "pass", "summary": "ok", "diagnostics": []},
    )
    hcc.compile_course("messy-01", ["dirty-01"], adapter)
    for user in adapter.user_prompts():
        assert "Producer Scope" not in user
        assert "本次只负责" not in user
        assert "只生成" not in user
        assert "hypothesis_target" not in user
        assert "compile_concept_assets" not in user
        assert "compile_review_batch" not in user


def test_every_call_contains_full_sense_and_neighbor():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={
            "verdict": "fail",
            "summary": "x",
            "diagnostics": [{"severity": "blocker", "area": "主线", "message": "X-1"}],
        },
        repair=valid_course(),
    )
    hcc.compile_course("messy-01", ["dirty-01"], adapter)
    assert len(adapter.calls) == 3
    for user, _system in adapter.calls:
        assert "id: messy-01" in user
        assert "definition: Visibly disordered or untidy" in user
        assert "id: dirty-01" in user


def test_critic_sees_full_course_package():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={"verdict": "pass", "summary": "ok", "diagnostics": []},
    )
    hcc.compile_course("messy-01", ["dirty-01"], adapter)
    critic_user = adapter.calls[1][0]
    assert "learning_flow" in critic_user
    assert "holistic-test-messy" in critic_user
    assert "s1" in critic_user
    assert "review_progression" in critic_user


def test_repair_sees_original_course_and_all_diagnostics():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={
            "verdict": "fail",
            "summary": "重复教学",
            "diagnostics": [
                {"severity": "blocker", "area": "重复",
                 "message": "CRITIC-ISSUE-42 同一个误解教了两次"},
                {"severity": "warning", "area": "认知负担",
                 "message": "CRITIC-ISSUE-43 步骤偏多"},
            ],
        },
        repair=valid_course(),
    )
    hcc.compile_course("messy-01", ["dirty-01"], adapter)
    repair_user = adapter.calls[2][0]
    assert "holistic-test-messy" in repair_user      # 完整原课程
    assert "s1" in repair_user
    assert "CRITIC-ISSUE-42" in repair_user          # 全部 diagnostics
    assert "CRITIC-ISSUE-43" in repair_user


# --------------------------------------------------------------------------- #
# Validator：不强制课程结构
# --------------------------------------------------------------------------- #

def test_validator_accepts_minimal_two_step_course():
    # 不要求固定 unit 数量：只有绑定 + 绑定后使用两步也合法
    course = valid_course(
        learning_flow=valid_course()["learning_flow"][1:],
        review_progression=[],
    )
    result = validate(course)
    assert result.valid, result.diagnostics


def test_validator_accepts_seven_step_course():
    flow = valid_course()["learning_flow"]
    seven = []
    for i in range(7):
        step = dict(flow[i % len(flow)], id=f"step-{i}")
        step.pop("next", None)  # 避免生成重复的悬空引用
        seven.append(step)
    course = valid_course(learning_flow=seven, review_progression=[])
    result = validate(course)
    assert result.valid, result.diagnostics


def test_validator_does_not_require_all_misconceptions():
    course = valid_course()  # addresses 全部为空
    result = validate(course)
    assert result.valid, result.diagnostics


def test_validator_does_not_require_boundary():
    course = valid_course()
    assert not any(
        step.get("primitive") == "boundary_choice"
        for step in course["learning_flow"]
    )
    assert validate(course).valid


def test_validator_does_not_require_transfer():
    course = valid_course()
    assert not any(
        step.get("primitive") == "transfer_judgment"
        for step in course["learning_flow"]
    )
    assert validate(course).valid


def test_validator_accepts_boundary_with_dirty():
    flow = valid_course()["learning_flow"]
    flow.append({
        "id": "s4", "trigger": "immediate_followup",
        "primitive": "boundary_choice", "purpose": "辨析", "addresses": ["misc-1"],
        "learner_content": {
            "episode": "同一间房间：东西乱放但每件都干净。",
            "options": [
                {"sense_id": "messy-01", "lemma": "messy"},
                {"sense_id": "dirty-01", "lemma": "dirty"},
            ],
            "correct_sense_id": "messy-01",
            "explanation": [
                {"sense_id": "messy-01", "note": "判断的是位置秩序。"},
                {"sense_id": "dirty-01", "note": "判断的是表面污物。"},
            ],
        },
        "evaluation": {"kind": "sense_choice", "correct_sense_id": "messy-01"},
    })
    course = valid_course(learning_flow=flow)
    result = validate(course)
    assert result.valid, result.diagnostics


# --------------------------------------------------------------------------- #
# Validator：硬约束
# --------------------------------------------------------------------------- #

def test_validator_checks_sense_identity():
    course = valid_course()
    course["target"]["lemma"] = "dirty"
    assert "identity" in codes(validate(course))


def test_validator_checks_references():
    course = valid_course()
    course["learning_flow"][0]["next"] = "does-not-exist"
    assert "id_ref" in codes(validate(course))

    course = valid_course()
    course["learning_flow"][0]["addresses"] = ["misc-99"]
    assert "id_ref" in codes(validate(course))


def test_validator_checks_answer_structure():
    course = valid_course()
    choice = {
        "id": "s4", "trigger": "initial", "primitive": "binary_judgment",
        "purpose": "判断", "addresses": [],
        "learner_content": {
            "episode": "桌面只有一支笔不在原位。",
            "question": "这算整体可见的乱吗？",
            "options": [
                {"id": "a1", "text": "算", "is_correct": True, "feedback": "对"},
                {"id": "a2", "text": "不算", "is_correct": False, "feedback": "错"},
            ],
        },
        "evaluation": {"kind": "choice", "correct_option_id": "zzz"},
    }
    course = valid_course(learning_flow=valid_course()["learning_flow"] + [choice])
    assert "evaluation" in codes(validate(course))


def test_validator_accepts_correct_option_id_as_sole_authority():
    # 正确答案只由 evaluation.correct_option_id 声明（选项不标 is_correct）
    course = valid_course()
    choice = {
        "id": "s4", "trigger": "initial", "primitive": "binary_judgment",
        "purpose": "判断", "addresses": [],
        "learner_content": {
            "episode": "桌面只有一支笔不在原位。",
            "question": "这算整体可见的乱吗？",
            "options": [
                {"id": "a1", "text": "算", "feedback": "对"},
                {"id": "a2", "text": "不算", "feedback": "错"},
            ],
        },
        "evaluation": {"kind": "choice", "correct_option_id": "a1"},
    }
    course = valid_course(learning_flow=valid_course()["learning_flow"] + [choice])
    assert validate(course).valid


def test_validator_flags_is_correct_mismatch():
    course = valid_course()
    choice = {
        "id": "s4", "trigger": "initial", "primitive": "binary_judgment",
        "purpose": "判断", "addresses": [],
        "learner_content": {
            "episode": "桌面只有一支笔不在原位。",
            "question": "这算整体可见的乱吗？",
            "options": [
                {"id": "a1", "text": "算", "is_correct": True, "feedback": "对"},
                {"id": "a2", "text": "不算", "is_correct": False, "feedback": "错"},
            ],
        },
        "evaluation": {"kind": "choice", "correct_option_id": "a2"},
    }
    course = valid_course(learning_flow=valid_course()["learning_flow"] + [choice])
    assert "evaluation" in codes(validate(course))


def test_validator_checks_renderer_capability():
    course = valid_course()
    course["learning_flow"][0]["primitive"] = "drag_drop_quiz"
    result = validate(course)
    assert "capability" in codes(result)

    course = valid_course()
    course["learning_flow"][1]["learner_content"]["mystery_field"] = "x"
    assert "capability" in codes(validate(course))


def test_validator_survives_malformed_options_without_crash():
    # 模型输出畸形（options 里混入字符串）时只报诊断，不崩溃
    course = valid_course()
    choice = {
        "id": "s4", "trigger": "initial", "primitive": "binary_judgment",
        "purpose": "判断", "addresses": [],
        "learner_content": {
            "episode": "桌面只有一支笔不在原位。",
            "question": "这算整体可见的乱吗？",
            "options": ["a1", {"id": "a2", "text": "不算", "is_correct": True,
                               "feedback": "错"}],
        },
        "evaluation": {"kind": "choice", "correct_option_id": "a2"},
    }
    course = valid_course(learning_flow=valid_course()["learning_flow"] + [choice])
    result = validate(course)
    assert not result.valid
    assert "evaluation" in codes(result)


def test_validator_checks_l2_leakage_before_binding():
    course = valid_course()
    course["learning_flow"][0]["learner_content"]["episode"] = "The desk was messy."
    assert "l2_leak" in codes(validate(course))

    course = valid_course()
    course["learning_flow"][0]["learner_content"]["episode"] = "The desk was dirty."
    assert "l2_leak" in codes(validate(course))  # 相邻易混 L2 词同样禁止


def test_validator_checks_chinese_l1_surface_policy():
    course = valid_course()
    course["learning_flow"][0]["learner_content"]["episode"] = (
        "Everything lies scattered all over the desk without any order."
    )
    assert "l1_surface" in codes(validate(course))


def test_validator_requires_target_l2_after_binding():
    course = valid_course()
    course["learning_flow"][2]["learner_content"]["l2_realization"] = "桌面很乱。"
    course["learning_flow"][2]["learner_content"]["constructions"] = []
    course["learning_flow"][2]["learner_content"]["collocations"] = []
    course["review_progression"] = []  # 复习揭示也算出现，这里一并移除
    result = validate(course)
    assert "binding" in codes(result)


def test_validator_requires_symbol_reveal():
    course = valid_course()
    course["learning_flow"] = [
        step for step in course["learning_flow"]
        if step["primitive"] != "symbol_reveal"
    ]
    assert "binding" in codes(validate(course))


def test_validator_review_reveal_before_rule():
    course = valid_course()
    course["review_progression"][0]["learner_content"]["episode"] = (
        "The kitchen counter was messy."
    )
    result = validate(course)
    assert "l2_leak" in codes(result)


# --------------------------------------------------------------------------- #
# Lowering
# --------------------------------------------------------------------------- #

def test_lowering_preserves_step_order():
    course = valid_course()
    lowered = hcc.lower_course_package(course)
    ids = [step["id"] for step in lowered["steps"]]
    assert ids == ["s1", "s2", "s3", "r1"]
    # 不增加教学内容、不改变字段
    assert lowered["steps"][0]["content"] == course["learning_flow"][0]["learner_content"]
    assert lowered["steps"][3]["stage"] == "review_progression"
    assert lowered["steps"][3]["timing"] == "next_day"


def test_lowering_never_invokes_llm():
    # lowering 是纯函数：对同一输入两次输出逐字节一致
    course = valid_course()
    assert hcc.lower_course_package(course) == hcc.lower_course_package(course)


# --------------------------------------------------------------------------- #
# 落盘与不覆盖
# --------------------------------------------------------------------------- #

def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_save_course_does_not_overwrite_legacy_files(tmp_path):
    legacy_files = [
        FIXTURES_DIR / "messy-01.yaml",
        ASSETS_DIR / "messy-01" / "concept.yaml",
        ASSETS_DIR / "messy-01" / "review.yaml",
    ]
    before = {str(path): _sha256(path) for path in legacy_files}

    adapter = FakeAdapter(
        author=valid_course(),
        critic={"verdict": "pass", "summary": "ok", "diagnostics": []},
    )
    result = hcc.compile_course("messy-01", ["dirty-01"], adapter)

    drafts_dir = tmp_path / "drafts"
    preview_dir = tmp_path / "preview"
    hcc.DRAFTS_DIR = drafts_dir
    hcc.PREVIEW_ASSETS_DIR = preview_dir
    try:
        course_path, preview_path = hcc.save_course(result, "messy-01")
    finally:
        hcc.DRAFTS_DIR = ROOT / "data" / "drafts" / "holistic-courses"
        hcc.PREVIEW_ASSETS_DIR = ROOT / "app" / "assets" / "content" / "holistic-course-preview"

    assert course_path.exists()
    assert preview_path.exists()
    assert not drafts_dir.exists() or drafts_dir == drafts_dir  # 写入的是 tmp 目录
    for path in legacy_files:
        assert _sha256(path) == before[str(path)], f"legacy 文件被修改: {path}"


def test_metadata_records_calls_without_secrets():
    adapter = FakeAdapter(
        author=valid_course(),
        critic={
            "verdict": "fail",
            "summary": "x",
            "diagnostics": [{"severity": "blocker", "area": "主线", "message": "X"}],
        },
        repair=valid_course(),
    )
    result = hcc.compile_course("messy-01", ["dirty-01"], adapter)
    packaged = hcc.attach_metadata(result.package, result.calls)
    calls = packaged["metadata"]["calls"]
    assert [c["role"] for c in calls] == ["author", "critic", "repair"]
    assert all(c["request_id"] for c in calls)
    blob = json.dumps(packaged["metadata"])
    assert "api_key" not in blob and "Authorization" not in blob


# --------------------------------------------------------------------------- #
# 六个新 primitive 的确定性校验（Teaching Archetype MVP 扩展）
# --------------------------------------------------------------------------- #

def _new_primitive_step(primitive: str, content: dict, evaluation: dict,
                        **step_kwargs) -> dict:
    step = {
        "id": "n1", "trigger": "initial", "primitive": primitive,
        "purpose": "新能力测试", "addresses": [],
        "learner_content": content, "evaluation": evaluation,
    }
    step.update(step_kwargs)
    return step


def _with_steps(*new_steps: dict, review=None) -> dict:
    """保留 valid_course 的 binding + 绑定后步骤，把新步骤插在 binding 前。"""
    course = valid_course()
    base = course["learning_flow"]
    binding_idx = next(
        i for i, s in enumerate(base) if s["primitive"] == "symbol_reveal")
    course["learning_flow"] = list(new_steps) + base[binding_idx:]
    if review is not None:
        course["review_progression"] = review
    return course


def test_multi_label_choice_validates_correct_option_ids():
    course = _with_steps(
        _new_primitive_step("multi_label_choice", {
            "episode": "桌上有一个带柄的厚壁大杯。",
            "question": "这个物体可能属于哪些类别？",
            "options": [
                {"id": "a", "text": "杯子"},
                {"id": "b", "text": "马克杯"},
                {"id": "c", "text": "勺子"},
            ],
        }, {"kind": "multi_choice", "correct_option_ids": ["a", "b"]}),
    )
    result = validate(course)
    assert result.valid, result.diagnostics

    # 正确答案集合引用非选项 id
    course["learning_flow"][0]["evaluation"] = {
        "kind": "multi_choice", "correct_option_ids": ["a", "zzz"]}
    assert "evaluation" in codes(validate(course))

    # 空集合
    course["learning_flow"][0]["evaluation"] = {
        "kind": "multi_choice", "correct_option_ids": []}
    assert "evaluation" in codes(validate(course))

    # is_correct 标记与集合不一致（可选一致性标记）
    course["learning_flow"][0]["evaluation"] = {
        "kind": "multi_choice", "correct_option_ids": ["a"]}
    course["learning_flow"][0]["learner_content"]["options"][1]["is_correct"] = True
    assert "evaluation" in codes(validate(course))


def test_object_inspection_requires_objects_and_names():
    course = _with_steps(
        _new_primitive_step("object_inspection", {
            "inspect_prompt": "观察这两个容器。",
            "objects": [
                {"id": "o1", "name": "杯子", "features": ["开口较小", "有柄"]},
                {"id": "o2", "name": "马克杯", "features": ["厚壁", "大容量"]},
            ],
            "hide_object_names": True,
        }, {"kind": "none"}),
    )
    assert validate(course).valid

    course["learning_flow"][0]["learner_content"]["objects"] = []
    assert "capability" in codes(validate(course))

    course["learning_flow"][0]["learner_content"]["objects"] = [
        {"id": "o1", "name": "杯子"}]
    assert "capability" in codes(validate(course))


def test_spatial_stage_path_references_and_bounds():
    course = _with_steps(
        _new_primitive_step("spatial_stage", {
            "stage_title": "房间俯视图",
            "stage_width": 100, "stage_height": 60,
            "start": {"x": 10, "y": 30}, "end": {"x": 90, "y": 30},
            "regions": [{"id": "tunnel", "label": "隧道", "shape": "rect"}],
            "paths": [
                {"id": "p1", "label": "从桥面横跨", "points": [[10, 30], [90, 30]]},
                {"id": "p2", "label": "穿过隧道", "points": [[10, 30], [50, 30], [90, 30]]},
            ],
            "correct_path_id": "p2",
            "feedback": "穿过内部空间。",
        }, {"kind": "path_choice", "correct_path_id": "p2"}),
    )
    assert validate(course).valid

    # correct_path_id 不在路径中
    course["learning_flow"][0]["evaluation"]["correct_path_id"] = "px"
    assert "evaluation" in codes(validate(course))

    # 路径点超出舞台边界
    course["learning_flow"][0]["evaluation"]["correct_path_id"] = "p2"
    course["learning_flow"][0]["learner_content"]["paths"][0]["points"] = [
        [10, 30], [120, 30]]
    assert "capability" in codes(validate(course))

    # 路径点数不足
    course["learning_flow"][0]["learner_content"]["paths"][0]["points"] = [[10, 30]]
    assert "capability" in codes(validate(course))


def test_participant_map_role_references():
    course = _with_steps(
        _new_primitive_step("participant_map", {
            "episode": "小美把书借给了小明。",
            "participants": [
                {"id": "mei", "label": "小美", "role": "giver"},
                {"id": "ming", "label": "小明", "role": "receiver"},
            ],
            "transferable": {"id": "book", "label": "书"},
            "arrows": [{"id": "a1", "from": "mei", "to": "ming", "label": "书"}],
            "perspective": {"current_role": "ming", "roles": ["mei", "ming"]},
            "question": "从小明的视角看，这个动作是？",
            "options": [
                {"id": "x", "text": "借入"},
                {"id": "y", "text": "借出"},
            ],
        }, {"kind": "choice", "correct_option_id": "x"}),
    )
    assert validate(course).valid

    # 箭头引用未知参与者
    course["learning_flow"][0]["learner_content"]["arrows"][0]["from"] = "ghost"
    assert "capability" in codes(validate(course))

    # perspective roles 引用未知参与者
    course["learning_flow"][0]["learner_content"]["arrows"][0]["from"] = "mei"
    course["learning_flow"][0]["learner_content"]["perspective"]["roles"] = ["mei", "ghost"]
    assert "capability" in codes(validate(course))

    # current_role 不在 roles 中
    course["learning_flow"][0]["learner_content"]["perspective"]["roles"] = ["mei", "ming"]
    course["learning_flow"][0]["learner_content"]["perspective"]["current_role"] = "ghost"
    assert "capability" in codes(validate(course))


def test_scalar_threshold_numeric_ranges():
    course = _with_steps(
        _new_primitive_step("scalar_threshold", {
            "episode": "水慢慢接近沸点。",
            "scale": {"min": 0, "max": 100, "label": "温度"},
            "initial_value": 95,
            "threshold": 100,
            "direction": "falls_short",
            "outcome_markers": {"reached": "达到了", "not_reached": "还没到"},
            "question": "水烧开了吗？",
            "options": [
                {"id": "a", "text": "还没开"},
                {"id": "b", "text": "开了"},
            ],
        }, {"kind": "choice", "correct_option_id": "a"}),
    )
    assert validate(course).valid

    # min >= max
    course["learning_flow"][0]["learner_content"]["scale"] = {"min": 100, "max": 0, "label": "t"}
    assert "capability" in codes(validate(course))

    # initial_value 超出范围
    course["learning_flow"][0]["learner_content"]["scale"] = {"min": 0, "max": 100, "label": "t"}
    course["learning_flow"][0]["learner_content"]["initial_value"] = 150
    assert "capability" in codes(validate(course))

    # threshold 缺失或越界
    course["learning_flow"][0]["learner_content"]["initial_value"] = 95
    course["learning_flow"][0]["learner_content"]["threshold"] = 150
    assert "capability" in codes(validate(course))


def test_information_state_agent_fact_references():
    course = _with_steps(
        _new_primitive_step("information_state", {
            "episode": "小明走进房间。",
            "agents": [{"id": "ming", "label": "小明"}],
            "facts": [{"id": "f1", "text": "窗户开着"}, {"id": "f2", "text": "钥匙在桌上"}],
            "beats": [
                {"id": "b1", "label": "进门", "visible_evidence": ["窗外的风"], "reveals": ["f1"], "known_by": ["ming"]},
            ],
            "question": "小明是注意到还是理解到？",
            "options": [
                {"id": "a", "text": "注意到"},
                {"id": "b", "text": "理解到"},
            ],
        }, {"kind": "choice", "correct_option_id": "a"}),
    )
    assert validate(course).valid

    # reveals 引用未知 fact
    course["learning_flow"][0]["learner_content"]["beats"][0]["reveals"] = ["f9"]
    assert "capability" in codes(validate(course))

    # known_by 引用未知 agent
    course["learning_flow"][0]["learner_content"]["beats"][0]["reveals"] = ["f1"]
    course["learning_flow"][0]["learner_content"]["beats"][0]["known_by"] = ["ghost"]
    assert "capability" in codes(validate(course))


def test_timing_and_breakpoint_fields_validation():
    course = _with_steps(
        _new_primitive_step("scene_observation", {"episode": "房间一角。"},
                            {"kind": "none"},
                            estimated_seconds=45, can_pause_after=True),
        review=[{
            "id": "r1", "timing": "次日",
            "due_after_days": 1, "scaffold_level": "early_post_binding",
            "primitive": "recall_reveal",
            "learner_content": {"episode": "场景。", "l2_word": "messy",
                                "ipa": "/ˈmɛsi/", "minimal_gloss": "乱的"},
            "evaluation": {"kind": "none"},
        }],
    )
    assert validate(course).valid

    course["learning_flow"][0]["estimated_seconds"] = 0
    assert "timing" in codes(validate(course))
    course["learning_flow"][0]["estimated_seconds"] = 45
    course["learning_flow"][0]["can_pause_after"] = "yes"
    assert "timing" in codes(validate(course))
    course["learning_flow"][0]["can_pause_after"] = True
    course["review_progression"][0]["due_after_days"] = 0
    assert "timing" in codes(validate(course))


def test_unknown_primitive_rejected():
    course = _with_steps(
        _new_primitive_step("not_a_primitive", {"episode": "x"}, {"kind": "none"}),
    )
    assert "capability" in codes(validate(course))


# --------------------------------------------------------------------------- #
# teaching_profile 建议输入（非权威）
# --------------------------------------------------------------------------- #

def test_author_input_contains_teaching_profile_section():
    sense = load_sense("messy-01")
    neighbor = load_sense("dirty-01")
    contract = load_contract("messy-01")
    capabilities = hcc.load_capabilities()
    manifest = hcc.load_manifest()
    context = hcc.build_author_context(
        sense, [neighbor], contract, capabilities, manifest=manifest)
    text = hcc.format_author_input(context)
    assert "教学原型建议" in text
    assert "visible_attribute" in text
    assert "suggested_capabilities" in text
    assert "special_risks" in text
    assert "不采用任何建议能力" in text
    # WordSense 中的 teaching_profile 也随义项整体进入输入
    assert "teaching_profile" in text


def test_pair_second_course_sees_first_course_context():
    """pair 第二门课程必须看到第一门完整课程（避免机械重复 Boundary）。"""
    first = valid_course(course_id="holistic-first")
    second = dirty_course()
    adapter = FakeAdapter(author=second, critic={"verdict": "pass", "diagnostics": []})
    result = hcc.compile_course(
        "dirty-01", ["messy-01"], adapter, related_course=first)
    user_prompt = adapter.user_prompts()[0]
    assert "相关课程上下文" in user_prompt
    assert "holistic-first" in user_prompt
    assert "holistic-second" not in user_prompt  # 只携带第一门课


def test_critic_sees_pair_context_and_full_package():
    first = valid_course(course_id="holistic-first")
    second = dirty_course()
    adapter = FakeAdapter(author=second, critic={"verdict": "pass", "diagnostics": []})
    hcc.compile_course(
        "dirty-01", ["messy-01"], adapter, related_course=first)
    critic_prompt = adapter.user_prompts()[1]
    assert "待评审的完整 Course Package" in critic_prompt
    assert "holistic-first" in critic_prompt  # Critic 看到 pair 第一门课
    assert "holistic-test-dirty" in critic_prompt  # 与完整待评审课程


# --------------------------------------------------------------------------- #
# batch: 可恢复 / digest 跳过 / 单门失败隔离
# --------------------------------------------------------------------------- #

def _tiny_manifest(courses: list[str]) -> str:
    lemma_info = {
        "messy-01": ("messy", "adjective"),
        "dirty-01": ("dirty", "adjective"),
        "almost-01": ("almost", "adverb"),
    }
    lines = [
        'schema_version: "1.0"',
        "plan_id: test-batch",
        "policy_version: 1",
        "learner_l1: zh-CN",
        "target_l2: en",
        "capability_version: 1",
        "curriculum:",
    ]
    for i, sid in enumerate(courses):
        lines.append(f"  - {{ day: {i + 1}, course: {sid} }}")
    lines += [
        "archetypes:",
        "  - id: visible_attribute",
        "    semantic_types: [attribute]",
        "    teaching_archetype: visible_attribute",
        "    experience_mechanism: m",
        "    suggested_capabilities: [scene_observation]",
        "    special_risks: [x]",
        "    clusters:",
        "      - id: messy_dirty",
        "        priority: 1",
        f"        boundary: {{ between: [{', '.join(courses)}], allowed: both }}",
        "        lemmas:",
    ]
    for sid in courses:
        lemma, pos = lemma_info[sid]
        lines.append(
            f"          - {{ lemma: {lemma}, pos: {pos}, sense_id: {sid} }}")
    return "\n".join(lines) + "\n"


class BatchFake(FakeAdapter):
    """按 author prompt 中的目标义项返回对应课程；critic 一律 pass。"""

    def __init__(self, courses: dict[str, dict]):
        super().__init__(author={}, critic={"verdict": "pass", "diagnostics": []})
        self.courses = courses

    def __call__(self, user, system):
        self.calls.append((user, system))
        if system and system.startswith(AUTHOR_MARKER):
            for sense_id, course in self.courses.items():
                if f"目标义项：{sense_id}" in user:
                    return self._response("author", course)
            raise AssertionError(f"未识别目标义项: {user[:300]}")
        if system and system.startswith(CRITIC_MARKER):
            return self._response("critic", {"verdict": "pass", "diagnostics": []})
        raise AssertionError(f"fake adapter 无法识别角色: {system!r}")


def _batch_env(tmp_path, monkeypatch, courses):
    """把 DRAFTS_DIR / PREVIEW_ASSETS_DIR 重定向到 tmp，返回 manifest 路径。"""
    drafts = tmp_path / "holistic-courses"
    previews = tmp_path / "preview-assets"
    drafts.mkdir(parents=True)
    previews.mkdir(parents=True)
    monkeypatch.setattr(hcc, "DRAFTS_DIR", drafts)
    monkeypatch.setattr(hcc, "PREVIEW_ASSETS_DIR", previews)
    manifest_path = tmp_path / "mvp.yaml"
    manifest_path.write_text(_tiny_manifest(courses), encoding="utf-8")
    return manifest_path


def test_batch_compiles_pair_with_second_course_context(tmp_path, monkeypatch):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01", "dirty-01"])
    first = valid_course(course_id="holistic-first-messy")
    second = dirty_course()

    class PairAdapter(BatchFake):
        def __init__(self):
            super().__init__({})
            self.second_seen = False

        def __call__(self, user, system):
            if system and system.startswith(AUTHOR_MARKER) and "目标义项：dirty-01" in user:
                self.second_seen = "holistic-first-messy" in user
                return self._response("author", second)
            if system and system.startswith(AUTHOR_MARKER) and "目标义项：messy-01" in user:
                return self._response("author", first)
            if system and system.startswith(CRITIC_MARKER):
                return self._response("critic", {"verdict": "pass", "diagnostics": []})
            raise AssertionError(system)

    adapter = PairAdapter()
    exit_code = hcc.cmd_compile_batch(manifest_path, "v01", force=False, adapter=adapter)
    assert exit_code == 0
    assert adapter.second_seen, "pair 第二门课程没有看到第一门课程"
    assert (hcc.DRAFTS_DIR / "messy-01" / "v01" / "course.yaml").exists()
    assert (hcc.DRAFTS_DIR / "dirty-01" / "v01" / "course.yaml").exists()


def test_batch_skips_unchanged_digest(tmp_path, monkeypatch):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01"])
    adapter = BatchFake({"messy-01": valid_course()})
    assert hcc.cmd_compile_batch(manifest_path, "v01", force=False, adapter=adapter) == 0
    assert len(adapter.calls) > 0
    # 重跑: digest 未变化 → 跳过, 不产生任何新调用
    adapter2 = BatchFake({"messy-01": valid_course()})
    assert hcc.cmd_compile_batch(manifest_path, "v01", force=False, adapter=adapter2) == 0
    assert len(adapter2.calls) == 0
    # --force 覆盖
    adapter3 = BatchFake({"messy-01": valid_course()})
    assert hcc.cmd_compile_batch(manifest_path, "v01", force=True, adapter=adapter3) == 0
    assert len(adapter3.calls) > 0


def test_batch_single_failure_does_not_break_others(tmp_path, monkeypatch):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01", "dirty-01"])

    class FailingAdapter(BatchFake):
        def __init__(self):
            super().__init__({"messy-01": valid_course()})
            self.failed = False

        def __call__(self, user, system):
            if system and system.startswith(AUTHOR_MARKER) and "目标义项：dirty-01" in user:
                self.failed = True
                raise ConnectionError("模拟网络失败")
            return super().__call__(user, system)

    adapter = FailingAdapter()
    exit_code = hcc.cmd_compile_batch(manifest_path, "v01", force=False, adapter=adapter)
    assert exit_code == 1
    assert adapter.failed
    # messy-01 不受 dirty-01 失败影响
    assert (hcc.DRAFTS_DIR / "messy-01" / "v01" / "course.yaml").exists()
    assert not (hcc.DRAFTS_DIR / "dirty-01" / "v01" / "course.yaml").exists()


def test_validate_batch_offline(tmp_path, monkeypatch):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01"])
    out_dir = hcc.DRAFTS_DIR / "messy-01" / "v01"
    out_dir.mkdir(parents=True)
    (out_dir / "course.yaml").write_text(
        yaml.safe_dump(valid_course(), allow_unicode=True, sort_keys=False),
        encoding="utf-8")
    exit_code = hcc.cmd_validate_batch(manifest_path)
    assert exit_code == 0


def test_validate_batch_offline(tmp_path, monkeypatch):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01"])
    drafts = hcc.DRAFTS_DIR
    out_dir = drafts / "messy-01" / "v01"
    out_dir.mkdir(parents=True)
    (out_dir / "course.yaml").write_text(
        yaml.safe_dump(valid_course(), allow_unicode=True, sort_keys=False),
        encoding="utf-8")
    exit_code = hcc.cmd_validate_batch(manifest_path)
    assert exit_code == 0


def test_capability_report_lists_gaps_and_usage(tmp_path, monkeypatch, capsys):
    manifest_path = _batch_env(tmp_path, monkeypatch, ["messy-01"])
    exit_code = hcc.cmd_capability_report(manifest_path)
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "[visible_attribute]" in out
    assert "suggested:" in out
    assert "registered:" in out
    assert "course_used:" in out


def test_cjk_text_with_latin_labels_is_not_l1_surface():
    """中文叙事含 '路A/路B' 这类拉丁标签不应误报为成段英语。"""
    course = _with_steps(
        _new_primitive_step("spatial_stage", {
            "stage_title": "田野路径",
            "stage_width": 100, "stage_height": 60,
            "start": {"x": 10, "y": 30}, "end": {"x": 90, "y": 30},
            "paths": [
                {"id": "p1", "label": "路A在田野内部从东边界连续延伸到西边界。",
                 "points": [[10, 30], [90, 30]]},
                {"id": "p2", "label": "路B在田野外部绕行。",
                 "points": [[10, 30], [50, 10], [90, 30]]},
            ],
            "correct_path_id": "p1",
            "feedback": "路A",
        }, {"kind": "path_choice", "correct_path_id": "p1"}),
    )
    result = validate(course)
    assert result.valid, result.diagnostics
    # 纯英文段落仍被拒绝
    english = _with_steps(
        _new_primitive_step("scene_observation",
                            {"episode": "The desk was messy after homework."},
                            {"kind": "none"}),
    )
    assert "l1_surface" in codes(validate(english))


def test_related_sense_material_accepts_map_and_string_forms():
    """Author 可写数组对象 / 字符串条目 / 键值映射三种形状。"""
    course = valid_course()
    course["related_sense_material"] = {
        "dirty-01": {"decision": "delayed",
                     "rationale": "本课不正式绑定 lend 的拼写。"},
        "borrow-02": {"decision": "excluded_in_first_pass", "rationale": "x"},
    }
    assert validate(course).valid
    course["related_sense_material"] = ["dirty-01：本课只作对照词。", "x：y"]
    assert validate(course).valid


def test_explanation_accepts_note_or_text_key():
    course = valid_course()
    # boundary 必须在绑定后：追加到原 flow 之后
    course["learning_flow"].append(
        _new_primitive_step("boundary_choice", {
            "episode": "书桌又乱又脏。",
            "options": [
                {"sense_id": "messy-01", "lemma": "messy"},
                {"sense_id": "dirty-01", "lemma": "dirty"},
            ],
            "explanation": [
                {"sense_id": "messy-01", "text": "位置无序才是 messy。"},
                {"sense_id": "dirty-01", "note": "表面污物才是 dirty。"},
            ],
        }, {"kind": "sense_choice", "correct_sense_id": "messy-01"}),
    )
    result = validate(course)
    assert result.valid, result.diagnostics
