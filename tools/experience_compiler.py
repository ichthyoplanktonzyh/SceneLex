#!/usr/bin/env python3
"""Experience Compiler v2 — WordSense → 可增量资产集合 → ExperienceProgram。

对外 interface 很小:

- ``compile_experience_program(sense_id, *, adapter=..., config=..., program_version=1)``:
  输入 sense_id 与可注入的生成 adapter, 返回已通过 Schema、确定性校验与逐资产
  Semantic Quality Gate 的 ExperienceProgram dict; 签名与行为与 v1 兼容,
  内部改为"一个 semantic contract 上游 + 多个可独立运行/重跑/追加的 producer";
- ``validate_program(program)`` / ``validate_program_file(path)``: 完全离线的
  确定性校验 (JSON Schema + 契约规则 + contract 绑定/stale 检查), 返回聚合
  diagnostics;
- ``run_regression()``: 完全离线的四词 fixture 回归 (含 boundary fixture)。

资产层 (producers, 可独立调用; 落盘在 data/ 下, 编译器只产出 draft):

- contract producer   → ``data/contracts/{sense_id}.yaml``         (一次性, 唯一上游权威, 带 content hash)
- concept producer    → ``data/experience-assets/{id}/concept.yaml``    (一次性: units + symbol_binding)
- review producer     → ``data/experience-assets/{id}/review.yaml``     (可追加 N 次: review items)
- transfer producer   → ``data/experience-assets/{id}/transfer.yaml``   (可追加 N 次: transfer units)
- grounding producer  → ``data/experience-assets/{id}/grounding.yaml``  (一次性: collocations/constructions)
- boundary producer   → ``data/boundaries/{a}__{b}.yaml``               (key 是 sense 对, 不属于任何单个 program)

每个下游资产在 metadata 记录其 contract 的 content hash; hash 不匹配 = stale。
质量门按资产粒度 (维度集合按资产类型裁剪), 不再是单一整体 verdict; 整程序
quality_gate 由逐资产结论确定性聚合而来。

模型调用统一通过 ``tools/llm.py``; 测试必须注入纯内存 fake adapter, 本模块在
测试路径下不触网。编译产物 (program) 只允许写入 ``data/drafts/experience-programs/``。
"""

from __future__ import annotations

import argparse
import copy
import datetime
import functools
import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

import yaml
from jsonschema import Draft202012Validator, FormatChecker

import llm as llm_adapter

COMPILER_VERSION = "2.1.0"
CONTRACT_VERSION = "1.0"


@dataclass(frozen=True)
class PresentationLanguage:
    """Learning Presentation Language Contract v1 的语言配置。

    所有 producer（concept / review / transfer / grounding / boundary）必须收到
    同一份配置；资产据此声明 language_policy，配置不一致的资产视为 stale。
    """

    learner_l1: str = "zh-CN"
    target_l2: str = "en"
    policy_version: int = 1

    def to_metadata(self) -> dict:
        return {
            "policy_version": self.policy_version,
            "learner_l1": self.learner_l1,
            "target_l2": self.target_l2,
        }

    def matches_metadata(self, metadata: Any) -> bool:
        return (
            isinstance(metadata, dict)
            and metadata.get("policy_version") == self.policy_version
            and metadata.get("learner_l1") == self.learner_l1
            and metadata.get("target_l2") == self.target_l2
        )

    def policy_block(self) -> str:
        """注入 producer prompt 的语言政策节（Learning Presentation Language
        Contract v1 的执行规则）。"""
        return (
            f"# Presentation Language Policy (Learning Presentation Language "
            f"Contract v{self.policy_version})\n\n"
            f"学习者母语 learner_l1 = {self.learner_l1}；目标语言 target_l2 = "
            f"{self.target_l2}。\n\n"
            "本程序所有 learner-visible 内容必须遵守分阶段语言政策：\n\n"
            "1. pre_binding（绑定前：concept units 与 concept transfer）："
            "episode / observable_evidence / surface_dimensions / question / "
            "answers / feedback 一律使用 L1（中文）经验叙事描述可观察行为、"
            "动作、变化、空间关系与结果；\n"
            "   禁止出现目标 L2 词及其屈折、派生形式，禁止相邻或易混淆的 L2 词；\n"
            "   禁止用 L1 标签直接命名概念（例如 'messy 就是凌乱的'、'她不情愿'），"
            "L1 只能描述经验，不能给出定义或充当答案。\n"
            "2. symbol_binding：首次显示目标 L2 拼写与发音；presentation 可用 L1 "
            "说明；minimal_l1_gloss 只作确认，不展开定义。\n"
            "3. early_post_binding（复习 review_pool）：场景 / 证据 / 维度使用 L1；"
            "复习是反向回忆，reveal 之前任何字段不得出现目标 L2。\n"
            "4. later_post_binding（grounding）：l2_realization 使用自然 L2 表达"
            "并包含目标词或其被允许的自然词形。\n\n"
            "必要的专有名词、数字、单位与极少量符号允许出现在任何阶段。"
        )


DEFAULT_LANGUAGE = PresentationLanguage()

ROOT = Path(__file__).resolve().parent.parent
SENSES_DIR = ROOT / "data" / "senses"
PROMPTS_DIR = ROOT / "prompts" / "experience-compiler"
SCHEMA_PATH = ROOT / "schema" / "experience-program.schema.json"
BOUNDARY_SCHEMA_PATH = ROOT / "schema" / "boundary-package.schema.json"
DRAFTS_DIR = ROOT / "data" / "drafts" / "experience-programs"
FIXTURES_DIR = ROOT / "tests" / "fixtures" / "experience-programs"
BOUNDARY_FIXTURES_DIR = ROOT / "tests" / "fixtures" / "boundaries"

CONTRACTS_DIR = ROOT / "data" / "contracts"
ASSETS_DIR = ROOT / "data" / "experience-assets"
BOUNDARIES_DIR = ROOT / "data" / "boundaries"

STAGES = ("semantic_planner", "program_planner", "surface_generator", "quality_gate")
PROMPT_FILES = {
    "semantic_planner": "semantic-planner.md",
    "program_planner": "program-planner.md",
    "surface_generator": "surface-generator.md",
    "quality_gate": "quality-gate.md",
    "boundary_producer": "boundary-producer.md",
}
DETERMINISTIC_STAGE = "deterministic"

# Semantic Quality Gate 的固定审核维度 (资产; 逐资产门按类型裁剪这些维度)。
QUALITY_DIMENSIONS = (
    "semantic_correctness",
    "sense_purity",
    "prototype_quality",
    "definition_leakage",
    "l2_leakage",
    "l1_label_leakage",            # L1 等价标签/翻译当答案/定义式旁白 (独立可定位)
    "surface_language_compliance",  # learner-visible 语言是否符合语言合同 (阶段/L1-L2)
    "variable_isolation",
    "accidental_invariant",
    "transfer_novelty",
    "cognitive_noise",
)

# 逐资产质量门维度集合: 按资产类型裁剪, 不是整程序全集。
ASSET_TYPES = ("concept", "review", "transfer", "grounding")
ASSET_GATE_DIMENSIONS: dict[str, tuple[str, ...]] = {
    # 揭示前 assets: 完整语言合同 (l2_leakage + l1_label_leakage + surface 语言)
    "concept": (
        "semantic_correctness", "sense_purity", "prototype_quality",
        "definition_leakage", "l2_leakage", "l1_label_leakage",
        "surface_language_compliance", "variable_isolation",
        "accidental_invariant", "cognitive_noise",
    ),
    # 揭示后的复习场景: 无需查 prototype/变量隔离/transfer 新颖性; 场景 L1,
    # reveal 前禁目标词, 禁 L1 标签
    "review": (
        "semantic_correctness", "sense_purity", "definition_leakage",
        "l2_leakage", "l1_label_leakage", "surface_language_compliance",
        "cognitive_noise",
    ),
    # 揭示前 concept transfer: 与 concept 同源, 但需查 transfer_novelty
    "transfer": (
        "semantic_correctness", "sense_purity", "definition_leakage",
        "l2_leakage", "l1_label_leakage", "surface_language_compliance",
        "variable_isolation", "transfer_novelty", "cognitive_noise",
    ),
    # grounding 是绑定后 L2 落地: 必须包含目标词, 语言是自然 L2
    "grounding": ("semantic_correctness", "surface_language_compliance"),
}

# boundary 资产的独立维度集合 (与 concept program 不是一套)。
BOUNDARY_GATE_DIMENSIONS = (
    "minimal_pair_validity",   # 每个场景都是"两个义项都像、只有一个成立"的最小对立对
    "diagnostic_dimension",    # 是否沿同一诊断维度对比, 而非把 invariant 并排
    "bidirectional_answer",    # 正确答案两个方向都有, 不恒等于某一侧
    "sense_purity",            # 场景是否滑向相邻/包含/更具体的范畴
    "definition_leakage",      # learner-visible 内容是否旁白直陈词义
    "l1_label_leakage",        # 中文标签定义/翻译当答案 (独立可定位)
    "surface_language_compliance",  # 场景/问题/反馈为 L1, 选项只能是已绑定 L2 lemma
    "cognitive_noise",         # 是否夹带与辨析无关的认知负担
)

# 各 producer 调用在注入 scope 后使用的稳定标记头 (测试 fake adapter 据此分派)。
SCOPE_HEADERS: dict[str, str] = {
    "concept_plan": "Producer Scope: concept-plan",
    "concept_surface": "Producer Scope: concept-surface",
    "transfer_plan": "Producer Scope: transfer-plan",
    "transfer_surface": "Producer Scope: transfer-surface",
    "review_plan": "Producer Scope: review-plan",
    "review_surface": "Producer Scope: review-surface",
    "grounding_plan": "Producer Scope: grounding-plan",
    "grounding_surface": "Producer Scope: grounding-surface",
    "gate_concept": "Gate Scope: concept",
    "gate_review": "Gate Scope: review",
    "gate_transfer": "Gate Scope: transfer",
    "gate_grounding": "Gate Scope: grounding",
    "gate_boundary": "Gate Scope: boundary",
}


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


def _scoped(prompt: str, header: str, body: str) -> str:
    """在阶段 prompt 之后追加本次调用范围说明 (覆盖上文全局规则)。"""
    return f"{prompt}\n\n# {header}\n\n{body}"


def _recording_adapter(inner: Adapter, request_ids: list[str]) -> Adapter:
    """包装 adapter: 收集非敏感 request id (不收集任何认证信息)。"""

    def adapter(prompt: str) -> LLMCall:
        call = inner(prompt)
        if call.request_id:
            request_ids.append(call.request_id)
        return call

    return adapter


def _utc_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


# --------------------------------------------------------------------------- #
# semantic contract (contract producer, 唯一上游权威)
# --------------------------------------------------------------------------- #

def contract_content_hash(semantic_model: dict, sense_id: str,
                          semantic_revision: int) -> str:
    """semantic contract 的稳定 content hash (sha256)。

    覆盖 sense 身份绑定 + semantic_model 全文; 任一改动都会改变 hash, 使下游
    资产 (记录 contract_hash) 全部变为 stale。复用项目内 digest 惯例
    (tools/review.py / tools/inventory.py 的 sha256 规范化)。
    """
    payload = json.dumps(
        {
            "sense_id": sense_id,
            "semantic_revision": semantic_revision,
            "semantic_model": semantic_model,
        },
        ensure_ascii=False,
        sort_keys=True,
    )
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _contract_metadata(prompt_versions: dict[str, str], call: LLMCall,
                       request_ids: list[str],
                       language: PresentationLanguage | None = None) -> dict:
    metadata = {
        "compiler_version": COMPILER_VERSION,
        "prompt_versions": prompt_versions,
        "generated_at": _utc_now(),
        "model_provider": call.provider,
        "model_name": call.model,
        "request_ids": request_ids,
    }
    if language is not None:
        metadata["language_policy"] = language.to_metadata()
    return metadata


def compile_semantic_contract(sense_id: str, *,
                              adapter: Adapter | None = None,
                              config: llm_adapter.LLMConfig | None = None) -> dict:
    """contract producer: 把 WordSense 还原为 semantic contract 独立资产。

    一次性生成 (语义修订变化时重新生成, 覆盖旧 contract)。返回 contract dict,
    不落盘; 落盘由 CLI / 调用方通过 :func:`save_contract` 完成。
    """
    sense = load_sense(sense_id)
    resolver = adapter or _real_adapter(config)
    request_ids: list[str] = []
    resolver = _recording_adapter(resolver, request_ids)
    retries: dict[str, int] = {}

    semantic_model, call = _stage_semantic_planner(sense, resolver, retries)
    revision = int(sense.get("semantic_revision") or 1)
    return {
        "schema_version": CONTRACT_VERSION,
        "contract_id": f"{sense_id}-contract",
        "sense_id": sense_id,
        "lemma": sense["word"],
        "pos": sense["pos"],
        "semantic_revision": revision,
        "content_hash": contract_content_hash(semantic_model, sense_id, revision),
        "semantic_model": semantic_model,
        "metadata": _contract_metadata(
            {"semantic_planner": _prompt_version(_load_prompt("semantic_planner"),
                                                 "unversioned-semantic_planner")},
            call, request_ids,
        ),
    }


def contract_path(sense_id: str) -> Path:
    return CONTRACTS_DIR / f"{sense_id}.yaml"


def load_contract(sense_id: str) -> dict | None:
    path = contract_path(sense_id)
    if not path.exists():
        return None
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def save_contract(contract: dict) -> Path:
    """持久化 contract; contract 是上游权威, 语义修订变化时允许覆盖重生成。"""
    path = contract_path(contract["sense_id"])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(contract, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return path


def verify_contract_self_hash(contract: dict) -> bool:
    """contract 记录的内容 hash 是否与自身内容一致 (文件损坏检测)。"""
    return bool(
        contract.get("content_hash")
        == contract_content_hash(
            contract.get("semantic_model") or {},
            str(contract.get("sense_id") or ""),
            int(contract.get("semantic_revision") or 0),
        )
    )


def contract_matches_sense(contract: dict, sense: dict) -> bool:
    """contract 是否仍对应当前 WordSense (semantic_revision 未变)。"""
    return bool(
        contract.get("sense_id") == sense.get("id")
        and contract.get("semantic_revision")
        == int(sense.get("semantic_revision") or 1)
    )


def _load_or_produce_contract(sense: dict, resolver: Adapter,
                              retries: dict[str, int], *,
                              persist: bool) -> dict:
    """加载现有 contract (保持当前); 缺失或过期则重新生成 (可落盘)。"""
    existing = load_contract(sense["id"])
    if existing is not None and isinstance(existing, dict):
        if verify_contract_self_hash(existing) and contract_matches_sense(existing, sense):
            return existing
    contract = compile_semantic_contract(sense["id"], adapter=resolver)
    if persist:
        save_contract(contract)
    return contract


# --------------------------------------------------------------------------- #
# 四阶段调用 (供各 producer 复用)
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


def _parse_plan_roles(roles: set[str]) -> Callable[[str], dict]:
    """program_planner 变体: 额外要求 units 的 role 全部属于给定集合。"""

    def parse(text: str) -> dict:
        document = _parse_plan(text)
        for index, unit in enumerate(document["units"]):
            if unit.get("role") not in roles:
                raise CompileError(
                    "program_planner 输出角色越界",
                    [Diagnostic("program_planner", f"units[{index}].role",
                                f"本 producer 只允许 role ∈ {sorted(roles)}, "
                                f"实际 {unit.get('role')!r}")],
                )
        return document

    return parse


def _parse_plan_with_existing_ids(existing: set[str]) -> Callable[[str], dict]:
    """program_planner 变体: 额外要求 units id 不与已有 id 冲突。"""

    def parse(text: str) -> dict:
        document = _parse_plan(text)
        for index, unit in enumerate(document["units"]):
            if unit.get("id") in existing:
                raise CompileError(
                    "program_planner 输出 id 冲突",
                    [Diagnostic("program_planner", f"units[{index}].id",
                                f"id {unit.get('id')!r} 与已有资产冲突, 必须续编新 id")],
                )
        return document

    return parse


def _parse_plan_review_ids(existing: set[str]) -> Callable[[str], dict]:
    """program_planner 变体: 额外要求 review_pool id 不与已有 id 冲突。"""

    def parse(text: str) -> dict:
        document = _parse_plan(text)
        for index, item in enumerate(document["review_pool"]):
            if item.get("id") in existing:
                raise CompileError(
                    "program_planner 输出 review id 冲突",
                    [Diagnostic("program_planner", f"review_pool[{index}].id",
                                f"id {item.get('id')!r} 与已有复习项冲突, 必须续编新 id")],
                )
        return document

    return parse


def _base_program_planner_prompt(sense: dict, semantic_model: dict,
                                 extra_context: str = "",
                                 language: PresentationLanguage = DEFAULT_LANGUAGE) -> str:
    prompt = _load_prompt("program_planner")
    return (
        f"{language.policy_block()}\n\n"
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Model (Semantic Planner 产物)\n\n"
        f"{json.dumps(semantic_model, ensure_ascii=False, indent=2)}"
        f"{extra_context}"
    )


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


def _base_surface_generator_prompt(sense: dict, semantic_model: dict, plan: dict,
                                   extra_context: str = "",
                                   language: PresentationLanguage = DEFAULT_LANGUAGE) -> str:
    prompt = _load_prompt("surface_generator")
    return (
        f"{language.policy_block()}\n\n"
        f"{prompt}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Model\n\n"
        f"{json.dumps(semantic_model, ensure_ascii=False, indent=2)}\n\n"
        f"# Program Plan (Experience Program Planner 产物)\n\n"
        f"{json.dumps(plan, ensure_ascii=False, indent=2)}"
        f"{extra_context}"
    )


# --------------------------------------------------------------------------- #
# 逐资产质量门 (Semantic Critic; 维度按资产类型裁剪)
# --------------------------------------------------------------------------- #

def _parse_gate(text: str, dims: tuple[str, ...], path_prefix: str) -> dict:
    """解析 critic 输出并强制维度全集、唯一性与 verdict 枚举。"""
    document = _parse_json(text, "quality_gate", path_prefix)
    dimensions = document.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        raise CompileError(
            "quality_gate 输出缺少维度结论",
            [Diagnostic("quality_gate", f"{path_prefix}.dimensions",
                        "dimensions 必须是非空数组")],
        )
    names = [item.get("name") if isinstance(item, dict) else None for item in dimensions]
    if len(names) != len(dims) or set(names) != set(dims):
        missing = sorted(set(dims) - set(names))
        duplicates = sorted({name for name in names if names.count(name) > 1})
        unknown = sorted({name for name in names if name not in dims})
        raise CompileError(
            "quality_gate 维度集合不合法",
            [Diagnostic(
                "quality_gate", f"{path_prefix}.dimensions",
                f"必须恰好包含维度集合各一次: 缺失={missing} 重复={duplicates} "
                f"未知={unknown}")],
        )
    for item in dimensions:
        if item.get("verdict") not in ("pass", "fail", "warn"):
            raise CompileError(
                "quality_gate verdict 非法",
                [Diagnostic("quality_gate", f"{path_prefix}.dimensions",
                            f"维度 {item.get('name')!r} 的 verdict 必须是 "
                            f"pass/fail/warn, 实际 {item.get('verdict')!r}")])
        if not isinstance(item.get("note"), str) or not item["note"]:
            raise CompileError(
                "quality_gate 缺少依据",
                [Diagnostic("quality_gate", f"{path_prefix}.dimensions",
                            f"维度 {item.get('name')!r} 必须给出 note 依据")])
    passed = all(item.get("verdict") != "fail" for item in dimensions)
    result: dict = {"passed": passed, "dimensions": dimensions}
    if isinstance(document.get("scores"), dict) and document["scores"]:
        result["scores"] = document["scores"]
    return result


def _gate_asset(
    asset_type: str,
    review_doc: dict,
    sense: dict,
    adapter: Adapter,
    retries: dict[str, int],
) -> dict:
    """对一份资产执行裁剪后的质量门; fail 时抛出聚合 CompileError。

    复用 quality-gate.md 的九维定义, 通过注入 Gate Scope 覆盖为本次资产
    的维度集合 (不重写 prompt 文案)。
    """
    dims = ASSET_GATE_DIMENSIONS[asset_type]
    prompt = _load_prompt("quality_gate")
    scope = (
        "本次只审核以下资产，维度集合如下（每个恰好一次，不得缺失、重复或引入"
        f"集合外的维度）：\n{', '.join(dims)}\n"
        "verdict 取值为 pass/fail/warn；passed 由系统按 verdict 计算，你不输出它。"
    )
    prompt_text = (
        f"{_scoped(prompt, SCOPE_HEADERS[f'gate_{asset_type}'], scope)}\n\n"
        f"# WordSense (输入权威)\n\n"
        f"{yaml.safe_dump(sense, allow_unicode=True, sort_keys=False)}\n\n"
        f"# ExperienceProgram (待审, 不含 metadata)\n\n"
        f"{json.dumps(review_doc, ensure_ascii=False, indent=2)}"
    )
    parse = functools.partial(_parse_gate, dims=dims,
                              path_prefix=f"metadata.asset_gates.{asset_type}")
    document, _call = _call_stage(
        "quality_gate", prompt_text, adapter,
        f"metadata.asset_gates.{asset_type}", parse, retries,
    )
    blocked = [
        item for item in document["dimensions"]
        if isinstance(item, dict) and item.get("verdict") == "fail"
    ]
    if blocked:
        diagnostics = [
            Diagnostic("quality_gate", f"metadata.asset_gates.{asset_type}.dimensions",
                       f"阻塞维度 {item.get('name')!r}: {item.get('note')}")
            for item in blocked
        ]
        raise CompileError(
            f"Semantic Quality Gate 未通过 ({asset_type} 资产), 该资产不可返回",
            diagnostics)
    return document


# --------------------------------------------------------------------------- #
# concept producer (一次性: units + symbol_binding)
# --------------------------------------------------------------------------- #

def _produce_concept_assets(
    sense: dict, contract: dict, adapter: Adapter, retries: dict[str, int],
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> tuple[list[dict], dict, list[str], LLMCall]:
    """concept producer 纯函数: 规划并表面化 concept units + symbol_binding。"""
    request_ids: list[str] = []
    resolver = _recording_adapter(adapter, request_ids)
    semantic_model = contract["semantic_model"]

    plan_prompt = _base_program_planner_prompt(
        sense, semantic_model,
        extra_context="\n\n" + _scoped(
            _load_prompt("program_planner"), SCOPE_HEADERS["concept_plan"],
            "本阶段调用只规划 concept 单元（role ∈ anchor / variation / "
            "perturbation / discrimination）：\n"
            "- 不得包含 role=transfer 的单元（concept transfer 由独立的 transfer "
            "producer 负责）。\n"
            "- 必须让 Semantic Model 里的每个 misconception 至少被一个单元覆盖。\n"
            "- grounding 输出空对象 {}；review_pool 输出空数组；"
            "symbol_binding_plan 保留 presentation_plan 字段。\n"
            "units 数量与 role 组合由词义决定，不要凑数。",
        ),
    )
    plan, plan_call = _call_stage(
        "program_planner", plan_prompt, resolver, "plan",
        _parse_plan_roles({"anchor", "variation", "perturbation", "discrimination"}),
        retries,
    )

    surface_prompt = _base_surface_generator_prompt(
        sense, semantic_model, plan,
        extra_context="\n\n" + _scoped(
            _load_prompt("surface_generator"), SCOPE_HEADERS["concept_surface"],
            "本阶段调用只实现 units 与 symbol_binding：\n"
            "- units 不得包含 role=transfer 的单元；顺序与 id 必须与 Program Plan "
            "完全一致。\n"
            "- review_pool 输出空数组；grounding 输出空对象。\n"
            "- 揭示前禁令完整适用（units 的一切 learner-visible 内容不得出现目标 "
            "L2 词与相邻 L2 词）。",
        ),
    )
    surface, _ = _call_stage(
        "surface_generator", surface_prompt, resolver, "surface",
        _parse_surface, retries,
    )

    planned_units = _require_unit_list(plan, "units", "program_planner")
    surfaced_units = {unit["id"]: unit for unit in surface["units"]}
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

    return units, surface["symbol_binding"], request_ids, plan_call


def compile_concept_assets(sense_id: str, *,
                           adapter: Adapter | None = None,
                           config: llm_adapter.LLMConfig | None = None,
                           language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """concept producer 对外入口: 需要已有 contract, 产出 concept 资产 dict。"""
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        raise CompileError(
            f"缺少 semantic contract: {contract_path(sense_id)}",
            [Diagnostic("input", str(contract_path(sense_id)), "先运行 contract producer")])
    if not verify_contract_self_hash(contract) or not contract_matches_sense(contract, sense):
        raise CompileError(
            f"semantic contract 已过期: {contract_path(sense_id)}",
            [Diagnostic("input", str(contract_path(sense_id)), "重新生成 contract 后再运行")])
    resolver = adapter or _real_adapter(config)
    retries: dict[str, int] = {}
    units, symbol_binding, request_ids, plan_call = _produce_concept_assets(
        sense, contract, resolver, retries, language)
    review_doc = {
        "asset_type": "concept",
        "semantic_model": contract["semantic_model"],
        "units": units,
        "symbol_binding": symbol_binding,
    }
    gate = _gate_asset("concept", review_doc, sense, resolver, retries)
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "concept",
        "sense_id": sense_id,
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "units": units,
        "symbol_binding": symbol_binding,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }


# --------------------------------------------------------------------------- #
# transfer producer (可追加: transfer units)
# --------------------------------------------------------------------------- #

def _produce_transfer_batch(
    sense: dict, contract: dict, concept_units: list[dict],
    existing_units: list[dict], count: int,
    adapter: Adapter, retries: dict[str, int],
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> tuple[list[dict], list[str], LLMCall]:
    """transfer producer 纯函数: 产 count 个新的 concept transfer 单元。"""
    request_ids: list[str] = []
    resolver = _recording_adapter(adapter, request_ids)
    semantic_model = contract["semantic_model"]

    existing_block = "\n".join(
        f"```yaml\n{yaml.safe_dump(unit, allow_unicode=True, sort_keys=False)}```"
        for unit in existing_units
    ) or "(暂无已有 transfer 单元)"

    scope = (
        f"本阶段调用只规划 {count} 个 role=transfer 的 concept transfer 单元：\n"
        "- 全部单元 role 必须为 transfer；每个 transfer 单元必须至少改变两个表面"
        "维度（changed_variables ≥ 2），且 semantic_spec 必须为每个 "
        "preserved/changed 变量携带同名状态键。\n"
        "- hypothesis_target 一律为 null。\n"
        "- 不得与下面 `# 已有 transfer 单元（必须避开）` 重复：id、经验设定、"
        "变量组合都要新。\n"
        "- transfer 单元发生在 symbol_binding 之前，揭示前禁令语义适用。\n"
        "- grounding 输出空对象 {}；review_pool 输出空数组；symbol_binding_plan "
        "输出空对象。"
    )
    plan_prompt = _base_program_planner_prompt(
        sense, semantic_model,
        extra_context=(
            f"\n\n# 已有 transfer 单元（必须避开）\n\n{existing_block}\n\n"
            + _scoped(_load_prompt("program_planner"), SCOPE_HEADERS["transfer_plan"],
                      scope)
        ),
    )
    existing_ids = {unit["id"] for unit in existing_units}
    plan, plan_call = _call_stage(
        "program_planner", plan_prompt, resolver, "plan",
        _parse_plan_roles({"transfer"}), retries,
    )

    surface_prompt = _base_surface_generator_prompt(
        sense, semantic_model, plan,
        extra_context=(
            f"\n\n# 已有 transfer 单元（必须避开）\n\n{existing_block}\n\n"
            + _scoped(
                _load_prompt("surface_generator"), SCOPE_HEADERS["transfer_surface"],
                "本阶段调用只实现 units（全部 role=transfer）与各自 interaction：\n"
                "- 顺序与 id 必须与 Program Plan 完全一致；不得包含其他角色。\n"
                "- review_pool 输出空数组；symbol_binding 与 grounding 输出空对象。\n"
                "- 揭示前禁令完整适用：episode / observable_evidence / "
                "surface_dimensions / interaction 不得出现目标 L2 词与相邻 L2 词。\n"
                "- surface_dimensions 必须覆盖全部 changed_variables（每个变化变量"
                "都要有表面层落地）。",
            )
        ),
    )
    surface, _ = _call_stage(
        "surface_generator", surface_prompt, resolver, "surface",
        _parse_surface, retries,
    )

    planned = _require_unit_list(plan, "units", "program_planner")
    surfaced = {unit["id"]: unit for unit in surface["units"]}
    units: list[dict] = []
    for index, planned_unit in enumerate(planned, start=1):
        unit_id = planned_unit["id"]
        if unit_id not in surfaced:
            raise CompileError(
                "surface_generator 输出缺少单元",
                [Diagnostic("surface_generator", f"units[*].id",
                            f"计划单元 {unit_id!r} 没有对应的 surface 经验")])
        unit = dict(planned_unit)
        unit["sequence"] = index
        unit["experience"] = surfaced[unit_id]["experience"]
        unit["interaction"] = surfaced[unit_id]["interaction"]
        units.append(unit)
    return units, request_ids, plan_call


def compile_transfer_batch(sense_id: str, count: int, *,
                           adapter: Adapter | None = None,
                           config: llm_adapter.LLMConfig | None = None,
                           language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """transfer producer 对外入口: 需要已有 contract + concept 资产, 产新批次。"""
    if count < 1:
        raise CompileError("transfer 数量必须 >= 1",
                           [Diagnostic("input", "count", "count 必须为正整数")])
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        raise CompileError(
            f"缺少 semantic contract: {contract_path(sense_id)}",
            [Diagnostic("input", str(contract_path(sense_id)), "先运行 contract producer")])
    concept = load_asset(sense_id, "concept")
    if concept is None:
        raise CompileError(
            f"缺少 concept 资产: {asset_path(sense_id, 'concept')}",
            [Diagnostic("input", str(asset_path(sense_id, 'concept')),
                        "先运行 concept producer")])
    _ensure_asset_current(concept, contract, "concept", sense_id, language)
    existing = load_asset(sense_id, "transfer")
    existing_units = (existing or {}).get("units") or []
    resolver = adapter or _real_adapter(config)
    retries: dict[str, int] = {}
    units, request_ids, plan_call = _produce_transfer_batch(
        sense, contract, concept["units"], existing_units, count, resolver,
        retries, language)
    review_doc = {
        "asset_type": "transfer",
        "semantic_model": contract["semantic_model"],
        "units": units,
    }
    gate = _gate_asset("transfer", review_doc, sense, resolver, retries)
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "transfer",
        "sense_id": sense_id,
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "units": units,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }


# --------------------------------------------------------------------------- #
# review producer (可追加: review items)
# --------------------------------------------------------------------------- #

def _produce_review_batch(
    sense: dict, contract: dict, concept_units: list[dict],
    transfer_units: list[dict], existing_items: list[dict], count: int,
    adapter: Adapter, retries: dict[str, int],
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> tuple[list[dict], list[str], LLMCall]:
    """review producer 纯函数: 产 count 个新复习项, 避开已有 items 与首学经验。"""
    request_ids: list[str] = []
    resolver = _recording_adapter(adapter, request_ids)
    semantic_model = contract["semantic_model"]
    first_learn = concept_units + transfer_units

    def block(items: list[dict]) -> str:
        if not items:
            return "(暂无)"
        return "\n".join(
            f"```yaml\n{yaml.safe_dump(item, allow_unicode=True, sort_keys=False)}```"
            for item in items
        )

    plan_scope = (
        f"本阶段调用只规划 review_pool 的 {count} 个新复习条目：\n"
        "- units 输出空数组；grounding 输出空对象；symbol_binding_plan 输出空对象。\n"
        "- 复习发生在揭示之后，判断任务直接问'这是否是目标词义的经验'。\n"
        "- 必须避开下面 `# 已有复习项（必须避开）`：judgment、场景设定、表面维度"
        "不得重复。\n"
        "- 复习经验必须是首学未出现的新场景：不得与 `# 已有首学经验（必须避开）`"
        "中的任何 episode / 场景重复。\n"
        f"- 复习条目 id 用 review-{{n}}，从 1 起连续编号，不得与已有 id 冲突。"
    )
    plan_prompt = _base_program_planner_prompt(
        sense, semantic_model,
        extra_context=(
            f"\n\n# 已有复习项（必须避开）\n\n{block(existing_items)}\n\n"
            f"# 已有首学经验（必须避开）\n\n{block(first_learn)}\n\n"
            + _scoped(_load_prompt("program_planner"), SCOPE_HEADERS["review_plan"],
                      plan_scope)
        ),
    )
    existing_ids = {item["id"] for item in existing_items}
    plan, plan_call = _call_stage(
        "program_planner", plan_prompt, resolver, "plan",
        _parse_plan_review_ids(existing_ids), retries,
    )

    surface_scope = (
        f"本阶段调用只实现 review_pool 的 {count} 个新条目（experience 部分）：\n"
        "- units 输出空数组；symbol_binding 与 grounding 输出空对象。\n"
        "- 每个条目必须有 episode / observable_evidence / surface_dimensions。\n"
        "- 必须避开下面 `# 已有复习经验（必须避开）` 与 `# 已有首学经验（必须"
        "避开）`：人物、情境、事件全新，不得与已有任何 episode 重复。\n"
        "- 复习是揭示后的材料，可以出现目标词，但仍是纯经验叙事，不得旁白直陈词义。"
    )
    surface_prompt = _base_surface_generator_prompt(
        sense, semantic_model, plan,
        extra_context=(
            f"\n\n# 已有复习经验（必须避开）\n\n{block(existing_items)}\n\n"
            f"# 已有首学经验（必须避开）\n\n{block(first_learn)}\n\n"
            + _scoped(_load_prompt("surface_generator"),
                      SCOPE_HEADERS["review_surface"], surface_scope)
        ),
    )
    surface, _ = _call_stage(
        "surface_generator", surface_prompt, resolver, "surface",
        _parse_surface, retries,
    )

    planned_pool = {item["id"]: item for item in plan["review_pool"]}
    items: list[dict] = []
    for surfaced in surface["review_pool"]:
        surface_id = surfaced["id"]
        if surface_id not in planned_pool:
            raise CompileError(
                "surface_generator 引用了不存在的复习池计划",
                [Diagnostic("surface_generator", "review_pool[*].id",
                            f"复习项 {surface_id!r} 未在 program_planner 的 review_pool 中")])
        item = dict(planned_pool[surface_id])
        item["experience"] = surfaced["experience"]
        items.append(item)
    return items, request_ids, plan_call


def compile_review_batch(sense_id: str, count: int, *,
                         adapter: Adapter | None = None,
                         config: llm_adapter.LLMConfig | None = None,
                         language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """review producer 对外入口: 需要已有 contract + concept 资产, 产新批次。"""
    if count < 1:
        raise CompileError("review 数量必须 >= 1",
                           [Diagnostic("input", "count", "count 必须为正整数")])
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        raise CompileError(
            f"缺少 semantic contract: {contract_path(sense_id)}",
            [Diagnostic("input", str(contract_path(sense_id)), "先运行 contract producer")])
    concept = load_asset(sense_id, "concept")
    if concept is None:
        raise CompileError(
            f"缺少 concept 资产: {asset_path(sense_id, 'concept')}",
            [Diagnostic("input", str(asset_path(sense_id, 'concept')),
                        "先运行 concept producer")])
    _ensure_asset_current(concept, contract, "concept", sense_id, language)
    transfer = load_asset(sense_id, "transfer")
    if transfer is not None:
        _ensure_asset_current(transfer, contract, "transfer", sense_id, language)
    review = load_asset(sense_id, "review")
    if review is not None:
        _ensure_asset_current(review, contract, "review", sense_id, language)
    existing_items = (review or {}).get("items") or []
    resolver = adapter or _real_adapter(config)
    retries: dict[str, int] = {}
    items, request_ids, plan_call = _produce_review_batch(
        sense, contract, concept["units"], (transfer or {}).get("units") or [],
        existing_items, count, resolver, retries, language)
    review_doc = {
        "asset_type": "review",
        "semantic_model": contract["semantic_model"],
        "items": items,
    }
    gate = _gate_asset("review", review_doc, sense, resolver, retries)
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "review",
        "sense_id": sense_id,
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "items": items,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }


# --------------------------------------------------------------------------- #
# grounding producer (一次性: collocations / constructions)
# --------------------------------------------------------------------------- #

def _produce_grounding(
    sense: dict, contract: dict, concept_units: list[dict],
    adapter: Adapter, retries: dict[str, int],
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> tuple[dict, list[str], LLMCall]:
    """grounding producer 纯函数: source_experience_id + constructions/collocations
    + l2_realization。"""
    request_ids: list[str] = []
    resolver = _recording_adapter(adapter, request_ids)
    semantic_model = contract["semantic_model"]

    units_block = "\n".join(
        f"```yaml\n{yaml.safe_dump(unit, allow_unicode=True, sort_keys=False)}```"
        for unit in concept_units
    )
    plan_prompt = _base_program_planner_prompt(
        sense, semantic_model,
        extra_context=(
            f"\n\n# 已有 concept units（首学单元）\n\n{units_block}\n\n"
            + _scoped(
                _load_prompt("program_planner"), SCOPE_HEADERS["grounding_plan"],
                "本阶段调用只规划 grounding：\n"
                "- source_experience_id 必须引用 `# 已有 concept units（首学单元）`"
                "中真实存在的 unit id。\n"
                "- constructions 与 collocations 各至少一条。\n"
                "- units 输出空数组；review_pool 输出空数组；symbol_binding_plan "
                "输出空对象。",
            )
        ),
    )
    plan, plan_call = _call_stage(
        "program_planner", plan_prompt, resolver, "plan", _parse_plan, retries,
    )

    surface_prompt = _base_surface_generator_prompt(
        sense, semantic_model, plan,
        extra_context="\n\n" + _scoped(
            _load_prompt("surface_generator"), SCOPE_HEADERS["grounding_surface"],
            "本阶段调用只实现 grounding.l2_realization：\n"
            "- 在 source experience 场景中用自然 L2 语言说出目标词的例句"
            "（发生在揭示之后，可包含目标词）。\n"
            "- units 输出空数组；symbol_binding 与 review_pool 输出空对象。",
        ),
    )
    surface, _ = _call_stage(
        "surface_generator", surface_prompt, resolver, "surface",
        _parse_surface, retries,
    )

    planned = plan.get("grounding") or {}
    l2_realization = (surface.get("grounding") or {}).get("l2_realization")
    if not isinstance(l2_realization, str) or not l2_realization:
        raise CompileError(
            "surface_generator 输出缺少 l2_realization",
            [Diagnostic("surface_generator", "grounding.l2_realization",
                        "grounding 资产的 l2_realization 必须是非空字符串")])
    grounding = {
        "source_experience_id": planned.get("source_experience_id"),
        "l2_realization": l2_realization,
        "constructions": planned.get("constructions") or [],
        "collocations": planned.get("collocations") or [],
    }
    return grounding, request_ids, plan_call


def compile_grounding(sense_id: str, *,
                      adapter: Adapter | None = None,
                      config: llm_adapter.LLMConfig | None = None,
                      language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """grounding producer 对外入口: 需要已有 contract + concept 资产。"""
    sense = load_sense(sense_id)
    contract = load_contract(sense_id)
    if contract is None:
        raise CompileError(
            f"缺少 semantic contract: {contract_path(sense_id)}",
            [Diagnostic("input", str(contract_path(sense_id)), "先运行 contract producer")])
    concept = load_asset(sense_id, "concept")
    if concept is None:
        raise CompileError(
            f"缺少 concept 资产: {asset_path(sense_id, 'concept')}",
            [Diagnostic("input", str(asset_path(sense_id, 'concept')),
                        "先运行 concept producer")])
    _ensure_asset_current(concept, contract, "concept", sense_id, language)
    resolver = adapter or _real_adapter(config)
    retries: dict[str, int] = {}
    grounding, request_ids, plan_call = _produce_grounding(
        sense, contract, concept["units"], resolver, retries, language)
    review_doc = {
        "asset_type": "grounding",
        "semantic_model": contract["semantic_model"],
        "grounding": grounding,
    }
    gate = _gate_asset("grounding", review_doc, sense, resolver, retries)
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "grounding",
        "sense_id": sense_id,
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "grounding": grounding,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }


# --------------------------------------------------------------------------- #
# boundary producer (一等资产: key 是 sense 对)
# --------------------------------------------------------------------------- #

def _parse_boundary(text: str) -> dict:
    document = _parse_json(text, "boundary_producer", "boundary")
    _require_keys(
        document,
        ["diagnostic_dimension", "minimal_pairs"],
        "boundary_producer", "boundary",
    )
    for index, pair in enumerate(document["minimal_pairs"]):
        if not isinstance(pair, dict) or not isinstance(pair.get("id"), str) \
                or not pair["id"]:
            raise CompileError(
                "boundary_producer 输出结构错误",
                [Diagnostic("boundary_producer", f"minimal_pairs[{index}].id",
                            "每个最小对立对必须有非空字符串 id")])
    return document


def compile_boundary_package(sense_a: str, sense_b: str, *,
                             adapter: Adapter | None = None,
                             config: llm_adapter.LLMConfig | None = None,
                             language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """boundary producer: 两个 semantic contract → 义项辨析资产。

    key 是 sense 对 (字典序排列, 保证唯一): ``data/boundaries/{a}__{b}.yaml``。
    """
    if sense_a > sense_b:
        sense_a, sense_b = sense_b, sense_a
    if sense_a == sense_b:
        raise CompileError("boundary 需要两个不同义项",
                           [Diagnostic("input", "boundary", "sense_a 与 sense_b 不能相同")])
    sense_a_doc = load_sense(sense_a)
    sense_b_doc = load_sense(sense_b)
    contract_a = load_contract(sense_a)
    contract_b = load_contract(sense_b)
    if contract_a is None or contract_b is None:
        raise CompileError(
            f"缺少 semantic contract: {contract_path(sense_a)} / {contract_path(sense_b)}",
            [Diagnostic("input", "contracts", "boundary 需要两个 sense 都有 contract")])
    for contract, sense in ((contract_a, sense_a_doc), (contract_b, sense_b_doc)):
        if not verify_contract_self_hash(contract) or not contract_matches_sense(contract, sense):
            raise CompileError(
                f"semantic contract 已过期: {contract_path(sense['id'])}",
                [Diagnostic("input", str(contract_path(sense["id"])),
                            "重新生成 contract 后再运行")])

    resolver = adapter or _real_adapter(config)
    request_ids: list[str] = []
    resolver = _recording_adapter(resolver, request_ids)
    retries: dict[str, int] = {}

    prompt = _load_prompt("boundary_producer")
    prompt_text = (
        f"{prompt}\n\n"
        f"# WordSense A (输入权威)\n\n"
        f"{yaml.safe_dump(sense_a_doc, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Contract A\n\n"
        f"{json.dumps(contract_a['semantic_model'], ensure_ascii=False, indent=2)}\n\n"
        f"# WordSense B (输入权威)\n\n"
        f"{yaml.safe_dump(sense_b_doc, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Semantic Contract B\n\n"
        f"{json.dumps(contract_b['semantic_model'], ensure_ascii=False, indent=2)}"
    )
    document, call = _call_stage(
        "boundary_producer", prompt_text, resolver, "boundary",
        _parse_boundary, retries,
    )

    package = {
        "schema_version": CONTRACT_VERSION,
        "boundary_id": f"{sense_a}__{sense_b}",
        "sense_a": sense_a,
        "sense_b": sense_b,
        "status": "draft",
        "diagnostic_dimension": document["diagnostic_dimension"],
        "minimal_pairs": document["minimal_pairs"],
        "gate": {"passed": False, "dimensions": []},
        "metadata": {
            "compiler_version": COMPILER_VERSION,
            "prompt_versions": {
                "boundary_producer": _prompt_version(_load_prompt("boundary_producer"),
                                                     "unversioned-boundary_producer"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            "generated_at": _utc_now(),
            "contract_a_hash": contract_a["content_hash"],
            "contract_b_hash": contract_b["content_hash"],
            "model_provider": call.provider,
            "model_name": call.model,
            "request_ids": request_ids,
        },
    }

    package["gate"] = _gate_boundary(package, sense_a_doc, sense_b_doc, resolver, retries)
    return package


def _gate_boundary(package: dict, sense_a: dict, sense_b: dict,
                   adapter: Adapter, retries: dict[str, int]) -> dict:
    """boundary 资产的独立质量门 (六个专属维度)。"""
    dims = BOUNDARY_GATE_DIMENSIONS
    prompt = _load_prompt("quality_gate")
    scope = (
        "本次只审核 boundary 资产，维度集合如下（每个恰好一次，不得缺失、重复或"
        f"引入集合外的维度）：\n{', '.join(dims)}\n"
        "verdict 取值为 pass/fail/warn；passed 由系统按 verdict 计算，你不输出它。"
    )
    review_doc = {key: value for key, value in package.items() if key != "metadata"}
    prompt_text = (
        f"{_scoped(prompt, SCOPE_HEADERS['gate_boundary'], scope)}\n\n"
        f"# WordSense A (输入权威)\n\n"
        f"{yaml.safe_dump(sense_a, allow_unicode=True, sort_keys=False)}\n\n"
        f"# WordSense B (输入权威)\n\n"
        f"{yaml.safe_dump(sense_b, allow_unicode=True, sort_keys=False)}\n\n"
        f"# Boundary Package (待审, 不含 metadata)\n\n"
        f"{json.dumps(review_doc, ensure_ascii=False, indent=2)}"
    )
    parse = functools.partial(_parse_gate, dims=dims, path_prefix="gate")
    document, _call = _call_stage(
        "quality_gate", prompt_text, adapter, "gate", parse, retries,
    )
    blocked = [
        item for item in document["dimensions"]
        if isinstance(item, dict) and item.get("verdict") == "fail"
    ]
    if blocked:
        diagnostics = [
            Diagnostic("quality_gate", f"gate.dimensions",
                       f"阻塞维度 {item.get('name')!r}: {item.get('note')}")
            for item in blocked
        ]
        raise CompileError("Semantic Quality Gate 未通过 (boundary 资产), "
                           "该资产不可返回", diagnostics)
    return document


def boundary_path(sense_a: str, sense_b: str) -> Path:
    if sense_a > sense_b:
        sense_a, sense_b = sense_b, sense_a
    return BOUNDARIES_DIR / f"{sense_a}__{sense_b}.yaml"


def load_boundary_package(sense_a: str, sense_b: str) -> dict | None:
    path = boundary_path(sense_a, sense_b)
    if not path.exists():
        return None
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def save_boundary_package(package: dict) -> Path:
    path = boundary_path(package["sense_a"], package["sense_b"])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(package, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return path


# --------------------------------------------------------------------------- #
# 资产持久化 (data/experience-assets/{sense_id}/)
# --------------------------------------------------------------------------- #

def asset_path(sense_id: str, asset_type: str) -> Path:
    return ASSETS_DIR / sense_id / f"{asset_type}.yaml"


def load_asset(sense_id: str, asset_type: str) -> dict | None:
    path = asset_path(sense_id, asset_type)
    if not path.exists():
        return None
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def save_asset(sense_id: str, asset_type: str, asset: dict) -> Path:
    path = asset_path(sense_id, asset_type)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(asset, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return path


def _ensure_asset_current(asset: dict, contract: dict, asset_type: str,
                          sense_id: str,
                          language: PresentationLanguage = DEFAULT_LANGUAGE) -> None:
    """契约 hash 或语言政策不匹配 = stale; 资产必须重新生成, 不允许在 stale
    上追加。legacy 资产没有 language_policy 声明, 一律视为语言未受约束的 v0,
    不允许直接进入合同 v1 装配。"""
    if asset.get("contract_hash") != contract["content_hash"]:
        raise CompileError(
            f"{asset_type} 资产已 stale (contract hash 不匹配)",
            [Diagnostic(DETERMINISTIC_STAGE,
                        str(asset_path(sense_id, asset_type)),
                        "语义契约已变更, 该资产需针对新 contract 重新生成")])
    recorded = (asset.get("metadata") or {}).get("language_policy")
    if not language.matches_metadata(recorded):
        raise CompileError(
            f"{asset_type} 资产语言政策不匹配 (legacy v0 或配置变更)",
            [Diagnostic(DETERMINISTIC_STAGE,
                        str(asset_path(sense_id, asset_type)),
                        f"资产声明 {recorded!r}, 当前合同要求 "
                        f"{language.to_metadata()!r}; 该资产需按合同 v1 语言"
                        "政策重新生成")])


def append_review_items(sense_id: str, batch: dict) -> Path:
    """把 review producer 的新批次追加进已有 review 资产 (可追加 N 次)。"""
    existing = load_asset(sense_id, "review")
    if existing is None:
        raise CompileError(
            f"缺少 review 资产: {asset_path(sense_id, 'review')}",
            [Diagnostic("input", str(asset_path(sense_id, "review")),
                        "先运行 review producer 生成首条")])
    items = list((existing.get("items") or [])) + list(batch["items"])
    batches = list(existing.get("batches") or []) + [{
        "count": len(batch["items"]),
        "generated_at": batch["metadata"]["generated_at"],
        "gate": batch["gate"],
    }]
    existing["items"] = items
    existing["batches"] = batches
    existing["metadata"] = batch["metadata"]
    return save_asset(sense_id, "review", existing)


def append_transfer_items(sense_id: str, batch: dict) -> Path:
    """把 transfer producer 的新批次追加进已有 transfer 资产 (可追加 N 次)。"""
    existing = load_asset(sense_id, "transfer")
    if existing is None:
        raise CompileError(
            f"缺少 transfer 资产: {asset_path(sense_id, 'transfer')}",
            [Diagnostic("input", str(asset_path(sense_id, "transfer")),
                        "先运行 transfer producer 生成首条")])
    units = list((existing.get("units") or [])) + list(batch["units"])
    batches = list(existing.get("batches") or []) + [{
        "count": len(batch["units"]),
        "generated_at": batch["metadata"]["generated_at"],
        "gate": batch["gate"],
    }]
    existing["units"] = units
    existing["batches"] = batches
    existing["metadata"] = batch["metadata"]
    return save_asset(sense_id, "transfer", existing)


def _new_review_asset(sense_id: str, contract_hash: str, batch: dict) -> dict:
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "review",
        "sense_id": sense_id,
        "contract_hash": contract_hash,
        "items": list(batch["items"]),
        "batches": [{
            "count": len(batch["items"]),
            "generated_at": batch["metadata"]["generated_at"],
            "gate": batch["gate"],
        }],
        "metadata": batch["metadata"],
    }


def _new_transfer_asset(sense_id: str, contract_hash: str, batch: dict) -> dict:
    return {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "transfer",
        "sense_id": sense_id,
        "contract_hash": contract_hash,
        "units": list(batch["units"]),
        "batches": [{
            "count": len(batch["units"]),
            "generated_at": batch["metadata"]["generated_at"],
            "gate": batch["gate"],
        }],
        "metadata": batch["metadata"],
    }


# --------------------------------------------------------------------------- #
# 加载或生成 (facade 与 CLI 共用)
# --------------------------------------------------------------------------- #

def _load_or_produce_concept(sense, contract, resolver, retries, *, persist,
                                language=DEFAULT_LANGUAGE):
    existing = load_asset(sense["id"], "concept")
    if existing is not None:
        _ensure_asset_current(existing, contract, "concept", sense["id"], language)
        return existing
    units, symbol_binding, request_ids, plan_call = _produce_concept_assets(
        sense, contract, resolver, retries, language)
    review_doc = {
        "asset_type": "concept",
        "semantic_model": contract["semantic_model"],
        "units": units,
        "symbol_binding": symbol_binding,
    }
    gate = _gate_asset("concept", review_doc, sense, resolver, retries)
    asset = {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "concept",
        "sense_id": sense["id"],
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "units": units,
        "symbol_binding": symbol_binding,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }
    if persist:
        save_asset(sense["id"], "concept", asset)
    return asset


def _load_or_produce_transfer(sense, contract, concept, resolver, retries, *,
                              persist, language=DEFAULT_LANGUAGE):
    existing = load_asset(sense["id"], "transfer")
    if existing is not None:
        _ensure_asset_current(existing, contract, "transfer", sense["id"], language)
        return existing
    units, request_ids, plan_call = _produce_transfer_batch(
        sense, contract, concept["units"], [], TRANSFER_ITEM_TARGET,
        resolver, retries, language)
    review_doc = {
        "asset_type": "transfer",
        "semantic_model": contract["semantic_model"],
        "units": units,
    }
    gate = _gate_asset("transfer", review_doc, sense, resolver, retries)
    batch = {
        "units": units,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }
    asset = _new_transfer_asset(sense["id"], contract["content_hash"], batch)
    if persist:
        save_asset(sense["id"], "transfer", asset)
    return asset


def _load_or_produce_review(sense, contract, concept, transfer, resolver,
                            retries, *, persist, language=DEFAULT_LANGUAGE):
    existing = load_asset(sense["id"], "review")
    if existing is not None:
        _ensure_asset_current(existing, contract, "review", sense["id"], language)
        return existing
    items, request_ids, plan_call = _produce_review_batch(
        sense, contract, concept["units"], (transfer or {}).get("units") or [],
        [], REVIEW_POOL_TARGET, resolver, retries, language)
    review_doc = {
        "asset_type": "review",
        "semantic_model": contract["semantic_model"],
        "items": items,
    }
    gate = _gate_asset("review", review_doc, sense, resolver, retries)
    batch = {
        "items": items,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }
    asset = _new_review_asset(sense["id"], contract["content_hash"], batch)
    if persist:
        save_asset(sense["id"], "review", asset)
    return asset


def _load_or_produce_grounding(sense, contract, concept, resolver, retries, *,
                               persist, language=DEFAULT_LANGUAGE):
    existing = load_asset(sense["id"], "grounding")
    if existing is not None:
        _ensure_asset_current(existing, contract, "grounding", sense["id"], language)
        return existing
    grounding, request_ids, plan_call = _produce_grounding(
        sense, contract, concept["units"], resolver, retries, language)
    review_doc = {
        "asset_type": "grounding",
        "semantic_model": contract["semantic_model"],
        "grounding": grounding,
    }
    gate = _gate_asset("grounding", review_doc, sense, resolver, retries)
    asset = {
        "schema_version": CONTRACT_VERSION,
        "asset_type": "grounding",
        "sense_id": sense["id"],
        "contract_hash": contract["content_hash"],
        "language_policy": language.to_metadata(),
        "grounding": grounding,
        "gate": gate,
        "metadata": _contract_metadata(
            {
                "program_planner": _prompt_version(_load_prompt("program_planner"),
                                                   "unversioned-program_planner"),
                "surface_generator": _prompt_version(_load_prompt("surface_generator"),
                                                     "unversioned-surface_generator"),
                "quality_gate": _prompt_version(_load_prompt("quality_gate"),
                                                "unversioned-quality_gate"),
            },
            plan_call, request_ids, language,
        ),
    }
    if persist:
        save_asset(sense["id"], "grounding", asset)
    return asset


# --------------------------------------------------------------------------- #
# 确定性校验
# --------------------------------------------------------------------------- #

def _load_schema() -> Draft202012Validator:
    with open(SCHEMA_PATH, encoding="utf-8") as file:
        return Draft202012Validator(
            json.load(file), format_checker=FormatChecker()
        )


def _load_boundary_schema() -> Draft202012Validator:
    with open(BOUNDARY_SCHEMA_PATH, encoding="utf-8") as file:
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
        candidates = {symbol}
        if symbol.endswith("y") and len(symbol) > 1:
            stem = symbol[:-1]
            candidates.update({stem + "i", stem + "ier", stem + "iest"})
        pattern = re.compile(
            r"\b(?:"
            + "|".join(re.escape(candidate) for candidate in sorted(candidates))
            + r")(?:"
            + "|".join(_DERIVATION_SUFFIXES)
            + r")?\b"
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
        for hit in _l2_symbol_hits(text, {lemma}):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"learner-visible 内容出现目标 L2 词 '{hit}' (揭示前禁止): {text[:80]!r}",
            ))
        for hit in _l2_symbol_hits(text, neighbors):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"learner-visible 内容出现相邻 L2 词 '{hit}' (揭示前禁止): {text[:80]!r}",
            ))


_REVIEW_VISIBLE_PATHS = (
    "experience.episode",
    "experience.observable_evidence",
    "experience.surface_dimensions.name",
    "experience.surface_dimensions.baseline",
    "experience.surface_dimensions.deviation",
)


def _iter_review_visible(item: dict):
    """复习项 (early_post_binding) 的 learner-visible 文本迭代器。

    复习是反向回忆：reveal 之前 (即场景本身) 不得出现目标 L2，与 concept units
    同样的 L2 泄漏检查适用；L1 标签与成段英语检查同样适用。
    """
    for pattern in _REVIEW_VISIBLE_PATHS:
        if pattern == "experience.observable_evidence":
            yield from (
                item for item in item.get("experience", {}).get("observable_evidence", [])
            )
        elif pattern.startswith("experience.surface_dimensions"):
            field_name = pattern.rsplit(".", 1)[1]
            for dim in item.get("experience", {}).get("surface_dimensions", []):
                if isinstance(dim, dict):
                    yield str(dim.get(field_name) or "")
        else:
            value = _find(pattern, item)
            if isinstance(value, str):
                yield value


def _check_review_l2_leakage(
    item: dict,
    lemma: str,
    neighbors: set[str],
    path: str,
    diagnostics: list[Diagnostic],
) -> None:
    """复习项 L2 leakage (early_post_binding: reveal 前禁止目标与相邻 L2)。"""
    for text in _iter_review_visible(item):
        if not text:
            continue
        for hit in _l2_symbol_hits(text, {lemma}):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"复习场景出现目标 L2 词 '{hit}' (reveal 前禁止): {text[:80]!r}",
            ))
        for hit in _l2_symbol_hits(text, neighbors):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, path,
                f"复习场景出现相邻 L2 词 '{hit}' (reveal 前禁止): {text[:80]!r}",
            ))


# --------------------------------------------------------------------------- #
# Learning Presentation Language Contract v1: 确定性语言门
# --------------------------------------------------------------------------- #

_LATIN_TOKEN = re.compile(r"[A-Za-z][A-Za-z'-]{2,}")
_NUMBER_TOKEN = re.compile(r"^\d+(\.\d+)?([.,]?\d+)*([a-zA-Z%°℃]{0,4})$")
_ENGLISH_FUNCTION_WORDS = frozenset({
    "the", "a", "an", "and", "or", "but", "for", "of", "to", "in", "on",
    "at", "by", "with", "is", "are", "was", "were", "be", "been", "being",
    "this", "that", "it", "its", "he", "she", "they", "them", "his", "her",
    "from", "into", "as", "do", "does", "did", "not", "no", "so", "then",
    "than", "when", "which", "who", "will", "would", "can", "could",
    "should", "there", "where", "what", "about", "after", "before",
    "between", "over", "under", "through", "during", "because", "if",
    "has", "have", "had", "one", "two", "three", "just", "very", "more",
    "most", "some", "any", "all", "each", "other", "such", "only", "also",
    "up", "down", "out", "off", "back", "away", "again", "along", "across",
    "still", "even", "though", "while",
})


def _english_token_count(text: str) -> int:
    """拉丁字母实词 token 数 (过滤数字/单位与功能词)。用于成段英语检测。"""
    tokens = _LATIN_TOKEN.findall(text)
    meaningful = [
        token for token in tokens
        if not _NUMBER_TOKEN.fullmatch(token)
        and token.lower() not in _ENGLISH_FUNCTION_WORDS
        and not re.search(r"\d", token)
    ]
    return len(meaningful)


def _looks_like_english_passage(text: str) -> bool:
    """确定性表面语言检查: 明显违规的成段英语。

    - 无 CJK 且实词 token >= 3 → 成段英语。
    - 有 CJK 但实词 token >= 3 → 中文夹带英文段落 (超过必要专名/单位量)。
    专有名词、数字、单位与极少量符号允许；本检查只拦明显违规，语言合规的
    最终判断由 LLM asset gate (surface_language_compliance) 负责。
    """
    meaningful = _english_token_count(text)
    if meaningful == 0:
        return False
    has_cjk = any("\u4e00" <= ch <= "\u9fff" for ch in text)
    return meaningful >= (3 if has_cjk else 3)


def _l1_label_terms(sense: dict, program: dict | None = None) -> set[str]:
    """已知 L1 等价标签词 (Learning Presentation Language Contract 的 label
    词): WordSense relations.l1_confusables.zh[*].l1_term 为权威来源;
    semantic_model.l1_interference 中引号包裹的中文词作补充。"""
    terms: set[str] = set()
    relations = sense.get("relations") or {}
    for items in (relations.get("l1_confusables") or {}).values():
        if not isinstance(items, list):
            continue
        for item in items:
            term = item.get("l1_term")
            if isinstance(term, str) and term.strip():
                terms.add(term.strip())
    if program:
        semantic = program.get("semantic_model") or {}
        for interference in semantic.get("l1_interference") or []:
            if not isinstance(interference, str):
                continue
            for quoted in re.findall(r"[\u201c\u201d\"']([\u4e00-\u9fff]{1,6})[\u201c\u201d\"']",
                                     interference):
                terms.add(quoted)
    return {term for term in terms if term}


def _is_l1_label_definition(text: str) -> bool:
    """直陈式 L1 标签定义句式 (如 'X 就是 Y' / 'X 等于 Y' / 'X 的意思是 Y')。"""
    return bool(re.search(r"就是|等于|叫[做作]|指的是|意思是|表示", text))


def _check_surface_language(
    units: list[dict],
    review_items: list[dict],
    diagnostics: list[Diagnostic],
) -> None:
    """Surface language compliance (确定性部分): pre-binding 与 early-post-binding
    的 learner-visible 文本不得是成段英语。"""
    for index, unit in enumerate(units, start=1):
        path = f"units[{index}] ({unit.get('id')})"
        for text in _iter_learner_visible(unit):
            if not text:
                continue
            if _looks_like_english_passage(text):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, path,
                    "pre_binding learner-visible 内容是成段英语 (语言合同 v1 "
                    f"要求中文经验叙事): {text[:80]!r} → 改写为 L1 描述可观察"
                    "行为; 仅允许必要专名/数字/单位"))
    for index, item in enumerate(review_items, start=1):
        path = f"review_pool[{index}] ({item.get('id')})"
        for text in _iter_review_visible(item):
            if not text:
                continue
            if _looks_like_english_passage(text):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, path,
                    "复习场景是成段英语 (early_post_binding 要求 L1): "
                    f"{text[:80]!r} → 改写为中文经验叙事"))


def _check_l1_label_leakage(
    units: list[dict],
    review_items: list[dict],
    symbol_binding: dict,
    sense: dict,
    program: dict,
    diagnostics: list[Diagnostic],
) -> None:
    """L1 label leakage (确定性部分): 已知 L1 等价标签被当作定义/答案放进
    绑定前字段。

    - 字段整体等于 minimal_l1_gloss → 原样复制。
    - interaction (question/answers/feedback) 出现任意已知 L1 标签 → 标签泄漏。
    - 叙事字段 (episode/evidence/dimensions) 出现标签且是直陈定义句式或短句
      → 标签泄漏。叙事中自然出现的常用词不误伤 (最终判断由 LLM gate 负责)。
    """
    gloss = (symbol_binding or {}).get("minimal_l1_gloss")
    terms = _l1_label_terms(sense, program)

    def check_texts(path: str, texts, *, interaction: bool) -> None:
        for text in texts:
            if not text:
                continue
            stripped = text.strip()
            if gloss and stripped == gloss:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, path,
                    f"绑定前字段原样复制 minimal_l1_gloss {gloss!r} (L1 label "
                    f"leakage): {text[:80]!r} → 用行为描述替代中文标签"))
            for term in sorted(terms):
                if not term or stripped == term:
                    if stripped == term:
                        diagnostics.append(Diagnostic(
                            DETERMINISTIC_STAGE, path,
                            f"绑定前字段整体等于已知 L1 标签 {term!r} (L1 label "
                            f"leakage): 中文只能描述经验，不能命名概念"))
                        continue
                if term in text and (interaction or _is_l1_label_definition(text)
                                     or len(text) <= 24):
                    diagnostics.append(Diagnostic(
                        DETERMINISTIC_STAGE, path,
                        f"绑定前字段出现已知 L1 标签 {term!r} (L1 label leakage): "
                        f"{text[:80]!r} → 中文只能描述经验，不能给出等价标签"))

    for index, unit in enumerate(units, start=1):
        path = f"units[{index}] ({unit.get('id')})"
        interaction = (unit.get("interaction") or {})
        question = interaction.get("question")
        answers = interaction.get("answers") or []
        feedback_texts = [a.get("feedback") for a in answers if isinstance(a, dict)]
        answer_texts = [a.get("text") for a in answers if isinstance(a, dict)]
        check_texts(f"{path}.interaction.question", [question], interaction=True)
        check_texts(f"{path}.interaction.answers.text", answer_texts, interaction=True)
        check_texts(f"{path}.interaction.answers.feedback", feedback_texts,
                    interaction=True)
        for pattern in _LEARNER_VISIBLE_PATHS:
            if pattern.startswith("experience"):
                if pattern == "experience.observable_evidence":
                    check_texts(
                        path,
                        (item for item in unit.get("experience", {}).get(
                            "observable_evidence", [])),
                        interaction=False,
                    )
                elif pattern.startswith("experience.surface_dimensions"):
                    field_name = pattern.rsplit(".", 1)[1]
                    dim_texts = [
                        str(dim.get(field_name) or "")
                        for dim in unit.get("experience", {}).get("surface_dimensions", [])
                        if isinstance(dim, dict)
                    ]
                    check_texts(path, dim_texts, interaction=False)
                elif pattern == "experience.episode":
                    check_texts(path, [unit.get("experience", {}).get("episode")],
                                interaction=False)

    for index, item in enumerate(review_items, start=1):
        path = f"review_pool[{index}] ({item.get('id')})"
        check_texts(path, _iter_review_visible(item), interaction=False)


def _check_stage_consistency_review_item(item: dict, index: int,
                                           diagnostics: list[Diagnostic]) -> None:
    """复习项 scaffold_level (early_post_binding 默认) 的阶段一致性。"""
    level = item.get("scaffold_level")
    if level is None:
        return
    if level not in ("pre_binding", "symbol_binding", "early_post_binding",
                     "later_post_binding"):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"review_pool[{index}].scaffold_level",
            f"scaffold_level 必须是 pre_binding/symbol_binding/"
            f"early_post_binding/later_post_binding, 实际 {level!r}"))
    elif level == "pre_binding":
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"review_pool[{index}].scaffold_level",
            "复习池不可能是 pre_binding (复习发生在揭示之后); "
            "MVP 固定 early_post_binding 或更晚"))


def _check_stage_consistency(program: dict, sense: dict,
                             diagnostics: list[Diagnostic]) -> None:
    """Stage consistency (确定性部分):

    - symbol_binding 必须首次包含目标 L2 (reveal.l2_word == lemma)。
    - grounding 必须实际包含目标 lemma 或其被允许的自然词形。
    - review item 的 scaffold_level 必须合法 (MVP 固定 early_post_binding)。
    - target.locale_l1 必须与 language_policy.learner_l1 一致。
    """
    target = program.get("target") or {}
    lemma = str(target.get("lemma") or "")
    binding = program.get("symbol_binding") or {}
    reveal = binding.get("reveal") or {}

    if not lemma:
        return
    if reveal.get("l2_word") != lemma:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "symbol_binding.reveal.l2_word",
            f"symbol_binding 必须首次展示目标 L2 {lemma!r}, 实际 "
            f"{reveal.get('l2_word')!r}"))
    ipa = str(target.get("ipa") or "")
    if ipa and (binding.get("reveal") or {}).get("ipa") != ipa:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "symbol_binding.reveal.ipa",
            f"reveal 的 IPA 与 WordSense 不一致: {reveal.get('ipa')!r} vs {ipa!r}"))

    grounding = program.get("grounding") or {}
    realization = str(grounding.get("l2_realization") or "")
    if realization:
        lowered = realization.lower()
        allowed = {lemma.lower()}
        base = lemma.lower()
        if base.endswith("y") and len(base) > 1:
            stem = base[:-1]
            allowed.update({stem + "ier", stem + "iest", stem + "ies"})
        else:
            allowed.update(
                f"{base}{suffix}"
                for suffix in ("s", "es", "ed", "ing", "er", "est", "ies")
            )
        allowed.update(f"{base}{suffix}"
                       for suffix in ("ly", "ness"))
        if not any(token in lowered for token in allowed):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, "grounding.l2_realization",
                f"grounding 必须实际包含目标 L2 {lemma!r} 或其自然词形: "
                f"{realization[:80]!r}"))

    policy = program.get("language_policy") or {}
    locale_l1 = target.get("locale_l1")
    if locale_l1 and policy.get("learner_l1"):
        expected = str(policy["learner_l1"]).split("-")[0]
        if locale_l1 != expected:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, "target.locale_l1",
                f"target.locale_l1={locale_l1!r} 与 language_policy.learner_l1"
                f"={policy['learner_l1']!r} 不一致 (必须为其短码)"))


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
    lemma = str(program.get("target", {}).get("lemma") or "")
    neighbors = _neighbor_symbols(sense, lemma) if lemma else set()
    for index, item in enumerate(review_items, start=1):
        if not isinstance(item, dict):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"review_pool[{index}]", "review item 必须是对象"))
            continue
        path = f"review_pool[{index}] ({item.get('id')})"
        episode = item.get("experience", {}).get("episode")
        if episode in unit_episodes:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.experience.episode",
                "review_pool 不能重新播放首学故事 (episode 与首学 unit 相同)"))
        if lemma:
            _check_review_l2_leakage(item, lemma, neighbors, path, diagnostics)
        _check_stage_consistency_review_item(item, index, diagnostics)

    _check_surface_language(units, review_items, diagnostics)
    _check_l1_label_leakage(
        units, review_items, program.get("symbol_binding") or {}, sense,
        program, diagnostics)


def _check_gate_record(gate: Any, dims: tuple[str, ...], path_prefix: str,
                       diagnostics: list[Diagnostic]) -> None:
    """逐资产 gate 记录的一致性检查: 维度集/唯一/verdict/note/passed。"""
    if not isinstance(gate, dict):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}", "gate 必须是对象"))
        return
    dimensions = gate.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            "gate 必须记录维度结论"))
        return
    names = [item.get("name") if isinstance(item, dict) else None
             for item in dimensions]
    if len(names) != len(dims) or set(names) != set(dims):
        missing = sorted(set(dims) - set(names))
        duplicates = sorted({name for name in names if names.count(name) > 1})
        unknown = sorted({name for name in names if name not in dims})
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            f"必须恰好包含维度集合各一次: 缺失={missing} 重复={duplicates} "
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


def _check_asset_gates(asset_gates: Any, diagnostics: list[Diagnostic]) -> None:
    """metadata.asset_gates: 每个资产类型必须有裁剪后的维度集。"""
    if not isinstance(asset_gates, dict):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "metadata.asset_gates",
            "asset_gates 必须是对象"))
        return
    for asset_type in ASSET_TYPES:
        _check_gate_record(
            asset_gates.get(asset_type),
            ASSET_GATE_DIMENSIONS[asset_type],
            f"metadata.asset_gates.{asset_type}",
            diagnostics,
        )


def _check_quality_gate(gate: Any, diagnostics: list[Diagnostic],
                        path_prefix: str) -> None:
    """metadata.quality_gate (聚合) 的一致性检查。

    聚合 gate 由逐资产 gate 确定性合并而来: 维度名为 ``{asset}.{dim}``,
    必须与四类资产的裁剪维度集逐一对应; passed 由 verdict 计算。
    """
    if not isinstance(gate, dict):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}", "quality_gate 必须是对象"))
        return
    dimensions = gate.get("dimensions")
    if not isinstance(dimensions, list) or not dimensions:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            "quality_gate 必须记录聚合维度结论"))
        return
    expected = [
        f"{asset_type}.{dim}"
        for asset_type in ASSET_TYPES
        for dim in ASSET_GATE_DIMENSIONS[asset_type]
    ]
    names = [item.get("name") if isinstance(item, dict) else None
             for item in dimensions]
    if len(names) != len(expected) or set(names) != set(expected):
        missing = sorted(set(expected) - set(names))
        duplicates = sorted({name for name in names if names.count(name) > 1})
        unknown = sorted({name for name in names if name not in expected})
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, f"{path_prefix}.dimensions",
            f"聚合维度集合不合法: 缺失={missing} 重复={duplicates} 未知={unknown}"))
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


def _validate_metadata(program: dict, diagnostics: list[Diagnostic],
                       skip_quality_gate: bool = False,
                       skip_contract_link: bool = False) -> None:
    metadata = program.get("metadata") or {}
    required = (
        "compiler_version", "prompt_versions", "generated_at",
        "source_semantic_revision", "source_contract_hash",
        "model_provider", "model_name", "asset_gates", "quality_gate",
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
        _check_asset_gates(metadata.get("asset_gates"), diagnostics)
        _check_quality_gate(metadata.get("quality_gate"), diagnostics,
                            "metadata.quality_gate")
    if not skip_contract_link:
        _validate_contract_link(program, diagnostics)


def _validate_contract_link(program: dict, diagnostics: list[Diagnostic]) -> None:
    """program 与其上游 semantic contract 的绑定 (stale 追踪)。

    - metadata.source_contract_hash 必须等于 contract 文件的 content_hash
      (contract 变化 → 下游 program 识别为 stale);
    - program.semantic_model 必须是 contract.semantic_model 的投影;
    - contract 自身 hash 必须自洽, 且 semantic_revision 仍对应当前 WordSense。
    """
    metadata = program.get("metadata") or {}
    sense_id = (program.get("target") or {}).get("sense_id", "")
    recorded_hash = metadata.get("source_contract_hash")
    contract = load_contract(sense_id)
    if contract is None:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "metadata.source_contract_hash",
            f"contract 文件缺失: {contract_path(sense_id)} (program 无法核对 stale 状态)"))
        return
    if not verify_contract_self_hash(contract):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, str(contract_path(sense_id)),
            "contract 自身 content hash 不一致 (文件损坏或手工改动)"))
        return
    try:
        sense = load_sense(sense_id)
    except CompileError:
        return  # 根因 (sense 缺失) 已由 load_sense 报告
    if contract.get("semantic_revision") != int(sense.get("semantic_revision") or 1):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, str(contract_path(sense_id)),
            "contract 已过期: WordSense semantic_revision 已变化, "
            "需要重新生成 contract"))
    if recorded_hash != contract["content_hash"]:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "metadata.source_contract_hash",
            f"program stale: 记录的 contract hash {recorded_hash!r} 与当前 contract "
            f"{contract['content_hash']!r} 不一致 (下游资产需按新 contract 重新生成)"))
    if program.get("semantic_model") != contract.get("semantic_model"):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "semantic_model",
            "semantic_model 不是当前 contract 的投影 (必须是 contract 的投影, "
            "而不是权威副本)"))


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
                     skip_quality_gate: bool = False,
                     skip_contract_link: bool = False) -> list[Diagnostic]:
    """对一份 ExperienceProgram 执行确定性校验; 返回全部 diagnostics (空 = 通过)。

    ``skip_quality_gate=True`` 只供编译器内部使用: 在资产门记录就位之前跳过
    gate 检查。``skip_contract_link=True`` 只供 facade 内部使用: 装配产物尚未
    持久化, 没有可对照的 contract 文件时跳过 stale 检查。
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
    _check_stage_consistency(program, sense, diagnostics)
    _validate_metadata(program, diagnostics,
                       skip_quality_gate=skip_quality_gate,
                       skip_contract_link=skip_contract_link)
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
# boundary 资产校验
# --------------------------------------------------------------------------- #

def _boundary_pair_texts(pair: dict, keys: tuple[str, ...]):
    """boundary minimal pair 的 learner-visible 文本迭代。"""
    experience = pair.get("experience") or {}
    for key in keys:
        if key == "episode":
            yield "experience.episode", experience.get("episode")
        elif key == "observable_evidence":
            for item in experience.get("observable_evidence") or []:
                yield "experience.observable_evidence", item
        elif key == "surface_dimensions":
            for dim in experience.get("surface_dimensions") or []:
                if not isinstance(dim, dict):
                    continue
                for field in ("name", "baseline", "deviation"):
                    yield f"experience.surface_dimensions.{field}", dim.get(field)
        elif key == "question":
            yield "interaction.question", (pair.get("interaction") or {}).get("question")
        elif key == "feedback":
            for answer in (pair.get("interaction") or {}).get("answers") or []:
                if isinstance(answer, dict):
                    yield "interaction.answers.feedback", answer.get("feedback")
        elif key == "explanation":
            explanation = pair.get("explanation") or {}
            yield "explanation.correct", explanation.get("correct")
            yield "explanation.other", explanation.get("other")


def _check_boundary_language_contract(
    pkg: dict,
    sense_a_doc: dict,
    sense_b_doc: dict,
    diagnostics: list[Diagnostic],
) -> None:
    """Boundary 的语言合同确定性门:

    - 场景 (experience) 是 pre_binding: 中文, 禁止两个 lemma 与相邻 L2,
      禁止 L1 标签。
    - 问题/反馈/解释是 early_post_binding: L1, 不得是成段英语。
    - 选项只能是两个已绑定 sense 的合法 L2 lemma, 不能是英文解释段落。
    - language_policy 必须声明 (schema 已强制 required)。
    """
    lemma_a = str(sense_a_doc.get("word") or pkg.get("sense_a", ""))
    lemma_b = str(sense_b_doc.get("word") or pkg.get("sense_b", ""))
    neighbors = set()
    for sense in (sense_a_doc, sense_b_doc):
        neighbors |= _neighbor_symbols(sense, str(sense.get("word") or ""))
    neighbors.discard(lemma_a)
    neighbors.discard(lemma_b)
    terms = _l1_label_terms(sense_a_doc) | _l1_label_terms(sense_b_doc)
    if not lemma_a or not lemma_b:
        return

    policy = pkg.get("language_policy") or {}
    if not policy.get("learner_l1") or not policy.get("target_l2"):
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "language_policy",
            "boundary 必须声明 Learning Presentation Language Contract "
            "(learner_l1 / target_l2)"))

    for index, pair in enumerate(pkg.get("minimal_pairs") or [], start=1):
        if not isinstance(pair, dict):
            continue
        path = f"minimal_pairs[{index}] ({pair.get('id')})"

        # 1. pre-binding 场景: L2 leakage (两个 lemma + 相邻词)
        for field, text in _boundary_pair_texts(
                pair, ("episode", "observable_evidence", "surface_dimensions")):
            if not isinstance(text, str) or not text:
                continue
            for lemma in (lemma_a, lemma_b):
                for hit in _l2_symbol_hits(text, {lemma}):
                    diagnostics.append(Diagnostic(
                        DETERMINISTIC_STAGE, f"{path}.{field}",
                        f"boundary 场景出现 L2 词 '{hit}' (pre_binding 禁止): "
                        f"{text[:80]!r}"))
            for hit in _l2_symbol_hits(text, neighbors):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.{field}",
                    f"boundary 场景出现相邻 L2 词 '{hit}' (pre_binding 禁止): "
                    f"{text[:80]!r}"))

        # 2. 场景/问题/反馈/解释: 中文, 不得成段英语
        for field, text in _boundary_pair_texts(
                pair, ("episode", "observable_evidence", "surface_dimensions",
                       "question", "feedback", "explanation")):
            if not isinstance(text, str) or not text:
                continue
            if _looks_like_english_passage(text):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.{field}",
                    "boundary 文本是成段英语 (合同 v1 要求 L1 场景/问题/反馈/解释): "
                    f"{text[:80]!r} → 改写为中文; 选项才允许 L2 lemma"))

        # 3. L1 标签泄漏 (场景与解释文本)
        for field, text in _boundary_pair_texts(
                pair, ("episode", "observable_evidence", "surface_dimensions",
                       "question", "feedback", "explanation")):
            if not isinstance(text, str) or not text:
                continue
            stripped = text.strip()
            for term in sorted(terms):
                if not term:
                    continue
                if stripped == term or (
                        term in text and (_is_l1_label_definition(text)
                                          or len(text) <= 24)):
                    diagnostics.append(Diagnostic(
                        DETERMINISTIC_STAGE, f"{path}.{field}",
                        f"boundary 文本出现已知 L1 标签 {term!r} (L1 label "
                        f"leakage): {text[:80]!r} → 用行为描述替代标签"))

        # 4. 选项只能是两个已绑定 L2 lemma
        answers = (pair.get("interaction") or {}).get("answers") or []
        for answer_index, answer in enumerate(answers, start=1):
            if not isinstance(answer, dict):
                continue
            option = str(answer.get("text") or "").strip()
            if option.lower() not in (lemma_a.lower(), lemma_b.lower()):
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.interaction.answers[{answer_index}].text",
                    f"boundary 选项必须是已绑定 sense 的合法 L2 符号 "
                    f"({lemma_a} / {lemma_b}), 实际 {option[:60]!r}; "
                    "不得把整段解释写成英语选项"))
        if answers:
            option_lemmas = {
                str(a.get("text") or "").strip().lower()
                for a in answers if isinstance(a, dict)
            }
            if len(option_lemmas) < 2:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.interaction.answers",
                    "boundary 选项必须同时包含两个义项的 L2 符号 (dirty / messy)"))


def validate_boundary_package(pkg: dict) -> list[Diagnostic]:
    """对一份 boundary package 执行确定性校验; 返回全部 diagnostics。"""
    diagnostics: list[Diagnostic] = []
    if not isinstance(pkg, dict):
        return [Diagnostic(DETERMINISTIC_STAGE, "(root)", "boundary 根节点必须是对象")]
    schema = _load_boundary_schema()
    for error in schema.iter_errors(pkg):
        location = "/".join(str(part) for part in error.absolute_path) or "(root)"
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, location, error.message))
    if diagnostics:
        return diagnostics

    sense_a = str(pkg.get("sense_a"))
    sense_b = str(pkg.get("sense_b"))
    if not sense_a or not sense_b or sense_a >= sense_b:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "sense_a/sense_b",
            "sense_a 必须是字典序较小的义项 id, 且两义项不同"))
    if pkg.get("boundary_id") != f"{sense_a}__{sense_b}":
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "boundary_id",
            f"boundary_id 应为 '{sense_a}__{sense_b}' (sense id 字典序排列, 保证唯一 key)"))

    sense_a_doc: dict = {}
    sense_b_doc: dict = {}
    for sid in (sense_a, sense_b):
        path = SENSES_DIR / f"{sid}.yaml"
        if not path.exists():
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"sense {sid}",
                f"WordSense '{sid}' 不存在 (boundary 必须绑定真实义项)"))
        else:
            document = yaml.safe_load(path.read_text(encoding="utf-8"))
            if sid == sense_a:
                sense_a_doc = document
            else:
                sense_b_doc = document

    _check_boundary_language_contract(
        pkg, sense_a_doc, sense_b_doc, diagnostics)

    pairs = pkg.get("minimal_pairs") or []
    correct_senses: set[str] = set()
    episodes: set[str] = set()
    for index, pair in enumerate(pairs, start=1):
        if not isinstance(pair, dict):
            continue
        path = f"minimal_pairs[{index}] ({pair.get('id')})"
        correct = pair.get("correct_sense")
        if correct not in (sense_a, sense_b):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.correct_sense",
                f"correct_sense 必须是 {sense_a} 或 {sense_b}, 实际 {correct!r}"))
        else:
            correct_senses.add(correct)
        episode = (pair.get("experience") or {}).get("episode")
        if episode in episodes:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"{path}.experience.episode",
                "minimal_pairs 之间的 episode 必须互不相同"))
        if episode is not None:
            episodes.add(episode)
        answers = (pair.get("interaction") or {}).get("answers")
        if isinstance(answers, list):
            correct_count = sum(
                1 for answer in answers
                if isinstance(answer, dict) and answer.get("is_correct") is True
            )
            if correct_count != 1:
                diagnostics.append(Diagnostic(
                    DETERMINISTIC_STAGE, f"{path}.interaction",
                    f"每个 minimal pair 必须恰好一个正确答案 (is_correct=true), "
                    f"实际 {correct_count} 个"))
    missing_direction = (set((sense_a, sense_b)) if sense_a < sense_b else set()) \
        - correct_senses
    if missing_direction:
        diagnostics.append(Diagnostic(
            DETERMINISTIC_STAGE, "minimal_pairs[*].correct_sense",
            f"双向判定缺失: 以下义项从未作为正确答案出现: "
            f"{', '.join(sorted(missing_direction))} (正确答案必须两个方向都有)"))

    _check_gate_record(pkg.get("gate"), BOUNDARY_GATE_DIMENSIONS, "gate", diagnostics)

    metadata = pkg.get("metadata") or {}
    for side, hash_field in (("a", "contract_a_hash"), ("b", "contract_b_hash")):
        sid = sense_a if side == "a" else sense_b
        contract = load_contract(sid)
        recorded = metadata.get(hash_field)
        if contract is None:
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"metadata.{hash_field}",
                f"contract 文件缺失: {contract_path(sid)}"))
        elif recorded != contract.get("content_hash"):
            diagnostics.append(Diagnostic(
                DETERMINISTIC_STAGE, f"metadata.{hash_field}",
                f"boundary stale: 记录的 contract hash {recorded!r} 与当前 "
                f"contract {contract.get('content_hash')!r} 不一致"))
    return diagnostics


def validate_boundary_package_file(path: Path) -> list[Diagnostic]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [Diagnostic(DETERMINISTIC_STAGE, str(path), f"文件读取失败: {exc}")]
    try:
        if path.suffix.lower() == ".json":
            pkg = json.loads(text)
        else:
            pkg = yaml.safe_load(text)
    except (json.JSONDecodeError, yaml.YAMLError) as exc:
        return [Diagnostic(DETERMINISTIC_STAGE, str(path), f"解析失败: {exc}")]
    return validate_boundary_package(pkg)


# --------------------------------------------------------------------------- #
# 装配 (compile_experience_program 的便利门面)
# --------------------------------------------------------------------------- #

REVIEW_POOL_TARGET = 6
TRANSFER_ITEM_TARGET = 3


def _merged_gate_records(concept: dict, review: dict, transfer: dict,
                         grounding: dict) -> dict:
    """从各资产提取 gate 记录: review/transfer 取最近一个批次的 gate。"""
    review_batches = review.get("batches") or []
    transfer_batches = transfer.get("batches") or []
    return {
        "concept": concept["gate"],
        "review": review_batches[-1]["gate"] if review_batches else {"passed": False, "dimensions": []},
        "transfer": transfer_batches[-1]["gate"] if transfer_batches else {"passed": False, "dimensions": []},
        "grounding": grounding["gate"],
    }


def _aggregate_quality_gate(asset_gates: dict) -> dict:
    """整程序 quality_gate = 逐资产 gate 的确定性聚合 (不是新的整体评审)。"""
    dimensions: list[dict] = []
    for asset_type in ASSET_TYPES:
        for dim in (asset_gates.get(asset_type) or {}).get("dimensions") or []:
            if isinstance(dim, dict) and dim.get("name"):
                dimensions.append({**dim, "name": f"{asset_type}.{dim['name']}"})
    passed = all(
        bool((asset_gates.get(asset_type) or {}).get("passed"))
        for asset_type in ASSET_TYPES
    )
    return {"passed": passed, "dimensions": dimensions}


def assemble_program(
    sense: dict,
    contract: dict,
    concept_asset: dict,
    review_asset: dict,
    transfer_asset: dict,
    grounding_asset: dict,
    program_version: int,
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> dict:
    """从 contract + 各资产确定性装配一份 ExperienceProgram (status=draft)。

    只做结构装配与元数据合并, 不调用任何模型; semantic_model 是 contract 的
    投影, metadata 记录 contract hash 与逐资产质量门。
    """
    concept_units = concept_asset["units"]
    transfer_units = transfer_asset["units"]
    units: list[dict] = []
    for index, unit in enumerate(concept_units + transfer_units, start=1):
        assembled = dict(unit)
        assembled["sequence"] = index
        units.append(assembled)

    asset_gates = _merged_gate_records(
        concept_asset, review_asset, transfer_asset, grounding_asset)

    def merged_request_ids() -> list[str]:
        ids: list[str] = []
        for asset in (concept_asset, review_asset, transfer_asset, grounding_asset):
            ids.extend((asset.get("metadata") or {}).get("request_ids") or [])
        return ids

    provider = (concept_asset.get("metadata") or {}).get("model_provider")
    model = (concept_asset.get("metadata") or {}).get("model_name")
    prompt_versions = {
        stage: _prompt_version(_load_prompt(stage), f"unversioned-{stage}")
        for stage in STAGES
    }
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
            "locale_l1": language.learner_l1.split("-")[0],
        },
        "language_policy": language.to_metadata(),
        "semantic_model": copy.deepcopy(contract["semantic_model"]),
        "units": units,
        "symbol_binding": concept_asset["symbol_binding"],
        "grounding": grounding_asset["grounding"],
        "review_pool": review_asset["items"],
        "metadata": {
            "compiler_version": COMPILER_VERSION,
            "prompt_versions": prompt_versions,
            "generated_at": _utc_now(),
            "source_semantic_revision": int(contract.get("semantic_revision") or 1),
            "source_contract_hash": contract["content_hash"],
            "model_provider": provider,
            "model_name": model,
            "request_ids": merged_request_ids(),
            "asset_gates": asset_gates,
            "quality_gate": _aggregate_quality_gate(asset_gates),
        },
    }
    return program


def compile_experience_program(
    sense_id: str,
    *,
    adapter: Adapter | None = None,
    config: llm_adapter.LLMConfig | None = None,
    program_version: int = 1,
    language: PresentationLanguage = DEFAULT_LANGUAGE,
) -> dict:
    """把 WordSense 编译为通过全部逐资产质量门的 ExperienceProgram dict (status=draft)。

    签名与 v1 兼容: 现在是"装配全套"的便利门面 —— 保证 semantic contract 当前,
    保证 concept / transfer / review / grounding 资产齐备 (缺失才生成, 已有则
    直接复用; stale 资产报错), 再离线装配与确定性校验。编译器只能产出 draft;
    reviewed/published 由未来独立的人工 promotion 流程设置。失败时抛出
    :class:`CompileError`。adapter 缺省时使用 tools/llm.py 的真实模型路径。
    """
    sense = load_sense(sense_id)
    resolver = adapter or _real_adapter(config)
    retries: dict[str, int] = {}

    contract = _load_or_produce_contract(sense, resolver, retries, persist=False)
    concept = _load_or_produce_concept(sense, contract, resolver, retries,
                                       persist=False, language=language)
    transfer = _load_or_produce_transfer(sense, contract, concept, resolver,
                                         retries, persist=False, language=language)
    review = _load_or_produce_review(sense, contract, concept, transfer,
                                     resolver, retries, persist=False,
                                     language=language)
    grounding = _load_or_produce_grounding(sense, contract, concept, resolver,
                                           retries, persist=False,
                                           language=language)

    program = assemble_program(
        sense, contract, concept, review, transfer, grounding, program_version,
        language,
    )
    diagnostics = validate_program(program, skip_contract_link=True)
    if diagnostics:
        raise CompileError(
            "编译产物未通过确定性校验 (Schema / 引用 / 变量 / 泄漏规则 / 逐资产质量门)",
            diagnostics)
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
    boundaries: list[Path] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not self.errors


def run_regression() -> RegressionResult:
    """完全离线的四词回归: 四个 fixture 全部通过确定性校验且结构互不相同,
    外加 dirty-01↔messy-01 boundary fixture 通过其确定性校验。"""
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

    for path in sorted(BOUNDARY_FIXTURES_DIR.glob("*.yaml")):
        diagnostics = validate_boundary_package_file(path)
        result.boundaries.append(path)
        if diagnostics:
            result.errors.append(f"boundary {path.name}:")
            result.errors.extend(f"  ✗ {item.render()}" for item in diagnostics)
    required_boundary = BOUNDARY_FIXTURES_DIR / "dirty-01__messy-01.yaml"
    if not required_boundary.exists():
        result.errors.append(
            "缺少 dirty-01↔messy-01 boundary fixture (boundary producer 第一对资产)")
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


def _require_llm_config() -> llm_adapter.LLMConfig:
    try:
        return llm_adapter.LLMConfig.from_env()
    except llm_adapter.LLMConfigurationError as exc:
        print(
            f"该命令需要已配置的 LLM (SCENELEX_LLM_PROTOCOL 等): {exc}",
            file=sys.stderr,
        )
        raise SystemExit(2) from exc


def _compile_with_persistence(sense_id: str, program_version: int,
                              config: llm_adapter.LLMConfig,
                              language: PresentationLanguage = DEFAULT_LANGUAGE) -> dict:
    """CLI compile 路径: 装配全套并把中间资产全部落盘 (可增量追加的前提)。"""
    sense = load_sense(sense_id)
    resolver = _real_adapter(config)
    retries: dict[str, int] = {}

    contract = _load_or_produce_contract(sense, resolver, retries, persist=True)
    concept = _load_or_produce_concept(sense, contract, resolver, retries,
                                       persist=True, language=language)
    transfer = _load_or_produce_transfer(sense, contract, concept, resolver,
                                         retries, persist=True, language=language)
    review = _load_or_produce_review(sense, contract, concept, transfer,
                                     resolver, retries, persist=True,
                                     language=language)
    grounding = _load_or_produce_grounding(sense, contract, concept, resolver,
                                           retries, persist=True,
                                           language=language)

    program = assemble_program(
        sense, contract, concept, review, transfer, grounding, program_version,
        language,
    )
    diagnostics = validate_program(program)
    if diagnostics:
        raise CompileError(
            "编译产物未通过确定性校验 (Schema / 引用 / 变量 / 泄漏规则 / 逐资产质量门)",
            diagnostics)
    return program


def _compile_and_dump(sense_id: str, program_version: int,
                      output: Path | None) -> int:
    try:
        output_path = _resolve_output(sense_id, program_version, output)
    except CompileError as exc:
        print(f"编译失败: {exc.render()}", file=sys.stderr)
        return 1
    if output_path.exists():
        print(f"编译失败: 目标产物已存在, 禁止覆盖: {output_path}",
              file=sys.stderr)
        return 1
    if not DRAFTS_DIR.exists():
        DRAFTS_DIR.mkdir(parents=True)
    config = _require_llm_config()
    try:
        program = _compile_with_persistence(sense_id, program_version, config)
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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="experience_compiler",
        description="Experience Compiler v2: WordSense → 可增量资产集合 → "
                    "ExperienceProgram",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser(
        "validate", help="离线确定性校验一份程序文件 (YAML/JSON)")
    validate_parser.add_argument("program_file", type=Path)

    validate_boundary_parser = subparsers.add_parser(
        "validate-boundary", help="离线确定性校验一份 boundary package 文件")
    validate_boundary_parser.add_argument("boundary_file", type=Path)

    subparsers.add_parser("regression", help="离线四词 fixture 回归 (含 boundary)")

    compile_parser = subparsers.add_parser(
        "compile", help="完整装配一个 WordSense (缺什么生成什么, 需要 LLM 配置)")
    compile_parser.add_argument("sense_id")
    compile_parser.add_argument("--output", type=Path, default=None,
                                help="输出路径; 缺省写入 data/drafts/experience-programs/")
    compile_parser.add_argument("--version", type=int, default=None,
                                help="program_version; 缺省自动递增, 目录 vNN 与版本一致")

    assemble_parser = subparsers.add_parser(
        "assemble", help="只用已有资产离线装配 (不调用模型, 缺资产报错)")
    assemble_parser.add_argument("sense_id")
    assemble_parser.add_argument("--output", type=Path, default=None)
    assemble_parser.add_argument("--version", type=int, default=None)

    contract_parser = subparsers.add_parser(
        "contract", help="contract producer: 生成/更新 semantic contract")
    contract_parser.add_argument("sense_id")

    concept_parser = subparsers.add_parser(
        "concept", help="concept producer: 生成 concept 资产 (units + symbol_binding)")
    concept_parser.add_argument("sense_id")

    review_parser = subparsers.add_parser(
        "review-add", help="review producer: 追加 N 条新复习项 (避开已有条目)")
    review_parser.add_argument("sense_id")
    review_parser.add_argument("--count", type=int, default=1,
                               help="新增复习条数 (默认 1)")

    transfer_parser = subparsers.add_parser(
        "transfer-add", help="transfer producer: 追加 N 个新 transfer 单元")
    transfer_parser.add_argument("sense_id")
    transfer_parser.add_argument("--count", type=int, default=1,
                                 help="新增 transfer 条数 (默认 1)")

    grounding_parser = subparsers.add_parser(
        "grounding", help="grounding producer: 生成 grounding 资产")
    grounding_parser.add_argument("sense_id")

    boundary_parser = subparsers.add_parser(
        "boundary", help="boundary producer: 生成义项对辨析资产")
    boundary_parser.add_argument("sense_a")
    boundary_parser.add_argument("sense_b")

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

    if arguments.command == "validate-boundary":
        diagnostics = validate_boundary_package_file(arguments.boundary_file)
        if diagnostics:
            print("校验未通过:")
            for diagnostic in diagnostics:
                print(f"  ✗ {diagnostic.render()}")
            return 1
        print(f"✓ {arguments.boundary_file}: 通过 boundary 确定性校验")
        return 0

    if arguments.command == "regression":
        result = run_regression()
        for path in result.fixtures:
            print(f"  ✓ {path.name}")
        for path in result.boundaries:
            print(f"  ✓ boundary/{path.name}")
        if not result.errors:
            print("✓ 四词回归全部通过 (Schema + 确定性校验 + 结构差异 + "
                  "reluctant eventual_action 双值 + boundary fixture)")
            return 0
        for error in result.errors:
            print(f"  ✗ {error}", file=sys.stderr)
        return 1

    if arguments.command == "compile":
        program_version = arguments.version
        if program_version is None:
            program_version = _next_version(arguments.sense_id)
        return _compile_and_dump(arguments.sense_id, program_version,
                                 arguments.output)

    if arguments.command == "contract":
        config = _require_llm_config()
        sense = load_sense(arguments.sense_id)
        existing = load_contract(arguments.sense_id)
        if existing is not None and verify_contract_self_hash(existing) \
                and contract_matches_sense(existing, sense):
            print(f"✓ {arguments.sense_id} contract 已是最新, 跳过生成")
            return 0
        try:
            contract = compile_semantic_contract(arguments.sense_id, config=config)
            path = save_contract(contract)
        except CompileError as exc:
            print(f"contract producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ {contract['contract_id']} content_hash={contract['content_hash']} → {path}")
        return 0

    if arguments.command == "concept":
        config = _require_llm_config()
        try:
            asset = compile_concept_assets(arguments.sense_id, config=config)
            path = save_asset(arguments.sense_id, "concept", asset)
        except CompileError as exc:
            print(f"concept producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ concept 资产 ({len(asset['units'])} units, "
              f"gate passed={asset['gate']['passed']}) → {path}")
        return 0

    if arguments.command == "review-add":
        config = _require_llm_config()
        try:
            batch = compile_review_batch(arguments.sense_id, arguments.count,
                                         config=config)
            existing = load_asset(arguments.sense_id, "review")
            if existing is None:
                path = save_asset(
                    arguments.sense_id, "review",
                    _new_review_asset(arguments.sense_id, batch["contract_hash"],
                                      batch))
            else:
                path = append_review_items(arguments.sense_id, batch)
        except CompileError as exc:
            print(f"review producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ 追加 {arguments.count} 条复习项 (gate passed={batch['gate']['passed']}) "
              f"→ {path}")
        return 0

    if arguments.command == "transfer-add":
        config = _require_llm_config()
        try:
            batch = compile_transfer_batch(arguments.sense_id, arguments.count,
                                           config=config)
            existing = load_asset(arguments.sense_id, "transfer")
            if existing is None:
                path = save_asset(
                    arguments.sense_id, "transfer",
                    _new_transfer_asset(arguments.sense_id, batch["contract_hash"],
                                        batch))
            else:
                path = append_transfer_items(arguments.sense_id, batch)
        except CompileError as exc:
            print(f"transfer producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ 追加 {arguments.count} 个 transfer 单元 "
              f"(gate passed={batch['gate']['passed']}) → {path}")
        return 0

    if arguments.command == "grounding":
        config = _require_llm_config()
        try:
            asset = compile_grounding(arguments.sense_id, config=config)
            path = save_asset(arguments.sense_id, "grounding", asset)
        except CompileError as exc:
            print(f"grounding producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ grounding 资产 (source={asset['grounding']['source_experience_id']}, "
              f"gate passed={asset['gate']['passed']}) → {path}")
        return 0

    if arguments.command == "boundary":
        config = _require_llm_config()
        path = boundary_path(arguments.sense_a, arguments.sense_b)
        if path.exists():
            print(f"boundary 资产已存在, 禁止覆盖: {path}", file=sys.stderr)
            return 1
        try:
            package = compile_boundary_package(arguments.sense_a,
                                               arguments.sense_b, config=config)
            save_boundary_package(package)
        except CompileError as exc:
            print(f"boundary producer 失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ boundary {package['boundary_id']} ({len(package['minimal_pairs'])} "
              f"minimal pairs, gate passed={package['gate']['passed']}) → {path}")
        return 0

    if arguments.command == "assemble":
        program_version = arguments.version
        if program_version is None:
            program_version = _next_version(arguments.sense_id)
        sense = load_sense(arguments.sense_id)
        contract = load_contract(arguments.sense_id)
        if contract is None:
            print(f"装配失败: 缺少 contract, 先运行 'contract {arguments.sense_id}'",
                  file=sys.stderr)
            return 1
        assets = {}
        for asset_type in ASSET_TYPES:
            asset = load_asset(arguments.sense_id, asset_type)
            if asset is None:
                print(f"装配失败: 缺少 {asset_type} 资产, 先运行对应 producer",
                      file=sys.stderr)
                return 1
            assets[asset_type] = asset
        try:
            for asset_type in ASSET_TYPES:
                _ensure_asset_current(assets[asset_type], contract, asset_type,
                                      arguments.sense_id)
        except CompileError as exc:
            print(f"装配失败: {exc.render()}", file=sys.stderr)
            return 1
        program = assemble_program(
            sense, contract, assets["concept"], assets["review"],
            assets["transfer"], assets["grounding"], program_version)
        diagnostics = validate_program(program)
        if diagnostics:
            print("装配产物未通过确定性校验:")
            for diagnostic in diagnostics:
                print(f"  ✗ {diagnostic.render()}")
            return 1
        try:
            output_path = _resolve_output(arguments.sense_id, program_version,
                                          arguments.output)
            _dump_program(program, output_path)
        except CompileError as exc:
            print(f"装配失败: {exc.render()}", file=sys.stderr)
            return 1
        print(f"✓ 离线装配 {program['program_id']} v{program_version} "
              f"(status=draft) → {output_path}")
        return 0

    parser.error(f"未知命令: {arguments.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
