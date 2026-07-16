#!/usr/bin/env python3
"""Validate SceneLex's published resource repository.

This is the machine gate before a resource can be promoted. It validates JSON
Schema, stable identifiers, cross-resource references and a small set of
semantic invariants that JSON Schema cannot express conveniently.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parent.parent
SENSE_ID = re.compile(r"^[a-z][a-z_]*-\d{2}$")
SCENE_TYPE_ABBR = {
    "prototype": "proto",
    "contrast": "contrast",
    "boundary": "boundary",
    "counterexample": "counter",
    "transfer": "transfer",
}
RELATION_KEYS = ("synonyms", "antonyms", "hypernyms", "hyponyms", "confusables")


@dataclass
class ValidationResult:
    senses: dict[Path, dict[str, Any]] = field(default_factory=dict)
    scenes: dict[Path, dict[str, Any]] = field(default_factory=dict)
    known_sense_ids: set[str] = field(default_factory=set)
    referenced: dict[str, list[str]] = field(
        default_factory=lambda: defaultdict(list)
    )
    coverage: dict[str, set[str]] = field(
        default_factory=lambda: defaultdict(set)
    )
    errors: list[str] = field(default_factory=list)

    @property
    def dangling(self) -> dict[str, list[str]]:
        return {
            ref: locations
            for ref, locations in self.referenced.items()
            if ref not in self.known_sense_ids
        }


def load_schema(name: str) -> Draft202012Validator:
    with open(ROOT / "schema" / name, encoding="utf-8") as file:
        return Draft202012Validator(
            json.load(file), format_checker=FormatChecker()
        )


def load_yaml_files(directory: Path, errors: list[str]) -> dict[Path, dict[str, Any]]:
    documents: dict[Path, dict[str, Any]] = {}
    if not directory.exists():
        return documents
    for path in sorted(directory.rglob("*.yaml")):
        try:
            with open(path, encoding="utf-8") as file:
                document = yaml.safe_load(file)
        except (OSError, yaml.YAMLError) as exc:
            errors.append(f"{path}: YAML 读取失败: {exc}")
            continue
        if not isinstance(document, dict):
            errors.append(f"{path}: YAML 根节点必须是对象")
            continue
        documents[path] = document
    return documents


def _location(path: Path, data_root: Path) -> str:
    try:
        return str(path.relative_to(data_root.parent))
    except ValueError:
        return str(path)


def _schema_errors(
    document: dict[str, Any], validator: Draft202012Validator, label: str
) -> list[str]:
    errors = []
    for error_item in validator.iter_errors(document):
        location = "/".join(str(part) for part in error_item.absolute_path) or "(root)"
        errors.append(
            f"{label}: schema 校验失败 [{location}] {error_item.message}"
        )
    return errors


def _valid_reference(reference: Any, location: str, result: ValidationResult) -> None:
    if not isinstance(reference, str) or not SENSE_ID.fullmatch(reference):
        result.errors.append(f"{location}: 义项引用 '{reference}' 不符合 ID 约定")


def _validate_frequency(document: dict[str, Any], label: str, errors: list[str]) -> None:
    frequency = document.get("frequency") or {}
    band, rank = frequency.get("band"), frequency.get("rank")
    if band is None or rank is None or not isinstance(rank, int):
        return
    matches = {
        "core": rank <= 500,
        "high": 501 <= rank <= 1500,
        "mid": 1501 <= rank <= 3500,
        "low": rank >= 3501,
    }
    if band in matches and not matches[band]:
        errors.append(f"{label}: frequency.band '{band}' 与 rank {rank} 不一致")


def _beats_are_contiguous(beats: list[Any]) -> bool:
    return beats == list(range(1, len(beats) + 1))


def validate_repository(data_root: Path | None = None) -> ValidationResult:
    """Validate a data directory containing ``senses`` and ``scenes``."""
    data_root = (data_root or ROOT / "data").resolve()
    result = ValidationResult()
    sense_validator = load_schema("word-sense.schema.json")
    scene_validator = load_schema("scene-spec.schema.json")

    result.senses = load_yaml_files(data_root / "senses", result.errors)
    result.scenes = load_yaml_files(data_root / "scenes", result.errors)

    seen_sense_ids: dict[str, Path] = {}
    boundary_relations: dict[tuple[str, str], str] = {}
    for path, document in result.senses.items():
        label = _location(path, data_root)
        result.errors += _schema_errors(document, sense_validator, label)
        sense_id = document.get("id", "")
        if not isinstance(sense_id, str) or not SENSE_ID.fullmatch(sense_id):
            result.errors.append(
                f"{label}: id '{sense_id}' 不符合 {{word}}-{{nn}} 约定"
            )
        if path.stem != sense_id:
            result.errors.append(f"{label}: 文件名与 id '{sense_id}' 不一致")
        if sense_id in seen_sense_ids:
            result.errors.append(
                f"{label}: id '{sense_id}' 与 {seen_sense_ids[sense_id]} 重复"
            )
        else:
            seen_sense_ids[sense_id] = path
        result.known_sense_ids.add(sense_id)
        if document.get("status") == "draft":
            result.errors.append(f"{label}: draft 资源不能出现在正式库")
        if document.get("status") == "published":
            sources = (document.get("provenance") or {}).get("sources") or []
            if not sources:
                result.errors.append(f"{label}: published 义项必须包含 provenance.sources")
        _validate_frequency(document, label, result.errors)

        relations = document.get("relations") or {}
        for key in RELATION_KEYS:
            for reference in relations.get(key) or []:
                _valid_reference(reference, f"{label}:relations.{key}", result)
                result.referenced[reference].append(f"{sense_id}:relations.{key}")
        for boundary in relations.get("boundaries") or []:
            reference = boundary.get("target")
            _valid_reference(reference, f"{label}:relations.boundaries", result)
            result.referenced[reference].append(f"{sense_id}:relations.boundaries")
            boundary_relations[(sense_id, reference)] = boundary.get("relation")
        for language, items in (relations.get("l1_confusables") or {}).items():
            for item in items:
                for reference in item.get("covers") or []:
                    _valid_reference(
                        reference,
                        f"{label}:relations.l1_confusables.{language}",
                        result,
                    )
                    result.referenced[reference].append(
                        f"{sense_id}:l1_confusables.{language}"
                    )
        for excluded in (document.get("conditions") or {}).get("excluded") or []:
            alternative = excluded.get("alternative")
            if alternative:
                _valid_reference(
                    alternative, f"{label}:conditions.excluded", result
                )
                result.referenced[alternative].append(
                    f"{sense_id}:conditions.excluded"
                )

    seen_scene_ids: dict[str, Path] = {}
    for path, document in result.scenes.items():
        label = _location(path, data_root)
        result.errors += _schema_errors(document, scene_validator, label)
        scene_id = document.get("id", "")
        sense_ref = document.get("sense_ref", "")
        scene_type = document.get("scene_type", "")
        if path.stem != scene_id:
            result.errors.append(f"{label}: 文件名与 id '{scene_id}' 不一致")
        if scene_id in seen_scene_ids:
            result.errors.append(
                f"{label}: id '{scene_id}' 与 {seen_scene_ids[scene_id]} 重复"
            )
        else:
            seen_scene_ids[scene_id] = path
        _valid_reference(sense_ref, f"{label}:sense_ref", result)
        if sense_ref not in result.known_sense_ids:
            result.errors.append(
                f"{label}: sense_ref '{sense_ref}' 指向不存在的义项"
            )
        abbreviation = SCENE_TYPE_ABBR.get(scene_type, scene_type)
        expected = re.compile(
            rf"^{re.escape(str(sense_ref))}-{re.escape(str(abbreviation))}-\d{{2}}$"
        )
        if sense_ref and not expected.fullmatch(str(scene_id)):
            result.errors.append(
                f"{label}: id '{scene_id}' 不符合 {sense_ref}-{abbreviation}-{{nn}} 约定"
            )
        contrast_target = document.get("contrast_target")
        if scene_type in ("contrast", "boundary", "counterexample") and not contrast_target:
            result.errors.append(f"{label}: {scene_type} 场景缺少 contrast_target")
        if contrast_target:
            _valid_reference(contrast_target, f"{label}:contrast_target", result)
            result.referenced[contrast_target].append(
                f"{scene_id}:contrast_target"
            )
        if scene_type in ("contrast", "boundary", "counterexample") and not document.get(
            "contrast_relation"
        ):
            result.errors.append(f"{label}: {scene_type} 场景缺少 contrast_relation")
        if document.get("status") == "draft":
            result.errors.append(f"{label}: draft 资源不能出现在正式库")
        if document.get("status") == "published":
            if not document.get("teaching_evidence"):
                result.errors.append(
                    f"{label}: published 场景必须包含 teaching_evidence"
                )
            for index, task in enumerate(document.get("learning_tasks") or [], 1):
                if not task.get("expected_answer") and not task.get("scoring_note"):
                    result.errors.append(
                        f"{label}: published learning_tasks[{index}] 必须可机器评分或提供 scoring_note"
                    )
        expected_relation = boundary_relations.get((sense_ref, contrast_target))
        actual_relation = document.get("contrast_relation")
        if expected_relation and actual_relation != expected_relation:
            result.errors.append(
                f"{label}: contrast_relation '{actual_relation}' 与词义边界 "
                f"'{expected_relation}' 不一致"
            )

        beats = [beat.get("beat") for beat in document.get("storyboard") or []]
        if not _beats_are_contiguous(beats):
            result.errors.append(
                f"{label}: storyboard beat 序号应从 1 开始且连续递增"
            )
        if scene_type == "transfer":
            dimensions = document.get("transfer_dimensions") or []
            if len(dimensions) < 2:
                result.errors.append(
                    f"{label}: transfer 场景至少声明两个 transfer_dimensions"
                )
        result.coverage[sense_ref].add(scene_type)

    return result


def print_result(result: ValidationResult, backlog: bool = False) -> None:
    print(f"义项: {len(result.senses)} 个 | 场景: {len(result.scenes)} 个")
    for sense_id in sorted(result.known_sense_ids):
        types = result.coverage.get(sense_id)
        if types:
            functions = ", ".join(sorted(types))
            print(f"  {sense_id}: {len(types)} 类教学证据 ({functions})")
        else:
            print(f"  {sense_id}: 尚无场景证据")

    print(f"\n悬空引用: {len(result.dangling)} 个义项被引用但未建立")
    if backlog:
        print("\n=== 待建义项 backlog (按被引用次数排序) ===")
        for reference, locations in sorted(
            result.dangling.items(), key=lambda item: -len(item[1])
        ):
            print(
                f"  {reference}  ({len(locations)} 处引用: "
                f"{', '.join(locations)})"
            )

    if result.errors:
        print(f"\n发现 {len(result.errors)} 个错误:", file=sys.stderr)
        for validation_error in result.errors:
            print(f"  ✗ {validation_error}", file=sys.stderr)
    else:
        print("\n✓ 全部校验通过")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backlog", action="store_true", help="输出被引用但尚未建立的义项清单"
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        default=ROOT / "data",
        help="包含 senses/ 与 scenes/ 的数据目录；用于发布前隔离校验",
    )
    arguments = parser.parse_args()
    result = validate_repository(arguments.data_root)
    print_result(result, arguments.backlog)
    if result.errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
