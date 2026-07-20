#!/usr/bin/env python3
"""Wiktionary 词典事实源适配器。

角色定位 (与 AGENT.md 一致):
- 词典事实是起草与审核的**事实锚点** (word / pos / IPA / 义项清单),
  不是内容来源——SceneLex 的语义骨架与释义必须自行撰写, 不抄词典原文。
- 数据来自 kaikki.org 对 Wiktionary 的机器解析 (CC-BY-SA), 逐词在线获取并
  缓存到 data/dictionary/wiktionary/; 缓存文件保留原始数据与署名信息。

用法:
    python3 tools/dictionary.py <word>            # 查看事实摘要
    python3 tools/dictionary.py <word> --refresh  # 强制重新抓取
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = ROOT / "data" / "dictionary" / "wiktionary"
KAIKKI_URL = ("https://kaikki.org/dictionary/English/meaning/"
              "{a}/{ab}/{word}.jsonl")
LICENSE_NOTE = "Wiktionary via kaikki.org, CC-BY-SA 3.0/4.0"
TIMEOUT = 30
# 教学词库关心的词类; 其余 (缩写、专名等) 摘要时忽略
POS_KEEP = {"noun", "verb", "adj", "adjective", "adv", "adverb", "prep",
            "preposition", "conj", "conjunction", "pron", "pronoun",
            "det", "determiner", "intj", "interjection", "num", "particle"}
# 标记了这些标签的义项不适合核心教学词汇
EXCLUDE_TAGS = {"obsolete", "archaic", "rare", "dated", "poetic", "dialectal",
                "nonstandard", "humorous", "slang"}
# 义项显示优先级（按词性）
POS_ORDER = {"verb": 0, "noun": 1, "adj": 2, "adjective": 2,
             "adv": 3, "adverb": 3, "prep": 4, "conj": 5,
             "det": 6, "pron": 7, "intj": 8, "particle": 9}
# 核心教学词汇义项上限（超过此数的词取前 N 个最常用义项）
MAX_TEACHABLE_SENSES = 8


def _example_texts(raw_examples: Any) -> list[str]:
    """把词典用例统一成纯文本。

    kaikki 的用例是对象 ({text, type, bold_text_offsets, ref, ...}), 但下游
    (inventory 提示词、evidence snapshot、evidence digest) 消费的是句子本身。
    偏移量与 ref 是排版信息, 不是语义证据, 丢弃它们不损失词义判据。少数早期
    条目直接就是字符串, 一并接受; 没有 text 的对象没有可用证据, 直接跳过。
    """
    texts: list[str] = []
    for example in raw_examples or []:
        if isinstance(example, str):
            text = example
        elif isinstance(example, dict):
            text = example.get("text") or ""
        else:
            continue
        text = " ".join(str(text).split())
        if text:
            texts.append(text)
    return texts


def teachable_senses(word: str, refresh: bool = False) -> list[dict]:
    """返回该词所有值得教学的义项列表，已按优先级编号。

    每条义项包含:
      - pos: 词性
      - glosses: 释义列表
      - tags: 标签列表（语法标记如 transitive，已排除 obsolete 等）
      - examples: 用例（最多2条）
      - has_raw: 是否有 raw_glosses（需要人工复核）
    """
    entries = fetch(word, refresh)
    senses: list[dict] = []
    seen_gloss: set[str] = set()

    sorted_entries = sorted(
        entries,
        key=lambda e: POS_ORDER.get(e.get("pos", ""), 99),
    )

    for entry in sorted_entries:
        pos = entry.get("pos", "")
        if pos not in POS_KEEP:
            continue
        for raw_sense in entry.get("senses") or []:
            tags = set(raw_sense.get("tags") or [])
            if EXCLUDE_TAGS & tags:
                continue
            glosses = raw_sense.get("glosses") or []
            if not glosses:
                continue
            key = "; ".join(glosses).strip()
            if not key or key in seen_gloss:
                continue
            seen_gloss.add(key)
            senses.append({
                "pos": pos,
                "glosses": glosses,
                "tags": sorted(tags - EXCLUDE_TAGS),
                "examples": _example_texts(raw_sense.get("examples"))[:2],
                "has_raw": "raw_glosses" in raw_sense,
            })

    return senses[:MAX_TEACHABLE_SENSES]


def get_filtered_entries(word: str, refresh: bool = False) -> list[dict[str, Any]]:
    """结构化的、经当前标签过滤的词典证据条目，供 Sense Inventory 层消费。

    与 teachable_senses() 使用同一套过滤规则 (POS_KEEP + EXCLUDE_TAGS + 去重 +
    MAX_TEACHABLE_SENSES 截断)，只是换成 inventory 层需要的字段形状，并按
    当前过滤后条目顺序生成稳定的 entry_id (不使用随机 hash，不与 SceneLex
    sense ID 混用)。
    """
    word = word.strip().lower()
    senses = teachable_senses(word, refresh)
    return [
        {
            "entry_id": f"{word}-dict-{i:03d}",
            "pos": sense["pos"],
            "gloss": "; ".join(sense["glosses"]),
            "labels": sense["tags"],
            "examples": sense["examples"],
        }
        for i, sense in enumerate(senses, 1)
    ]


def sense_count(word: str) -> int:
    """该词有几个可教学义项。"""
    try:
        return len(teachable_senses(word))
    except (LookupError, requests.RequestException):
        return 1  # 拿不到数据时保守估计至少 1 个


def source_url(word: str) -> str:
    return KAIKKI_URL.format(a=word[0], ab=word[:2], word=word)


def _cache_path(word: str) -> Path:
    return CACHE_DIR / f"{word}.jsonl"


def fetch(word: str, refresh: bool = False) -> list[dict[str, Any]]:
    """取一个词的全部 Wiktionary 词条 (每词性一条), 带本地缓存。"""
    word = word.strip().lower()
    cache = _cache_path(word)
    if cache.exists() and not refresh:
        text = cache.read_text(encoding="utf-8")
    else:
        response = requests.get(source_url(word), timeout=TIMEOUT)
        if response.status_code == 404:
            raise LookupError(f"Wiktionary 无词条: {word}")
        response.raise_for_status()
        text = response.text
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache.write_text(text, encoding="utf-8")
    entries = []
    for line in text.splitlines():
        line = line.strip()
        if line:
            entries.append(json.loads(line))
    return entries


def facts(word: str, refresh: bool = False) -> dict[str, Any]:
    """把原始词条摘要成起草需要的事实锚点。"""
    entries = fetch(word, refresh)
    ipas: list[str] = []
    pos_senses: dict[str, list[str]] = {}
    for entry in entries:
        pos = entry.get("pos", "")
        for sound in entry.get("sounds") or []:
            ipa = sound.get("ipa")
            if ipa and ipa not in ipas:
                ipas.append(ipa)
        if pos not in POS_KEEP:
            continue
        glosses = pos_senses.setdefault(pos, [])
        for sense in entry.get("senses") or []:
            gloss = "; ".join(sense.get("glosses") or [])
            tags = sense.get("tags") or []
            if not gloss or any(t in ("obsolete", "archaic") for t in tags):
                continue
            if gloss not in glosses:
                glosses.append(gloss)
    return {
        "word": word,
        "ipa": ipas[:4],
        "pos_senses": pos_senses,
        "source": source_url(word),
        "license": LICENSE_NOTE,
    }


def cached_facts(word: str) -> dict[str, Any] | None:
    """只读缓存, 不触网 (供校验器等离线消费者使用)。"""
    if not _cache_path(word.strip().lower()).exists():
        return None
    return facts(word)


def prompt_block(word: str, sense_num: str | None = None) -> str:
    """生成注入起草 prompt 的词典事实块; 若指定 sense_num 则只展示对应义项。"""
    try:
        senses = teachable_senses(word)
        f = facts(word)
    except (requests.RequestException, LookupError, json.JSONDecodeError) as exc:
        return (f"(未能获取 '{word}' 的词典事实: {exc}。"
                "请保守起草, 音标与义项划分需人工重点复核。)")
    lines = [f"word: {f['word']}"]
    if f["ipa"]:
        lines.append(f"IPA: {', '.join(f['ipa'])}")
    if sense_num:
        idx = int(sense_num) - 1
        if 0 <= idx < len(senses):
            lines.append(f"义项 {sense_num}/{len(senses)} (当前起草目标):")
            s = senses[idx]
            gloss = "; ".join(s["glosses"][:1])
            tag_str = f" [{', '.join(s['tags'])}]" if s["tags"] else ""
            lines.append(f"  [{s['pos']}{tag_str}] {gloss}")
    else:
        lines.append(f"义项清单 (共 {len(senses)} 个可教学义项):")
        for i, s in enumerate(senses, 1):
            gloss = "; ".join(s["glosses"][:1])
            tag_str = f" [{', '.join(s['tags'])}]" if s["tags"] else ""
            lines.append(f"  {i:02d}. [{s['pos']}{tag_str}] {gloss}")
    lines.append(f"来源: {f['source']} ({f['license']})")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="查询 Wiktionary 词典事实")
    parser.add_argument("word")
    parser.add_argument("--refresh", action="store_true", help="忽略缓存重新抓取")
    args = parser.parse_args()
    print(prompt_block(args.word) if not args.refresh
          else (fetch(args.word, refresh=True) and prompt_block(args.word)))


if __name__ == "__main__":
    main()
