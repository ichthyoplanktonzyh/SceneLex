#!/usr/bin/env python3
"""Build the deterministic ExperienceProgram v1 App bundle asset.

Input:  reviewed/published fixtures under tests/fixtures/experience-programs/
        plus WordSense metadata from data/senses/ (status: reviewed only).
Output: app/assets/content/experience-programs.v1.json

Each source program is validated with the Experience Compiler's own
validate_program before it may enter the bundle; draft content (data/drafts/)
is rejected. The output is byte-stable: same inputs, same bytes. --check
compares the current asset against a fresh build without writing.

Bundle shape (v2): { bundle_version, schema_version, catalog, programs }.
catalog maps sense_id -> WordSenseCatalogEntry (consumer-facing WordSense
summary: semantic_type/locale_l1/program version link + invariant +
l1_confusables extracted from semantic_model.l1_interference + explicit
boundaries list, currently empty until content provides relations data).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import experience_compiler as compiler  # noqa: E402

FIXTURE_DIR = ROOT / "tests" / "fixtures" / "experience-programs"
SENSE_DIR = ROOT / "data" / "senses"
OUTPUT_PATH = ROOT / "app" / "assets" / "content" / "experience-programs.v1.json"
SENSE_IDS = ("reluctant-01", "messy-01", "almost-01", "dirty-01")
BUNDLE_VERSION = 2
REVIEWABLE_STATUSES = ("reviewed", "published")


def _load_reviewed_sense(sense_id: str) -> dict:
    """WordSense 元数据（semantic_type 等）只采信 status: reviewed 的规格。"""
    path = SENSE_DIR / f"{sense_id}.yaml"
    if not path.exists():
        raise SystemExit(f"{path}: 缺失 WordSense 规格（bundle catalog 需要）")
    with path.open(encoding="utf-8") as handle:
        sense = yaml.safe_load(handle)
    if sense.get("status") != "reviewed":
        raise SystemExit(
            f"{path}: status={sense.get('status')!r} 不是 reviewed，"
            "catalog 只收录已审核的 WordSense")
    return sense


def _validate_source(path: Path) -> dict:
    diagnostics = compiler.validate_program_file(path)
    if diagnostics:
        rendered = "\n".join(
            f"  [{d.stage}] {d.path}: {d.message}" for d in diagnostics
        )
        raise SystemExit(f"{path}: 未通过 Experience Compiler 校验:\n{rendered}")
    with path.open(encoding="utf-8") as handle:
        program = yaml.safe_load(handle)
    status = program.get("status")
    if status not in REVIEWABLE_STATUSES:
        raise SystemExit(
            f"{path}: status={status!r} 不是可发布状态 "
            f"{REVIEWABLE_STATUSES}（draft 内容禁止进入 App bundle）")
    return program


def _build_catalog_entry(sense_id: str, program: dict) -> dict:
    """从 WordSense 规格 + program 抽取消费者侧 catalog 条目。

    semantic_model 内部字段不直接进入 catalog；只有显式抽取的 invariant 与
    l1_confusables（来源 l1_interference）成为可渲染的消费字段。
    boundaries 当前内容未收录 relations 数据，保持空数组并显式标记 status。
    """
    sense = _load_reviewed_sense(sense_id)
    semantic = program.get("semantic_model") or {}
    l1_interference = semantic.get("l1_interference") or []
    target = program["target"]
    return {
        "sense_id": sense_id,
        "sense_key": sense.get("id") or sense_id,
        "lemma": target["lemma"],
        "pos": target["pos"],
        "ipa": target.get("ipa"),
        "semantic_type": sense.get("semantic_type"),
        "locale_l1": target.get("locale_l1"),
        "invariant": semantic.get("invariant") or "",
        "l1_confusables": [str(item) for item in l1_interference],
        "boundaries": [],
        "boundaries_status": "not_collected",
        "program_id": program["program_id"],
        "program_version": program["program_version"],
    }


def build_bundle() -> dict:
    programs = {}
    catalog = {}
    for sense_id in SENSE_IDS:
        path = FIXTURE_DIR / f"{sense_id}.yaml"
        if not path.exists():
            raise SystemExit(f"{path}: 缺失")
        program = _validate_source(path)
        actual_sense_id = (program.get("target") or {}).get("sense_id")
        if actual_sense_id != sense_id:
            raise SystemExit(
                f"{path}: target.sense_id={actual_sense_id!r} 与输入名 {sense_id} 不一致")
        programs[sense_id] = program
        catalog[sense_id] = _build_catalog_entry(sense_id, program)
    return {
        "bundle_version": BUNDLE_VERSION,
        "schema_version": compiler.CONTRACT_VERSION,
        "catalog": catalog,
        "programs": programs,
    }


def render(bundle: dict) -> str:
    return json.dumps(bundle, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true",
        help="不与当前 asset 相同则退出非 0，不写文件")
    args = parser.parse_args(argv)

    bundle = build_bundle()
    rendered = render(bundle)

    if args.check:
        if OUTPUT_PATH.exists() and OUTPUT_PATH.read_text(encoding="utf-8") == rendered:
            print(f"{OUTPUT_PATH}: 一致")
            return 0
        print(f"{OUTPUT_PATH}: 与重新生成结果不一致", file=sys.stderr)
        return 1

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(rendered, encoding="utf-8")
    print(f"已写入 {OUTPUT_PATH} "
          f"({len(bundle['programs'])} programs, "
          f"{len(bundle['catalog'])} catalog entries, {len(rendered)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
