#!/usr/bin/env python3
"""Teaching Archetype Coverage: MVP 教学原型覆盖清单的校验、报告与生产队列。

数据来源: data/content-plans/mvp-teaching-archetypes.yaml (manifest)。
所有状态都从仓库真实文件计算, manifest 不存状态快照:

    python3 tools/teaching_coverage.py validate   # schema 校验 manifest
    python3 tools/teaching_coverage.py report     # 每 archetype 覆盖程度与缺口
    python3 tools/teaching_coverage.py queue      # 每个缺口的下一个真实动作
    python3 tools/teaching_coverage.py queue --json

状态链 (从不成熟到成熟):
    needs_candidate < needs_inventory < needs_wordsense < needs_contract
    < needs_concept < needs_transfer < needs_review < needs_boundary
    < draft_ready < release_ready

对未建立身份的 lemma, 只报告 lemma + pos, 绝不伪造 sense_id, 也不得跳过
inventory 直接调用 experience compiler。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import experience_compiler as compiler  # noqa: E402
import holistic_course_compiler as hcc  # noqa: E402

MANIFEST_PATH = ROOT / "data" / "content-plans" / "mvp-teaching-archetypes.yaml"
MANIFEST_SCHEMA_PATH = ROOT / "schema" / "teaching-archetype-coverage.schema.json"
CAPABILITIES_PATH = ROOT / "config" / "app-teaching-capabilities.v1.yaml"
HOLISTIC_DRAFTS_DIR = ROOT / "data" / "drafts" / "holistic-courses"
MVP_BUNDLE_PATH = ROOT / "app" / "assets" / "content" / "archetype-mvp.v1.json"

# 状态链 (MVP): 越靠前越不成熟。身份链 (dictionary evidence → inventory →
# WordSense) 之后进入生产链: contract → Holistic Course → MVP bundle。
STATUS_ORDER = (
    "needs_candidate",
    "needs_inventory",
    "needs_wordsense",
    "needs_contract",
    "needs_holistic_course",
    "needs_bundle",
    "release_ready",
)
STATUS_RANK = {name: index for index, name in enumerate(STATUS_ORDER)}

ACTIONS = {
    "needs_candidate": (
        "运行 python3 tools/inventory.py draft {lemma} 抓取词典证据并起草 "
        "sense inventory (Dictionary Evidence → Sense Inventory 身份链第一环)"
    ),
    "needs_inventory": (
        "运行 python3 tools/inventory.py approve {lemma} 批准 inventory "
        "(dictionary → inventory 身份链)"
    ),
    "needs_wordsense": (
        "依据已批准的 inventory 起草 WordSense: "
        "python3 tools/draft.py senses {lemma} → promote（inventory → "
        "WordSense 身份链）; 禁止伪造 sense_id"
    ),
    "needs_contract": "运行 python3 tools/experience_compiler.py contract {sense_id}",
    "needs_holistic_course": (
        "运行 python3 tools/holistic_course_compiler.py compile-batch "
        "--manifest data/content-plans/mvp-teaching-archetypes.yaml "
        "(或单课 compile {sense_id} --neighbor {sense_b} --version v01)"
    ),
    "needs_bundle": "运行 python3 tools/build_archetype_mvp_bundle.py",
    "release_ready": (
        "运行 python3 tools/build_archetype_mvp_bundle.py --check 验证 bundle; "
        "课程与 App 预览均可执行"
    ),
}


class CoverageError(RuntimeError):
    pass


def load_manifest(path: Path | None = None) -> dict:
    path = path or MANIFEST_PATH
    if not path.exists():
        raise CoverageError(f"缺少覆盖清单: {path}")
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def _load_schema() -> Draft202012Validator:
    with open(MANIFEST_SCHEMA_PATH, encoding="utf-8") as file:
        return Draft202012Validator(json.load(file))


def validate() -> list[str]:
    """schema 校验 manifest；返回错误列表 (空 = 通过)。

    额外做一条真实文件交叉校验：archetype.suggested_capabilities 必须引用
    config/app-teaching-capabilities.v1.yaml 已注册的 primitive。
    """
    manifest = load_manifest()
    errors: list[str] = []
    for error in _load_schema().iter_errors(manifest):
        location = "/".join(str(part) for part in error.absolute_path) or "(root)"
        errors.append(f"{location}: {error.message}")

    registered = {p["id"] for p in (load_capabilities().get("primitives") or [])}
    for archetype in manifest.get("archetypes") or []:
        for suggested in archetype.get("suggested_capabilities") or []:
            if suggested not in registered:
                errors.append(
                    f"archetypes/{archetype['id']}: suggested_capabilities "
                    f"{suggested!r} 未在 {CAPABILITIES_PATH.name} 中注册"
                )
    return errors


def load_capabilities() -> dict:
    try:
        doc = yaml.safe_load(CAPABILITIES_PATH.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise CoverageError(f"App capabilities 无法读取: {exc}") from exc
    if not isinstance(doc, dict) or not isinstance(doc.get("primitives"), list):
        raise CoverageError("App capabilities 结构不完整")
    return doc


# --------------------------------------------------------------------------- #
# 仓库真实状态计算
# --------------------------------------------------------------------------- #

def _inventory_status(lemma: str) -> str | None:
    """inventory 身份链: approved 正式 inventory / reviewed 草稿 / 无。"""
    official = ROOT / "data" / "inventories" / f"{lemma}.yaml"
    if official.exists():
        doc = yaml.safe_load(official.read_text(encoding="utf-8"))
        if doc.get("status") == "approved":
            return "approved"
    draft = ROOT / "data" / "drafts" / "inventories" / f"{lemma}.yaml"
    if draft.exists() and not draft.name.startswith("_"):
        doc = yaml.safe_load(draft.read_text(encoding="utf-8"))
        if doc.get("status") in ("reviewed", "draft"):
            return "reviewed"
    return None


def _find_sense_ids(lemma: str) -> list[str]:
    if not (ROOT / "data" / "senses").exists():
        return []
    return sorted(
        path.stem for path in (ROOT / "data" / "senses").glob(f"{lemma}*.yaml")
    )


def _contract_ok(sense_id: str) -> tuple[bool, str]:
    path = ROOT / "data" / "contracts" / f"{sense_id}.yaml"
    if not path.exists():
        return False, ""
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not (doc.get("content_hash") and compiler.verify_contract_self_hash(doc)):
        return False, ""
    return True, doc["content_hash"]


def _evidence_ok(lemma: str) -> bool:
    """Dictionary Evidence 身份链第一环：官方证据文件存在（draft snapshot 也可）。"""
    return (
        (ROOT / "data" / "dictionary-evidence" / f"{lemma}.yaml").exists()
        or (ROOT / "data" / "drafts" / "dictionary-evidence" / f"{lemma}.yaml").exists()
    )


def _holistic_status(sense_id: str) -> str:
    """Holistic Course 状态链（从真实课程文件计算）：
    missing_contract < not_generated < invalid < validated。
    校验复用 holistic_course_compiler.validate_course_package（只做硬约束）。
    路径在调用时基于 ROOT 计算（测试可重定向 ROOT）。
    """
    if not (ROOT / "data" / "contracts" / f"{sense_id}.yaml").exists():
        return "missing_contract"
    base = ROOT / "data" / "drafts" / "holistic-courses" / sense_id
    if not base.exists():
        return "not_generated"
    try:
        sense = compiler.load_sense(sense_id)
        contract = compiler.load_contract(sense_id)
        capabilities = hcc.load_capabilities()
    except Exception:
        return "invalid"
    for path in sorted(base.glob("v*/course.yaml")):
        try:
            course = yaml.safe_load(path.read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError):
            continue
        if not isinstance(course, dict):
            continue
        result = hcc.validate_course_package(
            course, sense=sense, contract=contract, capabilities=capabilities
        )
        if result.valid:
            return "validated"
    return "invalid"


def _related_course_status(sense_id: str) -> str:
    """related course 状态：minimal pair 邻接义项的 Holistic Course 状态。"""
    partner = _boundary_partner(sense_id)
    if not partner:
        return "no_pair_partner"
    return _holistic_status(partner)


def _bundle_status(sense_id: str) -> str:
    """preview bundle 状态：archetype-mvp.v1.json 是否真实包含该课程。"""
    bundle_path = ROOT / "app" / "assets" / "content" / "archetype-mvp.v1.json"
    if not bundle_path.exists():
        return "not_bundled"
    try:
        bundle = yaml.safe_load(bundle_path.read_text(encoding="utf-8"))
        courses = bundle.get("courses") or []
    except (OSError, yaml.YAMLError):
        return "not_bundled"
    course_ids = {
        (c.get("target") or {}).get("sense_id") for c in courses
        if isinstance(c, dict)
    }
    return "bundled" if sense_id in course_ids else "not_bundled"


def _capability_gaps(archetype: dict) -> list[str]:
    """App capability 缺口：suggested_capabilities 中未在 capabilities 注册的 id。"""
    registered = {p["id"] for p in (load_capabilities().get("primitives") or [])}
    return sorted(
        set(archetype.get("suggested_capabilities") or []) - registered
    )


def _sense_status(sense_id: str, lemma: str) -> str:
    """对已有 WordSense 身份的义项计算 MVP 生产状态 (从真实文件)。

    链: contract → Holistic Course（真实生成且通过硬校验）→ MVP bundle。
    """
    ok, _contract_hash = _contract_ok(sense_id)
    if not ok:
        return "needs_contract"
    if _holistic_status(sense_id) != "validated":
        return "needs_holistic_course"
    if _bundle_status(sense_id) != "bundled":
        return "needs_bundle"
    return "release_ready"


def lemma_status(lemma: str, sense_id: str | None) -> str:
    """一个 lemma 的身份链 + 生产状态。

    身份链不得跳过: 无词典证据 → needs_candidate; 有证据无 inventory →
    needs_inventory; 有 inventory 但无 WordSense → needs_wordsense;
    之后才进入生产状态。有 sense_id 的 lemma 直接走义项生产链。
    """
    if sense_id is None:
        if not _evidence_ok(lemma):
            return "needs_candidate"
        inventory = _inventory_status(lemma)
        if inventory is None:
            return "needs_inventory"
        if inventory == "reviewed":
            return "needs_inventory"
        sense_ids = _find_sense_ids(lemma)
        if not sense_ids:
            return "needs_wordsense"
        return min((_sense_status(sid, lemma) for sid in sense_ids),
                   key=lambda status: STATUS_RANK[status])
    return _sense_status(sense_id, lemma)


def _action_for(lemma: str, sense_id: str | None, status: str) -> str:
    if sense_id is None:
        template = ACTIONS[status]
        return template.format(lemma=lemma, sense_id="", sense_b="")
    template = ACTIONS[status]
    return template.format(
        lemma=lemma, sense_id=sense_id,
        sense_a=sense_id,
        sense_b=_boundary_partner(sense_id),
    )


def _boundary_partner(sense_id: str) -> str:
    """manifest 中与 sense_id 配对的义项 (boundary 队列需要); 找不到返回空。"""
    for archetype in load_manifest().get("archetypes") or []:
        for cluster in archetype.get("clusters") or []:
            lemmas = [item.get("sense_id") for item in cluster.get("lemmas") or []]
            if sense_id in lemmas and any(item for item in lemmas if item):
                partners = [item for item in lemmas if item and item != sense_id]
                return partners[0] if partners else ""
    return ""


def _boundary_allowance(sense_id: str) -> tuple[str, bool]:
    """返回 (allowed, insufficient_evidence_allowed)。

    allowed 取 manifest cluster.boundary.allowed 的原始枚举
    (one / other / both / insufficient_evidence)；没有 boundary 声明时为
    "none"。insufficient_evidence_allowed 是可选布尔，缺失时为 False。
    """
    for archetype in load_manifest().get("archetypes") or []:
        for cluster in archetype.get("clusters") or []:
            lemmas = [item.get("sense_id") for item in cluster.get("lemmas") or []]
            if sense_id not in lemmas:
                continue
            boundary = cluster.get("boundary") or {}
            allowed = boundary.get("allowed", "none")
            insufficient = bool(boundary.get("insufficient_evidence_allowed", False))
            return allowed, insufficient
    return "none", False


def _collect_lemmas() -> list[dict]:
    manifest = load_manifest()
    rows: list[dict] = []
    for archetype in manifest.get("archetypes") or []:
        for cluster in archetype.get("clusters") or []:
            for lemma in cluster.get("lemmas") or []:
                sense_id = lemma.get("sense_id")
                status = lemma_status(str(lemma["lemma"]), sense_id)
                allowed, insufficient = _boundary_allowance(sense_id) if sense_id else ("none", False)
                rows.append({
                    "archetype": archetype.get("id"),
                    "cluster": cluster.get("id"),
                    "lemma": lemma["lemma"],
                    "pos": lemma.get("pos"),
                    "sense_id": sense_id,
                    "status": status,
                    "action": _action_for(str(lemma["lemma"]), sense_id, status),
                    "identity_chain": _identity_chain(str(lemma["lemma"]), sense_id),
                    "holistic_status": _holistic_status(sense_id) if sense_id else "not_generated",
                    "related_status": _related_course_status(sense_id) if sense_id else "no_pair_partner",
                    "boundary_allowed": allowed,
                    "insufficient_evidence_allowed": insufficient,
                    "bundle_status": _bundle_status(sense_id) if sense_id else "not_bundled",
                })
    return rows


def _identity_chain(lemma: str, sense_id: str | None) -> str:
    """身份链状态：dictionary_evidence / inventory / wordsense / locked。"""
    if sense_id is None:
        if not _evidence_ok(lemma):
            return "dictionary_evidence_missing"
        inventory = _inventory_status(lemma)
        if inventory is None:
            return "dictionary_evidence_ok"
        if _find_sense_ids(lemma):
            return "inventory_approved"
        return "inventory_approved"
    return "locked"


# --------------------------------------------------------------------------- #
# report / queue
# --------------------------------------------------------------------------- #

def report() -> str:
    rows = _collect_lemmas()
    manifest = load_manifest()
    lines: list[str] = []
    lines.append("Teaching Archetype Coverage (MVP)")
    lines.append(f"  learner_l1=zh-CN  target_l2=en  policy_version=1")
    lines.append("")
    for archetype_id in sorted({row["archetype"] for row in rows}):
        group = [row for row in rows if row["archetype"] == archetype_id]
        archetype = next(
            a for a in manifest.get("archetypes") or []
            if a.get("id") == archetype_id
        )
        gaps = _capability_gaps(archetype)
        lines.append(f"[{archetype_id}]")
        lines.append(f"  suggested_capabilities: "
                     f"{', '.join(archetype.get('suggested_capabilities') or [])}")
        if gaps:
            lines.append(f"  capability_gaps: {', '.join(gaps)}")
        for row in group:
            label = row["sense_id"] or f"{row['lemma']} ({row['pos']})"
            boundary = row["boundary_allowed"]
            if row["insufficient_evidence_allowed"]:
                boundary = f"{boundary}+insufficient_evidence"
            lines.append(
                f"  {label:<22} {row['status']:<16} "
                f"chain={row['identity_chain']:<24} "
                f"holistic={row['holistic_status']:<15} "
                f"related={row['related_status']:<15} "
                f"boundary={boundary:<24} "
                f"bundle={row['bundle_status']}"
            )
        lines.append("")
    lines.append(f"共 {len(rows)} 个 lemma, "
                 f"{sum(1 for r in rows if r['status'] == 'release_ready')} "
                 f"个可发布, "
                 f"{sum(1 for r in rows if r['status'] == 'draft_ready')} "
                 f"个待冻结, "
                 f"{sum(1 for r in rows if r['status'] in ('needs_candidate', 'needs_inventory', 'needs_wordsense'))} "
                 f"个尚未进入身份链")
    return "\n".join(lines)


def queue() -> list[dict]:
    return sorted(_collect_lemmas(),
                  key=lambda row: (STATUS_RANK[row["status"]], row["lemma"]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("validate", help="按 schema 校验 manifest")
    sub.add_parser("report", help="输出每个 archetype 的覆盖程度与缺口")
    queue_parser = sub.add_parser("queue", help="为每个缺口输出下一步真实动作")
    queue_parser.add_argument("--json", action="store_true",
                              help="以 JSON 输出")
    arguments = parser.parse_args()

    if arguments.command == "validate":
        errors = validate()
        if errors:
            print("教学原型覆盖清单未通过 schema 校验:")
            for error in errors:
                print(f"  ✗ {error}")
            return 1
        print(f"✓ {MANIFEST_PATH.name} 通过 schema 校验")
        return 0

    if arguments.command == "report":
        print(report())
        return 0

    if arguments.command == "queue":
        rows = queue()
        if arguments.json:
            print(json.dumps(rows, ensure_ascii=False, indent=2))
        else:
            for row in rows:
                label = row["sense_id"] or f"{row['lemma']} ({row['pos']})"
                print(f"{row['status']:<16} {label:<22} → {row['action']}")
        return 0

    return 2


if __name__ == "__main__":
    sys.exit(main())
