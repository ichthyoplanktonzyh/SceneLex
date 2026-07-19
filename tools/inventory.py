#!/usr/bin/env python3
"""SceneLex 整词级 Sense Inventory 工具 — 管线新增的规划阶段。

Wiktionary 条目是 dictionary evidence; Sense Inventory 才决定 SceneLex 接受
哪些稳定、可教学的 sense, 以及它们的 ID。approved inventory 是新 WordSense 的
唯一身份权威: sense ID、lemma、pos、语义身份与 dictionary source mapping 都以
它为准, 起草单个义项时不得重新解释编号或按词典条目顺序另立门户。

起草时会同时保存一份本次实际使用的 dictionary evidence snapshot
(data/drafts/dictionary-evidence/{word}.yaml), 并把对它计算的确定性摘要写入
inventory 的 source.evidence_digest。这样 entry_id 的含义被冻结在起草当时,
之后 Wiktionary 内容变化不会让已有 inventory 里的旧 entry_id 被静默重新解释;
validate 时优先读取 snapshot, 没有 snapshot 才回退到实时抓取。

状态流转 (approve 不生成 WordSense, 也不删除 draft, 便于审计):

    draft → reviewed → approved

用法:
    python3 tools/inventory.py draft slow            # 起草整词 inventory + evidence snapshot
    python3 tools/inventory.py draft slow --force     # 覆盖已存在的 draft
    python3 tools/inventory.py validate slow          # 校验 (draft 优先, 否则正式库)
    python3 tools/inventory.py mark-reviewed slow     # 校验通过后把 draft 标为 reviewed
    python3 tools/inventory.py approve slow           # reviewed draft → 正式 inventory
    python3 tools/inventory.py approve slow --force    # 覆盖已有正式 inventory (仍全量校验)
    python3 tools/inventory.py show slow              # 查看原始内容, 不修改文件

草稿一律落在 data/drafts/inventories/; data/inventories/ 与
data/dictionary-evidence/ 是批准后的权威目录, 只能由 approve 写入。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import requests
import yaml

import dictionary
import draft
import llm

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "prompts"
DRAFTS_INVENTORIES = ROOT / "data" / "drafts" / "inventories"
INVENTORIES = ROOT / "data" / "inventories"
DRAFTS_EVIDENCE = ROOT / "data" / "drafts" / "dictionary-evidence"
EVIDENCE = ROOT / "data" / "dictionary-evidence"
SCHEMA_NAME = "sense-inventory.schema.json"
EVIDENCE_SCHEMA_NAME = "dictionary-evidence.schema.json"
WORD_PATTERN = re.compile(r"^[a-z][a-z_]*$")

# 当前唯一支持的词典来源与语言; 仓库尚无多语言词典事实来源机制,
# 不为此提前设计枚举或配置项。
EVIDENCE_PROVIDER = "wiktionary"
SUPPORTED_LANGUAGE = "en"


class InventoryError(RuntimeError):
    """approved inventory 无法被安全加载或使用; 消息面向命令行使用者。"""


def _rel(path: Path) -> str:
    """尽量输出相对 ROOT 的路径; 测试中重定向到 ROOT 之外的目录时仍可读。"""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _sense_number(word: str, sense_id: str) -> int | None:
    match = re.fullmatch(rf"^{re.escape(word)}-([0-9]{{2}})$", sense_id or "")
    return int(match.group(1)) if match else None


# --------------------------------------------------------- evidence digest

def compute_evidence_digest(entries: list[dict]) -> str:
    """对 dictionary evidence entries 计算确定性 SHA-256 摘要。

    用于检测 dictionary entry ID 随词典内容变化而被静默重新解释: 摘要只依赖
    entries 本身的内容 (稳定 key 排序 + 按 entry_id 排序 + UTF-8 编码的规范化
    JSON), 不依赖 Python 进程内 hash() (不跨进程稳定, 也不适合做持久化摘要)。
    """
    canonical = [
        {
            "entry_id": entry.get("entry_id"),
            "pos": entry.get("pos"),
            "gloss": entry.get("gloss"),
            "labels": list(entry.get("labels") or []),
            "examples": list(entry.get("examples") or []),
        }
        for entry in entries
    ]
    canonical.sort(key=lambda entry: entry["entry_id"] or "")
    payload = json.dumps(
        canonical, sort_keys=True, ensure_ascii=False, separators=(",", ":")
    )
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


# --------------------------------------------------------- identity digest

# 锁定身份只包含机器可比较的结构字段。definition / label_zh / decision.reason
# 等自由文本刻意排除在外: 文字润色不应该让已经生成的 WordSense 集体失效。
IDENTITY_SIGNATURE_FIELDS = (
    "semantic_type",
    "dimension",
    "change_of_state",
    "causative",
    "valency",
)


def identity_payload(inventory_sense: dict) -> dict:
    """inventory sense 的锁定身份负载, 与 compute_identity_digest 共用。"""
    raw = inventory_sense.get("semantic_signature")
    signature = raw if isinstance(raw, dict) else {}
    return {
        "id": inventory_sense.get("id"),
        "lemma": inventory_sense.get("lemma"),
        "pos": inventory_sense.get("pos"),
        "semantic_signature": {
            field: signature.get(field) for field in IDENTITY_SIGNATURE_FIELDS
        },
    }


def compute_identity_digest(inventory_sense: dict) -> str:
    """对单个 inventory sense 的锁定身份计算确定性 SHA-256。

    与 compute_evidence_digest 相同的规范化约定 (sort_keys + 稳定分隔符 +
    UTF-8), 使摘要跨进程、跨机器稳定。
    """
    payload = json.dumps(
        identity_payload(inventory_sense),
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


# ------------------------------------------------------- deterministic content

def validate_inventory_content(doc: dict, entries: list[dict], word: str) -> list[str]:
    """确定性引用完整性检查, 独立于 JSON Schema。

    见 PR 说明的检查类别: 顶层身份一致性 (word/lemma/provider/entry_count/
    language/evidence_digest)、sense id 唯一/前缀/连续编号、relation 引用与
    重复、source entry 引用真实性、split 一致性、used/deferred 冲突、未处理
    条目、空定义与空理由。
    """
    errors: list[str] = []
    senses = [s for s in (doc.get("senses") or []) if isinstance(s, dict)]
    deferred = [d for d in (doc.get("deferred_entries") or []) if isinstance(d, dict)]
    relations = [r for r in (doc.get("relations") or []) if isinstance(r, dict)]

    entry_ids = {e["entry_id"] for e in entries if isinstance(e, dict) and e.get("entry_id")}

    # 0: 顶层身份一致性
    doc_word = doc.get("word")
    if doc_word != word:
        errors.append(
            f"顶层 word 不一致: 得到 {doc_word!r}, 期望 {word!r} (CLI 请求的词)"
        )
    for sense in senses:
        sid = sense.get("id", "?")
        lemma = sense.get("lemma")
        if lemma != doc_word:
            errors.append(
                f"sense '{sid}' lemma 不一致: 得到 {lemma!r}, "
                f"期望与顶层 word 一致 {doc_word!r}"
            )
    raw_source = doc.get("source")
    source = raw_source if isinstance(raw_source, dict) else {}
    provider = source.get("provider")
    if provider != EVIDENCE_PROVIDER:
        errors.append(
            f"source.provider 不一致: 得到 {provider!r}, 期望 {EVIDENCE_PROVIDER!r}"
        )
    entry_count = source.get("entry_count")
    if entry_count != len(entries):
        errors.append(
            f"source.entry_count 不一致: 得到 {entry_count!r}, "
            f"期望 {len(entries)} (当前词典证据条目数)"
        )
    language = doc.get("language")
    if language != SUPPORTED_LANGUAGE:
        errors.append(
            f"language 不一致: 得到 {language!r}, 期望 {SUPPORTED_LANGUAGE!r} "
            "(当前仓库尚无多语言词典事实来源机制)"
        )
    declared_digest = source.get("evidence_digest")
    computed_digest = compute_evidence_digest(entries)
    if declared_digest != computed_digest:
        errors.append(
            f"source.evidence_digest 不一致: 得到 {declared_digest!r}, "
            f"期望 {computed_digest!r} (依据当前词典证据计算)"
        )

    # 1+2+3: sense id 唯一 / lemma 前缀 / 连续编号
    seen_ids: set[str] = set()
    sense_ids: set[str] = set()
    numbers: list[int] = []
    for sense in senses:
        sid = sense.get("id", "")
        if sid in seen_ids:
            errors.append(f"sense id '{sid}' 重复")
        else:
            seen_ids.add(sid)
        sense_ids.add(sid)
        number = _sense_number(word, sid)
        if number is None:
            errors.append(f"sense id '{sid}' 不符合 '{word}-NN' 前缀约定")
        else:
            numbers.append(number)
    if numbers:
        expected = list(range(1, len(numbers) + 1))
        if sorted(numbers) != expected:
            errors.append(
                f"sense 编号不连续: 得到 {sorted(numbers)}, "
                f"期望从 01 开始连续编号 {expected}"
            )

    # 9: 空定义 / 空理由
    for sense in senses:
        sid = sense.get("id", "?")
        if not str(sense.get("definition", "")).strip():
            errors.append(f"sense '{sid}' definition 不能为空")
        reason = (sense.get("decision") or {}).get("reason", "")
        if not str(reason).strip():
            errors.append(f"sense '{sid}' decision.reason 不能为空")
    for item in deferred:
        ref = item.get("source_entry", "?")
        if not str(item.get("reason", "")).strip():
            errors.append(f"deferred_entries '{ref}' reason 不能为空")
    for rel in relations:
        if not str(rel.get("distinction", "")).strip():
            errors.append(
                f"relation {rel.get('source')} → {rel.get('target')} "
                "distinction 不能为空"
            )

    # 4: relation 引用完整, 不允许 self relation, 不允许完全重复
    # 重复键包含 relation 类型本身: 同一对 senses 之间的不同关系类型
    # (如 state_change 与 shared_dimension) 是合法的, 不能被误判为重复。
    seen_triples: set[tuple[str | None, str | None, str | None]] = set()
    for rel in relations:
        source_id, target_id = rel.get("source"), rel.get("target")
        if source_id not in sense_ids:
            errors.append(f"relation source '{source_id}' 不在当前 inventory 的 senses 中")
        if target_id not in sense_ids:
            errors.append(f"relation target '{target_id}' 不在当前 inventory 的 senses 中")
        if source_id is not None and source_id == target_id:
            errors.append(f"relation 不允许 self relation: '{source_id}'")
        triple = (source_id, target_id, rel.get("relation"))
        if triple in seen_triples:
            errors.append(
                f"relation ({source_id} → {target_id}, {rel.get('relation')}) 重复"
            )
        else:
            seen_triples.add(triple)

    # 5: source entry 引用必须真实存在于当前词典证据中
    for sense in senses:
        sid = sense.get("id", "?")
        for entry_id in sense.get("source_entries") or []:
            if entry_id not in entry_ids:
                errors.append(
                    f"sense '{sid}' 引用的 source_entries '{entry_id}' "
                    "不存在于当前词典证据中"
                )
    for item in deferred:
        entry_id = item.get("source_entry")
        if entry_id not in entry_ids:
            errors.append(
                f"deferred_entries 引用的 source_entry '{entry_id}' "
                "不存在于当前词典证据中"
            )

    # 6+7: 非 split 重复映射 / used+deferred 冲突
    entry_to_senses: dict[str, list[dict]] = defaultdict(list)
    for sense in senses:
        for entry_id in sense.get("source_entries") or []:
            entry_to_senses[entry_id].append(sense)
    deferred_entry_ids = {item.get("source_entry") for item in deferred}

    for entry_id, mapped in entry_to_senses.items():
        if entry_id in deferred_entry_ids:
            names = ", ".join(s.get("id", "?") for s in mapped)
            errors.append(
                f"dictionary entry '{entry_id}' 同时被 sense ({names}) 使用且被 deferred"
            )
        if len(mapped) > 1:
            non_split = [
                s.get("id", "?") for s in mapped
                if (s.get("decision") or {}).get("type") != "split"
            ]
            if non_split:
                names = ", ".join(s.get("id", "?") for s in mapped)
                errors.append(
                    f"dictionary entry '{entry_id}' 被多个 senses ({names}) 引用, "
                    "但并非全部标记 decision.type: split"
                )

    # 8: 每个过滤后的词典条目必须被处理 (使用或 deferred)
    used_ids = set(entry_to_senses) | deferred_entry_ids
    unhandled = sorted(entry_ids - used_ids)
    if unhandled:
        errors.append(
            f"以下词典条目未被任何 sense 使用也未 deferred: {', '.join(unhandled)}"
        )

    return errors


def _all_errors(doc: dict, entries: list[dict], word: str) -> list[str]:
    validator = draft.load_schema(SCHEMA_NAME)
    errors = draft.schema_check(doc, validator, f"{word}.yaml")
    errors += [
        f"  ✗ {word}.yaml: {msg}"
        for msg in validate_inventory_content(doc, entries, word)
    ]
    return errors


def _apply_machine_fields(doc: dict, word: str, entries: list[dict]) -> None:
    """程序覆盖机器权威字段, 不信任模型输出这些字段的值 (PR 五)。

    只覆盖 schema_version/word/language/status/inventory_version/
    source.provider/source.entry_count/source.evidence_digest; sense 内容
    (包括 lemma) 仍由模型负责, 由 validate_inventory_content 校验一致性。
    """
    doc["schema_version"] = "1.0"
    doc["word"] = word
    doc["language"] = SUPPORTED_LANGUAGE
    doc["status"] = "draft"
    doc["inventory_version"] = 1
    source = doc.get("source")
    if not isinstance(source, dict):
        source = {}
    source["provider"] = EVIDENCE_PROVIDER
    source["entry_count"] = len(entries)
    source["evidence_digest"] = compute_evidence_digest(entries)
    doc["source"] = source


# ------------------------------------------------------------ evidence I/O

def _evidence_path(word: str) -> Path:
    return DRAFTS_EVIDENCE / f"{word}.yaml"


def _official_evidence_path(word: str) -> Path:
    return EVIDENCE / f"{word}.yaml"


def _official_inventory_path(word: str) -> Path:
    return INVENTORIES / f"{word}.yaml"


def _build_evidence_doc(word: str, entries: list[dict]) -> dict:
    return {
        "schema_version": "1.0",
        "word": word,
        "language": SUPPORTED_LANGUAGE,
        "provider": EVIDENCE_PROVIDER,
        "captured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "entries": [
            {
                "entry_id": entry["entry_id"],
                "pos": entry["pos"],
                "gloss": entry["gloss"],
                "labels": list(entry.get("labels") or []),
                "examples": list(entry.get("examples") or []),
            }
            for entry in entries
        ],
    }


def _entries_for_validation(word: str) -> tuple[list[dict], str]:
    """优先使用已保存的 evidence snapshot。

    这样即使 Wiktionary 当前内容已经变化, 也不会重新解释旧 inventory 里
    的 entry_id; 只有从未起草过 (没有 snapshot) 时才回退到实时抓取。
    """
    for path in (_evidence_path(word), _official_evidence_path(word)):
        if not path.exists():
            continue
        snapshot = yaml.safe_load(draft.read(path))
        if isinstance(snapshot, dict) and isinstance(snapshot.get("entries"), list):
            return snapshot["entries"], f"evidence snapshot ({_rel(path)})"
    entries = _fetch_entries(word, "validate")
    return entries, "实时词典抓取 (无 evidence snapshot)"


# ------------------------------------------------------------------ prompt

def _format_evidence(entries: list[dict]) -> str:
    lines = []
    for entry in entries:
        lines.append(f"- entry_id: {entry['entry_id']}")
        lines.append(f"  pos: {entry['pos']}")
        lines.append(f"  gloss: {entry['gloss']}")
        labels = ", ".join(entry.get("labels") or []) or "(none)"
        lines.append(f"  labels: [{labels}]")
        examples = entry.get("examples") or []
        if examples:
            lines.append("  examples:")
            for example in examples:
                lines.append(f"    - {example}")
        else:
            lines.append("  examples: []")
    return "\n".join(lines)


def _build_prompt(word: str, entries: list[dict], evidence_digest: str) -> str:
    template = draft.read(PROMPTS / "inventory-draft.md")
    schema = draft.read(ROOT / "schema" / SCHEMA_NAME)
    return (template
            .replace("{{SCHEMA}}", schema)
            .replace("{{WORD}}", word)
            .replace("{{ENTRY_COUNT}}", str(len(entries)))
            .replace("{{EVIDENCE_DIGEST}}", evidence_digest)
            .replace("{{DICTIONARY_EVIDENCE}}", _format_evidence(entries)))


# ------------------------------------------------------------------- I/O

def _unparsed_path(word: str) -> Path:
    return DRAFTS_INVENTORIES / f"_unparsed-{word}.yaml"


def _dump_unparsed(word: str, text: str) -> None:
    path = _unparsed_path(word)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _atomic_write_many(items: list[tuple[Path, str]]) -> None:
    """为多个路径各自准备临时文件, 全部就绪后依次 os.replace。

    起草需要同时更新 inventory 与 evidence snapshot 两个文件; 先把两份完整
    内容都写进各自的临时文件, 任何一步失败都不会有真实文件被替换, 最后再
    连续 os.replace, 把两次替换之间的窗口压到最短。
    """
    prepared: list[tuple[str, Path]] = []
    try:
        for path, text in items:
            path.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp_name = tempfile.mkstemp(
                dir=path.parent, prefix=f".{path.name}.", suffix=".tmp"
            )
            with os.fdopen(fd, "w", encoding="utf-8") as file:
                file.write(text)
            prepared.append((tmp_name, path))
        for tmp_name, path in prepared:
            os.replace(tmp_name, path)
    except Exception:
        for tmp_name, _ in prepared:
            Path(tmp_name).unlink(missing_ok=True)
        raise


def _atomic_write(path: Path, text: str) -> None:
    """临时文件 + os.replace, 保证单个文件写入是原子的。"""
    _atomic_write_many([(path, text)])


def _fetch_entries(word: str, stage: str) -> list[dict]:
    try:
        entries = dictionary.get_filtered_entries(word)
    except (LookupError, requests.RequestException) as exc:
        sys.exit(f"[{word}] {stage} 阶段获取词典证据失败: {exc}")
    if not entries:
        sys.exit(f"[{word}] {stage} 阶段没有可用词典证据 (标签过滤后为空)")
    return entries


# ---------------------------------------------------------------- draft

def cmd_draft(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    if not WORD_PATTERN.match(word):
        sys.exit(f"单词 '{word}' 含非法字符 (只允许小写字母和下划线)")

    out_path = DRAFTS_INVENTORIES / f"{word}.yaml"
    if out_path.exists() and not args.force:
        sys.exit(
            f"[{word}] draft 阶段失败: inventory 草稿已存在于 {_rel(out_path)}; "
            "使用 --force 覆盖"
        )

    print(f"→ 获取 '{word}' 的词典证据 ...", file=sys.stderr)
    entries = _fetch_entries(word, "draft")
    evidence_digest = compute_evidence_digest(entries)

    prompt = _build_prompt(word, entries, evidence_digest)
    print(f"→ 起草 '{word}' 的 sense inventory ({len(entries)} 条词典证据) ...",
          file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = draft.extract_yaml_blocks(raw)
    if not blocks:
        sys.exit(f"[{word}] draft 阶段失败: 模型未返回任何 YAML 内容")

    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as exc:
        _dump_unparsed(word, blocks[0])
        sys.exit(
            f"[{word}] draft 阶段 YAML 解析失败: {exc}; "
            f"原始输出已存 {_rel(_unparsed_path(word))}"
        )
    if not isinstance(doc, dict):
        _dump_unparsed(word, blocks[0])
        sys.exit(
            f"[{word}] draft 阶段失败: inventory 的 YAML 根节点必须是对象; "
            f"原始输出已存 {_rel(_unparsed_path(word))}"
        )

    # 不信任模型输出这些机器权威字段, 起草工具基于本次实际证据强制覆盖。
    _apply_machine_fields(doc, word, entries)

    errors = _all_errors(doc, entries, word)
    if errors:
        _dump_unparsed(word, blocks[0])
        print(
            f"[{word}] draft 阶段校验失败 ({len(errors)} 处), 原始输出已存 "
            f"{_rel(_unparsed_path(word))}:",
            file=sys.stderr,
        )
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    evidence_doc = _build_evidence_doc(word, entries)
    evidence_errors = draft.schema_check(
        evidence_doc, draft.load_schema(EVIDENCE_SCHEMA_NAME),
        f"{word}-dictionary-evidence.yaml",
    )
    if evidence_errors:
        # 由程序自行构造, 理论上不会触发; 出现即视为 draft 失败, 不带着
        # 损坏的 evidence snapshot 继续, 也不覆盖任何已有合法文件。
        _dump_unparsed(word, blocks[0])
        print(
            f"[{word}] draft 阶段失败: evidence snapshot 构造异常, "
            f"原始模型输出已存 {_rel(_unparsed_path(word))}:",
            file=sys.stderr,
        )
        for error in evidence_errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    # 两个文件都已在内存中完整构造并通过校验, 才依次原子替换; 校验失败的
    # 任何分支都在此之前退出, 不会有真实文件被改动。
    inventory_text = yaml.safe_dump(doc, allow_unicode=True, sort_keys=False)
    evidence_text = yaml.safe_dump(evidence_doc, allow_unicode=True, sort_keys=False)
    evidence_path = _evidence_path(word)
    _atomic_write_many([
        (evidence_path, evidence_text),
        (out_path, inventory_text),
    ])
    print(f"✓ dictionary evidence snapshot 已写入 {_rel(evidence_path)}")
    print(f"✓ inventory 草稿已写入 {_rel(out_path)}")


# ------------------------------------------------------------- validate

def _resolve_inventory_path(word: str) -> tuple[Path | None, str]:
    draft_path = DRAFTS_INVENTORIES / f"{word}.yaml"
    if draft_path.exists():
        return draft_path, "draft"
    official_path = INVENTORIES / f"{word}.yaml"
    if official_path.exists():
        return official_path, "official"
    return None, ""


def cmd_validate(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    path, source = _resolve_inventory_path(word)
    if path is None:
        sys.exit(
            f"[{word}] validate 阶段失败: 未找到 inventory "
            f"({_rel(DRAFTS_INVENTORIES / f'{word}.yaml')} / "
            f"{_rel(INVENTORIES / f'{word}.yaml')} 均不存在)"
        )

    try:
        doc = yaml.safe_load(draft.read(path))
    except yaml.YAMLError as exc:
        sys.exit(f"[{word}] validate 阶段 YAML 解析失败 ({_rel(path)}): {exc}")
    if not isinstance(doc, dict):
        sys.exit(f"[{word}] validate 阶段失败: {_rel(path)} 的 YAML 根节点必须是对象")

    entries, evidence_source = _entries_for_validation(word)
    errors = _all_errors(doc, entries, word)
    if errors:
        print(
            f"✗ [{word}] inventory 校验失败 ({len(errors)} 处, 来源 {_rel(path)}, "
            f"证据来源: {evidence_source}):",
            file=sys.stderr,
        )
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    print(
        f"✓ PASS [{word}] inventory 校验通过 "
        f"({source}, {_rel(path)}, 证据来源: {evidence_source})"
    )


# --------------------------------------------------- approved inventory 加载

def _read_yaml_mapping(path: Path, word: str, stage: str) -> dict:
    """读一个必须是 YAML 映射的文件; 任何失败都变成带 word/阶段的 InventoryError。"""
    try:
        text = draft.read(path)
    except OSError as exc:
        raise InventoryError(f"[{word}] {stage} 阶段读取 {_rel(path)} 失败: {exc}") from exc
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise InventoryError(
            f"[{word}] {stage} 阶段 YAML 解析失败 ({_rel(path)}): {exc}"
        ) from exc
    if not isinstance(doc, dict):
        raise InventoryError(
            f"[{word}] {stage} 阶段失败: {_rel(path)} 的 YAML 根节点必须是对象"
        )
    return doc


def _evidence_entries(doc: dict, path: Path, word: str, stage: str) -> list[dict]:
    entries = doc.get("entries")
    if not isinstance(entries, list):
        raise InventoryError(
            f"[{word}] {stage} 阶段失败: evidence snapshot {_rel(path)} 缺少 entries 列表"
        )
    return [entry for entry in entries if isinstance(entry, dict)]


def load_approved_evidence_entries(word: str) -> list[dict]:
    """读取正式 dictionary evidence snapshot; 只读文件, 绝不触网。"""
    path = _official_evidence_path(word)
    if not path.exists():
        raise InventoryError(
            f"[{word}] 缺少正式 dictionary evidence snapshot ({_rel(path)})。\n"
            f"它应由 tools/inventory.py approve {word} 写入; "
            "不要手工补写, 请重新走 approve 流程。"
        )
    doc = _read_yaml_mapping(path, word, "load-approved-evidence")
    return _evidence_entries(doc, path, word, "load-approved-evidence")


def load_approved_inventory(word: str) -> dict:
    """加载并全面校验某个词的 approved Sense Inventory。

    这是 WordSense 起草唯一的 inventory 入口: 只读 data/inventories/{word}.yaml,
    绝不回退到草稿, 绝不发网络请求。校验 schema、status、正式 evidence snapshot
    的存在性与 digest 一致性, 以及确定性引用完整性; 任何一项不通过都抛
    InventoryError, 不返回半可信的文档。
    """
    word = word.strip().lower()
    path = _official_inventory_path(word)
    if not path.exists():
        raise InventoryError(
            f"No approved Sense Inventory for '{word}' ({_rel(path)} 不存在)。\n"
            f"Draft one with tools/inventory.py draft {word},\n"
            "review it, then approve it before drafting WordSenses:\n"
            f"  python3 tools/inventory.py draft {word}\n"
            f"  python3 tools/inventory.py mark-reviewed {word}\n"
            f"  python3 tools/inventory.py approve {word}"
        )

    doc = _read_yaml_mapping(path, word, "load-approved-inventory")
    status = doc.get("status")
    if status != "approved":
        raise InventoryError(
            f"[{word}] load-approved-inventory 阶段失败: {_rel(path)} 的 status 是 "
            f"{status!r}, 只有 'approved' 的 inventory 可以驱动 WordSense 起草。"
        )

    entries = load_approved_evidence_entries(word)
    declared = (doc.get("source") or {}).get("evidence_digest")
    computed = compute_evidence_digest(entries)
    if declared != computed:
        raise InventoryError(
            f"[{word}] load-approved-inventory 阶段失败: evidence digest 不一致。\n"
            f"  inventory 声明: {declared!r}\n"
            f"  snapshot 计算: {computed!r}\n"
            f"正式 inventory 与 {_rel(_official_evidence_path(word))} 已经脱节, "
            "请重新 approve, 不要手工改摘要。"
        )

    errors = _all_errors(doc, entries, word)
    if errors:
        detail = "\n".join(errors)
        raise InventoryError(
            f"[{word}] load-approved-inventory 阶段失败: 正式 inventory 未通过校验 "
            f"({len(errors)} 处, {_rel(path)}):\n{detail}"
        )
    return doc


def find_inventory_sense(inventory_doc: dict, sense_id: str) -> dict | None:
    for sense in inventory_doc.get("senses") or []:
        if isinstance(sense, dict) and sense.get("id") == sense_id:
            return sense
    return None


def inventory_sense_ids(inventory_doc: dict) -> list[str]:
    return [
        sense["id"]
        for sense in inventory_doc.get("senses") or []
        if isinstance(sense, dict) and isinstance(sense.get("id"), str)
    ]


def relations_for_sense(inventory_doc: dict, sense_id: str) -> list[dict]:
    """与该 sense 相关的全部 inventory relations (作为 source 或 target)。"""
    return [
        relation
        for relation in inventory_doc.get("relations") or []
        if isinstance(relation, dict)
        and sense_id in (relation.get("source"), relation.get("target"))
    ]


# ----------------------------------------------- WordSense ↔ inventory 一致性

# 模型"没写"与"写错了"必须区别对待: 前者交给程序补全, 后者是模型对 CURRENT_SENSE
# 的理解与已批准 Inventory 冲突, 静默覆盖只会把这个误解藏进一份看似合法的草稿里。
_MISSING = object()


def _stated(container: object, field: str) -> object:
    """取模型明确写出的值; 只有 key 不存在才算"未表态"。

    显式的 null 是一次表态而不是沉默: `dimension: null` 是在断言该义项没有维度,
    与 Inventory 声明的 `dimension: rate` 直接冲突, 必须参与比较。把它当成缺失
    会让这类漂移被程序静默补成正确值。
    """
    if not isinstance(container, dict) or field not in container:
        return _MISSING
    return container[field]


def detect_identity_drift(
    raw_sense_doc: dict,
    inventory_doc: dict,
    inventory_sense: dict,
) -> list[tuple[str, object, object]]:
    """在程序覆盖机器字段之前, 检查模型原始输出是否误解了 CURRENT_SENSE。

    只看模型**明确写出**的字段: 省略的机器字段由起草工具补全 (那是簿记, 不是
    模型的语义判断); 写出来却与 approved Inventory 冲突的, 说明模型正在按另一个
    义项理解本次任务, 后续内容整体不可信 — 返回 (字段, expected, actual) 列表,
    由调用方判定为 identity_drift 并保留原始输出。

    不检查 inventory.* provenance: 那几个字段是摘要与版本号, 不表达模型对词义的
    理解, 缺失或写错都由程序按 Inventory 强制写入。
    """
    signature = inventory_sense.get("semantic_signature")
    signature = signature if isinstance(signature, dict) else {}
    drift: list[tuple[str, object, object]] = []

    # WordSense 用顶层 word 承载 lemma; 仓库中没有独立的 lemma 字段。
    scalar_checks = (
        ("id", inventory_sense.get("id"), _stated(raw_sense_doc, "id")),
        ("word (lemma)", inventory_sense.get("lemma"),
         _stated(raw_sense_doc, "word")),
        ("pos", inventory_sense.get("pos"), _stated(raw_sense_doc, "pos")),
    )
    for field, expected, actual in scalar_checks:
        if actual is not _MISSING and actual != expected:
            drift.append((field, expected, actual))

    identity = raw_sense_doc.get("semantic_identity")
    for field in IDENTITY_SIGNATURE_FIELDS:
        actual = _stated(identity, field)
        expected = signature.get(field)
        # dimension 可以合法地为 null。写了 null 就要比较: Inventory 说 rate 而
        # 模型说 null 是冲突, 两边都是 null 则一致。
        if actual is not _MISSING and actual != expected:
            drift.append((f"semantic_identity.{field}", expected, actual))

    stated_entries = _stated(raw_sense_doc, "inventory_source_entries")
    if stated_entries is not _MISSING:
        expected_entries = list(inventory_sense.get("source_entries") or [])
        if isinstance(stated_entries, list):
            if set(stated_entries) != set(expected_entries):
                drift.append(
                    ("inventory_source_entries", expected_entries, stated_entries)
                )
        else:
            drift.append(
                ("inventory_source_entries", expected_entries, stated_entries)
            )
    return drift


def validate_sense_against_inventory(
    sense_doc: dict,
    inventory_doc: dict,
    inventory_sense: dict,
) -> list[str]:
    """检查一份 WordSense 是否忠实于它所属的 approved inventory sense。

    只做确定性的身份检查: ID / lemma / pos / 语义身份 / inventory provenance /
    source entry 集合 / 跨义项引用真实性 / relation 方向与类型。不判断措辞好坏,
    也不在这里重构 relation 本体 (留给后续的 cross-sense 校验 PR)。
    """
    errors: list[str] = []
    sense_id = inventory_sense.get("id")
    label = sense_id or "?"
    all_ids = set(inventory_sense_ids(inventory_doc))

    # 1: ID
    if sense_doc.get("id") != sense_id:
        errors.append(
            f"[{label}] id 不一致: WordSense 为 {sense_doc.get('id')!r}, "
            f"approved inventory 为 {sense_id!r}"
        )

    # 2: lemma (WordSense 用 word 字段承载 lemma)
    lemma = inventory_sense.get("lemma")
    if sense_doc.get("word") != lemma:
        errors.append(
            f"[{label}] word/lemma 不一致: WordSense 为 {sense_doc.get('word')!r}, "
            f"approved inventory sense 为 {lemma!r}"
        )
    if lemma != inventory_doc.get("word"):
        errors.append(
            f"[{label}] approved inventory 自身不一致: sense lemma {lemma!r} "
            f"与顶层 word {inventory_doc.get('word')!r} 不同"
        )

    # 3: POS
    if sense_doc.get("pos") != inventory_sense.get("pos"):
        errors.append(
            f"[{label}] pos 不一致: WordSense 为 {sense_doc.get('pos')!r}, "
            f"approved inventory 为 {inventory_sense.get('pos')!r}"
        )

    # 4: 语义身份 (逐字段比较, 不做任何等价换算)
    raw_signature = inventory_sense.get("semantic_signature")
    signature = raw_signature if isinstance(raw_signature, dict) else {}
    raw_identity = sense_doc.get("semantic_identity")
    if not isinstance(raw_identity, dict):
        errors.append(
            f"[{label}] 缺少 semantic_identity: inventory-driven WordSense 必须"
            "结构化复制 approved inventory 的 semantic_signature"
        )
    else:
        for field in IDENTITY_SIGNATURE_FIELDS:
            if raw_identity.get(field) != signature.get(field):
                errors.append(
                    f"[{label}] semantic_identity.{field} 不一致: WordSense 为 "
                    f"{raw_identity.get(field)!r}, approved inventory 为 "
                    f"{signature.get(field)!r}"
                )

    # 5: inventory provenance
    raw_provenance = sense_doc.get("inventory")
    if not isinstance(raw_provenance, dict):
        errors.append(f"[{label}] 缺少 inventory provenance 对象")
    else:
        expected = {
            "word": inventory_doc.get("word"),
            "version": inventory_doc.get("inventory_version"),
            "evidence_digest": (inventory_doc.get("source") or {}).get(
                "evidence_digest"
            ),
            "sense_id": sense_id,
            "identity_digest": compute_identity_digest(inventory_sense),
        }
        for field, want in expected.items():
            if raw_provenance.get(field) != want:
                errors.append(
                    f"[{label}] inventory.{field} 不一致: WordSense 为 "
                    f"{raw_provenance.get(field)!r}, 期望 {want!r}"
                )
        if raw_provenance.get("sense_id") != sense_doc.get("id"):
            errors.append(
                f"[{label}] inventory.sense_id 与 WordSense 顶层 id 不一致"
            )

    # 6: source entries 必须与 inventory 完全一致, 不能少也不能多
    declared = sense_doc.get("inventory_source_entries")
    if not isinstance(declared, list):
        errors.append(f"[{label}] 缺少 inventory_source_entries 列表")
    else:
        want_entries = set(inventory_sense.get("source_entries") or [])
        got_entries = set(declared)
        missing = sorted(want_entries - got_entries)
        extra = sorted(got_entries - want_entries)
        if missing:
            errors.append(
                f"[{label}] inventory_source_entries 缺少 approved inventory 的条目: "
                f"{', '.join(missing)}"
            )
        if extra:
            errors.append(
                f"[{label}] inventory_source_entries 出现 approved inventory 中没有的"
                f"条目: {', '.join(extra)}"
            )

    # 7: 所有跨义项引用只能落在 ALL_SENSES 内, 默认禁止自引用
    errors += _cross_reference_errors(sense_doc, label, all_ids)

    # 8: relation 方向与类型必须与 inventory 一致 (WordSense 不必复制全部关系)
    errors += _boundary_relation_errors(sense_doc, inventory_doc, label)
    return errors


# 默认禁止自引用。唯一例外是 l1_confusables 的 covers: 它回答"这个 L1 词覆盖了
# 哪几个 L2 义项", 当前义项本来就应该在列表里, 否则这条混淆记录不成立。
SELF_REFERENCE_OK = "relations.l1_confusables."


def _cross_reference_errors(
    sense_doc: dict, label: str, all_ids: set[str]
) -> list[str]:
    errors: list[str] = []
    relations = sense_doc.get("relations")
    relations = relations if isinstance(relations, dict) else {}
    own_id = sense_doc.get("id")

    references: list[tuple[str, object]] = []
    for key in ("synonyms", "antonyms", "hypernyms", "hyponyms", "confusables"):
        for reference in relations.get(key) or []:
            references.append((f"relations.{key}", reference))
    for boundary in relations.get("boundaries") or []:
        if isinstance(boundary, dict):
            references.append(("relations.boundaries.target", boundary.get("target")))
    for language, items in (relations.get("l1_confusables") or {}).items():
        for item in items or []:
            if isinstance(item, dict):
                for reference in item.get("covers") or []:
                    references.append(
                        (f"relations.l1_confusables.{language}.covers", reference)
                    )
    for excluded in (sense_doc.get("conditions") or {}).get("excluded") or []:
        if isinstance(excluded, dict) and excluded.get("alternative"):
            references.append(("conditions.excluded.alternative",
                               excluded.get("alternative")))

    for field, reference in references:
        if not isinstance(reference, str):
            continue
        # 只约束同一个词内部的引用: 跨词引用 (如 dirty-01 → messy-01) 由
        # tools/validate.py 的悬空引用 backlog 负责, 不是 inventory 的权威范围。
        word_prefix = reference.rsplit("-", 1)[0]
        if word_prefix != sense_doc.get("word"):
            continue
        if reference not in all_ids:
            errors.append(
                f"[{label}] {field} 引用 '{reference}', 但它不在 approved inventory "
                f"的 senses 中 (可用: {', '.join(sorted(all_ids)) or '(空)'})"
            )
        elif reference == own_id and not field.startswith(SELF_REFERENCE_OK):
            errors.append(f"[{label}] {field} 不允许引用自身 '{reference}'")
    return errors


def _boundary_relation_errors(
    sense_doc: dict, inventory_doc: dict, label: str
) -> list[str]:
    """WordSense 复制 inventory relation 时, 方向与类型必须一致。

    WordSense 的 boundary 词汇表 (mutually_exclusive 等) 与 inventory 的自由
    relation 字符串不是同一套本体, 因此只在两边使用了同名 relation 时比较方向,
    不强行做跨本体映射 — 那属于后续的 cross-sense 校验。
    """
    errors: list[str] = []
    own_id = sense_doc.get("id")
    inventory_relations = [
        relation for relation in inventory_doc.get("relations") or []
        if isinstance(relation, dict)
    ]
    known_types = {relation.get("relation") for relation in inventory_relations}
    directed = {
        (relation.get("source"), relation.get("target"), relation.get("relation"))
        for relation in inventory_relations
    }

    relations = sense_doc.get("relations")
    relations = relations if isinstance(relations, dict) else {}
    for boundary in relations.get("boundaries") or []:
        if not isinstance(boundary, dict):
            continue
        relation_type = boundary.get("relation")
        target = boundary.get("target")
        if relation_type not in known_types:
            continue
        if (own_id, target, relation_type) in directed:
            continue
        if (target, own_id, relation_type) in directed:
            errors.append(
                f"[{label}] boundary 对 '{target}' 使用了 approved inventory 中方向"
                f"相反的 relation '{relation_type}' (inventory 记录的是 "
                f"{target} → {own_id})"
            )
        else:
            errors.append(
                f"[{label}] boundary 声称与 '{target}' 存在 relation "
                f"'{relation_type}', 但 approved inventory 没有这条关系; "
                "跨义项权威关系只能在 inventory 中建立"
            )
    return errors


# --------------------------------------------------------- mark-reviewed

def _validated_draft(
    word: str, stage: str, entries: list[dict] | None = None
) -> tuple[dict, Path, list[dict]]:
    """读取并全量校验 draft inventory, 返回 (doc, path, entries)。

    调用方可以传入已经确定的证据条目 (approve 必须如此), 这样即使没有 snapshot
    也绝不会退回实时抓取。
    """
    path = DRAFTS_INVENTORIES / f"{word}.yaml"
    if not path.exists():
        sys.exit(
            f"[{word}] {stage} 阶段失败: 未找到 inventory 草稿 ({_rel(path)}); "
            f"先运行 python3 tools/inventory.py draft {word}"
        )
    try:
        doc = _read_yaml_mapping(path, word, stage)
    except InventoryError as exc:
        sys.exit(str(exc))

    if entries is None:
        entries, evidence_source = _entries_for_validation(word)
    else:
        evidence_source = f"evidence snapshot ({_rel(_evidence_path(word))})"
    errors = _all_errors(doc, entries, word)
    if errors:
        print(
            f"✗ [{word}] {stage} 阶段校验失败 ({len(errors)} 处, 来源 {_rel(path)}, "
            f"证据来源: {evidence_source}):",
            file=sys.stderr,
        )
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)
    return doc, path, entries


def cmd_mark_reviewed(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    doc, path, _ = _validated_draft(word, "mark-reviewed")

    current = doc.get("status")
    if current == "reviewed":
        print(f"✓ [{word}] inventory 草稿已经是 reviewed ({_rel(path)}), 无需改动")
        return
    if current != "draft":
        sys.exit(
            f"[{word}] mark-reviewed 阶段失败: 当前 status 是 {current!r}, "
            "只有 'draft' 可以被标记为 reviewed"
        )

    doc["status"] = "reviewed"
    _atomic_write(path, yaml.safe_dump(doc, allow_unicode=True, sort_keys=False))
    print(f"✓ [{word}] inventory 草稿已标记为 reviewed → {_rel(path)}")
    print(f"  下一步: python3 tools/inventory.py approve {word}")


# ---------------------------------------------------------------- approve

def _identity_map(doc: dict) -> dict[str, str]:
    return {
        sense["id"]: compute_identity_digest(sense)
        for sense in doc.get("senses") or []
        if isinstance(sense, dict) and isinstance(sense.get("id"), str)
    }


def _identity_changes(existing: dict, incoming: dict) -> list[str]:
    """比较两版 inventory 的锁定身份, 返回人类可读的变化清单。"""
    before, after = _identity_map(existing), _identity_map(incoming)
    changes: list[str] = []
    if existing.get("word") != incoming.get("word"):
        changes.append(
            f"顶层 word: {existing.get('word')!r} → {incoming.get('word')!r}"
        )
    for sense_id in sorted(set(before) - set(after)):
        changes.append(f"sense '{sense_id}' 被删除")
    for sense_id in sorted(set(after) - set(before)):
        changes.append(f"sense '{sense_id}' 是新增的")
    for sense_id in sorted(set(before) & set(after)):
        if before[sense_id] != after[sense_id]:
            old = identity_payload(
                find_inventory_sense(existing, sense_id) or {}
            )
            new = identity_payload(
                find_inventory_sense(incoming, sense_id) or {}
            )
            changes.append(f"sense '{sense_id}' 语义身份变化: {old} → {new}")
    return changes


def _guard_overwrite(word: str, doc: dict, target: Path) -> None:
    """--force 覆盖已有 approved inventory 时的身份保护。

    已批准的 sense ID 是对外稳定引用: 身份改变必须伴随 inventory_version 提升,
    否则同一个 ID 会被静默重新解释, 已生成的 WordSense 无从察觉。本 PR 只拦截,
    不做自动版本迁移。
    """
    try:
        existing = _read_yaml_mapping(target, word, "approve")
    except InventoryError as exc:
        sys.exit(f"{exc}\n无法解析已有正式 inventory, 拒绝覆盖。")

    changes = _identity_changes(existing, doc)
    if not changes:
        return

    old_version = existing.get("inventory_version")
    new_version = doc.get("inventory_version")
    print(f"⚠ [{word}] approve --force 会改变已批准的语义身份:", file=sys.stderr)
    for change in changes:
        print(f"    - {change}", file=sys.stderr)
    if not isinstance(new_version, int) or not isinstance(old_version, int) \
            or new_version <= old_version:
        sys.exit(
            f"[{word}] approve 阶段失败: 语义身份已改变, 但 inventory_version 仍是 "
            f"{new_version!r} (已批准版本为 {old_version!r})。\n"
            "请先在草稿中提升 inventory_version, 再重新 approve; "
            "本工具不做自动版本迁移。"
        )
    print(
        f"⚠ [{word}] inventory_version {old_version} → {new_version}: 已批准的 sense "
        "身份被改写。引用旧身份的 WordSense 需要重新起草或人工复核。",
        file=sys.stderr,
    )


def cmd_approve(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    if not WORD_PATTERN.match(word):
        sys.exit(f"单词 '{word}' 含非法字符 (只允许小写字母和下划线)")

    # approve 是完全离线的: 证据只能来自已冻结的 snapshot, 绝不回退到实时抓取,
    # 否则批准的含义会随 Wiktionary 当前内容漂移。
    evidence_draft_path = _evidence_path(word)
    if not evidence_draft_path.exists():
        sys.exit(
            f"[{word}] approve 阶段失败: 缺少 dictionary evidence snapshot "
            f"({_rel(evidence_draft_path)}); 请重新运行 inventory draft"
        )
    try:
        evidence_doc = _read_yaml_mapping(evidence_draft_path, word, "approve")
        snapshot_entries = _evidence_entries(
            evidence_doc, evidence_draft_path, word, "approve"
        )
    except InventoryError as exc:
        sys.exit(str(exc))

    evidence_errors = draft.schema_check(
        evidence_doc, draft.load_schema(EVIDENCE_SCHEMA_NAME),
        f"{word}-dictionary-evidence.yaml",
    )
    if evidence_errors:
        print(f"✗ [{word}] approve 阶段失败: evidence snapshot 未通过 schema 校验:",
              file=sys.stderr)
        for error in evidence_errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    # --force 只放宽"目标已存在"这一条, 校验一律照跑。
    doc, draft_path, _ = _validated_draft(word, "approve", snapshot_entries)

    status = doc.get("status")
    if status != "reviewed":
        sys.exit(
            f"[{word}] approve 阶段失败: 草稿 status 是 {status!r}, "
            "只有 'reviewed' 的 inventory 可以批准。\n"
            f"先人工审阅, 再运行 python3 tools/inventory.py mark-reviewed {word}"
        )

    declared = (doc.get("source") or {}).get("evidence_digest")
    computed = compute_evidence_digest(snapshot_entries)
    if declared != computed:
        sys.exit(
            f"[{word}] approve 阶段失败: evidence digest 不一致。\n"
            f"  inventory 声明: {declared!r}\n"
            f"  snapshot 计算: {computed!r}\n"
            f"草稿与 {_rel(evidence_draft_path)} 已脱节, 请重新起草而不是手工改摘要。"
        )

    target = _official_inventory_path(word)
    evidence_target = _official_evidence_path(word)
    if target.exists() and not args.force:
        sys.exit(
            f"[{word}] approve 阶段失败: 正式 inventory 已存在于 {_rel(target)}; "
            "拒绝静默覆盖 (确需覆盖用 --force, 校验不会被跳过)"
        )
    if target.exists():
        _guard_overwrite(word, doc, target)

    # status 是机器权威字段: 由 approve 程序化设定, 不信任草稿里写了什么。
    approved = dict(doc)
    approved["status"] = "approved"

    approved_errors = _all_errors(approved, snapshot_entries, word)
    if approved_errors:
        # 只改了 status, 理论上不会触发; 出现即视为 approve 失败, 不写正式库。
        print(f"✗ [{word}] approve 阶段失败: 批准后的文档未通过复校验:",
              file=sys.stderr)
        for error in approved_errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    _atomic_write_many([
        (evidence_target, yaml.safe_dump(
            evidence_doc, allow_unicode=True, sort_keys=False)),
        (target, yaml.safe_dump(approved, allow_unicode=True, sort_keys=False)),
    ])
    print(f"✓ dictionary evidence snapshot 已批准 → {_rel(evidence_target)}")
    print(f"✓ inventory 已批准 → {_rel(target)} (status: approved)")
    print(f"  草稿保留在 {_rel(draft_path)} 供审计; approve 不生成 WordSense。")
    ids = ", ".join(inventory_sense_ids(approved)) or "(无)"
    print(f"  可起草的 sense: {ids}")
    print(f"  下一步: python3 tools/draft.py senses {word}")


# ------------------------------------------------------------------ show

def cmd_show(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    path, source = _resolve_inventory_path(word)
    if path is None:
        sys.exit(f"[{word}] show 阶段失败: 未找到 inventory")
    print(f"# {source}: {_rel(path)}")
    print(draft.read(path))


def main() -> None:
    parser = argparse.ArgumentParser(description="SceneLex 整词级 Sense Inventory 工具")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("draft", help="起草整词 sense inventory + evidence snapshot")
    p.add_argument("word")
    p.add_argument("--force", action="store_true", help="覆盖已存在的 draft 文件")
    p.set_defaults(func=cmd_draft)

    p = sub.add_parser("validate", help="校验 sense inventory (draft 优先, 否则正式库)")
    p.add_argument("word")
    p.set_defaults(func=cmd_validate)

    p = sub.add_parser("mark-reviewed",
                       help="校验通过后把 inventory 草稿标记为 reviewed")
    p.add_argument("word")
    p.set_defaults(func=cmd_mark_reviewed)

    p = sub.add_parser(
        "approve",
        help="把 reviewed 草稿批准为正式 inventory + 正式 evidence snapshot",
    )
    p.add_argument("word")
    p.add_argument("--force", action="store_true",
                   help="覆盖已存在的正式 inventory (仍执行全部校验)")
    p.set_defaults(func=cmd_approve)

    p = sub.add_parser("show", help="查看 sense inventory 原始内容, 不修改文件")
    p.add_argument("word")
    p.set_defaults(func=cmd_show)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
