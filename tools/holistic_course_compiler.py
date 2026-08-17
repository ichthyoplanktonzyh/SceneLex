#!/usr/bin/env python3
"""Holistic Course Compiler v1 — LLM 整课创作的纵向实验路径。

与 Experience Compiler v2（局部 producer 管线）完全独立：

- 一次 Course Author 调用看到完整上下文（目标 WordSense + 相关邻近义项 +
  中文 L1 Language Contract + App Teaching Capabilities），一次性产出完整
  Course Package（首学 / 绑定 / 边界 / 迁移 / 复习由 Author 决定）；
- 一次 Whole-course Critic 对整门课给出全局 verdict 与 diagnostics；
- Critic fail 时最多一次 Whole-course Repair，返回完整修订后的课程；
- 除上述课程级调用外，不调用任何局部 producer LLM，不做逐资产 gate。

本模块不修改 ``tools/experience_compiler.py``；只读复用其纯工具能力
（WordSense / Contract 加载、PresentationLanguage 政策块、tools/llm.py
adapter）。课程产物只写入 ``data/drafts/holistic-courses/``；预览资产
（确定性 lowering，无 LLM）写入 ``app/assets/content/holistic-course-preview/``。
"""

from __future__ import annotations

import argparse
import copy
import datetime
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

import yaml
from jsonschema import Draft202012Validator, FormatChecker

from experience_compiler import (
    DEFAULT_LANGUAGE,
    PresentationLanguage,
    load_contract,
    load_sense,
)

COMPILER_VERSION = "1.0.0"
SCHEMA_VERSION = "1.0"

ROOT = Path(__file__).resolve().parent.parent
PROMPTS_DIR = ROOT / "prompts" / "holistic-course"
SCHEMA_PATH = ROOT / "schema" / "holistic-course-package.schema.json"
CAPABILITIES_PATH = ROOT / "config" / "app-teaching-capabilities.v1.yaml"
DRAFTS_DIR = ROOT / "data" / "drafts" / "holistic-courses"
PREVIEW_ASSETS_DIR = ROOT / "app" / "assets" / "content" / "holistic-course-preview"
FIXTURES_DIR = ROOT / "tests" / "fixtures" / "experience-programs"

PRIMITIVES = (
    "scene_observation",
    "evidence_highlight",
    "single_choice",
    "binary_judgment",
    "symbol_reveal",
    "pronunciation",
    "l1_confirmation",
    "l2_grounding",
    "boundary_choice",
    "transfer_judgment",
    "recall_reveal",
    "recall_self_grade",
    "multi_label_choice",
    "object_inspection",
    "spatial_stage",
    "participant_map",
    "scalar_threshold",
    "information_state",
)

# primitive → 必须使用的 evaluation.kind（确定性答案结构约束）
REQUIRED_EVALUATION_KIND = {
    "scene_observation": "none",
    "evidence_highlight": "none",
    "single_choice": "choice",
    "binary_judgment": "choice",
    "symbol_reveal": "none",
    "pronunciation": "none",
    "l1_confirmation": "none",
    "l2_grounding": "none",
    "boundary_choice": "sense_choice",
    "transfer_judgment": "choice",
    "recall_reveal": "none",
    "recall_self_grade": "self_grade",
    "multi_label_choice": "multi_choice",
    "object_inspection": "none",
    "spatial_stage": "path_choice",
    "participant_map": "choice",
    "scalar_threshold": "choice",
    "information_state": "choice",
}

# 绑定前 learner-visible 文本"成段英语"的判定阈值（合同 §3 的确定性规则）
LATIN_WORD_RATIO_LIMIT = 0.6


class HolisticCompileError(RuntimeError):
    """Holistic 路径的编译/校验错误；携带结构化 diagnostics。"""

    def __init__(self, message: str, diagnostics: list[dict] | None = None):
        super().__init__(message)
        self.message = message
        self.diagnostics = diagnostics or []


@dataclass(frozen=True)
class HolisticCall:
    """一次课程级 LLM 调用的非敏感记录。"""

    role: str
    text: str
    provider: str | None = None
    model: str | None = None
    request_id: str | None = None


# (user_prompt, system_prompt) → HolisticCall
Adapter = Callable[[str, str | None], HolisticCall]

COURSE_LEVEL_ROLES = ("author", "critic", "repair")
RETRY_ROLES = ("author_format_retry", "critic_format_retry", "repair_format_retry")


# --------------------------------------------------------------------------- #
# 基础加载
# --------------------------------------------------------------------------- #

def load_capabilities() -> dict:
    try:
        doc = yaml.safe_load(CAPABILITIES_PATH.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise HolisticCompileError(f"App capabilities 无法读取: {exc}") from exc
    if not isinstance(doc, dict) or not isinstance(doc.get("primitives"), list):
        raise HolisticCompileError("App capabilities 结构不完整")
    return doc


def capability_index(capabilities: dict) -> dict[str, dict]:
    return {p["id"]: p for p in capabilities["primitives"]}


def load_prompt(name: str) -> str:
    path = PROMPTS_DIR / f"{name}.md"
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise HolisticCompileError(f"prompt 文件无法读取: {path}") from exc


def _utc_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _real_adapter(config: Any | None) -> Adapter:
    import llm as llm_adapter

    def adapter(prompt: str, system_prompt: str | None) -> HolisticCall:
        result = llm_adapter.invoke(
            prompt, config=config, system_prompt=system_prompt
        )
        return HolisticCall(
            role="",
            text=result.text,
            provider=result.protocol,
            model=result.model,
            request_id=result.request_id,
        )

    return adapter


# --------------------------------------------------------------------------- #
# Course Author 输入组装（完整上下文，不做局部 Scope 裁剪）
# --------------------------------------------------------------------------- #

def _dump_yaml(document: dict) -> str:
    return yaml.safe_dump(document, allow_unicode=True, sort_keys=False).strip()


TASK_SECTION = """你是完整课程作者。请端到端设计一个词义的完整课程，而不是填写
concept/review 等局部槽位。你的输出必须同时考虑首学、符号绑定、边界辨析、迁移与
后续复习；这些阶段是否出现、出现几次、什么顺序，全部由你决定。

约束：
- 只使用下方 App Teaching Capabilities 中已有的 primitive；不要发明新交互。
- 遵守下方呈现语言政策（L1 → L2 符号绑定）。
- 不提供、也不参考现有的 ExperienceProgram 或其他旧课程产物；不要复制它们的
  结构或文案。
- 输出一个完整 Course Package（结构见 Course Package Schema 说明）。"""


def build_author_context(
    sense: dict,
    neighbor_senses: list[dict],
    contract: dict,
    capabilities: dict,
    policy: PresentationLanguage | None = None,
    related_course: dict | None = None,
    manifest: dict | None = None,
) -> dict:
    """组装 Author（以及 Critic / Repair 共用的）完整上下文。

    related_course: pair 生成中已存在的第一门完整课程（可选）——第二门课程
    必须看到它，避免机械重复 Boundary；是否复用/递进由 Author 决定。
    manifest: data/content-plans/mvp-teaching-archetypes.yaml（可选）——
    提供 archetype 的经验机制与特殊风险，作为教学建议输入。
    """
    policy = policy or DEFAULT_LANGUAGE
    sections: list[dict] = [
        {
            "title": f"任务要求（目标义项：{sense['id']}）",
            "body": TASK_SECTION,
        },
        {
            "title": f"1. 目标义项完整 WordSense（{sense['id']}）",
            "body": _dump_yaml(sense),
        },
    ]
    for neighbor in neighbor_senses:
        sections.append(
            {
                "title": f"2. 相关邻近义项（{neighbor['id']}）—— 可选参考材料",
                "body": (
                    _dump_yaml(neighbor)
                    + "\n\n你可以选择使用、延后或不处理该义项；"
                    "是否处理、何时处理由你决定，代码不会替你决定。"
                ),
            }
        )
    sections.append(
        {
            "title": "3. 中文 L1 Language Contract（语义模型 / misconception / L1 干扰）",
            "body": _dump_yaml(contract),
        }
    )
    sections.append(
        {
            "title": "4. 呈现语言政策（Learning Presentation Language Contract v1）",
            "body": policy.policy_block(),
        }
    )
    sections.append(
        {
            "title": "5. App Teaching Capabilities（当前可渲染的 primitive）",
            "body": CAPABILITIES_PATH.read_text(encoding="utf-8").strip(),
        }
    )
    if manifest:
        archetype = next(
            (a for a in manifest.get("archetypes") or []
             if sense_id_in_archetype(a, sense["id"])),
            None,
        )
        if archetype:
            sections.append(
                {
                    "title": "6. 教学原型建议（非权威，可采纳可不采纳）",
                    "body": (
                        "以下建议来自仓库的 teaching profile；它们只是建议：\n"
                        + _dump_yaml({
                            "teaching_archetype": archetype.get("teaching_archetype"),
                            "semantic_types": archetype.get("semantic_types"),
                            "experience_mechanism": archetype.get("experience_mechanism"),
                            "suggested_capabilities": archetype.get("suggested_capabilities"),
                            "special_risks": archetype.get("special_risks"),
                            "word_sense_teaching_profile": sense.get("teaching_profile"),
                        })
                        + "\n你可以不采用任何建议能力，也可以混用多个 archetype 的 "
                        "primitive；没有代码强制 archetype 与 renderer 的对应关系。"
                    ),
                }
            )
    if related_course is not None:
        sections.append(
            {
                "title": "7. 相关课程上下文（pair 中已存在的第一门完整课程）",
                "body": (
                    "这是与目标义项配对的邻近义项课程。你可以参考它："
                    "避免机械重复同样的 Boundary/Transfer/Review 结构；"
                    "如果两门课都处理 Boundary，必须有明确的递进理由（例如不同场景、"
                    "不同方向、更晚的复习再提取）。不要复制它的文案。\n\n"
                    + _dump_yaml(related_course)
                ),
            }
        )
    sections.append(
        {
            "title": "8. Course Package 结构要求",
            "body": (
                "按 Course Package Schema 输出：schema_version=\"1.0\"、course_id、"
                "target（sense_id/lemma/pos/ipa/learner_l1/target_l2，必须与输入一致）、"
                "author_intent（course_thesis/learner_start/intended_outcome/"
                "design_rationale）、learning_flow（有序步骤数组）、"
                "review_progression（复习数组，与整课一起创作）、"
                "related_sense_material（可选）、metadata（可选）。\n"
                "learning_flow 每一步含：id、trigger（initial | on_error | "
                "immediate_followup | scheduled_review）、primitive、purpose、"
                "addresses（可选）、estimated_seconds（可选正整数，预计秒数）、"
                "can_pause_after（可选布尔，是否自然断点；symbol binding 前"
                "未声明断点时 App 不会随意切断）、learner_content（字段与 "
                "primitive 的 data_fields 一致）、evaluation（choice 用 "
                "correct_option_id；multi_choice 用 correct_option_ids 集合；"
                "boundary 用 correct_sense_id；spatial_stage 用 correct_path_id；"
                "自评 self_grade；观察/揭示 none）。\n"
                "review_progression 每项含：id、timing（解释文案）、"
                "due_after_days（可选正整数，结构化调度：绑定完成多少天后到期）、"
                "scaffold_level（early_post_binding | later_post_binding）、"
                "primitive、learner_content、evaluation。\n"
                "只输出完整 Course Package（单个 YAML 或 JSON 文档），不要输出其他文字。"
            ),
        },
    )
    return {"sections": sections, "sense": sense, "contract": contract}


def sense_id_in_archetype(archetype: dict, sense_id: str) -> bool:
    for cluster in archetype.get("clusters") or []:
        for lemma in cluster.get("lemmas") or []:
            if lemma.get("sense_id") == sense_id:
                return True
    return False


def format_author_input(context: dict) -> str:
    lines: list[str] = []
    for section in context["sections"]:
        lines.append(f"## {section['title']}")
        lines.append("")
        lines.append(section["body"])
        lines.append("")
    return "\n".join(lines).strip()


# --------------------------------------------------------------------------- #
# 解析
# --------------------------------------------------------------------------- #

def parse_course_package(text: str, stage: str) -> dict:
    """从模型输出提取 Course Package（支持 fenced JSON/YAML 与裸文档）。"""
    stripped = text.strip()
    fence = re.search(r"```(?:yaml|yml|json)?\s*(.*?)```", stripped, re.S)
    if fence:
        stripped = fence.group(1).strip()
    try:
        doc = json.loads(stripped)
        if isinstance(doc, dict):
            return doc
    except json.JSONDecodeError:
        pass
    try:
        doc = yaml.safe_load(stripped)
    except yaml.YAMLError as exc:
        raise HolisticCompileError(
            f"{stage} 输出既不是合法 JSON 也不是合法 YAML",
            [{"code": "parse", "message": f"{exc}; 输出前 200 字符: {stripped[:200]!r}"}],
        ) from exc
    if not isinstance(doc, dict):
        raise HolisticCompileError(
            f"{stage} 输出根节点必须是对象",
            [{"code": "parse", "message": "解析结果不是对象"}],
        )
    return doc


# --------------------------------------------------------------------------- #
# 确定性校验（只检查硬约束）
# --------------------------------------------------------------------------- #

@dataclass
class ValidationResult:
    valid: bool
    diagnostics: list[dict] = field(default_factory=list)

    def add(self, code: str, message: str, path: str = "") -> None:
        self.diagnostics.append({"code": code, "path": path, "message": message})
        self.valid = False


def _schema_validator() -> Draft202012Validator:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    return Draft202012Validator(schema, format_checker=FormatChecker())


def _iter_flow_items(course: dict) -> list[tuple[str, dict]]:
    """(stage, item) 序列：learning_flow 在前，review_progression 在后。"""
    items: list[tuple[str, dict]] = [
        ("learning_flow", step) for step in course.get("learning_flow", [])
    ]
    items += [
        ("review_progression", item) for item in course.get("review_progression", [])
    ]
    return items


# learner_content 中"机器引用/数值"字段的键：不是 learner-visible 文本，
# L2 泄漏与 L1 surface 检查必须跳过（例如选项 id、坐标、数值、引用 id）。
MACHINE_CONTENT_KEYS = {
    "id", "from", "to", "x", "y", "min", "max", "initial_value",
    "threshold", "stage_width", "stage_height", "hide_object_names",
    "is_correct", "shape", "role", "current_role", "roles", "reveals",
    "known_by", "correct_option_id", "correct_option_ids", "correct_sense_id",
    "correct_path_id", "source_step_id", "due_after_days",
    "estimated_seconds", "can_pause_after", "points", "direction",
    "priority", "version",
}


def _learner_visible_strings(item: dict) -> list[str]:
    strings: list[str] = []

    def walk(node: Any, key: str | None = None) -> None:
        if isinstance(node, str):
            strings.append(node)
        elif isinstance(node, list):
            for child in node:
                walk(child)
        elif isinstance(node, dict):
            for child_key, value in node.items():
                if child_key in MACHINE_CONTENT_KEYS:
                    continue
                walk(value, child_key)

    walk(item.get("learner_content") or {})
    return strings


def _pre_reveal_strings(item: dict) -> list[str]:
    """复习项中揭示前的 learner-visible 字段（场景/证据/问题/确认语）。"""
    content = item.get("learner_content") or {}
    strings: list[str] = []
    for key in ("episode", "evidence", "question", "prompt_text"):
        value = content.get(key)
        if isinstance(value, str):
            strings.append(value)
        elif isinstance(value, list):
            strings.extend(x for x in value if isinstance(x, str))
    return strings


def _latin_word_ratio(text: str) -> float:
    """CJK 感知的"成段英语"判定：拉丁字母数 / (拉丁字母数 + CJK 字符数)。

    中文文本没有空格分词，按空白分词会把整段中文当成一个"词"，任何内嵌拉丁
    字符（如"路A"）都会误报。按字母计数对 CJK 文本稳定：纯英文段落比率≈1，
    中文叙事（即使含 A/B/C 标签）比率很低。
    """
    latin = len(re.findall(r"[A-Za-z]", text))
    cjk = len(re.findall(r"[\u4e00-\u9fff]", text))
    total = latin + cjk
    if total == 0:
        return 0.0
    return latin / total


def _l2_tokens(text: str) -> list[str]:
    return re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text)


def forbidden_l2_tokens(sense: dict) -> set[str]:
    """目标 lemma + 屈折/派生 + WordSense relations 声明的相邻/易混 L2 词。

    relations 里的词形可能是 sense id（如 dirty-01），需要去掉数字后缀。
    """
    lemma = str(sense.get("word", "")).lower()
    tokens = {lemma}
    suffixes = ("s", "es", "ier", "iest", "ily", "iness")
    for suffix in suffixes:
        tokens.add(f"{lemma}{suffix}")
    relations = sense.get("relations") or {}
    for key in ("synonyms", "antonyms", "hypernyms", "hyponyms", "confusables"):
        for word in relations.get(key) or []:
            tokens.add(re.sub(r"-\d+$", "", str(word)).lower())
    for boundary in relations.get("boundaries") or []:
        if isinstance(boundary, dict) and boundary.get("target"):
            tokens.add(re.sub(r"-\d+$", "", str(boundary["target"])).lower())
    return tokens


def validate_course_package(
    course: dict,
    *,
    sense: dict,
    contract: dict,
    capabilities: dict,
) -> ValidationResult:
    """只做确定性硬约束校验；课程数量、顺序、误解覆盖、Boundary/Transfer
    是否出现等质量问题一律不在此检查（交给 Whole-course Critic）。"""
    result = ValidationResult(valid=True)
    cap_index = capability_index(capabilities)

    # 1. schema / 结构
    errors = sorted(_schema_validator().iter_errors(course), key=lambda e: list(e.path))
    for error in errors:
        result.add("schema", error.message, path="/".join(str(p) for p in error.path))

    # 2. sense identity 不漂移
    target = course.get("target") or {}
    if target.get("sense_id") != sense["id"]:
        result.add("identity", f"target.sense_id={target.get('sense_id')!r} != 输入义项 {sense['id']}")
    if target.get("lemma") != sense.get("word"):
        result.add("identity", f"target.lemma={target.get('lemma')!r} != WordSense.word={sense.get('word')!r}")
    if target.get("pos") != sense.get("pos"):
        result.add("identity", f"target.pos={target.get('pos')!r} != WordSense.pos={sense.get('pos')!r}")
    ipa = (sense.get("pronunciation") or {}).get("ipa")
    if ipa and target.get("ipa") and target.get("ipa") != ipa:
        result.add("identity", f"target.ipa={target.get('ipa')!r} != WordSense.ipa={ipa!r}")
    policy = DEFAULT_LANGUAGE
    if target.get("learner_l1") != policy.learner_l1:
        result.add("identity", f"target.learner_l1={target.get('learner_l1')!r} != {policy.learner_l1}")
    if target.get("target_l2") != policy.target_l2:
        result.add("identity", f"target.target_l2={target.get('target_l2')!r} != {policy.target_l2}")

    # 3. ID 唯一、引用存在
    flow_items = _iter_flow_items(course)
    seen_flow_ids: set[str] = set()
    for stage, item in flow_items:
        item_id = item.get("id")
        if not item_id:
            continue
        if item_id in seen_flow_ids:
            result.add("id_unique", f"{stage} 中 id={item_id!r} 重复", item_id)
        seen_flow_ids.add(item_id)

    flow_ids = [item.get("id") for _, item in flow_items if item.get("id")]
    for stage, item in flow_items:
        nxt = item.get("next")
        if nxt and nxt not in flow_ids:
            result.add("id_ref", f"{item.get('id')}.next={nxt!r} 引用了不存在的步骤", item.get("id", ""))
        for ref in item.get("addresses") or []:
            if not any(m.get("id") == ref for m in (contract.get("semantic_model") or {}).get("misconceptions") or []):
                result.add("id_ref", f"{item.get('id')}.addresses={ref!r} 不是 contract 中的 misconception id", item.get("id", ""))
        source = (item.get("learner_content") or {}).get("source_step_id")
        if source and source not in flow_ids:
            result.add("id_ref", f"{item.get('id')} 的 source_step_id={source!r} 引用了不存在的步骤", item.get("id", ""))

    # 4. 答案结构合法 + primitive 能力
    binding_index: int | None = None
    for idx, (stage, item) in enumerate(flow_items):
        primitive = item.get("primitive")
        if primitive not in PRIMITIVES or primitive not in cap_index:
            result.add("capability", f"{item.get('id')} 使用了未知 primitive={primitive!r}", item.get("id", ""))
            continue
        content = item.get("learner_content") or {}
        allowed = set(cap_index[primitive]["data_fields"])
        for key in content:
            if key not in allowed:
                result.add("capability", f"{item.get('id')} 的 learner_content.{key} 不在 primitive={primitive} 的 data_fields 中", item.get("id", ""))

        # evaluation kind 与答案结构
        required_kind = REQUIRED_EVALUATION_KIND.get(primitive)
        evaluation = item.get("evaluation") or {}
        kind = evaluation.get("kind")
        if required_kind and kind != required_kind:
            result.add("evaluation", f"{item.get('id')} 的 evaluation.kind={kind!r}，primitive={primitive} 要求 {required_kind}", item.get("id", ""))
            continue
        options = content.get("options") or []
        option_dicts = [o for o in options if isinstance(o, dict)]
        if kind == "choice":
            if len(option_dicts) < 2:
                result.add("evaluation", f"{item.get('id')} 的 choice 步骤至少需要 2 个选项", item.get("id", ""))
            if primitive == "binary_judgment" and len(option_dicts) != 2:
                result.add("evaluation", f"{item.get('id')} 的 binary_judgment 必须恰好 2 个选项", item.get("id", ""))
            option_ids = [o.get("id") for o in option_dicts]
            if len(option_ids) != len(set(option_ids)):
                result.add("evaluation", f"{item.get('id')} 的选项 id 重复", item.get("id", ""))
            # 正确答案的权威来源是 evaluation.correct_option_id；is_correct 是
            # 可选的一致性标记：出现时必须恰好一个且与权威一致。
            flagged = [o for o in option_dicts if o.get("is_correct") is True]
            if len(flagged) > 1:
                result.add("evaluation", f"{item.get('id')} 有 {len(flagged)} 个选项标记 is_correct=true（最多 1 个）", item.get("id", ""))
            if len(flagged) == 1 and flagged[0].get("id") != evaluation.get("correct_option_id"):
                result.add("evaluation", f"{item.get('id')} 的 is_correct 标记与 evaluation.correct_option_id 不一致", item.get("id", ""))
            if evaluation.get("correct_option_id") not in option_ids:
                result.add("evaluation", f"{item.get('id')} 的 correct_option_id={evaluation.get('correct_option_id')!r} 不在选项 id 中", item.get("id", ""))
        elif kind == "sense_choice":
            if len(option_dicts) < 2:
                result.add("evaluation", f"{item.get('id')} 的 boundary 步骤至少需要 2 个 sense 选项", item.get("id", ""))
            # 选项可以是 {sense_id, lemma} 或 {sense_id, text}（text 作为显示词）
            for option in option_dicts:
                if not option.get("sense_id"):
                    result.add("evaluation", f"{item.get('id')} 的 sense 选项缺少 sense_id", item.get("id", ""))
                if not (option.get("lemma") or option.get("text")):
                    result.add("evaluation", f"{item.get('id')} 的 sense 选项缺少 lemma/text 显示词", item.get("id", ""))
            sense_ids = [o.get("sense_id") for o in option_dicts if o.get("sense_id")]
            if len(sense_ids) != len(set(sense_ids)):
                result.add("evaluation", f"{item.get('id')} 的 sense 选项重复", item.get("id", ""))
            if evaluation.get("correct_sense_id") not in sense_ids:
                result.add("evaluation", f"{item.get('id')} 的 correct_sense_id={evaluation.get('correct_sense_id')!r} 不在选项 sense_id 中", item.get("id", ""))
            explanation_senses = [
                e.get("sense_id") for e in content.get("explanation") or []
                if isinstance(e, dict)
            ]
            for eid in explanation_senses:
                if eid not in sense_ids:
                    result.add("evaluation", f"{item.get('id')} 的 explanation 引用了非选项 sense={eid!r}", item.get("id", ""))
        elif kind == "none":
            if content.get("options") or content.get("question"):
                result.add("evaluation", f"{item.get('id')} 的 {primitive} 不应包含 question/options", item.get("id", ""))
        elif kind == "self_grade":
            if not content.get("l2_word"):
                result.add("evaluation", f"{item.get('id')} 的 recall_self_grade 需要 l2_word", item.get("id", ""))
        elif kind == "multi_choice":
            if len(option_dicts) < 2:
                result.add("evaluation", f"{item.get('id')} 的 multi_label_choice 至少需要 2 个选项", item.get("id", ""))
            option_ids = [o.get("id") for o in option_dicts]
            if len(option_ids) != len(set(option_ids)):
                result.add("evaluation", f"{item.get('id')} 的选项 id 重复", item.get("id", ""))
            correct = evaluation.get("correct_option_ids")
            if not isinstance(correct, list) or not correct:
                result.add("evaluation", f"{item.get('id')} 的 multi_label_choice 需要非空 correct_option_ids", item.get("id", ""))
            elif len(correct) != len(set(correct)):
                result.add("evaluation", f"{item.get('id')} 的 correct_option_ids 有重复", item.get("id", ""))
            else:
                for cid in correct:
                    if cid not in option_ids:
                        result.add("evaluation", f"{item.get('id')} 的 correct_option_ids 含非选项 id={cid!r}", item.get("id", ""))
            flagged = [o.get("id") for o in option_dicts if o.get("is_correct") is True]
            if flagged and set(flagged) != set(correct):
                result.add("evaluation", f"{item.get('id')} 的 is_correct 标记与 correct_option_ids 不一致", item.get("id", ""))
        elif kind == "path_choice":
            paths = [p for p in content.get("paths") or [] if isinstance(p, dict)]
            if len(paths) < 2:
                result.add("evaluation", f"{item.get('id')} 的 spatial_stage 至少需要 2 条候选路径", item.get("id", ""))
            path_ids = [p.get("id") for p in paths]
            if len(path_ids) != len(set(path_ids)):
                result.add("evaluation", f"{item.get('id')} 的路径 id 重复", item.get("id", ""))
            if evaluation.get("correct_path_id") not in path_ids:
                result.add("evaluation", f"{item.get('id')} 的 correct_path_id={evaluation.get('correct_path_id')!r} 不在路径 id 中", item.get("id", ""))

        # ---- 六个新 primitive 的内容结构检查（机器可读的引用与数值约束） ----
        if primitive == "object_inspection":
            objects = [o for o in content.get("objects") or [] if isinstance(o, dict)]
            if not objects:
                result.add("capability", f"{item.get('id')} 的 object_inspection 需要至少 1 个对象", item.get("id", ""))
            obj_ids = [o.get("id") for o in objects]
            if len(obj_ids) != len(set(obj_ids)):
                result.add("capability", f"{item.get('id')} 的对象 id 重复", item.get("id", ""))
            for obj in objects:
                if not obj.get("name"):
                    result.add("capability", f"{item.get('id')} 的对象 {obj.get('id')!r} 缺少 name", item.get("id", ""))
                if not obj.get("features"):
                    result.add("capability", f"{item.get('id')} 的对象 {obj.get('id')!r} 缺少 features", item.get("id", ""))
        elif primitive == "spatial_stage":
            width, height = content.get("stage_width"), content.get("stage_height")
            for label, point in (("start", content.get("start")), ("end", content.get("end"))):
                if not isinstance(point, dict) or not isinstance(point.get("x"), (int, float)) or not isinstance(point.get("y"), (int, float)):
                    result.add("capability", f"{item.get('id')} 的 {label} 必须是 {{x, y}} 数值", item.get("id", ""))
                elif width and height and not (0 <= point["x"] <= width and 0 <= point["y"] <= height):
                    result.add("capability", f"{item.get('id')} 的 {label} 超出舞台边界", item.get("id", ""))
            for path in [p for p in content.get("paths") or [] if isinstance(p, dict)]:
                points = path.get("points") or []
                if len(points) < 2:
                    result.add("capability", f"{item.get('id')} 的路径 {path.get('id')!r} 至少需要 2 个点", item.get("id", ""))
                for point in points:
                    if (not isinstance(point, (list, tuple)) or len(point) != 2
                            or not all(isinstance(v, (int, float)) for v in point)):
                        result.add("capability", f"{item.get('id')} 的路径 {path.get('id')!r} 点必须是 [x, y] 数值对", item.get("id", ""))
                    elif width and height and not (0 <= point[0] <= width and 0 <= point[1] <= height):
                        result.add("capability", f"{item.get('id')} 的路径 {path.get('id')!r} 有点超出舞台边界", item.get("id", ""))
        elif primitive == "participant_map":
            participants = [p for p in content.get("participants") or [] if isinstance(p, dict)]
            p_ids = [p.get("id") for p in participants]
            if not p_ids:
                result.add("capability", f"{item.get('id')} 的 participant_map 需要至少 1 个参与者", item.get("id", ""))
            if len(p_ids) != len(set(p_ids)):
                result.add("capability", f"{item.get('id')} 的参与者 id 重复", item.get("id", ""))
            for arrow in [a for a in content.get("arrows") or [] if isinstance(a, dict)]:
                if arrow.get("from") not in p_ids or arrow.get("to") not in p_ids:
                    result.add("capability", f"{item.get('id')} 的箭头 {arrow.get('id')!r} 引用了不存在的参与者", item.get("id", ""))
            perspective = content.get("perspective") or {}
            roles = perspective.get("roles") or []
            if perspective.get("current_role") not in roles:
                result.add("capability", f"{item.get('id')} 的 perspective.current_role 不在 roles 中", item.get("id", ""))
            for role in roles:
                if role not in p_ids:
                    result.add("capability", f"{item.get('id')} 的 perspective.roles 含未知参与者 {role!r}", item.get("id", ""))
        elif primitive == "scalar_threshold":
            scale = content.get("scale") or {}
            smin, smax = scale.get("min"), scale.get("max")
            if not isinstance(smin, (int, float)) or not isinstance(smax, (int, float)) or not smin < smax:
                result.add("capability", f"{item.get('id')} 的 scale 需要 min < max 数值", item.get("id", ""))
            else:
                initial = content.get("initial_value")
                if initial is not None and not (smin <= initial <= smax):
                    result.add("capability", f"{item.get('id')} 的 initial_value 超出 [min, max]", item.get("id", ""))
                threshold = content.get("threshold")
                if threshold is None or not (smin <= threshold <= smax):
                    result.add("capability", f"{item.get('id')} 的 threshold 需要在 [min, max] 内", item.get("id", ""))
        elif primitive == "information_state":
            agents = [a for a in content.get("agents") or [] if isinstance(a, dict)]
            facts = [f for f in content.get("facts") or [] if isinstance(f, dict)]
            agent_ids = [a.get("id") for a in agents]
            fact_ids = [f.get("id") for f in facts]
            if not agent_ids or len(agent_ids) != len(set(agent_ids)):
                result.add("capability", f"{item.get('id')} 的 information_state 需要唯一 agents", item.get("id", ""))
            if not fact_ids or len(fact_ids) != len(set(fact_ids)):
                result.add("capability", f"{item.get('id')} 的 information_state 需要唯一 facts", item.get("id", ""))
            for beat in [b for b in content.get("beats") or [] if isinstance(b, dict)]:
                for fid in beat.get("reveals") or []:
                    if fid not in fact_ids:
                        result.add("capability", f"{item.get('id')} 的 beat {beat.get('id')!r} reveals 引用了未知 fact {fid!r}", item.get("id", ""))
                for aid in beat.get("known_by") or []:
                    if aid not in agent_ids:
                        result.add("capability", f"{item.get('id')} 的 beat {beat.get('id')!r} known_by 引用了未知 agent {aid!r}", item.get("id", ""))

        # ---- 时间与自然断点（Course Author 声明，App 执行） ----
        estimated = item.get("estimated_seconds")
        if estimated is not None and (not isinstance(estimated, int) or estimated < 1):
            result.add("timing", f"{item.get('id')} 的 estimated_seconds 必须是正整数", item.get("id", ""))
        if item.get("can_pause_after") is not None and not isinstance(item.get("can_pause_after"), bool):
            result.add("timing", f"{item.get('id')} 的 can_pause_after 必须是布尔值", item.get("id", ""))
        if stage == "review_progression":
            due = item.get("due_after_days")
            if due is not None and (not isinstance(due, int) or due < 1):
                result.add("timing", f"{item.get('id')} 的 due_after_days 必须是正整数", item.get("id", ""))

        if primitive == "symbol_reveal":
            if content.get("l2_word") != sense.get("word"):
                result.add("binding", f"{item.get('id')} 的 symbol_reveal.l2_word={content.get('l2_word')!r} != 目标 lemma {sense.get('word')!r}", item.get("id", ""))
            if binding_index is None:
                binding_index = idx

    # 5. 绑定前不泄漏目标 L2 / 相邻易混 L2 词；中文 L1 surface policy
    forbidden = forbidden_l2_tokens(sense)
    pre_binding_items = flow_items[:binding_index] if binding_index is not None else flow_items
    for stage, item in pre_binding_items:
        for text in _learner_visible_strings(item):
            for token in _l2_tokens(text):
                if token.lower() in forbidden:
                    result.add("l2_leak", f"{item.get('id')} 在 symbol binding 前出现 L2 词 {token!r}: {text[:80]!r}", item.get("id", ""))
            if _latin_word_ratio(text) > LATIN_WORD_RATIO_LIMIT:
                result.add("l1_surface", f"{item.get('id')} 在 symbol binding 前使用成段英语（中文学习者在绑定前不应被英文解释）: {text[:80]!r}", item.get("id", ""))

    # 6. 绑定后目标 L2 确实出现（绑定步骤之后的 learner-visible 内容或复习）
    if binding_index is None:
        result.add("binding", "课程缺少 symbol_reveal 步骤（目标 L2 从未揭示）")
    else:
        post_items = flow_items[binding_index + 1:]
        seen_after = False
        for stage, item in post_items:
            for text in _learner_visible_strings(item):
                if any(t.lower() == sense.get("word", "").lower() for t in _l2_tokens(text)):
                    seen_after = True
        if not seen_after:
            result.add("binding", "symbol binding 之后没有任何 learner-visible 内容出现目标 L2")

    # 7. 复习脚手架：early_post_binding 的复习项，揭示前字段必须为 L1
    for _stage, item in flow_items:
        if item.get("scaffold_level") != "early_post_binding":
            continue
        primitive = item.get("primitive")
        if primitive in ("recall_reveal", "recall_self_grade"):
            for text in _pre_reveal_strings(item):
                if any(t.lower() == sense.get("word", "").lower() for t in _l2_tokens(text)):
                    result.add("l2_leak", f"复习项 {item.get('id')} 在揭示前出现目标 L2（反向回忆规则）", item.get("id", ""))
        for text in _pre_reveal_strings(item):
            if _latin_word_ratio(text) > LATIN_WORD_RATIO_LIMIT:
                result.add("l1_surface", f"复习项 {item.get('id')}（early_post_binding）场景使用成段英语", item.get("id", ""))

    return result


# --------------------------------------------------------------------------- #
# 确定性 lowering：HolisticCoursePackage → preview runtime data（无 LLM）
# --------------------------------------------------------------------------- #

def lower_course_package(course: dict) -> dict:
    """只转换字段以复用现有 Widget；不增加教学内容、不重新决定顺序、
    不把课程拆回局部 producer。"""
    steps: list[dict] = []
    for step in course.get("learning_flow", []):
        steps.append({
            "id": step.get("id"),
            "stage": "learning_flow",
            "trigger": step.get("trigger"),
            "primitive": step.get("primitive"),
            "purpose": step.get("purpose"),
            "addresses": step.get("addresses") or [],
            "timing": None,
            "scaffold_level": None,
            "estimated_seconds": step.get("estimated_seconds"),
            "can_pause_after": step.get("can_pause_after"),
            "due_after_days": None,
            "content": step.get("learner_content") or {},
            "evaluation": step.get("evaluation") or {},
        })
    for item in course.get("review_progression", []):
        steps.append({
            "id": item.get("id"),
            "stage": "review_progression",
            "trigger": "scheduled_review",
            "primitive": item.get("primitive"),
            "purpose": item.get("purpose") or item.get("timing") or "",
            "addresses": item.get("addresses") or [],
            "timing": item.get("timing"),
            "scaffold_level": item.get("scaffold_level"),
            "estimated_seconds": item.get("estimated_seconds"),
            "can_pause_after": item.get("can_pause_after"),
            "due_after_days": item.get("due_after_days"),
            "content": item.get("learner_content") or {},
            "evaluation": item.get("evaluation") or {},
        })
    return {
        "schema_version": course.get("schema_version", SCHEMA_VERSION),
        "course_id": course.get("course_id"),
        "target": course.get("target") or {},
        "author_intent": course.get("author_intent") or {},
        "steps": steps,
    }


# --------------------------------------------------------------------------- #
# 编排：Author → Critic → 可选 Repair
# --------------------------------------------------------------------------- #

def _retry_suffix(stage: str, previous_text: str, problem: str) -> str:
    return (
        f"\n\n--- {stage} 格式/校验修复（一次机会） ---\n"
        f"你上一次的输出无法通过解析或硬约束校验：{problem}\n"
        f"你上一次的完整输出如下，请在此基础上修复并重新输出完整 Course Package：\n"
        f"```\n{previous_text}\n```"
    )


def _call_with_retry(
    adapter: Adapter,
    user_prompt: str,
    system_prompt: str,
    role: str,
    retry_role: str,
    parse: Callable[[str], dict],
    max_parse_attempts: int = 3,
) -> tuple[dict, list[HolisticCall]]:
    """课程级调用 + 解析失败重试（每次携带完整前次输出）。

    模型/网关偶发提前终止输出（截断的 JSON/YAML）时，最多重试
    max_parse_attempts - 1 次，每次提示基于上次输出修复并输出完整文档。
    """
    calls: list[HolisticCall] = []
    prompt = user_prompt
    for attempt in range(max_parse_attempts):
        call = adapter(prompt, system_prompt)
        call = HolisticCall(role=role if attempt == 0 else retry_role,
                            text=call.text, provider=call.provider,
                            model=call.model, request_id=call.request_id)
        calls.append(call)
        try:
            return parse(call.text), calls
        except HolisticCompileError as exc:
            if attempt == max_parse_attempts - 1:
                raise
            prompt = user_prompt + _retry_suffix(role, call.text, exc.message)
    raise AssertionError("unreachable")


@dataclass
class CompileResult:
    package: dict
    calls: list[HolisticCall]
    critic_verdict: str
    repaired: bool


def load_manifest() -> dict:
    path = ROOT / "data" / "content-plans" / "mvp-teaching-archetypes.yaml"
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise HolisticCompileError(f"教学原型 manifest 无法读取: {exc}") from exc
    if not isinstance(doc, dict):
        raise HolisticCompileError("教学原型 manifest 根节点必须是对象")
    return doc


def compile_course(
    sense_id: str,
    neighbor_ids: list[str],
    adapter: Adapter,
    config: Any | None = None,
    related_course: dict | None = None,
    manifest: dict | None = None,
) -> CompileResult:
    """Author(1) → Critic(1) → Repair(≤1)。不写任何文件。

    只有课程级调用（author / critic / repair）；格式/硬校验失败时最多一次
    携带完整输出的修复调用（记入 metadata，不计入课程级调用数）。
    related_course: pair 生成中已存在的第一门完整课程（第二门课程可见）。
    """
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        raise HolisticCompileError(
            f"缺少 Language Contract: data/contracts/{sense_id}.yaml"
        )
    capabilities = load_capabilities()
    neighbors = [load_sense(nid) for nid in neighbor_ids]
    context = build_author_context(
        sense, neighbors, contract, capabilities,
        related_course=related_course, manifest=manifest,
    )
    user_input = format_author_input(context)

    author_prompt = load_prompt("course-author")
    critic_prompt = load_prompt("whole-course-critic")
    repair_prompt = load_prompt("whole-course-repair")

    all_calls: list[HolisticCall] = []

    def validate_author(course: dict) -> ValidationResult:
        return validate_course_package(course, sense=sense, contract=contract,
                                       capabilities=capabilities)

    # Author
    package, calls = _call_with_retry(
        adapter, user_input, author_prompt,
        role="author", retry_role="author_format_retry",
        parse=lambda text: parse_course_package(text, "Course Author"),
    )
    all_calls.extend(calls)
    validation = validate_author(package)
    if not validation.valid:
        # 硬约束失败：一次携带完整输出的作者级修复（不是局部 producer）
        messages = "; ".join(d["message"] for d in validation.diagnostics)
        retry = adapter(
            user_input + _retry_suffix("Course Author", package_text(all_calls), messages),
            author_prompt,
        )
        all_calls.append(HolisticCall(role="author_format_retry", text=retry.text,
                                      provider=retry.provider, model=retry.model,
                                      request_id=retry.request_id))
        package = parse_course_package(retry.text, "Course Author")
        validation = validate_author(package)
        if not validation.valid:
            raise HolisticCompileError(
                "Course Author 输出未通过确定性校验（两次尝试）",
                validation.diagnostics,
            )

    # Critic
    critic_input = (
        user_input
        + "\n\n## 7. 待评审的完整 Course Package\n"
        + _dump_yaml(package)
        + "\n\n请给出整体 verdict 与全局 diagnostics。"
    )
    critic_doc, calls = _call_with_retry(
        adapter, critic_input, critic_prompt,
        role="critic", retry_role="critic_format_retry",
        parse=lambda text: _parse_critic(text),
    )
    all_calls.extend(calls)
    verdict = critic_doc.get("verdict", "fail")
    diagnostics = critic_doc.get("diagnostics") or []

    if verdict == "pass":
        return CompileResult(
            package=package, calls=all_calls,
            critic_verdict="pass", repaired=False,
        )

    # Repair（最多一次）
    repair_input = (
        critic_input
        + "\n\n## 8. Critic 的全部 diagnostics（verdict=fail）\n"
        + _dump_yaml({"verdict": verdict, "diagnostics": diagnostics})
        + "\n\n请返回完整修订后的 Course Package。"
    )
    repaired_package, calls = _call_with_retry(
        adapter, repair_input, repair_prompt,
        role="repair", retry_role="repair_format_retry",
        parse=lambda text: parse_course_package(text, "Whole-course Repair"),
    )
    all_calls.extend(calls)
    repaired_validation = validate_author(repaired_package)
    if not repaired_validation.valid:
        messages = "; ".join(d["message"] for d in repaired_validation.diagnostics)
        retry = adapter(
            repair_input + _retry_suffix("Whole-course Repair", package_text(all_calls), messages),
            repair_prompt,
        )
        all_calls.append(HolisticCall(role="repair_format_retry", text=retry.text,
                                      provider=retry.provider, model=retry.model,
                                      request_id=retry.request_id))
        repaired_package = parse_course_package(retry.text, "Whole-course Repair")
        repaired_validation = validate_author(repaired_package)
        if not repaired_validation.valid:
            raise HolisticCompileError(
                "Whole-course Repair 输出未通过确定性校验（两次尝试）",
                repaired_validation.diagnostics,
            )
    return CompileResult(
        package=repaired_package, calls=all_calls,
        critic_verdict=verdict, repaired=True,
    )


def package_text(calls: list[HolisticCall]) -> str:
    """最近一次课程级输出的完整文本（用于格式修复时携带完整输出）。"""
    for call in reversed(calls):
        if call.role in COURSE_LEVEL_ROLES:
            return call.text
    return ""


def _parse_critic(text: str) -> dict:
    doc = parse_course_package(text, "Whole-course Critic")
    if doc.get("verdict") not in ("pass", "fail"):
        raise HolisticCompileError(
            "Whole-course Critic 输出缺少 verdict（pass|fail）",
            [{"code": "parse", "message": "verdict 缺失或非法"}],
        )
    if not isinstance(doc.get("diagnostics"), list):
        raise HolisticCompileError(
            "Whole-course Critic 输出缺少 diagnostics 数组",
            [{"code": "parse", "message": "diagnostics 缺失"}],
        )
    return doc


# --------------------------------------------------------------------------- #
# 落盘
# --------------------------------------------------------------------------- #

def attach_metadata(package: dict, calls: list[HolisticCall]) -> dict:
    package = copy.deepcopy(package)
    metadata = dict(package.get("metadata") or {})
    metadata.update({
        "holistic_compiler_version": COMPILER_VERSION,
        "generated_at": _utc_now(),
        "calls": [
            {"role": c.role, "provider": c.provider, "model": c.model,
             "request_id": c.request_id}
            for c in calls
        ],
    })
    package["metadata"] = metadata
    return package


def save_course(result: CompileResult, sense_id: str,
                version: str = "v01", input_digest: str | None = None) -> tuple[Path, Path]:
    """写入 data/drafts/holistic-courses/<sense>/<version>/course.yaml 与
    app/assets/content/holistic-course-preview/<sense>.json（确定性 lowering）。
    不覆盖任何 legacy program / contract / assets / fixtures / bundle。"""
    out_dir = DRAFTS_DIR / sense_id / version
    out_dir.mkdir(parents=True, exist_ok=True)
    course_path = out_dir / "course.yaml"
    package = attach_metadata(result.package, result.calls)
    if input_digest:
        package["metadata"]["input_digest"] = input_digest
    course_path.write_text(
        yaml.safe_dump(package, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    preview_assets_dir = PREVIEW_ASSETS_DIR
    preview_assets_dir.mkdir(parents=True, exist_ok=True)
    preview_path = preview_assets_dir / f"{sense_id}.json"
    preview_path.write_text(
        json.dumps(lower_course_package(package), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return course_path, preview_path


# --------------------------------------------------------------------------- #
# compare：只读对比报告（不宣称谁更好，只展示可核查差异）
# --------------------------------------------------------------------------- #

def _legacy_roles(program: dict) -> dict[str, int]:
    counts: dict[str, int] = {}
    for unit in program.get("units", []):
        role = unit.get("role") or "unknown"
        counts[role] = counts.get(role, 0) + 1
    return counts


def _legacy_misconception_map(program: dict) -> dict[str, list[str]]:
    mapping: dict[str, list[str]] = {}
    for unit in program.get("units", []):
        target = unit.get("hypothesis_target")
        if target:
            mapping.setdefault(str(target), []).append(unit.get("id", ""))
    return mapping


def _holistic_misconception_map(course: dict, contract: dict) -> dict[str, list[str]]:
    mapping: dict[str, list[str]] = {}
    ids = [m.get("id") for m in (contract.get("semantic_model") or {}).get("misconceptions") or []]
    for stage, item in _iter_flow_items(course):
        for ref in item.get("addresses") or []:
            if ref in ids:
                mapping.setdefault(str(ref), []).append(item.get("id", ""))
    return mapping


def compare_courses(
    sense_id: str,
    holistic: dict,
    legacy: dict,
) -> dict:
    sense = load_sense(sense_id)
    contract = load_contract(sense_id) or {}
    capabilities = load_capabilities()
    validation = validate_course_package(
        holistic, sense=sense, contract=contract, capabilities=capabilities
    )

    holistic_flow = holistic.get("learning_flow", [])
    holistic_reviews = holistic.get("review_progression", [])
    legacy_units = legacy.get("units", [])
    legacy_reviews = legacy.get("review_pool", [])

    binding_index = None
    for idx, step in enumerate(holistic_flow):
        if step.get("primitive") == "symbol_reveal":
            binding_index = idx
            break

    primitive_dist: dict[str, int] = {}
    for _, item in _iter_flow_items(holistic):
        primitive_dist[item.get("primitive")] = primitive_dist.get(item.get("primitive"), 0) + 1

    boundary_steps = [
        item.get("id") for _, item in _iter_flow_items(holistic)
        if item.get("primitive") == "boundary_choice"
    ]
    transfer_steps = [
        item.get("id") for _, item in _iter_flow_items(holistic)
        if item.get("primitive") == "transfer_judgment"
    ]
    legacy_transfer = [
        unit.get("id") for unit in legacy_units if unit.get("role") == "transfer"
    ]

    holistic_dirty = len(boundary_steps) + len(
        _holistic_misconception_map(holistic, contract).get("misc-1", [])
    )
    legacy_dirty = sum(
        1 for unit in legacy_units if unit.get("hypothesis_target") == "misc-1"
    )

    holistic_calls = [
        c for c in (holistic.get("metadata") or {}).get("calls", [])
        if c.get("role") in COURSE_LEVEL_ROLES
    ]
    legacy_calls = (legacy.get("metadata") or {}).get("request_ids", [])

    return {
        "sense_id": sense_id,
        "holistic_valid": validation.valid,
        "holistic_validation_diagnostics": validation.diagnostics,
        "steps": {
            "holistic_total": len(holistic_flow) + len(holistic_reviews),
            "holistic_flow": len(holistic_flow),
            "holistic_reviews": len(holistic_reviews),
            "legacy_total": len(legacy_units) + len(legacy_reviews),
            "legacy_units": len(legacy_units),
            "legacy_reviews": len(legacy_reviews),
        },
        "task_distribution": {
            "holistic_primitives": primitive_dist,
            "legacy_roles": _legacy_roles(legacy),
            "legacy_review_items": len(legacy_reviews),
        },
        "misconception_coverage": {
            "holistic": _holistic_misconception_map(holistic, contract),
            "legacy": _legacy_misconception_map(legacy),
        },
        "dirty_handled": {
            "holistic_steps": holistic_dirty,
            "legacy_units": legacy_dirty,
            "boundary_steps": boundary_steps,
        },
        "symbol_binding": {
            "holistic_flow_index": binding_index,
            "legacy_position": "units 之后（symbol_binding 区块）",
        },
        "boundary": {
            "holistic_steps": boundary_steps,
            "legacy": "program 内无 boundary（boundary 属独立 package 管线）",
        },
        "transfer": {
            "holistic_steps": transfer_steps,
            "legacy_units": legacy_transfer,
        },
        "review_scaffold": {
            "holistic": [
                {"id": item.get("id"), "timing": item.get("timing"),
                 "scaffold_level": item.get("scaffold_level"),
                 "primitive": item.get("primitive")}
                for item in holistic_reviews
            ],
            "legacy": [item.get("id") for item in legacy_reviews],
        },
        "llm_calls": {
            "holistic_course_level": len(holistic_calls),
            "holistic_all": len((holistic.get("metadata") or {}).get("calls", [])),
            "legacy_request_ids": len(legacy_calls),
        },
    }


def format_compare_report(report: dict) -> str:
    lines: list[str] = []
    lines.append(f"# Holistic vs Legacy 对比报告 — {report['sense_id']}")
    lines.append("")
    lines.append("> 只展示可核查差异，不自动宣称哪边更好。")
    lines.append("")
    lines.append("## 1. 步骤数量")
    s = report["steps"]
    lines.append(f"- Holistic 总计 {s['holistic_total']} 步（learning_flow "
                 f"{s['holistic_flow']} + review_progression {s['holistic_reviews']}）")
    lines.append(f"- Legacy 总计 {s['legacy_total']} 步（units {s['legacy_units']} "
                 f"+ review_pool {s['legacy_reviews']}）")
    lines.append("")
    lines.append("## 2. 任务 / primitive 分布")
    lines.append(f"- Holistic primitives: {report['task_distribution']['holistic_primitives']}")
    lines.append(f"- Legacy roles: {report['task_distribution']['legacy_roles']}")
    lines.append(f"- Legacy review items: {report['task_distribution']['legacy_review_items']}")
    lines.append("")
    lines.append("## 3. misconception 分别在哪些步骤处理")
    mc = report["misconception_coverage"]
    lines.append(f"- Holistic: {mc['holistic'] or '（无 addresses）'}")
    lines.append(f"- Legacy (hypothesis_target): {mc['legacy'] or '（无）'}")
    lines.append("")
    lines.append("## 4. dirty / messy 处理")
    d = report["dirty_handled"]
    lines.append(f"- Holistic 处理 dirty 侧（misc-1 或 boundary_choice）的步骤数：{d['holistic_steps']}"
                 f"（boundary 步骤：{d['boundary_steps'] or '无'}）")
    lines.append(f"- Legacy 以 hypothesis_target=misc-1 处理脏乱混淆的单元数：{d['legacy_units']}")
    lines.append("")
    lines.append("## 5. Symbol Binding 位置")
    b = report["symbol_binding"]
    lines.append(f"- Holistic: learning_flow 第 {b['holistic_flow_index']} 步"
                 f"（0-based；None=缺失）")
    lines.append(f"- Legacy: {b['legacy_position']}")
    lines.append("")
    lines.append("## 6. Boundary")
    bd = report["boundary"]
    lines.append(f"- Holistic boundary_choice 步骤：{bd['holistic_steps'] or '无'}")
    lines.append(f"- Legacy：{bd['legacy']}")
    lines.append("")
    lines.append("## 7. Transfer 策略")
    t = report["transfer"]
    lines.append(f"- Holistic transfer_judgment 步骤：{t['holistic_steps'] or '无'}")
    lines.append(f"- Legacy role=transfer 单元：{t['legacy_units'] or '无'}")
    lines.append("")
    lines.append("## 8. Review 脚手架递进")
    r = report["review_scaffold"]
    lines.append(f"- Holistic review_progression: {r['holistic'] or '无'}")
    lines.append(f"- Legacy review_pool（无 scaffold_level 字段）: {r['legacy'] or '无'}")
    lines.append("")
    lines.append("## 9. LLM 课程设计调用次数")
    c = report["llm_calls"]
    lines.append(f"- Holistic 课程级调用（author/critic/repair）：{c['holistic_course_level']}"
                 f"（全部调用含格式修复：{c['holistic_all']}）")
    lines.append(f"- Legacy request_ids 数量：{c['legacy_request_ids']}")
    if report["holistic_validation_diagnostics"]:
        lines.append("")
        lines.append("## 10. Holistic 课程确定性校验（注意：未通过则本报告仅为结构对比）")
        for dg in report["holistic_validation_diagnostics"]:
            lines.append(f"- [{dg['code']}] {dg['message']}")
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _print_diagnostics(diagnostics: list[dict]) -> None:
    for dg in diagnostics:
        path = f" @ {dg['path']}" if dg.get("path") else ""
        print(f"  [{dg['code']}]{path} {dg['message']}")


def cmd_validate(course_file: Path) -> int:
    try:
        course = yaml.safe_load(course_file.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        print(f"validate: 无法读取课程文件 {course_file}: {exc}")
        return 1
    if not isinstance(course, dict):
        print("validate: 课程文件根节点必须是对象")
        return 1
    sense_id = (course.get("target") or {}).get("sense_id")
    if not sense_id:
        print("validate: 课程缺少 target.sense_id，无法确定目标义项")
        return 1
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        print(f"validate: 缺少 Language Contract data/contracts/{sense_id}.yaml")
        return 1
    capabilities = load_capabilities()
    result = validate_course_package(course, sense=sense, contract=contract,
                                     capabilities=capabilities)
    print(f"validate {course_file} — sense {sense_id}: "
          f"{'通过' if result.valid else '未通过'} "
          f"（{len(result.diagnostics)} 条诊断）")
    _print_diagnostics(result.diagnostics)
    return 0 if result.valid else 1


def cmd_compile(sense_id: str, neighbor_ids: list[str], version: str) -> int:
    print(f"compile {sense_id}" + (f" --neighbor {' '.join(neighbor_ids)}" if neighbor_ids else ""))
    print("LLM 调用预算：Author ×1 → Critic ×1 → Repair ≤1（格式修复不计入）")
    try:
        result = compile_course(
            sense_id, neighbor_ids, _real_adapter(None)
        )
    except HolisticCompileError as exc:
        print(f"compile 失败: {exc.message}")
        _print_diagnostics(exc.diagnostics or [])
        return 1
    course_path, preview_path = save_course(result, sense_id, version=version)
    print(f"Critic verdict: {result.critic_verdict}（repaired={result.repaired}）")
    print(f"课程级调用: {sum(1 for c in result.calls if c.role in COURSE_LEVEL_ROLES)}"
          f"；全部调用: {len(result.calls)}")
    for call in result.calls:
        print(f"  - {call.role}: provider={call.provider} model={call.model} "
              f"request_id={call.request_id}")
    print(f"写入: {course_path}")
    print(f"预览资产（确定性 lowering）: {preview_path}")
    return 0


def cmd_compare(sense_id: str, holistic_file: Path, legacy_file: Path,
                output: Path | None) -> int:
    try:
        holistic = yaml.safe_load(holistic_file.read_text(encoding="utf-8"))
        legacy = yaml.safe_load(legacy_file.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        print(f"compare: 无法读取对比文件: {exc}")
        return 1
    if not isinstance(holistic, dict) or not isinstance(legacy, dict):
        print("compare: 输入文件根节点必须是对象")
        return 1
    try:
        report = compare_courses(sense_id, holistic, legacy)
    except HolisticCompileError as exc:
        print(f"compare 失败: {exc.message}")
        return 1
    text = format_compare_report(report)
    print(text)
    if output is not None:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text + "\n", encoding="utf-8")
        print(f"\n报告已写入: {output}")
    return 0


# --------------------------------------------------------------------------- #
# Batch: compile-batch / validate-batch / capability-report
# --------------------------------------------------------------------------- #

def _input_digest(sense_id: str, neighbor_ids: list[str],
                  related_course: dict | None) -> str:
    """编译输入的确定性摘要：sense + contract + capabilities + prompts +
    manifest + 邻近义项 + pair 第一门课程。digest 未变化时 batch 跳过。"""
    import hashlib
    parts: list[bytes] = []
    for path in (
        ROOT / "data" / "senses" / f"{sense_id}.yaml",
        ROOT / "data" / "contracts" / f"{sense_id}.yaml",
        CAPABILITIES_PATH,
        ROOT / "data" / "content-plans" / "mvp-teaching-archetypes.yaml",
    ):
        parts.append(path.read_bytes())
    for name in ("course-author", "whole-course-critic", "whole-course-repair"):
        parts.append((PROMPTS_DIR / f"{name}.md").read_bytes())
    for nid in neighbor_ids:
        parts.append((ROOT / "data" / "senses" / f"{nid}.yaml").read_bytes())
    if related_course is not None:
        parts.append(yaml.safe_dump(related_course, sort_keys=True).encode("utf-8"))
    return "sha256:" + hashlib.sha256(b"\n".join(parts)).hexdigest()


def _load_course_file(sense_id: str, version: str) -> dict | None:
    path = DRAFTS_DIR / sense_id / version / "course.yaml"
    if not path.exists():
        return None
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return None
    return doc if isinstance(doc, dict) else None


def _batch_courses(manifest: dict) -> list[dict]:
    """按 manifest 顺序展开 (sense_id, neighbor_ids, related_sense_id)。"""
    courses: list[dict] = []
    seen_pairs: set[str] = set()
    curriculum = manifest.get("curriculum") or []
    order = {entry["course"]: entry["day"] for entry in curriculum}
    for archetype in manifest.get("archetypes") or []:
        for cluster in archetype.get("clusters") or []:
            lemmas = [l for l in cluster.get("lemmas") or [] if l.get("sense_id")]
            pair_id = cluster.get("id")
            for lemma in lemmas:
                courses.append({
                    "sense_id": lemma["sense_id"],
                    "neighbor_ids": [l["sense_id"] for l in lemmas
                                     if l["sense_id"] != lemma["sense_id"]],
                    "pair_id": pair_id,
                    "day": order.get(lemma["sense_id"]),
                })
    courses.sort(key=lambda c: (c["day"] or 99, c["sense_id"]))
    return courses


def _compile_with_transport_retry(
    compile_fn: Callable[[], CompileResult],
    label: str,
    retries: int = 3,
    backoff_seconds: int = 20,
) -> CompileResult:
    """传输层错误（连接中断 / HTTP 5xx）重试；HolisticCompileError（校验/
    解析失败）不重试——那需要修全局问题而不是重试。"""
    import time as _time
    last: Exception | None = None
    for attempt in range(retries):
        try:
            return compile_fn()
        except HolisticCompileError:
            raise
        except Exception as exc:  # 网络/传输错误
            last = exc
            if attempt < retries - 1:
                print(f"  ⚠ {label} 传输错误（第 {attempt + 1} 次）: {exc}；"
                      f"{backoff_seconds}s 后重试")
                _time.sleep(backoff_seconds)
                backoff_seconds *= 2
    assert last is not None
    raise last


def cmd_compile_batch(manifest_path: Path, version: str, force: bool,
                      adapter: Adapter | None = None) -> int:
    """真实 LLM 批量编译（Author → Critic → Repair 课程级管线）。

    规则: 单门失败不覆盖其他成功课程；已存在课程默认保留（--force 覆盖）；
    输入 digest 未变化时跳过；不自动发布；不覆盖 legacy ExperienceProgram。
    """
    adapter = adapter or _real_adapter(None)
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    courses = _batch_courses(manifest)
    print(f"compile-batch: {len(courses)} 门课程（版本目录 {version}）")
    print("LLM 调用预算（每门）: Author ×1 → Critic ×1 → Repair ≤1（格式修复不计入）")
    failures: list[str] = []
    for i, entry in enumerate(courses, 1):
        sense_id = entry["sense_id"]
        print(f"\n[{i}/{len(courses)}] {sense_id}（pair={entry['pair_id']}）")
        neighbor_ids = entry["neighbor_ids"]
        related_course = None
        for nid in neighbor_ids:
            candidate = _load_course_file(nid, version)
            if candidate is not None:
                related_course = candidate
                print(f"  相关课程上下文: {nid}（pair 第一门课）")
        digest = _input_digest(sense_id, neighbor_ids, related_course)
        existing = _load_course_file(sense_id, version)
        if existing is not None and not force:
            stored = (existing.get("metadata") or {}).get("input_digest")
            if stored == digest:
                print(f"  跳过: 课程已存在且输入 digest 未变化")
                continue
            print(f"  跳过: 课程已存在（digest 变化；保留现有版本，"
                  f"--force 可覆盖）")
            continue
        if existing is not None and force:
            print(f"  --force: 覆盖现有课程")
        try:
            result = _compile_with_transport_retry(
                lambda: compile_course(
                    sense_id, neighbor_ids, adapter,
                    related_course=related_course, manifest=manifest,
                ),
                label=sense_id,
            )
        except HolisticCompileError as exc:
            print(f"  ✗ 编译失败: {exc.message}")
            _print_diagnostics(exc.diagnostics or [])
            failures.append(sense_id)
            continue
        except Exception as exc:  # 网络/传输错误隔离单门课程
            print(f"  ✗ 传输/未知失败: {exc}")
            failures.append(sense_id)
            continue
        course_path, preview_path = save_course(
            result, sense_id, version=version, input_digest=digest)
        print(f"  ✓ Critic verdict={result.critic_verdict} repaired={result.repaired} "
              f"课程级调用={sum(1 for c in result.calls if c.role in COURSE_LEVEL_ROLES)} "
              f"全部调用={len(result.calls)}")
        print(f"    写入: {course_path}")
    if failures:
        print(f"\n失败 {len(failures)} 门: {', '.join(failures)}")
        print("已成功的课程不受影响；修复全局问题后重跑可续（digest 未变自动跳过）。")
        return 1
    print("\n✓ 全部课程编译完成")
    return 0


def cmd_validate_batch(manifest_path: Path) -> int:
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    courses = _batch_courses(manifest)
    failures: list[str] = []
    total = 0
    for entry in courses:
        sense_id = entry["sense_id"]
        found = False
        for path in sorted((DRAFTS_DIR / sense_id).glob("v*/course.yaml")):
            course = yaml.safe_load(path.read_text(encoding="utf-8"))
            sense = load_sense(sense_id)
            contract = load_contract(sense_id)
            if contract is None:
                print(f"✗ {sense_id}: 缺少 contract（无法校验）")
                failures.append(sense_id)
                break
            capabilities = load_capabilities()
            result = validate_course_package(
                course, sense=sense, contract=contract, capabilities=capabilities)
            total += 1
            if result.valid:
                print(f"✓ {sense_id} ({path.parent.name}) 通过")
            else:
                print(f"✗ {sense_id} ({path.parent.name}) 未通过 "
                      f"（{len(result.diagnostics)} 条诊断）")
                _print_diagnostics(result.diagnostics)
                failures.append(sense_id)
            found = True
        if not found:
            print(f"✗ {sense_id}: 无课程（needs_holistic_course）")
            failures.append(sense_id)
    print(f"\nvalidate-batch: {total} 门课程校验完成")
    if failures:
        print(f"失败/缺失 {len(failures)} 门: {', '.join(failures)}")
        return 1
    return 0


def cmd_capability_report(manifest_path: Path) -> int:
    """capability 缺口报告：suggested vs 已注册；真实课程实际使用情况。"""
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    capabilities = load_capabilities()
    registered = {p["id"] for p in capabilities["primitives"]}
    lines: list[str] = []
    lines.append("Capability Report — Teaching Archetype MVP")
    lines.append(f"capabilities_version={capabilities.get('capabilities_version')} "
                 f"registered={len(registered)}")
    lines.append("")
    for archetype in manifest.get("archetypes") or []:
        suggested = set(archetype.get("suggested_capabilities") or [])
        gaps = sorted(suggested - registered)
        used: set[str] = set()
        for cluster in archetype.get("clusters") or []:
            for lemma in cluster.get("lemmas") or []:
                sense_id = lemma.get("sense_id")
                if not sense_id:
                    continue
                for path in sorted((DRAFTS_DIR / sense_id).glob("v*/course.yaml")):
                    try:
                        course = yaml.safe_load(path.read_text(encoding="utf-8"))
                    except yaml.YAMLError:
                        continue
                    for _stage, item in _iter_flow_items(course):
                        used.add(item.get("primitive"))
        lines.append(f"[{archetype['id']}]")
        lines.append(f"  suggested: {', '.join(sorted(suggested))}")
        lines.append(f"  registered: {', '.join(sorted(suggested & registered)) or '（无）'}")
        if gaps:
            lines.append(f"  GAP（建议但未注册）: {', '.join(gaps)}")
        unused = sorted(suggested - used)
        lines.append(f"  course_used: {', '.join(sorted(suggested & used)) or '（无课程使用）'}")
        if unused:
            lines.append(f"  not_used_by_courses: {', '.join(unused)}")
        lines.append("")
    all_used = set()
    for entry in _batch_courses(manifest):
        for path in sorted((DRAFTS_DIR / entry["sense_id"]).glob("v*/course.yaml")):
            try:
                course = yaml.safe_load(path.read_text(encoding="utf-8"))
            except yaml.YAMLError:
                continue
            for _stage, item in _iter_flow_items(course):
                all_used.add(item.get("primitive"))
    lines.append(f"全部 14 门课实际使用的 primitive: "
                 f"{', '.join(sorted(all_used)) or '（无）'}")
    lines.append(f"注册但未被任何课程使用: "
                 f"{', '.join(sorted(registered - all_used)) or '（无）'}")
    print("\n".join(lines))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Holistic Course Compiler v1 — LLM 整课创作纵向实验"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="离线确定性校验课程文件")
    validate_parser.add_argument("course_file", type=Path)

    compile_parser = subparsers.add_parser("compile", help="Author → Critic → 可选 Repair 生成课程")
    compile_parser.add_argument("sense_id")
    compile_parser.add_argument("--neighbor", action="append", default=[],
                                help="相关邻近义项 sense_id（可重复）")
    compile_parser.add_argument("--version", default="v01", help="草稿版本目录（默认 v01）")

    compare_parser = subparsers.add_parser("compare", help="Holistic vs Legacy 只读对比报告")
    compare_parser.add_argument("sense_id")
    compare_parser.add_argument("--holistic", required=True, type=Path)
    compare_parser.add_argument("--legacy", required=True, type=Path)
    compare_parser.add_argument("--output", type=Path, default=None,
                                help="把报告写入 markdown 文件")

    batch_parser = subparsers.add_parser(
        "compile-batch", help="按 manifest 顺序批量真实生成课程（可恢复，单门失败隔离）")
    batch_parser.add_argument("--manifest", required=True, type=Path)
    batch_parser.add_argument("--version", default="v01", help="版本目录（默认 v01）")
    batch_parser.add_argument("--force", action="store_true",
                              help="覆盖已存在课程（默认保留现有版本）")

    validate_batch_parser = subparsers.add_parser(
        "validate-batch", help="离线校验 manifest 全部课程的确定性硬约束")
    validate_batch_parser.add_argument("--manifest", required=True, type=Path)

    capability_parser = subparsers.add_parser(
        "capability-report", help="capability 缺口与真实课程使用情况报告")
    capability_parser.add_argument("--manifest", required=True, type=Path)

    args = parser.parse_args(argv)
    if args.command == "validate":
        return cmd_validate(args.course_file)
    if args.command == "compile":
        return cmd_compile(args.sense_id, args.neighbor, args.version)
    if args.command == "compare":
        return cmd_compare(args.sense_id, args.holistic, args.legacy, args.output)
    if args.command == "compile-batch":
        return cmd_compile_batch(args.manifest, args.version, args.force)
    if args.command == "validate-batch":
        return cmd_validate_batch(args.manifest)
    if args.command == "capability-report":
        return cmd_capability_report(args.manifest)
    parser.error(f"未知命令 {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
