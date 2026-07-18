#!/usr/bin/env python3
"""SceneLex 词典查看/导出工具 — 以词为中心聚合义项、场景与元信息。

用法:
    python3 tools/wordbook.py view <word>         # 终端查看词典页
    python3 tools/wordbook.py export <word>       # 导出单个词完整 JSON
    python3 tools/wordbook.py export              # 导出整本词典 JSON
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
SENSE_ID = re.compile(r"^[a-z][a-z_]*-\d{2}$")
SCENE_TYPE_ABBR = {
    "prototype": "proto",
    "contrast": "contrast",
    "boundary": "boundary",
    "counterexample": "counter",
    "transfer": "transfer",
}
# 词频带划分 (与 word-sense.schema.json 一致)
FREQ_RANKS = {"core": (1, 500), "high": (501, 1500), "mid": (1501, 3500), "low": (3501, 10 ** 9)}


def _rank_to_band(rank: int) -> str:
    for band, (lo, hi) in FREQ_RANKS.items():
        if lo <= rank <= hi:
            return band
    return "low"


def load_tsv_ranks() -> dict[str, int]:
    """从 en-top-20000.tsv 加载词频排名。"""
    path = ROOT / "data" / "wordlists" / "en-top-20000.tsv"
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


def yaml_load(path: Path) -> dict[str, Any] | None:
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        return doc if isinstance(doc, dict) else None
    except (OSError, yaml.YAMLError):
        return None


def word_dirs() -> set[str]:
    """返回 data/senses 和 data/drafts/senses 中所有已覆盖的去重词目。"""
    words: set[str] = set()
    for base in (ROOT / "data" / "senses", ROOT / "data" / "drafts" / "senses"):
        if base.exists():
            for p in base.glob("*.yaml"):
                word = p.stem.rsplit("-", 1)[0]
                words.add(word)
    return words


def senses_for_word(word: str) -> list[dict[str, Any]]:
    """从正式库和草稿库加载一个词的所有义项文档。"""
    results: list[dict[str, Any]] = []
    for base in (ROOT / "data" / "senses", ROOT / "data" / "drafts" / "senses"):
        if not base.exists():
            continue
        for p in sorted(base.glob(f"{word}-*.yaml")):
            doc = yaml_load(p)
            if doc:
                doc["_path"] = str(p.relative_to(ROOT))
                results.append(doc)
    return results


def scenes_for_sense(sense_id: str) -> list[dict[str, Any]]:
    """从正式库和草稿库加载一个义项的所有场景文档。"""
    results: list[dict[str, Any]] = []
    for base in (ROOT / "data" / "scenes" / sense_id,
                 ROOT / "data" / "drafts" / "scenes" / sense_id):
        if not base.exists():
            continue
        for p in sorted(base.glob("*.yaml")):
            doc = yaml_load(p)
            if doc:
                results.append(doc)
    return results


# ---------------------------------------------------------------- 词目条目维护

ENTRY_DIR = ROOT / "data" / "words"


def load_word_entry(word: str) -> dict[str, Any] | None:
    """加载 data/words/{word}.yaml 词目文件（如存在）。"""
    path = ENTRY_DIR / f"{word}.yaml"
    if not path.exists():
        return None
    doc = yaml_load(path)
    return doc if isinstance(doc, dict) else None


def build_word_entry(word: str, ranks: dict[str, int]) -> dict[str, Any]:
    """从现有 sense 文件聚合构建一个词的完整条目（无论是否有词目文件）。"""
    senses = senses_for_word(word)
    if not senses:
        return {}

    # 按 id 排序
    senses.sort(key=lambda s: s.get("id", ""))

    # 聚合词性
    pos_set: set[str] = set()
    # 聚合 IPA
    ipas: list[str] = []
    seen_ipa: set[str] = set()
    min_rank = 10 ** 9

    sense_list: list[dict[str, Any]] = []
    for doc in senses:
        sid = doc.get("id", "")
        pos = doc.get("pos", "")
        if pos:
            pos_set.add(pos)
        pron = doc.get("pronunciation") or {}
        ipa = pron.get("ipa", "")
        if ipa and ipa not in seen_ipa:
            ipas.append(ipa)
            seen_ipa.add(ipa)
        freq = doc.get("frequency") or {}
        rank = freq.get("rank")
        if isinstance(rank, int) and rank < min_rank:
            min_rank = rank

        # 场景摘要
        scenes = scenes_for_sense(sid)
        scene_types = defaultdict(list)
        for sc in scenes:
            st = sc.get("scene_type", "")
            sc_id = sc.get("id", "")
            scene_types[st].append(sc_id)

        sense_list.append({
            "id": sid,
            "pos": pos,
            "sense_label": doc.get("sense_label", ""),
            "definition": doc.get("definition", ""),
            "status": doc.get("status", "draft"),
            "scene_count": len(scenes),
            "scene_types": dict(scene_types),
        })

    freq_rank = min_rank if min_rank < 10 ** 9 else ranks.get(word)

    entry: dict[str, Any] = {
        "word": word,
        "pos": sorted(pos_set),
        "senses": sense_list,
    }

    if ipas:
        entry["pronunciation"] = {"ipa": ipas}

    if isinstance(freq_rank, int):
        entry["frequency"] = {
            "rank": freq_rank,
            "band": _rank_to_band(freq_rank),
        }

    # 尝试从现有词目文件继承 version（新构建时为 1）
    existing = load_word_entry(word)
    entry["version"] = existing["version"] if existing and isinstance(existing.get("version"), int) else 1

    return entry


def write_word_entry(word: str, entry: dict[str, Any]) -> None:
    """写出/更新 data/words/{word}.yaml。"""
    if not entry:
        return
    ENTRY_DIR.mkdir(parents=True, exist_ok=True)
    path = ENTRY_DIR / f"{word}.yaml"

    # 保留顶层字段顺序
    lines: list[str] = []
    top_keys = ["schema_version", "version", "word", "pos", "pronunciation", "frequency", "senses"]
    written_keys: set[str] = set()
    for key in top_keys:
        if key in entry:
            if key == "senses":
                lines.append("")
                lines.append("senses:")
                for sense in entry[key]:
                    lines.append(f"  - id: {sense['id']}")
                    lines.append(f"    pos: {sense['pos']}")
                    lines.append(f"    sense_label: \"{sense['sense_label']}\"")
                    lines.append(f"    definition: \"{sense['definition']}\"")
                    lines.append(f"    status: {sense['status']}")
                    lines.append(f"    scene_count: {sense['scene_count']}")
            elif key == "pronunciation":
                ipas = entry[key].get("ipa", [])
                if ipas:
                    lines.append("")
                    lines.append("pronunciation:")
                    lines.append(f"  ipa:")
                    for ipa in ipas:
                        lines.append(f"    - \"{ipa}\"")
            elif key == "frequency":
                lines.append("")
                lines.append("frequency:")
                lines.append(f"  rank: {entry['frequency']['rank']}")
                lines.append(f"  band: {entry['frequency']['band']}")
            else:
                lines.append(f"{key}: {entry[key]}")
            written_keys.add(key)

    # 其余字段
    for key, value in entry.items():
        if key.startswith("_") or key in written_keys:
            continue
        lines.append(f"{key}: {value}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- view

def cmd_view(args: argparse.Namespace) -> None:
    word = args.word.strip().lower()
    ranks = load_tsv_ranks()
    entry = load_word_entry(word) or build_word_entry(word, ranks)

    if not entry or not entry.get("senses"):
        sys.exit(f"'{word}' 尚无任何义项")

    senses = entry["senses"]
    pos_str = ", ".join(entry.get("pos", []))
    ipa_str = ", ".join(
        ipa.strip("/") for ipa in (entry.get("pronunciation", {})).get("ipa", [])
        if ipa
    )
    freq_str = ""
    if entry.get("frequency"):
        f = entry["frequency"]
        freq_str = f"  频次: {f.get('band', '?')} (rank {f.get('rank', '?')})"

    # 标题行
    width = 60
    print()
    print(f"{'═' * width}")
    title = f"  {word}"
    if ipa_str:
        title += f"  /{ipa_str}/"
    print(title)
    if pos_str:
        print(f"  {pos_str}")
    if freq_str:
        print(f"{freq_str}")
    print(f"{'═' * width}")
    print()

    # 义项列表
    plural = "个义项" if len(senses) > 1 else "个义项"
    print(f"共 {len(senses)} {plural}:")
    print(f"{'─' * width}")
    for sense in senses:
        sid = sense["id"]
        label = sense.get("sense_label", "")
        status = sense.get("status", "draft")
        sc = sense.get("scene_count", 0)
        scene_types = sense.get("scene_types", {})
        status_icon = "✓" if status in ("reviewed", "published") else "·"
        scene_summary = "  ".join(
            f"{abbr}-{len(scene_types.get(typ, [])):02d}"
            for abbr, typ in [("proto", "prototype"), ("contrast", "contrast"),
                              ("counter", "counterexample"), ("boundary", "boundary"),
                              ("transfer", "transfer")]
            if typ in scene_types
        ) if scene_types else "(尚无场景)"
        print(f"  {sid:<22} {label:<18} {status_icon} {status:<10} {sc} scenes")
        if scene_summary:
            print(f"  {' ' * 22}  {scene_summary}")
    print()


# ---------------------------------------------------------------- export

def cmd_export(args: argparse.Namespace) -> None:
    if args.word:
        _export_single(args.word)
    else:
        _export_all()


def _build_export_sense(doc: dict[str, Any]) -> dict[str, Any]:
    """为导出构建纯净的义项文档（去掉内部 _path）。"""
    return {k: v for k, v in doc.items() if not k.startswith("_")}


def _build_export_sense_entry(sense: dict[str, Any]) -> dict[str, Any]:
    """构建导出用的义项摘要（不含完整场景数据）。"""
    sid = sense.get("id", "")
    scenes = scenes_for_sense(sid)
    return {
        "id": sid,
        "sense_label": sense.get("sense_label", ""),
        "definition": sense.get("definition", ""),
        "pos": sense.get("pos", ""),
        "status": sense.get("status", "draft"),
        "semantic_skeleton": sense.get("semantic_skeleton"),
        "conditions": sense.get("conditions"),
        "scene_requirements": sense.get("scene_requirements"),
        "scenes": [
            {
                "id": sc.get("id"),
                "scene_type": sc.get("scene_type"),
                "title": sc.get("title"),
                "synopsis": sc.get("synopsis"),
                "surface": sc.get("surface"),
                "storyboard": sc.get("storyboard"),
            }
            for sc in scenes
        ],
    }


def _export_single(word: str) -> None:
    word = word.strip().lower()
    ranks = load_tsv_ranks()
    entry = build_word_entry(word, ranks)
    if not entry or not entry.get("senses"):
        sys.exit(f"'{word}' 尚无任何义项")

    # 聚合完整的义项数据+场景
    senses_docs = senses_for_word(word)
    senses_docs.sort(key=lambda s: s.get("id", ""))
    export: dict[str, Any] = {
        "schema_version": "1.0",
        "word": word,
        "pos": entry.get("pos", []),
        "pronunciation": entry.get("pronunciation"),
        "frequency": entry.get("frequency"),
        "senses": [_build_export_sense_entry(s) for s in senses_docs],
    }

    json.dump(export, sys.stdout, ensure_ascii=False, indent=2, sort_keys=False)
    print()


def _export_all() -> None:
    ranks = load_tsv_ranks()
    words = sorted(word_dirs())
    export: list[dict[str, Any]] = []
    for word in words:
        entry = build_word_entry(word, ranks)
        if entry and entry.get("senses"):
            # 仅导出词目级摘要信息
            entry_export: dict[str, Any] = {
                "word": word,
                "pos": entry.get("pos", []),
                "pronunciation": entry.get("pronunciation"),
                "frequency": entry.get("frequency"),
                "senses": [
                    {
                        "id": s["id"],
                        "sense_label": s.get("sense_label", ""),
                        "pos": s.get("pos", ""),
                        "status": s.get("status", ""),
                        "scene_count": s.get("scene_count", 0),
                    }
                    for s in entry["senses"]
                ],
            }
            export.append(entry_export)

    json.dump(export, sys.stdout, ensure_ascii=False, indent=2, sort_keys=False)
    print()
    print(f"✓ 导出了 {len(export)} 个词目", file=sys.stderr)


# ---------------------------------------------------------------- main

def main() -> None:
    parser = argparse.ArgumentParser(description="SceneLex 词典工具")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("view", help="终端查看某个词的词典页")
    p.add_argument("word")
    p.set_defaults(func=cmd_view)

    p = sub.add_parser("export", help="导出词典 JSON")
    p.add_argument("word", nargs="?", help="导出一个词；缺省时导出整本词典")
    p.set_defaults(func=cmd_export)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
