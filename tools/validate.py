#!/usr/bin/env python3
"""SceneLex 数据校验器。

用法:
    python3 tools/validate.py            # 校验全部数据
    python3 tools/validate.py --backlog  # 额外输出"被引用但未建"的义项清单

检查项:
  1. data/senses/*.yaml  符合 schema/word-sense.schema.json
  2. data/scenes/**/*.yaml 符合 schema/scene-spec.schema.json
  3. ID 格式约定: 义项 {word}-{nn}, 场景 {sense_id}-{type}-{nn}
  4. 文件名与 id 字段一致
  5. 场景 sense_ref 必须指向已存在的义项
  6. 悬空引用统计 (relations / conditions.excluded.alternative / contrast_target)
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SENSE_ID = re.compile(r"^[a-z][a-z_]*-\d{2}$")
SCENE_TYPE_ABBR = {
    "prototype": "proto",
    "contrast": "contrast",
    "boundary": "boundary",
    "counterexample": "counter",
    "transfer": "transfer",
}


def load_schema(name):
    with open(ROOT / "schema" / name, encoding="utf-8") as f:
        return Draft202012Validator(json.load(f))


def load_yaml_files(directory):
    docs = {}
    if not directory.exists():
        return docs
    for path in sorted(directory.rglob("*.yaml")):
        with open(path, encoding="utf-8") as f:
            docs[path] = yaml.safe_load(f)
    return docs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backlog", action="store_true",
                        help="输出被引用但尚未建立的义项清单")
    args = parser.parse_args()

    errors = []
    sense_validator = load_schema("word-sense.schema.json")
    scene_validator = load_schema("scene-spec.schema.json")

    senses = load_yaml_files(ROOT / "data" / "senses")
    scenes = load_yaml_files(ROOT / "data" / "scenes")

    known_sense_ids = set()
    # referenced_by: sense_id -> [引用它的位置描述]
    referenced = defaultdict(list)

    # ---- 义项校验 ----
    for path, doc in senses.items():
        rel = path.relative_to(ROOT)
        for err in sense_validator.iter_errors(doc):
            loc = "/".join(str(p) for p in err.absolute_path) or "(root)"
            errors.append(f"{rel}: schema 校验失败 [{loc}] {err.message}")
        sid = doc.get("id", "")
        if not SENSE_ID.match(sid):
            errors.append(f"{rel}: id '{sid}' 不符合 {{word}}-{{nn}} 约定")
        if path.stem != sid:
            errors.append(f"{rel}: 文件名与 id '{sid}' 不一致")
        known_sense_ids.add(sid)

        rels = doc.get("relations", {}) or {}
        for key in ("synonyms", "antonyms", "hypernyms", "hyponyms", "confusables"):
            for ref in rels.get(key) or []:
                referenced[ref].append(f"{sid}:relations.{key}")
        for lang, items in (rels.get("l1_confusables") or {}).items():
            for item in items:
                for ref in item.get("covers") or []:
                    referenced[ref].append(f"{sid}:l1_confusables.{lang}")
        for exc in (doc.get("conditions", {}) or {}).get("excluded") or []:
            alt = exc.get("alternative")
            if alt:
                if not SENSE_ID.match(alt):
                    errors.append(
                        f"{rel}: excluded.alternative '{alt}' 不符合 ID 约定")
                referenced[alt].append(f"{sid}:conditions.excluded")

    # ---- 场景校验 ----
    for path, doc in scenes.items():
        rel = path.relative_to(ROOT)
        for err in scene_validator.iter_errors(doc):
            loc = "/".join(str(p) for p in err.absolute_path) or "(root)"
            errors.append(f"{rel}: schema 校验失败 [{loc}] {err.message}")
        scene_id = doc.get("id", "")
        sense_ref = doc.get("sense_ref", "")
        scene_type = doc.get("scene_type", "")
        if path.stem != scene_id:
            errors.append(f"{rel}: 文件名与 id '{scene_id}' 不一致")
        if sense_ref not in known_sense_ids:
            errors.append(f"{rel}: sense_ref '{sense_ref}' 指向不存在的义项")
        abbr = SCENE_TYPE_ABBR.get(scene_type, scene_type)
        expected = re.compile(
            rf"^{re.escape(sense_ref)}-{re.escape(abbr)}-\d{{2}}$")
        if sense_ref and not expected.match(scene_id):
            errors.append(
                f"{rel}: id '{scene_id}' 不符合 {sense_ref}-{abbr}-{{nn}} 约定")
        ct = doc.get("contrast_target")
        if scene_type in ("contrast", "boundary") and not ct:
            errors.append(f"{rel}: {scene_type} 场景缺少 contrast_target")
        if ct:
            referenced[ct].append(f"{scene_id}:contrast_target")
        beats = [b.get("beat") for b in doc.get("storyboard") or []]
        if beats != sorted(set(beats)) or (beats and beats[0] != 1):
            errors.append(f"{rel}: storyboard beat 序号应从 1 开始且连续递增")

    # ---- 场景组完整性(信息性) ----
    coverage = defaultdict(set)
    for doc in scenes.values():
        coverage[doc.get("sense_ref")].add(doc.get("scene_type"))

    # ---- 输出 ----
    print(f"义项: {len(senses)} 个 | 场景: {len(scenes)} 个")
    for sid in sorted(known_sense_ids):
        types = coverage.get(sid)
        if types:
            missing = set(SCENE_TYPE_ABBR) - types
            note = f"缺 {', '.join(sorted(missing))}" if missing else "场景组完整"
            print(f"  {sid}: {len(types)}/5 场景类型 ({note})")
        else:
            print(f"  {sid}: 尚无场景")

    dangling = {r: locs for r, locs in referenced.items()
                if r not in known_sense_ids}
    print(f"\n悬空引用: {len(dangling)} 个义项被引用但未建立")
    if args.backlog:
        print("\n=== 待建义项 backlog (按被引用次数排序) ===")
        for ref, locs in sorted(dangling.items(), key=lambda kv: -len(kv[1])):
            print(f"  {ref}  ({len(locs)} 处引用: {', '.join(locs)})")

    if errors:
        print(f"\n发现 {len(errors)} 个错误:", file=sys.stderr)
        for e in errors:
            print(f"  ✗ {e}", file=sys.stderr)
        sys.exit(1)
    print("\n✓ 全部校验通过")


if __name__ == "__main__":
    main()
