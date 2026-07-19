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
from collections import Counter
from jsonschema import Draft202012Validator, FormatChecker

import revisions

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
    coverage: dict[str, Counter] = field(
        default_factory=lambda: defaultdict(Counter)
    )
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    scene_revisions: dict[Path, revisions.SceneRevisionCheck] = field(
        default_factory=dict
    )

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
    entry_validator = load_schema("word-entry.schema.json")

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
        result.coverage[sense_ref][scene_type] += 1

    _check_scene_revisions(result, data_root)
    _check_surface_diversity(result, data_root)
    _check_inventory_identity(result, data_root)
    _check_dictionary_facts(result, data_root)
    _check_word_entries(result, data_root, entry_validator)
    return result


def _check_scene_revisions(result: ValidationResult, data_root: Path) -> None:
    """场景与它所教义项的语义契约修订是否仍然对得上。

    落后一版 (NEEDS_REVIEW) 只是警告: 语义契约更新意味着这些场景需要人重新看一遍
    视觉证据, 不意味着它们此刻就是错的, 不该因此卡住整条视频生产线。修订超前、
    依赖不存在或 1.1 场景缺少绑定则是错误 — 那是依赖关系本身不成立。
    """
    senses_by_id = {
        str(document.get("id")): document for document in result.senses.values()
    }
    for path, document in result.scenes.items():
        label = _location(path, data_root)
        check = revisions.check_scene_revision(
            document, senses_by_id.get(str(document.get("sense_ref")))
        )
        result.scene_revisions[path] = check
        if check.status == revisions.NEEDS_REVIEW:
            result.warnings.append(f"{label}: {check.message}")
        elif check.is_error:
            result.errors.append(f"{label}: {check.message}")


def print_scene_revisions(
    result: ValidationResult, data_root: Path, sense_filter: str = ""
) -> int:
    """输出场景语义修订状态; 返回退出码 (只有 INVALID / MISSING 才失败)。"""
    print("Scene semantic revision check")
    counts: Counter = Counter()
    for path in sorted(result.scene_revisions):
        check = result.scene_revisions[path]
        document = result.scenes[path]
        if sense_filter and document.get("sense_ref") != sense_filter:
            continue
        counts[check.status] += 1
        if check.status == revisions.CURRENT:
            continue
        # 默认只详细打印非 CURRENT 项: 需要人看的是变化, 不是清单。
        print(f"\n{check.status} {document.get('id') or _location(path, data_root)}")
        if check.scene_revision is not None:
            print(f"  scene revision: {check.scene_revision}")
        if check.current_revision is not None:
            print(f"  current WordSense revision: {check.current_revision}")
        print(f"  {check.message}")

    print("\nSummary:")
    for status in revisions.STATUSES:
        print(f"  {status.lower()}: {counts[status]}")
    return 1 if counts[revisions.INVALID] or counts[revisions.MISSING] else 0


def _check_inventory_identity(result: ValidationResult, data_root: Path) -> None:
    """schema_version 1.1 的义项必须仍然忠实于它的 approved Sense Inventory。

    起草时程序已强制写入身份字段, 这里防的是之后的人工编辑: 有人把 pos 改掉、
    删掉一个 source entry 或把 boundary 指向不存在的义项, 都必须在发布门被拦下。
    1.0 是 inventory 层之前的历史资源, 不参与本检查; 只读文件, 不触网。
    """
    try:
        import inventory
    except ImportError:
        return
    cache: dict[str, dict[str, Any] | str] = {}
    for path, document in result.senses.items():
        if document.get("schema_version") != "1.1":
            continue
        label = _location(path, data_root)
        word = str(document.get("word") or "")
        if not word:
            continue
        if word not in cache:
            try:
                cache[word] = inventory.load_approved_inventory(word)
            except inventory.InventoryError as exc:
                cache[word] = str(exc)
        loaded = cache[word]
        if isinstance(loaded, str):
            result.errors.append(
                f"{label}: schema_version 1.1 义项无法加载 approved Sense "
                f"Inventory: {loaded.splitlines()[0]}"
            )
            continue
        inventory_sense = inventory.find_inventory_sense(
            loaded, str(document.get("id"))
        )
        if inventory_sense is None:
            result.errors.append(
                f"{label}: id '{document.get('id')}' 不在 '{word}' 的 approved "
                "Sense Inventory 中"
            )
            continue
        for message in inventory.validate_sense_against_inventory(
            document, loaded, inventory_sense
        ):
            result.errors.append(f"{label}: {message}")


def _check_dictionary_facts(result: ValidationResult, data_root: Path) -> None:
    """与本地词典缓存交叉核对 pos (软校验; 无缓存则跳过, 不触网)。"""
    try:
        import dictionary
    except ImportError:
        return
    # 词典 pos 标签与本库 pos 的对应
    pos_aliases = {
        "adj": {"adjective"}, "adv": {"adverb"}, "prep": {"preposition"},
        "conj": {"conjunction"}, "pron": {"pronoun"}, "det": {"determiner"},
        "intj": {"interjection"},
    }
    for path, document in result.senses.items():
        word, pos = document.get("word"), document.get("pos")
        if not word or not pos:
            continue
        facts = dictionary.cached_facts(str(word))
        if not facts or not facts["pos_senses"]:
            continue
        dict_pos = set(facts["pos_senses"])
        for abbr, fulls in pos_aliases.items():
            if abbr in dict_pos:
                dict_pos |= fulls
        if str(pos) not in dict_pos:
            result.warnings.append(
                f"{_location(path, data_root)}: pos '{pos}' 不在词典记录的"
                f"词性中 ({', '.join(sorted(set(facts['pos_senses'])))})"
            )


def _check_word_entries(
    result: ValidationResult, data_root: Path, validator: Draft202012Validator
) -> None:
    """校验 data/words/ 下的可选词目条目文件。"""
    entry_dir = data_root.parent / "words"
    if not entry_dir.exists():
        return
    for path in sorted(entry_dir.glob("*.yaml")):
        label = _location(path, data_root.parent)
        try:
            with open(path, encoding="utf-8") as file:
                doc = yaml.safe_load(file)
        except (OSError, yaml.YAMLError) as exc:
            result.errors.append(f"{label}: YAML 读取失败: {exc}")
            continue
        if not isinstance(doc, dict):
            result.errors.append(f"{label}: YAML 根节点必须是对象")
            continue

        # Schema 校验
        result.errors += _schema_errors(doc, validator, label)

        word = doc.get("word", "")
        if not word:
            continue

        # 校验每个义项引用
        for sense in doc.get("senses") or []:
            sid = sense.get("id", "")
            if not sid:
                continue
            if sid not in result.known_sense_ids:
                result.errors.append(
                    f"{label}: 引用的义项 '{sid}' 在正式库中不存在"
                )
                continue

            # 校验 scene_count 一致性
            actual_scenes = [
                sc
                for sc in result.scenes.values()
                if sc.get("sense_ref") == sid
            ]
            declared_count = sense.get("scene_count", 0)
            if declared_count != len(actual_scenes):
                result.errors.append(
                    f"{label}/{sid}: 声明的 scene_count={declared_count} "
                    f"与实际场景数 {len(actual_scenes)} 不一致"
                )

            # 校验 pos 一致性
            sense_doc = next(
                (s for s in result.senses.values() if s.get("id") == sid),
                None,
            )
            if sense_doc and sense.get("pos") != sense_doc.get("pos"):
                result.errors.append(
                    f"{label}/{sid}: pos '{sense.get('pos')}' "
                    f"与义项文件中的 '{sense_doc.get('pos')}' 不一致"
                )


def _check_surface_diversity(result: ValidationResult, data_root: Path) -> None:
    """同一义项、同一类型的多个场景必须在表面特征上有差异。

    多场景的价值在于泛化；surface 三字段全同的两个场景是重复证据。
    只产生 warning：表面判断最终属于人工审核，机器只负责提示。
    """
    grouped: dict[tuple[str, str], list[tuple[str, Any]]] = defaultdict(list)
    for path, document in result.scenes.items():
        key = (str(document.get("sense_ref")), str(document.get("scene_type")))
        grouped[key].append((_location(path, data_root), document.get("surface")))

    for (sense_ref, scene_type), scenes in grouped.items():
        if len(scenes) < 2:
            continue
        for label, surface in scenes:
            if not isinstance(surface, dict):
                result.warnings.append(
                    f"{label}: {sense_ref} 的 {scene_type} 有多个场景, "
                    "缺少 surface 无法检验泛化多样性"
                )
        seen: dict[tuple[str, str, str], str] = {}
        for label, surface in scenes:
            if not isinstance(surface, dict):
                continue
            triple = (
                str(surface.get("domain")),
                str(surface.get("participant_type")),
                str(surface.get("setting")),
            )
            if triple in seen:
                result.warnings.append(
                    f"{label}: 与 {seen[triple]} 的 surface 完全相同 "
                    f"({'/'.join(triple)})——重复证据不构成泛化"
                )
            else:
                seen[triple] = label


def print_result(result: ValidationResult, backlog: bool = False) -> None:
    print(f"义项: {len(result.senses)} 个 | 场景: {len(result.scenes)} 个")
    for sense_id in sorted(result.known_sense_ids):
        counts = result.coverage.get(sense_id)
        if counts:
            missing = [t for t in SCENE_TYPE_ABBR if t not in counts]
            functions = ", ".join(
                f"{t}×{counts[t]}" if counts[t] > 1 else t
                for t in SCENE_TYPE_ABBR if t in counts
            )
            line = (f"  {sense_id}: {sum(counts.values())} 个场景, "
                    f"{len(counts)} 类教学证据 ({functions})")
            if missing:
                line += f" | 缺少: {', '.join(missing)}"
            print(line)
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

    if result.warnings:
        print(f"\n⚠ {len(result.warnings)} 个提示 (不阻塞发布):", file=sys.stderr)
        for validation_warning in result.warnings:
            print(f"  ⚠ {validation_warning}", file=sys.stderr)

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
    parser.add_argument(
        "--scene-revisions",
        nargs="?",
        const="",
        metavar="SENSE_ID",
        help="只报告场景与 WordSense 的语义修订状态; 可选按义项 ID 过滤",
    )
    arguments = parser.parse_args()
    result = validate_repository(arguments.data_root)
    if arguments.scene_revisions is not None:
        sys.exit(
            print_scene_revisions(
                result, arguments.data_root.resolve(), arguments.scene_revisions
            )
        )
    print_result(result, arguments.backlog)
    if result.errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
