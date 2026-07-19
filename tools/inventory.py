#!/usr/bin/env python3
"""SceneLex 整词级 Sense Inventory 工具 — 管线新增的规划阶段。

Wiktionary 条目是 dictionary evidence; Sense Inventory 才决定 SceneLex 接受
哪些稳定、可教学的 sense, 以及它们的 ID。本工具只建立 drafts 与校验基础,
不实现 approve/promote, 不改变现有 sense/scene 起草流程。

用法:
    python3 tools/inventory.py draft slow            # 起草整词 inventory
    python3 tools/inventory.py draft slow --force     # 覆盖已存在的 draft
    python3 tools/inventory.py validate slow          # 校验 (draft 优先, 否则正式库)
    python3 tools/inventory.py show slow              # 查看原始内容, 不修改文件

草稿一律落在 data/drafts/inventories/; data/inventories/ 是未来批准后的
权威目录, 本 PR 不实现自动写入。
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from collections import defaultdict
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
SCHEMA_NAME = "sense-inventory.schema.json"
WORD_PATTERN = re.compile(r"^[a-z][a-z_]*$")


def _rel(path: Path) -> str:
    """尽量输出相对 ROOT 的路径; 测试中重定向到 ROOT 之外的目录时仍可读。"""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _sense_number(word: str, sense_id: str) -> int | None:
    match = re.fullmatch(rf"^{re.escape(word)}-([0-9]{{2}})$", sense_id or "")
    return int(match.group(1)) if match else None


def validate_inventory_content(doc: dict, entries: list[dict], word: str) -> list[str]:
    """确定性引用完整性检查, 独立于 JSON Schema。

    见 AGENT.md/PR 说明的 9 类检查: ID 唯一/前缀/连续编号、relation 引用、
    source entry 引用真实性、split 一致性、used/deferred 冲突、未处理条目、
    空定义与空理由。
    """
    errors: list[str] = []
    senses = [s for s in (doc.get("senses") or []) if isinstance(s, dict)]
    deferred = [d for d in (doc.get("deferred_entries") or []) if isinstance(d, dict)]
    relations = [r for r in (doc.get("relations") or []) if isinstance(r, dict)]

    entry_ids = {e["entry_id"] for e in entries if isinstance(e, dict) and e.get("entry_id")}

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
    seen_pairs: set[tuple[str | None, str | None]] = set()
    for rel in relations:
        source, target = rel.get("source"), rel.get("target")
        if source not in sense_ids:
            errors.append(f"relation source '{source}' 不在当前 inventory 的 senses 中")
        if target not in sense_ids:
            errors.append(f"relation target '{target}' 不在当前 inventory 的 senses 中")
        if source is not None and source == target:
            errors.append(f"relation 不允许 self relation: '{source}'")
        pair = (source, target)
        if pair in seen_pairs:
            errors.append(f"relation ({source} → {target}) 重复")
        else:
            seen_pairs.add(pair)

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


def _build_prompt(word: str, entries: list[dict]) -> str:
    template = draft.read(PROMPTS / "inventory-draft.md")
    schema = draft.read(ROOT / "schema" / SCHEMA_NAME)
    return (template
            .replace("{{SCHEMA}}", schema)
            .replace("{{WORD}}", word)
            .replace("{{ENTRY_COUNT}}", str(len(entries)))
            .replace("{{DICTIONARY_EVIDENCE}}", _format_evidence(entries)))


def _unparsed_path(word: str) -> Path:
    return DRAFTS_INVENTORIES / f"_unparsed-{word}.yaml"


def _dump_unparsed(word: str, text: str) -> None:
    path = _unparsed_path(word)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _atomic_write(path: Path, text: str) -> None:
    """临时文件 + os.replace, 保证 draft 写入是原子的。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(text)
        os.replace(tmp_name, path)
    except Exception:
        Path(tmp_name).unlink(missing_ok=True)
        raise


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

    prompt = _build_prompt(word, entries)
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

    _atomic_write(out_path, blocks[0].rstrip() + "\n")
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

    entries = _fetch_entries(word, "validate")
    errors = _all_errors(doc, entries, word)
    if errors:
        print(
            f"✗ [{word}] inventory 校验失败 ({len(errors)} 处, 来源 {_rel(path)}):",
            file=sys.stderr,
        )
        for error in errors:
            print(error, file=sys.stderr)
        sys.exit(1)

    print(f"✓ PASS [{word}] inventory 校验通过 ({source}, {_rel(path)})")


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

    p = sub.add_parser("draft", help="起草整词 sense inventory")
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
