#!/usr/bin/env python3
"""SceneLex 整词级 Sense Inventory 工具 — 管线新增的规划阶段。

Wiktionary 条目是 dictionary evidence; Sense Inventory 才决定 SceneLex 接受
哪些稳定、可教学的 sense, 以及它们的 ID。本工具只建立 drafts 与校验基础,
不实现 approve/promote, 不改变现有 sense/scene 起草流程。

起草时会同时保存一份本次实际使用的 dictionary evidence snapshot
(data/drafts/dictionary-evidence/{word}.yaml), 并把对它计算的确定性摘要写入
inventory 的 source.evidence_digest。这样 entry_id 的含义被冻结在起草当时,
之后 Wiktionary 内容变化不会让已有 inventory 里的旧 entry_id 被静默重新解释;
validate 时优先读取 snapshot, 没有 snapshot 才回退到实时抓取。

用法:
    python3 tools/inventory.py draft slow            # 起草整词 inventory + evidence snapshot
    python3 tools/inventory.py draft slow --force     # 覆盖已存在的 draft
    python3 tools/inventory.py validate slow          # 校验 (draft 优先, 否则正式库)
    python3 tools/inventory.py show slow              # 查看原始内容, 不修改文件

草稿一律落在 data/drafts/inventories/; data/inventories/ 是未来批准后的
权威目录, 本 PR 不实现自动写入。
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
SCHEMA_NAME = "sense-inventory.schema.json"
EVIDENCE_SCHEMA_NAME = "dictionary-evidence.schema.json"
WORD_PATTERN = re.compile(r"^[a-z][a-z_]*$")

# 当前唯一支持的词典来源与语言; 仓库尚无多语言词典事实来源机制,
# 不为此提前设计枚举或配置项。
EVIDENCE_PROVIDER = "wiktionary"
SUPPORTED_LANGUAGE = "en"


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


def _load_evidence_snapshot(word: str) -> dict | None:
    path = _evidence_path(word)
    if not path.exists():
        return None
    doc = yaml.safe_load(draft.read(path))
    return doc if isinstance(doc, dict) else None


def _entries_for_validation(word: str) -> tuple[list[dict], str]:
    """优先使用已保存的 evidence snapshot。

    这样即使 Wiktionary 当前内容已经变化, 也不会重新解释旧 inventory 里
    的 entry_id; 只有从未起草过 (没有 snapshot) 时才回退到实时抓取。
    """
    snapshot = _load_evidence_snapshot(word)
    if snapshot is not None:
        snapshot_entries = snapshot.get("entries")
        if isinstance(snapshot_entries, list):
            return snapshot_entries, f"evidence snapshot ({_rel(_evidence_path(word))})"
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

    p = sub.add_parser("show", help="查看 sense inventory 原始内容, 不修改文件")
    p.add_argument("word")
    p.set_defaults(func=cmd_show)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
