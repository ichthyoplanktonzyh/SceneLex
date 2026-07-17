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


def prompt_block(word: str) -> str:
    """生成注入起草 prompt 的词典事实块; 拿不到数据时明确说明。"""
    try:
        f = facts(word)
    except (requests.RequestException, LookupError, json.JSONDecodeError) as exc:
        return (f"(未能获取 '{word}' 的词典事实: {exc}。"
                "请保守起草, 音标与义项划分需人工重点复核。)")
    lines = [f"word: {f['word']}"]
    if f["ipa"]:
        lines.append(f"IPA: {', '.join(f['ipa'])}")
    lines.append("词性与义项清单 (义项划分的参照系, 释义不得照抄):")
    for pos, glosses in f["pos_senses"].items():
        lines.append(f"- {pos}:")
        for i, gloss in enumerate(glosses[:8], 1):
            lines.append(f"    {i}. {gloss}")
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
