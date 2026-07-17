#!/usr/bin/env python3
"""SceneLex 扩产候选队列 — 决定"下一个建什么词"。

合并两个信号源, 输出带优先级的候选词队列:

1. 悬空引用 (来自 validate.py): 已有内容引用但未建立的义项。
   它们阻塞现有词义的对比/边界网络, 永远排在前面; 按被引用次数降序。
2. 高频词表 (data/wordlists/): 尚未入库也未被引用的高频词, 按词频排名升序。

已有正式义项或待审草稿的词会被排除。输出既是人读的清单, 也是
draft.py batch 的机器输入 (--json)。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
WORDLIST = ROOT / "data" / "wordlists" / "en-top-20000.tsv"


def load_ranks(path: Path = WORDLIST) -> dict[str, int]:
    ranks: dict[str, int] = {}
    if not path.exists():
        return ranks
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) >= 2 and parts[0].isdigit():
            ranks[parts[1]] = int(parts[0])
    return ranks


def covered_words() -> set[str]:
    """已有正式义项或待审词义草稿的词。"""
    words = set()
    for base in (ROOT / "data" / "senses", ROOT / "data" / "drafts" / "senses"):
        if base.exists():
            for p in base.glob("*.yaml"):
                words.add(p.stem.rsplit("-", 1)[0])
    return words


def build_queue(limit: int | None = None) -> list[dict]:
    result = validate.validate_repository()
    ranks = load_ranks()
    covered = covered_words()

    candidates: list[dict] = []
    seen: set[str] = set()

    dangling = sorted(
        result.dangling.items(),
        key=lambda item: (-len(item[1]),
                          ranks.get(item[0].rsplit("-", 1)[0], 10 ** 9),
                          item[0]),
    )
    for sense_id, locations in dangling:
        word = sense_id.rsplit("-", 1)[0]
        if word in covered or word in seen:
            continue
        seen.add(word)
        candidates.append({
            "word": word,
            "reason": "dangling_reference",
            "refs": len(locations),
            "rank": ranks.get(word),
        })

    for word, rank in sorted(ranks.items(), key=lambda item: item[1]):
        if word in covered or word in seen:
            continue
        # 单靠词频入队的词必须像一个可教学的内容词; 功能词交给人工判断。
        if not re.fullmatch(r"[a-z]{3,}", word):
            continue
        seen.add(word)
        candidates.append({
            "word": word,
            "reason": "frequency",
            "refs": 0,
            "rank": rank,
        })
        if limit and len(candidates) >= limit * 3:
            break

    return candidates[:limit] if limit else candidates


def main() -> None:
    parser = argparse.ArgumentParser(description="输出扩产候选词队列")
    parser.add_argument("--count", type=int, default=20, help="输出条数")
    parser.add_argument("--json", action="store_true", help="输出机器可读 JSON")
    args = parser.parse_args()

    queue = build_queue(args.count)
    if args.json:
        json.dump(queue, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return
    print(f"=== 扩产候选队列 (前 {len(queue)} 个) ===")
    for i, item in enumerate(queue, 1):
        rank = f"rank {item['rank']}" if item["rank"] else "rank —"
        if item["reason"] == "dangling_reference":
            print(f"{i:3}. {item['word']:16} 悬空引用×{item['refs']}  ({rank})")
        else:
            print(f"{i:3}. {item['word']:16} 高频词         ({rank})")


if __name__ == "__main__":
    main()
