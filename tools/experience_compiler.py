#!/usr/bin/env python3
"""Experience Compiler v1 — WordSense → ExperienceProgram 的四阶段编译器。

对外 interface 很小:

- ``compile_experience_program(sense_id, *, adapter=...)``: 输入 sense_id 与可注入
  的生成 adapter, 返回已经通过 Schema、确定性校验与 Semantic Quality Gate 的
  ExperienceProgram dict;
- ``validate_program(program)`` / ``validate_program_file(path)``: 完全离线的
  确定性校验 (JSON Schema + 契约规则), 返回聚合 diagnostics;
- ``run_regression()``: 完全离线的四词 fixture 回归。

内部四阶段 (Semantic Planner → Experience Program Planner → Surface Experience
Generator → Semantic Critic) 不对外暴露为公共接口; 失败时抛出聚合领域错误
:class:`CompileError`, 携带带 stage 与数据路径的 diagnostics。

模型调用统一通过 ``tools/llm.py``; 测试必须注入纯内存 fake adapter, 本模块在
测试路径下不触网。生成的原始结果只允许写入 ``data/drafts/experience-programs/``。
"""

from __future__ import annotations

import argparse
import datetime
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

import yaml
from jsonschema import Draft202012Validator, FormatChecker

import llm as llm_adapter

COMPILER_VERSION = "1.0.0"
CONTRACT_VERSION = "1.0"

ROOT = Path(__file__).resolve().parent.parent
SENSES_DIR = ROOT / "data" / "senses"
PROMPTS_DIR = ROOT / "prompts" / "experience-compiler"
SCHEMA_PATH = ROOT / "schema" / "experience-program.schema.json"
DRAFTS_DIR = ROOT / "data" / "drafts" / "experience-programs"
FIXTURES_DIR = ROOT / "tests" / "fixtures" / "experience-programs"

STAGES = ("semantic_planner", "program_planner", "surface_generator", "quality_gate")
PROMPT_FILES = {
    "semantic_planner": "semantic-planner.md",
    "program_planner": "program-planner.md",
    "surface_generator": "surface-generator.md",
    "quality_gate": "quality-gate.md",
}
DETERMINISTIC_STAGE = "deterministic"

# Semantic Quality Gate 的固定审核维度 (阻塞项)。
QUALITY_DIMENSIONS = (
    "semantic_correctness",
    "sense_purity",
    "prototype_quality",
    "definition_leakage",
    "l2_leakage",
    "variable_isolation",
    "accidental_invariant",
    "transfer_novelty",
    "cognitive_noise",
)


# --------------------------------------------------------------------------- #
# 领域错误与 diagnostics
# --------------------------------------------------------------------------- #

@dataclass(frozen=True)
class Diagnostic:
    """一条确定性校验问题: 编译器阶段 + 数据路径 + 可执行的问题描述。"""

    stage: str
    path: str
    message: str

    def render(self) -> str:
        return f"[{self.stage}] {self.path}: {self.message}"


class CompileError(RuntimeError):
    """编译失败的聚合领域错误; ``diagnostics`` 携带全部失败细节。"""

    def __init__(self, message: str, diagnostics: list[Diagnostic]):
        super().__init__(message)
        self.diagnostics = list(diagnostics)

    def render(self) -> str:
        lines = [str(self)]
        for diagnostic in self.diagnostics:
            lines.append(f"  ✗ {diagnostic.render()}")
        return "\n".join(lines)


@dataclass(frozen=True)
class LLMCall:
    """一次阶段调用的结果: 文本 + 可选的模型身份与非敏感 request id。"""

    text: str
    provider: str | None = None
    model: str | None = None
    request_id: str | None = None


Adapter = Callable[[str], LLMCall]


# --------------------------------------------------------------------------- #
# 默认 adapter: 统一走 tools/llm.py
# --------------------------------------------------------------------------- #

def _real_adapter(config: llm_adapter.LLMConfig | None) -> Adapter:
    def adapter(prompt: str) -> LLMCall:
        result = llm_adapter.invoke(prompt, config=config)
        return LLMCall(
            text=result.text,
            provider=result.protocol,
            model=result.model,
            request_id=result.request_id,
        )

    return adapter


# --------------------------------------------------------------------------- #
# 加载与解析
# --------------------------------------------------------------------------- #

def load_sense(sense_id: str) -> dict:
    path = SENSES_DIR / f"{sense_id}.yaml"
    if not path.exists():
        raise CompileError(
            f"WordSense '{sense_id}' 不存在: {path}",
            [Diagnostic("input", str(path), "输入权威 WordSense 文件缺失")],
        )
    try:
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise CompileError(
            f"WordSense '{sense_id}' 无法读取", [Diagnostic("input", str(path), str(exc))]
        ) from exc
    if not isinstance(document, dict):
        raise CompileError(
            f"WordSense '{sense_id}' 根节点必须是对象",
            [Diagnostic("input", str(path), "YAML 根节点不是对象")],
        )
    missing = [key for key in ("id", "word", "pos") if key not in document]
    if missing:
        raise CompileError(
            f"WordSense '{sense_id}' 缺少权威字段",
            [Diagnostic("input", str(path), f"缺少字段: {', '.join(missing)}")],
        )
    return document


def _prompt_version(prompt_text: str, fallback: str) -> str:
    for line in prompt_text.splitlines()[:12]:
        match = re.match(r"^prompt_version:\s*(\S+)\s*$", line)
        if match:
            return match.group(1)
    return fallback


def _load_prompt(stage: str) -> str:
    path = PROMPTS_DIR / PROMPT_FILES[stage]
    return path.read_text(encoding="utf-8")


def _parse_json(text: str, stage: str, path: str) -> dict:
    """从模型输出中提取 JSON 对象; 支持 ```json fenced block 与裸 JSON。"""
    stripped = text.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", stripped, re.S)
    if fence:
        stripped = fence.group(1).strip()
    try:
        document = json.loads(stripped)
    except json.JSONDecodeError as exc:
        raise CompileError(
            f"{stage} 输出不是合法 JSON",
            [Diagnostic(stage, path, f"JSON 解析失败: {exc}; 输出前 200 字符: "
                                       f"{stripped[:200]!r}")],
        ) from exc
    if not isinstance(document, dict):
        raise CompileError(
            f"{stage} 输出必须是 JSON 对象",
            [Diagnostic(stage, path, "解析结果不是对象")],
        )
    return document


def _require_keys(document: dict, keys: list[str], stage: str, path: str) -> None:
    missing = [key for key in keys if key not in document]
    if missing:
        raise CompileError(
            f"{stage} 输出缺少必需字段",
            [Diagnostic(stage, path, f"缺少字段: {', '.join(missing)}")],
        )


def _require_unit_list(document: dict, key: str, stage: str) -> list[dict]:
    """把嵌套结构错误 (非数组/缺 id/重复 id) 转为带 stage 与路径的 CompileError。"""
    items = document.get(key)
    if not isinstance(items, list):
        raise CompileError(
            f"{stage} 输出结构错误",
            [Diagnostic(stage, key, f"{key} 必须是数组, 实际 {type(items).__name__}")],
        )
    ids: list[str] = []
    for index, item in enumerate(items):
        if not isinstance(item, dict) or not isinstance(item.get("id"), str) or not item["id"]:
            raise CompileError(
                f"{stage} 输出结构错误",
                [Diagnostic(stage, f"{key}[{index}].id", "每个项必须有非空字符串 id")],
            )
        ids.append(item["id"])
    duplicates = {identifier for identifier in ids if ids.count(identifier) > 1}
    if duplicates:
        raise CompileError(
            f"{stage} 输出结构错误",
            [Diagnostic(stage, f"{key}[*].id", f"id 重复: {', '.join(sorted(duplicates))}")],
        )
    return items


def _repair_instruction(detail: str) -> str:
    return (
        "\n\n# 修复要求\n\n"
        f"你上一条输出未通过机器解析，编译器已丢弃它。原因：{detail}\n"
        "请重新输出完整、符合要求的 JSON 对象；除 JSON 之外不要输出任何文字。"
    )


def _call_stage(
    stage: str,
    prompt: str,
    adapter: Adapter,
    path: str,
    parse: Callable[[str], dict],
    retries: dict[str, int],
) -> tuple[dict, LLMCall]:
    """阶段调用: 最多一次重试。

    首次调用为空响应、传输失败、JSON 解析失败或缺少阶段必需结构时, 在追加
    明确 repair instruction 后再次调用; 第二次仍失败则抛带正确 stage/path 的
    CompileError。确定性语义失败与 critic 的 fail 判定不在此重试范围。
    """
    try:
        call = adapter(prompt)
    except llm_adapter.LLMResponseError as exc:
        retries[stage] = retries.get(stage, 0) + 1
        repair_prompt = prompt + _repair_instruction(f"前一次调用传输失败: {str(exc)[:200]}")
        try:
            call = adapter(repair_prompt)
        except llm_adapter.LLMResponseError as retry_exc:
            raise CompileError(
                f"{stage} 阶段两次调用均失败",
                [Diagnostic(stage, path, f"传输失败: {str(retry_exc)[:200]}")],
            ) from retry_exc
        return parse(call.text), call
    try:
        document = parse(call.text)
    except CompileError as first_error:
        retries[stage] = retries.get(stage, 0) + 1
        repair_prompt = prompt + _repair_instruction(first_error.diagnostics[0].message)
        try:
            call = adapter(repair_prompt)
        except llm_adapter.LLMResponseError as retry_exc:
            raise CompileError(
                f"{stage} 阶段重试调用失败",
                [Diagnostic(stage, path, f"传输失败: {str(retry_exc)[:200]}")],
            ) from retry_exc
        document = parse(call.text)
        return document, call
    return document, call


# --------------------------------------------------------------------------- #
# 四阶段
# --------------------------------------------------------------------------- #

def _parse_semantic_model(text: str) -> dict:
    document = _parse_json(text, "semantic_planner", "semantic_model")
    _require_keys(
        document,
        ["invariant", "necessary_conditions", "non_entailments",
         "typical_correlates", "misconceptions", "l1_interference"],
        "semantic_planner", "semantic_model",
    )
    return document


def _stage_semantic_planner(
    sense: dict, adapter: Adapter, retries: dict[str, int]
) -> tuple[dict, LLMCall]:
    prompt = _load_prompt("semantic_planner")
    prompt_text = (
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}"
    )
    return _call_stage(
        "semantic_planner", prompt_text, adapter, "semantic_model",
        _parse_semantic_model, retries,
    )


def _parse_plan(text: str) -> dict:
    document = _parse_json(text, "program_planner", "plan")
    _require_keys(
        document, ["units", "grounding", "review_pool", "symbol_binding_plan"],
        "program_planner", "plan",
    )
    _require_unit_list(document, "units", "program_planner")
    _require_unit_list(document, "review_pool", "program_planner")
    return document


def _stage_program_planner(
    sense: dict, semantic_model: dict, adapter: Adapter, retries: dict[str, int]
) -> dict:
    prompt = _load_prompt("program_planner")
    prompt_text = (
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Model (Semantic Planner 产物)\n\n"
        f"{json.dumps(semantic_model, ensure_ascii=False, indent=2)}"
    )
    document, _call = _call_stage(
        "program_planner", prompt_text, adapter, "plan", _parse_plan, retries,
    )
    return document


def _parse_surface(text: str) -> dict:
    document = _parse_json(text, "surface_generator", "surface")
    _require_keys(
        document, ["units", "symbol_binding", "grounding", "review_pool"],
        "surface_generator", "surface",
    )
    units = _require_unit_list(document, "units", "surface_generator")
    for index, unit in enumerate(units):
        for field in ("experience", "interaction"):
            if field not in unit or not isinstance(unit[field], dict):
                raise CompileError(
                    "surface_generator 输出缺少单元字段",
                    [Diagnostic("surface_generator", f"units[{index}].{field}",
                                f"单元 {unit['id']!r} 缺少对象类型的 {field}")])
    _require_unit_list(document, "review_pool", "surface_generator")
    return document


def _stage_surface_generator(
    sense: dict, semantic_model: dict, plan: dict, adapter: Adapter,
    retries: dict[str, int],
) -> dict:
    prompt = _load_prompt("surface_generator")
    prompt_text = (
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Model\n\n"
        f"{json.dumps(semantic_model, ensure_ascii=False, indent=2)}\n\n"
        f"# Program Plan (Experience Program Planner 产物)\n\n"
        f"{json.dumps(plan, ensure_ascii=False, indent=2)}"
    )
    document, _call = _call_stage(
        "surface_generator", prompt_text, adapter, "surface",
        _parse_surface, retries,
    )
    return document


def _parse_quality_gate(text: str) -> dict:
    """解析 critic 输出并强制九维全集、唯一性与 verdict 枚举。"""
    document = _parse_json(text, "quality_gate", "metadata.quality_gate")
    dimensions = document.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        raise CompileError(
            "quality_gate 输出缺少维度结论",
            [Diagnostic("quality_gate", "metadata.quality_gate.dimensions",
                        "dimensions 必须是非空数组")],
        )
    names = [item.get("name") if isinstance(item, dict) else None for item in dimensions]
    if len(names) != len(QUALITY_DIMENSIONS) or set(names) != set(QUALITY_DIMENSIONS):
        missing = sorted(set(QUALITY_DIMENSIONS) - set(names))
        duplicates = sorted({name for name in names if names.count(name) > 1})
        unknown = sorted({name for name in names if name not in QUALITY_DIMENSIONS})
        raise CompileError(
            "quality_gate 维度集合不合法",
            [Diagnostic(
                "quality_gate", "metadata.quality_gate.dimensions",
                f"必须恰好包含九个维度各一次: 缺失={missing} 重复={duplicates} "
                f"未知={unknown}")],
        )
    for item in dimensions:
        if item.get("verdict") not in ("pass", "fail", "warn"):
            raise CompileError(
                "quality_gate verdict 非法",
                [Diagnostic("quality_gate", "metadata.quality_gate.dimensions",
                            f"维度 {item.get('name')!r} 的 verdict 必须是 "
                            f"pass/fail/warn, 实际 {item.get('verdict')!r}")])
        if not isinstance(item.get("note"), str) or not item["note"]:
            raise CompileError(
                "quality_gate 缺少依据",
                [Diagnostic("quality_gate", "metadata.quality_gate.dimensions",
                            f"维度 {item.get('name')!r} 必须给出 note 依据")])
    passed = all(item.get("verdict") != "fail" for item in dimensions)
    result: dict = {"passed": passed, "dimensions": dimensions}
    if isinstance(document.get("scores"), dict) and document["scores"]:
        result["scores"] = document["scores"]
    return result


def _stage_quality_gate(
    program: dict, sense: dict, adapter: Adapter, retries: dict[str, int]
) -> dict:
    prompt = _load_prompt("quality_gate")
    review_doc = {key: value for key, value in program.items() if key != "metadata"}
    prompt_text = (
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# ExperienceProgram (待审, 不含 metadata)\n\n"
        f"{json.dumps(review_doc, ensure_ascii=False, indent=2)}"
    )
    document, _call = _call_stage(
        "quality_gate", prompt_text, adapter, "metadata.quality_gate",
        _parse_quality_gate, retries,
    )
    return document


def _recording_adapter(inner: Adapter, request_ids: list[str]) -> Adapter:
    """包装 adapter: 收集非敏感 request id (不收集任何认证信息)。"""

    def adapter(prompt: str) -> LLMCall:
        call = inner(prompt)
        if call.request_id:
            request_ids.append(call.request_id)
        return call

    return adapter


# --------------------------------------------------------------------------- #
# 确定性校验
# --------------------------------------------------------------------------- #

def _load_schema() -> Draft202012Validator:
    with open(SCHEMA_PATH, encoding="utf-8") as file:
        return Draft202012Validator(
            json.load(file), format_checker=FormatChecker()
        )


def _find(path: str, document: dict) -> Any:
    value: Any = document
    for part in re.split(r"\.|\[(\d+)\]", path):
        if part == "" or part is None:
            continue
        if part.isdigit():
            index = int(part)
            if not isinstance(value, list) or index >= len(value):
                return None
            value = value[index]
        else:
            if not isinstance(value, dict) or part not in value:
                return None
            value = value[part]
    return value


_NEIGHBOR_STOPWORDS = frozenset({
    "a", "an", "the", "to", "of", "at", "on", "in", "for", "from", "with",
    "not", "no", "and", "or", "but", "so", "as", "by", "into", "out", "up",
    "down", "over", "under", "after", "before", "if", "then", "when",
    # 介词性功能词: 在 learner-visible 文本中普遍存在, 其介词用法与目标词义
    # 无关 (例如 almost 的 confusable "about" 在 "true about ..." 中不是语义
    # 近邻)。只拦截实词性相邻词。
    "about", "around", "between", "through", "throughout", "without",
    "within", "upon", "across", "behind", "beyond", "beside", "during",
})


def _neighbor_symbols(sense: dict, lemma: str) -> set[str]:
    """从 WordSense relations/排除条件中提取相邻 L2 词 (词头形式)。

    相邻 L2 词在揭示 (symbol_binding) 之前不得出现在 learner-visible 内容中,
    否则学习者会把相邻范畴当成目标范畴。多词短语词头 (如 not_yet-01) 拆成
    单词后过滤功能词, 只保留有检查价值的实词。
    """
    words: set[str] = set()
    relations = sense.get("relations") or {}
    for key in ("synonyms", "antonyms", "confusables", "hypernyms", "hyponyms"):
        for reference in relations.get(key) or []:
            if isinstance(reference, str):
                words.add(reference.split("-")[0])
    for boundary in relations.get("boundaries") or []:
        target = boundary.get("target")
        if isinstance(target, str):
            words.add(target.split("-")[0])
    for excluded in (sense.get("conditions") or {}).get("excluded") or []:
        alternative = excluded.get("alternative")
        if isinstance(alternative, str):
            words.add(alternative.split("-")[0])
    for _language, items in (relations.get("l1_confusables") or {}).items():
        for item in items:
            for reference in item.get("covers") or []:
                if isinstance(reference, str):
                    words.add(reference.split("-")[0])
    words.discard(lemma)
    tokens: set[str] = set()
    for word in words:
        parts = re.split(r"[_]+", word)
        for part in parts:
            if re.fullmatch(r"[a-z]+", part) and part not in _NEIGHBOR_STOPWORDS:
                tokens.add(part)
    return tokens


_LEARNER_VISIBLE_PATHS = (
    "experience.episode",
    "experience.observable_evidence",
    "experience.surface_dimensions.name",
    "experience.surface_dimensions.baseline",
    "experience.surface_dimensions.deviation",
    "interaction.question",
    "interaction.answers.text",
    "interaction.answers.feedback",
)


def _iter_learner_visible(unit: dict):
    for pattern in _LEARNER_VISIBLE_PATHS:
        if pattern == "experience.observable_evidence":
            yield from (item for item in unit.get("experience", {}).get("observable_evidence", []))
        elif pattern.startswith("experience.surface_dimensions"):
            field_name = pattern.rsplit(".", 1)[1]
            for dim in unit.get("experience", {}).get("surface_dimensions", []):
                if isinstance(dim, dict):
                    yield str(dim.get(field_name) or "")
        elif pattern == "interaction.answers.text":
            for answer in unit.get("interaction", {}).get("answers", []):
                if isinstance(answer, dict):
                    yield str(answer.get("text") or "")
        elif pattern == "interaction.answers.feedback":
            for answer in unit.get("interaction", {}).get("answers", []):
                if isinstance(answer, dict):
                    yield str(answer.get("feedback") or "")
        else:
            value = _find(pattern, unit)
            if isinstance(value, str):
                yield value


# 相邻词检查覆盖的明显词形派生后缀 (如 unwilling → unwillingness / unwillingly)。
_DERIVATION_SUFFIXES = (
    "ness", "ly", "ing", "ed", "es", "s", "ied", "ies", "er", "est",
    "ful", "less", "tion",
)


def _l2_symbol_hits(text: str, symbols: set[str]) -> list[str]:
    lowered = text.lower()
    hits: list[str] = []
    for symbol in sorted(symbols):
        pattern = re.compile(
            rf"\b{re.escape(symbol)}(?:{'|'.join(_DERIVATION_SUFFIXES)})?\b"
        )
        if pattern.search(lowered):
            hits.append(symbol)
    return hits


def _check_l2_leakage(
    unit: dict,
    lemma: str,
    neighbors: set[str],
    path: str,
    diagnostics: list[Diagnostic],
) -> None:
    for text in _iter_learner_visible(unit):
        if not text:
            continue
        if re.search(rf"\b{re.escape(lemma)}", text.lower()):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"learner-visible 内容出现目标 L2 词 '{lemma}' (揭示前禁止): {text[:80]!r}",
            ))
        for hit in _l2_symbol_hits(text, neighbors):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"learner-visible 内容出现相邻 L2 词 '{hit}' (揭示前禁止): {text[:80]!r}",
            ))


def _changed_variable_visible(unit: dict, variable: str) -> bool:
    """一个 changed_variable 必须能在表面层或语义层找到对应。

    表面层: 变量 (或下划线分词后的 token) 与某个 surface_dimension 的 name
    相等 / 互为子串 / token 有交集 (过滤功能词)。语义层: 变量名本身就是
    semantic_spec 的键 (变量状态在语义规格中有定义)。
    """
    variable_tokens = set(variable.split("_"))
    variable_tokens.difference_update(_NEIGHBOR_STOPWORDS)
    dims = unit.get("experience", {}).get("surface_dimensions") or []
    dim_tokens: set[str] = set()
    dim_names: list[str] = []
    for dim in dims:
        if not isinstance(dim, dict):
            continue
        name = str(dim.get("name") or "")
        dim_names.append(name)
        tokens = set(name.split("_"))
        tokens.difference_update(_NEIGHBOR_STOPWORDS)
        dim_tokens.update(tokens)
    if variable_tokens & dim_tokens:
        return True
    if any(variable == name or variable in name or name in variable
           for name in dim_names if name):
        return True
    spec = unit.get("semantic_spec") or {}
    if isinstance(spec, dict) and variable in spec:
        return True
    return False


def _validate_structure(program: dict, sense: dict, diagnostics: list[Diagnostic]) -> None:
    lemma = str(program["target"]["lemma"])
    neighbors = _neighbor_symbols(sense, lemma)

    units = program.get("units")
    if not isinstance(units, list):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "units", "units 必须是数组"))
        return
    unit_ids = [str(unit.get("id")) for unit in units if isinstance(unit, dict)]
    if len(unit_ids) != len(set(unit_ids)):
        duplicates = {uid for uid in unit_ids if unit_ids.count(uid) > 1}
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "units[*].id",
            f"unit id 重复: {', '.join(sorted(duplicates))}"))

    review_items = program.get("review_pool") or []
    review_ids = [str(item.get("id")) for item in review_items if isinstance(item, dict)]
    if len(review_ids) != len(set(review_ids)):
        duplicates = {rid for rid in review_ids if review_ids.count(rid) > 1}
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "review_pool[*].id",
            f"review id 重复: {', '.join(sorted(duplicates))}"))
    overlapping = set(unit_ids) & set(review_ids)
    if overlapping:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "review_pool[*].id",
            f"review id 与 unit id 重叠: {', '.join(sorted(overlapping))}"))

    for index, unit in enumerate(units, start=1):
        if not isinstance(unit, dict):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"units[{index}]", "unit 必须是对象"))
            continue
        path = f"units[{index}] ({unit.get('id')})"
        sequence = unit.get("sequence")
        if sequence != index:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.sequence",
                f"sequence 应为 {index} (与数组顺序一致且连续递增), 实际为 {sequence!r}"))
        role = unit.get("role")
        for variable_field in ("preserved_variables", "changed_variables"):
            variables = unit.get(variable_field)
            if not isinstance(variables, list) or not variables or any(
                not isinstance(item, str) or not item for item in variables
            ):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.{variable_field}",
                    "受控单元必须明确填写非空 preserved_variables / changed_variables"))
        overlap = set(unit.get("preserved_variables") or []) & set(
            unit.get("changed_variables") or [])
        if overlap:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}",
                f"preserved_variables 与 changed_variables 不得重叠: "
                f"{', '.join(sorted(overlap))}"))
        for variable in unit.get("changed_variables") or []:
            if not _changed_variable_visible(unit, variable):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.changed_variables",
                    f"变量 {variable!r} 未能在 surface_dimensions 或 "
                    f"semantic_spec 中找到对应 (每个变化变量必须有表面层落地)"))
        if role == "transfer":
            changed = unit.get("changed_variables")
            if not isinstance(changed, list) or len(changed) < 2:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.changed_variables",
                    f"transfer 必须至少改变两个表面维度, 实际 {len(changed) if isinstance(changed, list) else '非数组'} 个"))
            dimensions = unit.get("experience", {}).get("surface_dimensions")
            if not isinstance(dimensions, list) or len(dimensions) < 2:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.experience.surface_dimensions",
                    "transfer 单元的 surface_dimensions 至少需要两个维度"))
        evidence = unit.get("experience", {}).get("observable_evidence")
        if not isinstance(evidence, list) or not evidence:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.experience.observable_evidence",
                "每个 experience 都必须有 observable_evidence"))
        interaction = unit.get("interaction") or {}
        answers = interaction.get("answers")
        if not isinstance(answers, list) or not answers:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.interaction",
                "interaction 答案必须是非空数组"))
        else:
            correct = [answer for answer in answers
                       if isinstance(answer, dict) and answer.get("is_correct") is True]
            if len(correct) != 1:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.interaction",
                    f"每个 interaction 必须恰好一个正确答案 (is_correct=true), "
                    f"实际 {len(correct)} 个"))
        _check_l2_leakage(unit, lemma, neighbors, path, diagnostics)

    roles = [unit.get("role") for unit in units if isinstance(unit, dict)]
    if "anchor" not in roles:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "units[*].role", "至少存在一个 anchor 单元"))
    if "transfer" not in roles:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "units[*].role",
            "至少存在一个揭示前 concept transfer 单元 (symbol_binding 独立于 concept units 之后)"))

    signatures: set[tuple] = set()
    for unit in units:
        if not isinstance(unit, dict):
            continue
        signature = (
            str(unit.get("role")),
            tuple(unit.get("preserved_variables") or []),
            tuple(unit.get("changed_variables") or []),
            str((unit.get("semantic_spec") or {}).get("judgment")),
        )
        if signature in signatures:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"units[*] ({unit.get('id')})",
                "存在完全同构的单元 (role + 变量 + judgment 全同): 模板凑数嫌疑"))
        signatures.add(signature)

    misconceptions = (program.get("semantic_model") or {}).get("misconceptions") or []
    misconception_ids = {
        str(item.get("id")) for item in misconceptions if isinstance(item, dict)
    }
    covered = {
        str(unit.get("hypothesis_target"))
        for unit in units
        if isinstance(unit, dict) and unit.get("hypothesis_target")
    }
    uncovered = misconception_ids - covered
    if uncovered:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "semantic_model.misconceptions",
            f"以下 misconception 未被任何 hypothesis_target 覆盖: "
            f"{', '.join(sorted(uncovered))}"))
    dangling = covered - misconception_ids
    if dangling:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "units[*].hypothesis_target",
            f"hypothesis_target 指向不存在的 misconception: "
            f"{', '.join(sorted(dangling))}"))

    source_id = (program.get("grounding") or {}).get("source_experience_id")
    if source_id not in unit_ids:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "grounding.source_experience_id",
            f"source_experience_id {source_id!r} 未引用首学中真实存在的 experience"))

    unit_episodes = {
        str(unit.get("experience", {}).get("episode"))
        for unit in units
        if isinstance(unit, dict)
    }
    for index, item in enumerate(review_items, start=1):
        if not isinstance(item, dict):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"review_pool[{index}]", "review item 必须是对象"))
            continue
        episode = item.get("experience", {}).get("episode")
        if episode in unit_episodes:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"review_pool[{index}].experience.episode",
                "review_pool 不能重新播放首学故事 (episode 与首学 unit 相同)"))


def _check_quality_gate(gate: Any, diagnostics: list[Diagnostic],
                        path_prefix: str) -> None:
    """metadata.quality_gate 的一致性检查: 九维全集/唯一/verdict/note/passed。"""
    if not isinstance(gate, dict):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}", "quality_gate 必须是对象"))
        return
    dimensions = gate.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            "quality_gate 必须记录九个维度各一次"))
        return
    names = [item.get("name") if isinstance(item, dict) else None
             for item in dimensions]
    if len(names) != len(QUALITY_DIMENSIONS) or set(names) != set(QUALITY_DIMENSIONS):
        missing = sorted(set(QUALITY_DIMENSIONS) - set(names))
        duplicates = sorted({name for name in names if names.count(name) > 1})
        unknown = sorted({name for name in names if name not in QUALITY_DIMENSIONS})
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            f"必须恰好包含九个维度各一次: 缺失={missing} 重复={duplicates} "
            f"未知={unknown}"))
        return
    has_fail = False
    for item in dimensions:
        if item.get("verdict") not in ("pass", "fail", "warn"):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path_prefix}.dimensions[{item.get('name')}]",
                f"verdict 必须是 pass/fail/warn, 实际 {item.get('verdict')!r}"))
        if not isinstance(item.get("note"), str) or not item["note"]:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path_prefix}.dimensions[{item.get('name')}]",
                "维度必须给出 note 依据"))
        if item.get("verdict") == "fail":
            has_fail = True
    computed = not has_fail
    if gate.get("passed") != computed:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.passed",
            f"passed 与 verdict 不一致: 记录为 {gate.get('passed')!r}, "
            f"但由 verdict 计算应为 {computed}"))
    scores = gate.get("scores")
    if scores is not None:
        if not isinstance(scores, dict):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path_prefix}.scores",
                "scores 必须是 0-10 数值的对象"))
        else:
            for name, score in scores.items():
                if not isinstance(score, (int, float)) or isinstance(score, bool) \
                        or not 0 <= score <= 10:
                    diagnostics.append(Diagnostic(
                        DETERMINISTIC_STAGE, f"{path_prefix}.scores[{name}]",
                        f"分数必须在 0..10, 实际 {score!r}"))


def _validate_metadata(program: dict, diagnostics: list[Diagnostic],
                       skip_quality_gate: bool = False) -> None:
    metadata = program.get("metadata") or {}
    required = (
        "compiler_version", "prompt_versions", "generated_at",
        "source_semantic_revision", "model_provider", "model_name", "quality_gate",
    )
    for field in required:
        if field not in metadata:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"metadata.{field}", "缺少必需元数据字段"))
    if "source_semantic_revision" in metadata and not (
        isinstance(metadata["source_semantic_revision"], int)
        and not isinstance(metadata["source_semantic_revision"], bool)
    ):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "metadata.source_semantic_revision",
            "必须是正整数 (legacy WordSense 按 revision 1 处理)"))
    if not skip_quality_gate:
        _check_quality_gate(metadata.get("quality_gate"), diagnostics,
                            "metadata.quality_gate")


def _validate_binding(program: dict, sense: dict,
                      diagnostics: list[Diagnostic]) -> None:
    """程序 target/metadata 必须绑定真实 WordSense 权威。"""
    if not sense:
        return  # load_sense 已报告缺失
    target = program.get("target") or {}
    sense_id = target.get("sense_id")
    if sense.get("id") != sense_id:
        return  # 根因 (sense 不存在) 已由 load_sense 报告
    if target.get("lemma") != sense.get("word"):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "target.lemma",
            f"与 WordSense {sense_id} 的 word 不一致: "
            f"{target.get('lemma')!r} vs {sense.get('word')!r}"))
    if target.get("pos") != sense.get("pos"):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "target.pos",
            f"与 WordSense {sense_id} 的 pos 不一致: "
            f"{target.get('pos')!r} vs {sense.get('pos')!r}"))
    expected_revision = int(sense.get("semantic_revision") or 1)
    actual = (program.get("metadata") or {}).get("source_semantic_revision")
    if actual != expected_revision:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "metadata.source_semantic_revision",
            f"与 WordSense {sense_id} 的有效 semantic_revision 不一致: "
            f"{actual!r} vs 应为 {expected_revision}"))


def validate_program(program: dict, *,
                     skip_quality_gate: bool = False) -> list[Diagnostic]:
    """对一份 ExperienceProgram 执行确定性校验; 返回全部 diagnostics (空 = 通过)。

    ``skip_quality_gate=True`` 只供编译器内部使用: 在质量门运行之前, quality_gate
    元数据还是占位值, 此时只校验程序本身。
    """
    diagnostics: list[Diagnostic] = []
    if not isinstance(program, dict):
        return [Diagnostic(DETERMINISTIC_STAGE, "(root)", "程序根节点必须是对象")]
    schema = _load_schema()
    for error in schema.iter_errors(program):
        location = "/".join(str(part) for part in error.absolute_path) or "(root)"
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, location, error.message))
    if diagnostics:
        return diagnostics

    sense_id = program.get("target", {}).get("sense_id", "")
    try:
        sense = load_sense(sense_id)
    except CompileError as exc:
        diagnostics.extend(exc.diagnostics)
        sense = {}

    _validate_structure(program, sense, diagnostics)
    _validate_metadata(program, diagnostics, skip_quality_gate=skip_quality_gate)
    _validate_binding(program, sense, diagnostics)
    return diagnostics


def validate_program_file(path: Path) -> list[Diagnostic]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [Diagnostic(DETERMINISTIC_STAGE, str(path), f"文件读取失败: {exc}")]
    try:
        if path.suffix.lower() == ".json":
            program = json.loads(text)
        else:
            program = yaml.safe_load(text)
    except (json.JSONDecodeError, yaml.YAMLError) as exc:
        return [Diagnostic(DETERMINISTIC_STAGE, str(path), f"解析失败: {exc}")]
    return validate_program(program)


# --------------------------------------------------------------------------- #
# 装配
# --------------------------------------------------------------------------- #

def _assemble(
    sense: dict,
    semantic_model: dict,
    plan: dict,
    surface: dict,
    program_version: int,
    model_provider: str | None,
    model_name: str | None,
    request_ids: list[str],
) -> dict:
    planned_units = _require_unit_list(plan, "units", "program_planner")
    surfaced_units_list = _require_unit_list(surface, "units", "surface_generator")
    surfaced_units = {unit["id"]: unit for unit in surfaced_units_list}
    units: list[dict] = []
    for index, planned in enumerate(planned_units, start=1):
        unit_id = planned["id"]
        if unit_id not in surfaced_units:
            raise CompileError(
                "surface_generator 输出缺少单元",
                [Diagnostic("surface_generator", f"units[*].id",
                            f"计划单元 {unit_id!r} 没有对应的 surface 经验")])
        unit = dict(planned)
        unit["sequence"] = index
        unit["experience"] = surfaced_units[unit_id]["experience"]
        unit["interaction"] = surfaced_units[unit_id]["interaction"]
        units.append(unit)

    planned_pool_list = _require_unit_list(plan, "review_pool", "program_planner")
    planned_pool = {item["id"]: item for item in planned_pool_list}
    surfaced_pool_list = _require_unit_list(surface, "review_pool", "surface_generator")
    review_pool: list[dict] = []
    for surfaced in surfaced_pool_list:
        surface_id = surfaced["id"]
        if surface_id not in planned_pool:
            raise CompileError(
                "surface_generator 引用了不存在的复习池计划",
                [Diagnostic("surface_generator", "review_pool[*].id",
                            f"复习项 {surface_id!r} 未在 program_planner 的 review_pool 中")])
        item = dict(planned_pool[surface_id])
        item["experience"] = surfaced["experience"]
        review_pool.append(item)

    prompt_versions = {
        stage: _prompt_version(_load_prompt(stage), f"unversioned-{stage}")
        for stage in STAGES
    }
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    program = {
        "schema_version": CONTRACT_VERSION,
        "program_id": f"{sense['id']}-program",
        "program_version": program_version,
        "status": "draft",
        "target": {
            "sense_id": sense["id"],
            "lemma": sense["word"],
            "pos": sense["pos"],
            "ipa": (sense.get("pronunciation") or {}).get("ipa"),
            "locale_l1": "zh",
        },
        "semantic_model": semantic_model,
        "units": units,
        "symbol_binding": surface["symbol_binding"],
        "grounding": {
            "source_experience_id": (plan.get("grounding") or {}).get("source_experience_id"),
            "l2_realization": (surface.get("grounding") or {}).get("l2_realization"),
            "constructions": (plan.get("grounding") or {}).get("constructions") or [],
            "collocations": (plan.get("grounding") or {}).get("collocations") or [],
        },
        "review_pool": review_pool,
        "metadata": {
            "compiler_version": COMPILER_VERSION,
            "prompt_versions": prompt_versions,
            "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source_semantic_revision": int(sense.get("semantic_revision") or 1),
            "model_provider": model_provider,
            "model_name": model_name,
            "request_ids": request_ids,
            "quality_gate": {"passed": False, "dimensions": []},
        },
    }
    return program


# --------------------------------------------------------------------------- #
# 编译主接口
# --------------------------------------------------------------------------- #

def compile_experience_program(
    sense_id: str,
    *,
    adapter: Adapter | None = None,
    config: llm_adapter.LLMConfig | None = None,
    program_version: int = 1,
) -> dict:
    """把 WordSense 编译为通过全部质量门的 ExperienceProgram dict (status=draft)。

    编译器只能产出 draft; reviewed/published 由未来独立的人工 promotion 流程
    设置。失败时抛出 :class:`CompileError`。adapter 缺省时使用 tools/llm.py
    的真实模型路径。
    """
    sense = load_sense(sense_id)
    resolver = adapter or _real_adapter(config)
    request_ids: list[str] = []
    retries: dict[str, int] = {}
    resolver = _recording_adapter(resolver, request_ids)

    semantic_model, first_call = _stage_semantic_planner(sense, resolver, retries)
    model_provider, model_name = first_call.provider, first_call.model

    plan = _stage_program_planner(sense, semantic_model, resolver, retries)
    surface = _stage_surface_generator(sense, semantic_model, plan, resolver, retries)

    program = _assemble(
        sense, semantic_model, plan, surface, program_version,
        model_provider, model_name, request_ids,
    )

    diagnostics = validate_program(program, skip_quality_gate=True)
    if diagnostics:
        raise CompileError(
            "编译产物未通过确定性校验 (Schema / 引用 / 变量 / 泄漏规则)",
            diagnostics)

    gate = _stage_quality_gate(program, sense, resolver, retries)
    blocked = [
        item for item in gate["dimensions"]
        if isinstance(item, dict) and item.get("verdict") == "fail"
    ]
    program["metadata"]["quality_gate"] = gate
    if blocked:
        diagnostics = [
            Diagnostic("quality_gate", f"metadata.quality_gate.dimensions",
                       f"阻塞维度 {item.get('name')!r}: {item.get('note')}")
            for item in blocked
        ]
        raise CompileError("Semantic Quality Gate 未通过, 程序不可返回", diagnostics)

    final_diagnostics = validate_program(program)
    if final_diagnostics:
        raise CompileError(
            "写入 quality gate 结果后程序不再通过确定性校验", final_diagnostics)
    return program


# --------------------------------------------------------------------------- #
# 离线回归
# --------------------------------------------------------------------------- #

def _structure_signature(program: dict) -> tuple:
    units = program.get("units") or []
    return (
        len(units),
        tuple(str(unit.get("role")) for unit in units),
        tuple(
            tuple(unit.get("changed_variables") or [])
            for unit in units
        ),
    )


@dataclass
class RegressionResult:
    fixtures: list[Path] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not self.errors


def run_regression() -> RegressionResult:
    """完全离线的四词回归: 四个 fixture 全部通过确定性校验且结构互不相同。"""
    result = RegressionResult()
    programs: dict[str, dict] = {}
    for path in sorted(FIXTURES_DIR.glob("*.yaml")):
        diagnostics = validate_program_file(path)
        result.fixtures.append(path)
        if diagnostics:
            result.errors.append(f"{path.name}:")
            result.errors.extend(f"  ✗ {item.render()}" for item in diagnostics)
            continue
        document = yaml.safe_load(path.read_text(encoding="utf-8"))
        programs[document["target"]["sense_id"]] = document

    signatures = {sense_id: _structure_signature(program)
                  for sense_id, program in programs.items()}
    if len(programs) < 4:
        result.errors.append(
            f"回归需要 4 个 fixture, 实际通过校验 {len(programs)} 个")
    unique = {value for value in signatures.values()}
    if len(unique) < len(signatures):
        duplicated = [key for key, value in signatures.items()
                      if list(signatures.values()).count(value) > 1]
        result.errors.append(
            f"程序结构未体现真实差异 (unit 数量/role 组合/变量结构相同): "
            f"{', '.join(duplicated)}")

    reluctant = programs.get("reluctant-01")
    if reluctant:
        outcomes = {
            str(unit.get("semantic_spec", {}).get("eventual_action"))
            for unit in reluctant.get("units") or []
            if unit.get("role") in ("anchor", "variation")
        }
        if "yes" not in outcomes or "no" not in outcomes:
            result.errors.append(
                "reluctant-01: 正例经验必须同时显式变化 eventual_action=yes 与 "
                f"eventual_action=no, 实际 {sorted(outcomes)}")
    return result


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _dump_program(program: dict, path: Path) -> None:
    if path.exists():
        raise CompileError(
            "禁止覆盖已有编译产物",
            [Diagnostic("output", str(path), "目标文件已存在, 不允许覆盖")])
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix.lower() == ".json":
        path.write_text(
            json.dumps(program, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    else:
        path.write_text(
            yaml.safe_dump(program, allow_unicode=True, sort_keys=False),
            encoding="utf-8",
        )


def _next_version(sense_id: str) -> int:
    """自动选择下一个可用 program_version (基于已有 vNN 目录的最大值 + 1)。"""
    base = DRAFTS_DIR / sense_id
    if not base.exists():
        return 1
    versions: list[int] = []
    for entry in base.iterdir():
        match = re.fullmatch(r"v(\d{2})", entry.name)
        if entry.is_dir() and match:
            versions.append(int(match.group(1)))
    return max(versions, default=0) + 1


def _resolve_output(sense_id: str, program_version: int,
                    output: Path | None) -> Path:
    """确定产物路径: 默认 vNN/program.yaml; 显式 --output 必须位于 drafts 内。"""
    if output is not None:
        if not output.is_absolute():
            output = ROOT / output
        resolved = output.resolve()
        drafts_root = DRAFTS_DIR.resolve()
        if drafts_root not in resolved.parents and resolved != drafts_root:
            raise CompileError(
                "输出路径越界",
                [Diagnostic("output", str(output),
                            f"显式输出路径必须位于 {drafts_root} 内")])
        return output
    return DRAFTS_DIR / sense_id / f"v{program_version:02d}" / "program.yaml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="experience_compiler",
        description="Experience Compiler v1: WordSense → ExperienceProgram",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser(
        "validate", help="离线确定性校验一份程序文件 (YAML/JSON)")
    validate_parser.add_argument("program_file", type=Path)

    subparsers.add_parser("regression", help="离线四词 fixture 回归")

    compile_parser = subparsers.add_parser(
        "compile", help="四阶段编译一个 WordSense (需要 LLM 配置)")
    compile_parser.add_argument("sense_id")
    compile_parser.add_argument("--output", type=Path, default=None,
                                help="输出路径; 缺省写入 data/drafts/experience-programs/")
    compile_parser.add_argument("--version", type=int, default=None,
                                help="program_version; 缺省自动递增, 目录 vNN 与版本一致")

    arguments = parser.parse_args(argv)

    if arguments.command == "validate":
        diagnostics = validate_program_file(arguments.program_file)
        if diagnostics:
            print("校验未通过:")
            for diagnostic in diagnostics:
                print(f"  ✗ {diagnostic.render()}")
            return 1
        print(f"✓ {arguments.program_file}: 通过 Schema 与确定性校验")
        return 0

    if arguments.command == "regression":
        result = run_regression()
        for path in result.fixtures:
            print(f"  ✓ {path.name}")
        if not result.errors:
            print("✓ 四词回归全部通过 (Schema + 确定性校验 + 结构差异 + "
                  "reluctant eventual_action 双值)")
            return 0
        for error in result.errors:
            print(f"  ✗ {error}", file=sys.stderr)
        return 1

    if arguments.command == "compile":
        program_version = arguments.version
        if program_version is None:
            program_version = _next_version(arguments.sense_id)
        try:
            output_path = _resolve_output(
                arguments.sense_id, program_version, arguments.output)
        except CompileError as exc:
            print(f"编译失败: {exc.render()}", file=sys.stderr)
            return 1
        if output_path.exists():
            print(f"编译失败: 目标产物已存在, 禁止覆盖: {output_path}",
                  file=sys.stderr)
            return 1
        if not DRAFTS_DIR.exists():
            DRAFTS_DIR.mkdir(parents=True)
        try:
            config = llm_adapter.LLMConfig.from_env()
        except llm_adapter.LLMConfigurationError as exc:
            print(
                f"compile 需要已配置的 LLM (SCENELEX_LLM_PROTOCOL 等): {exc}",
                file=sys.stderr,
            )
            return 2
        try:
            program = compile_experience_program(
                arguments.sense_id,
                config=config,
                program_version=program_version,
            )
        except CompileError as exc:
            print(f"编译失败: {exc.render()}", file=sys.stderr)
            return 1
        try:
            _dump_program(program, output_path)
        except CompileError as exc:
            print(f"编译失败: {exc.render()}", file=sys.stderr)
            return 1
        print(
            f"✓ {program['program_id']} v{program['program_version']} "
            f"(status={program['status']}) → {output_path}"
        )
        return 0

    parser.error(f"未知命令: {arguments.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
