#!/usr/bin/env python3
"""Build the Teaching Archetype MVP preview bundle (byte-stable).

    python3 tools/build_archetype_mvp_bundle.py          # build
    python3 tools/build_archetype_mvp_bundle.py --check   # verify byte-stable

内容:
  - archetype catalog（manifest 的 teaching_archetype / suggested_capabilities
    / special_risks / boundary allowed）
  - 14 门课程（只接受通过 Holistic Course validator 的课程；缺课明确报告）
  - pair relations（谁先谁后、boundary allowed）
  - curriculum order（哪一天哪门新课进入候选）
  - capability version 与输入 digest

规则:
  - 字节稳定: 同一输入 → 完全相同的字节（无时间戳、无随机内容、稳定排序）
  - --check: 与现有 bundle 逐字节比对
  - 不包含 metadata.calls（provider/model/request_id 不进 bundle）与任何
    prompt/密钥
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import holistic_course_compiler as hcc  # noqa: E402

BUNDLE_VERSION = 1
SCHEMA_VERSION = "1.0"
OUTPUT_PATH = ROOT / "app" / "assets" / "content" / "archetype-mvp.v1.json"
MANIFEST_PATH = ROOT / "data" / "content-plans" / "mvp-teaching-archetypes.yaml"
DRAFTS_DIR = ROOT / "data" / "drafts" / "holistic-courses"


class BundleError(RuntimeError):
    pass


def _digest_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_manifest() -> dict:
    doc = yaml.safe_load(MANIFEST_PATH.read_text(encoding="utf-8"))
    if not isinstance(doc, dict):
        raise BundleError("manifest 根节点必须是对象")
    return doc


def _load_sense_contract(sense_id: str):
    return hcc.load_sense(sense_id), hcc.load_contract(sense_id)


def sanitize_course(course: dict) -> dict:
    """bundle 只携带可执行结构 + 开发意图；剥离 metadata（calls/时间戳/
    input_digest 不进 bundle 内容，digest 单独登记）。

    使用确定性 lowering（与 holistic-course-preview 资产同一形状），App 端
    直接复用 HolisticCourse.fromJson，不重复解析 Course Package。"""
    return hcc.lower_course_package(course)


def build_bundle(manifest: dict | None = None) -> dict:
    manifest = manifest or load_manifest()
    capabilities = hcc.load_capabilities()
    curriculum = manifest.get("curriculum") or []
    archetypes_raw = manifest.get("archetypes") or []

    # 1. 课程: 只接受通过 validator 的课程
    courses: list[dict] = []
    input_digests: dict[str, str] = {}
    missing: list[str] = []
    invalid: list[str] = []
    expected_set: set[str] = set()
    for entry in curriculum:
        if entry.get("course"):
            expected_set.add(entry["course"])
    for archetype in archetypes_raw:
        for cluster in archetype.get("clusters") or []:
            for lemma in cluster.get("lemmas") or []:
                if lemma.get("sense_id"):
                    expected_set.add(lemma["sense_id"])
    expected = sorted(expected_set)
    for sense_id in expected:
        found = None
        for path in sorted((DRAFTS_DIR / sense_id).glob("v*/course.yaml")):
            try:
                course = yaml.safe_load(path.read_text(encoding="utf-8"))
            except (OSError, yaml.YAMLError):
                continue
            if not isinstance(course, dict):
                continue
            sense, contract = _load_sense_contract(sense_id)
            if contract is None:
                continue
            result = hcc.validate_course_package(
                course, sense=sense, contract=contract,
                capabilities=capabilities,
            )
            if result.valid:
                found = (path, course)
                break
            invalid.append(f"{sense_id} ({path.parent.name})")
        if found is None:
            missing.append(sense_id)
            continue
        path, course = found
        courses.append(sanitize_course(course))
        input_digests[sense_id] = _digest_file(path)

    # 2. archetype catalog + pair relations
    archetype_catalog: list[dict] = []
    pair_relations: list[dict] = []
    for archetype in archetypes_raw:
        pair_info: list[dict] = []
        for cluster in archetype.get("clusters") or []:
            between = cluster.get("boundary") or {}
            lemmas = [
                l for l in cluster.get("lemmas") or [] if l.get("sense_id")
            ]
            pair_info.append({
                "id": cluster.get("id"),
                "between": between.get("between") or [l["sense_id"] for l in lemmas],
                "allowed": between.get("allowed", "one"),
                "insufficient_evidence_allowed":
                    between.get("insufficient_evidence_allowed", False),
                "courses": [l["sense_id"] for l in lemmas],
            })
            pair_relations.append({
                "pair_id": cluster.get("id"),
                "between": between.get("between") or [l["sense_id"] for l in lemmas],
                "allowed": between.get("allowed", "one"),
                "insufficient_evidence_allowed":
                    between.get("insufficient_evidence_allowed", False),
                "courses": [l["sense_id"] for l in lemmas],
            })
        archetype_catalog.append({
            "id": archetype.get("id"),
            "semantic_types": archetype.get("semantic_types"),
            "teaching_archetype": archetype.get("teaching_archetype"),
            "experience_mechanism": archetype.get("experience_mechanism"),
            "suggested_capabilities": archetype.get("suggested_capabilities"),
            "special_risks": archetype.get("special_risks"),
            "pairs": pair_info,
        })

    bundle = {
        "schema_version": SCHEMA_VERSION,
        "bundle_version": BUNDLE_VERSION,
        "capability_version": capabilities.get("capabilities_version"),
        "learner_l1": manifest.get("learner_l1"),
        "target_l2": manifest.get("target_l2"),
        "curriculum": curriculum,
        "archetypes": archetype_catalog,
        "pair_relations": pair_relations,
        "courses": courses,
        "input_digests": input_digests,
        "_missing_courses": missing,
        "_invalid_courses": invalid,
    }
    return bundle


def render_bundle(bundle: dict) -> bytes:
    """确定性序列化: sort_keys + 固定缩进 + 结尾换行 → 字节稳定。"""
    return (
        json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def cmd_build(check_only: bool) -> int:
    bundle = build_bundle()
    payload = render_bundle(bundle)
    missing = bundle["_missing_courses"]
    invalid = bundle["_invalid_courses"]
    problems = bool(missing or invalid)

    if check_only:
        if not OUTPUT_PATH.exists():
            print(f"✗ bundle 不存在: {OUTPUT_PATH}")
            print(f"  缺失课程: {', '.join(missing) or '（无）'}")
            print(f"  无效课程: {', '.join(invalid) or '（无）'}")
            return 1
        current = OUTPUT_PATH.read_bytes()
        if current != payload:
            print("✗ bundle 与当前输入不一致（输入已变化，请重新构建）")
            if missing:
                print(f"  缺失课程: {', '.join(missing)}")
            if invalid:
                print(f"  无效课程: {', '.join(invalid)}")
            return 1
        print(f"✓ bundle 字节稳定（{len(payload)} 字节, "
              f"{len(bundle['courses'])} 门课程通过 validator）")
        return 0

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_bytes(payload)
    print(f"✓ bundle 已写入 {OUTPUT_PATH} "
          f"（{len(bundle['courses'])}/{len(bundle['curriculum'])} 门课程）")
    if missing:
        print(f"  ✗ 缺失课程: {', '.join(missing)}")
    if invalid:
        print(f"  ✗ 无效课程: {', '.join(invalid)}")
    if problems:
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="只校验现有 bundle 是否与当前输入字节一致")
    args = parser.parse_args(argv)
    return cmd_build(check_only=args.check)


if __name__ == "__main__":
    sys.exit(main())
