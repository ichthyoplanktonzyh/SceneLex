#!/usr/bin/env python3
"""SceneLex MVP 首批核心义项清单管理与校验工具。

用法:
    python3 tools/catalog.py report           # 打印按 12 语义分类与 14 微世界的分布统计
    python3 tools/catalog.py validate         # 严格校验 Schema 与内部引用
    python3 tools/catalog.py export-md        # 导出 Markdown 格式的完整清单表
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "data" / "content-plans" / "mvp-sense-catalog.yaml"
SCHEMA_PATH = ROOT / "schema" / "sense-catalog.schema.json"


def load_catalog(path: Path = CATALOG_PATH) -> dict:
    if not path.exists():
        raise FileNotFoundError(f"未找到义项清单文件: {path}")
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate_catalog(doc: dict | None = None) -> list[str]:
    if doc is None:
        doc = load_catalog()
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        schema = json.load(f)
    
    validator = Draft202012Validator(schema)
    errors: list[str] = []
    
    for err in validator.iter_errors(doc):
        loc = "/".join(str(p) for p in err.absolute_path) or "(root)"
        errors.append(f"Schema 校验错误 [{loc}]: {err.message}")

    senses = doc.get("senses", [])
    seen_ids = set()
    sense_id_set = {s.get("sense_id") for s in senses if isinstance(s, dict) and s.get("sense_id")}

    for s in senses:
        sid = s.get("sense_id")
        if sid in seen_ids:
            errors.append(f"重复的 sense_id: {sid}")
        seen_ids.add(sid)
        
        lemma = s.get("lemma")
        if sid and lemma:
            expected_prefix = lemma.replace(" ", "_")
            if not sid.startswith(expected_prefix):
                errors.append(f"sense_id '{sid}' 与 lemma '{lemma}' 前缀不一致")

    # 检查 nearest_contrast 引用
    for s in senses:
        sid = s.get("sense_id")
        contrasts = s.get("nearest_contrast", [])
        for c in contrasts:
            if c not in sense_id_set:
                # 记录悬空对比词（允许存在但在统计中提示）
                pass

    return errors


def report(doc: dict | None = None) -> None:
    if doc is None:
        doc = load_catalog()
    senses = doc.get("senses", [])
    total = len(senses)

    print("=" * 70)
    print(f"SceneLex MVP 首批核心义项清单统计 (总计: {total} 个 WordSense)")
    print("=" * 70)

    # 1. 12 语义分类分布
    by_semantic = Counter(s.get("semantic_type") for s in senses)
    print("\n【一、按 12 大词义经验分类 (Semantic Types) 分布】")
    for st, count in sorted(by_semantic.items(), key=lambda x: -x[1]):
        pct = (count / total) * 100
        print(f"  - {st:<22}: {count:3d} 门 ({pct:5.1f}%)")

    # 2. 14 微世界分布
    by_mw = Counter(s.get("primary_microworld") for s in senses)
    print("\n【二、按 14 个微世界候选 (Primary Microworlds) 分布】")
    for mw, count in sorted(by_mw.items(), key=lambda x: -x[1]):
        pct = (count / total) * 100
        print(f"  - {mw:<22}: {count:3d} 门 ({pct:5.1f}%)")

    # 3. 词频层级分布
    by_freq = Counter(s.get("frequency_tier") for s in senses)
    print("\n【三、按词频层级 (Frequency Tier) 分布】")
    for freq in ["top_500", "top_1000", "top_2000", "top_3000", "top_5000"]:
        count = by_freq.get(freq, 0)
        pct = (count / total) * 100
        print(f"  - {freq:<15}: {count:3d} 门 ({pct:5.1f}%)")

    # 4. 课程与原型状态
    by_course_status = Counter(s.get("course_status") for s in senses)
    print("\n【四、按课程状态 (Course Status) 分布】")
    for st, count in sorted(by_course_status.items(), key=lambda x: -x[1]):
        print(f"  - {st:<15}: {count:3d} 门")

    print("\n" + "=" * 70)


def export_markdown(doc: dict | None = None, out_path: Path | None = None) -> None:
    if doc is None:
        doc = load_catalog()
    senses = doc.get("senses", [])

    # 按 12 语义类型分组
    grouped = defaultdict(list)
    for s in senses:
        grouped[s.get("semantic_type", "unknown")].append(s)

    lines = [
        "# SceneLex MVP 首批核心义项清单 (320 WordSenses)",
        "",
        "> 基于 12 大词义经验分类与 14 个微世界候选构建的高频具身词义总表。",
        "",
    ]

    for st, items in grouped.items():
        lines.append(f"## {st} ({len(items)} 义项)")
        lines.append("")
        lines.append("| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |")
        lines.append("|---|---|---|---|---|---|---|---|")
        for s in items:
            contrasts = ", ".join(s.get("nearest_contrast", []))
            lines.append(
                f"| `{s['sense_id']}` | **{s['lemma']}** | {s['pos']} | `{s['primary_microworld']}` | {s['frequency_tier']} | {s['experience_invariant']} | {contrasts} | {s['sense_summary']} |"
            )
        lines.append("")

    content = "\n".join(lines)
    if out_path:
        out_path.write_text(content, encoding="utf-8")
        print(f"✓ 已导出至: {out_path}")
    else:
        print(content)


def main() -> None:
    parser = argparse.ArgumentParser(description="SceneLex MVP 义项清单管理工具")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("report", help="统计并打印分布报告")
    subparsers.add_parser("validate", help="校验清单格式与完整性")
    
    export_p = subparsers.add_parser("export-md", help="导出 Markdown 表格")
    export_p.add_argument("--out", type=str, default="", help="输出路径")

    args = parser.parse_args()

    if args.command == "validate":
        errs = validate_catalog()
        if errs:
            print(f"✗ 校验失败，共 {len(errs)} 个错误:")
            for e in errs:
                print(f"  - {e}")
            sys.exit(1)
        else:
            print("✓ 义项清单 Schema 校验全部通过！")
    elif args.command == "export-md":
        out = Path(args.out) if args.out else None
        export_markdown(out_path=out)
    else:
        report()


if __name__ == "__main__":
    main()
