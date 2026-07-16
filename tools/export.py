#!/usr/bin/env python3
"""Export reviewed SceneLex resources for external consumers.

The bundle is deterministic: the same repository and package version produce
the same JSON bytes. Delivery over HTTP, object storage, a dictionary database,
or an application package belongs to consumer adapters outside the core data
model.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import validate

ROOT = Path(__file__).resolve().parent.parent


def build_bundle(
    package_version: str, statuses: tuple[str, ...] = ("reviewed", "published")
) -> dict:
    result = validate.validate_repository()
    if result.errors:
        raise ValueError("正式资源库校验失败，拒绝导出")

    senses = [
        document
        for _, document in sorted(result.senses.items())
        if document.get("status") in statuses
    ]
    included_sense_ids = {document["id"] for document in senses}
    scenes = [
        document
        for _, document in sorted(result.scenes.items())
        if document.get("status") in statuses
        and document.get("sense_ref") in included_sense_ids
    ]

    sense_ids_by_word = defaultdict(list)
    for document in senses:
        sense_ids_by_word[document["word"]].append(document["id"])
    scene_ids_by_sense = defaultdict(list)
    for document in scenes:
        scene_ids_by_sense[document["sense_ref"]].append(document["id"])

    return {
        "schema_version": "1.0",
        "package": {
            "id": "scenelex-core",
            "version": package_version,
            "languages": sorted({document["language"] for document in senses}),
            "included_statuses": list(statuses),
        },
        "senses": senses,
        "scenes": scenes,
        "index": {
            "sense_ids_by_word": dict(sorted(sense_ids_by_word.items())),
            "scene_ids_by_sense": dict(sorted(scene_ids_by_sense.items())),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="导出可供外部消费者使用的资源包")
    parser.add_argument("--version", required=True, help="资源包版本，如 0.1.0")
    parser.add_argument("--output", type=Path, help="输出文件；默认写到 stdout")
    parser.add_argument(
        "--published-only", action="store_true", help="只导出 published 资源"
    )
    arguments = parser.parse_args()
    statuses = ("published",) if arguments.published_only else ("reviewed", "published")
    try:
        bundle = build_bundle(arguments.version, statuses)
    except ValueError as exc:
        sys.exit(str(exc))
    output = json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(output, encoding="utf-8")
        print(f"✓ 已导出 {len(bundle['senses'])} 个义项、{len(bundle['scenes'])} 个场景")
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
