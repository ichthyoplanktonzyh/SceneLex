"""Experience Program App bundle 生成器的回归测试。

验证: 确定性 (字节稳定)、--check 行为、reviewed/published 过滤与 draft 拒绝。
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import build_experience_app_bundle as bundle  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ASSET_PATH = ROOT / "app" / "assets" / "content" / "experience-programs.v1.json"
EXPECTED_SENSE_IDS = ("reluctant-01", "messy-01", "almost-01", "dirty-01")


def run_bundle(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(ROOT / "tools" / "build_experience_app_bundle.py"),
         *args],
        capture_output=True, text=True)


def test_bundle_shape_and_source_statuses() -> None:
    built = bundle.build_bundle()
    assert built["bundle_version"] == bundle.BUNDLE_VERSION
    assert built["schema_version"] == "1.0"
    assert tuple(built["programs"]) == EXPECTED_SENSE_IDS
    for sense_id in EXPECTED_SENSE_IDS:
        program = built["programs"][sense_id]
        assert program["status"] in ("reviewed", "published")
        assert program["target"]["sense_id"] == sense_id


def test_catalog_entries_are_consumer_shaped() -> None:
    built = bundle.build_bundle()
    catalog = built["catalog"]
    assert tuple(catalog) == EXPECTED_SENSE_IDS
    for sense_id in EXPECTED_SENSE_IDS:
        entry = catalog[sense_id]
        assert entry["sense_id"] == sense_id
        assert entry["lemma"]
        assert entry["pos"]
        assert entry["semantic_type"]
        assert entry["locale_l1"] == "zh"
        assert entry["program_id"] == built["programs"][sense_id]["program_id"]
        assert entry["program_version"] == built["programs"][sense_id]["program_version"]
        assert entry["boundaries"] == []
        assert entry["boundaries_status"] == "not_collected"
        assert isinstance(entry["l1_confusables"], list)
        # semantic_model 原始结构不得泄漏进 catalog
        assert "semantic_model" not in entry
        assert "units" not in entry


def test_render_is_byte_stable() -> None:
    first = bundle.render(bundle.build_bundle())
    second = bundle.render(bundle.build_bundle())
    assert first == second
    assert isinstance(first, str) and first.endswith("\n")


def test_check_passes_when_asset_matches() -> None:
    result = run_bundle("--check")
    assert result.returncode == 0, result.stderr
    # --check 不修改文件
    before = ASSET_PATH.read_bytes()
    run_bundle("--check")
    assert ASSET_PATH.read_bytes() == before


def test_check_fails_and_does_not_rewrite_when_asset_differs() -> None:
    original = ASSET_PATH.read_bytes()
    try:
        ASSET_PATH.write_bytes(original + b"# corrupted\n")
        result = run_bundle("--check")
        assert result.returncode != 0
        assert ASSET_PATH.read_bytes() == original + b"# corrupted\n"
    finally:
        ASSET_PATH.write_bytes(original)


def test_draft_source_is_rejected(tmp_path: Path) -> None:
    source = bundle.FIXTURE_DIR / "reluctant-01.yaml"
    program = yaml.safe_load(source.read_text(encoding="utf-8"))
    program["status"] = "draft"
    draft_path = tmp_path / "draft.yaml"
    draft_path.write_text(
        yaml.safe_dump(program, allow_unicode=True, sort_keys=False),
        encoding="utf-8")
    with pytest.raises(SystemExit, match="draft"):
        bundle._validate_source(draft_path)


def test_generated_asset_parses_and_is_reviewable() -> None:
    text = ASSET_PATH.read_text(encoding="utf-8")
    import json
    root = json.loads(text)
    assert root["bundle_version"] == bundle.BUNDLE_VERSION
    for sense_id in EXPECTED_SENSE_IDS:
        assert root["programs"][sense_id]["status"] in ("reviewed", "published")
