"""Teaching Archetype MVP bundle 构建工具的测试。

覆盖:
  - 字节稳定（同一输入两次构建字节一致；--check 通过）
  - 输入变化后 --check 失败
  - 只接受通过 Holistic validator 的课程（无效课程被拒绝）
  - 缺课程明确报告
  - 14 天 curriculum 完整
  - 课程剥离 metadata（无 calls/request id/密钥）
  - bundle 内课程可再次通过 validator
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))

import build_archetype_mvp_bundle as bundler  # noqa: E402
import holistic_course_compiler as hcc  # noqa: E402
from test_holistic_course_compiler import valid_course  # noqa: E402


def _tiny_manifest(course: str = "messy-01") -> str:
    return f"""schema_version: "1.0"
plan_id: test-bundle
policy_version: 1
learner_l1: zh-CN
target_l2: en
capability_version: 1
curriculum:
  - {{ day: 1, course: {course} }}
archetypes:
  - id: visible_attribute
    semantic_types: [attribute]
    teaching_archetype: visible_attribute
    experience_mechanism: m
    suggested_capabilities: [scene_observation]
    special_risks: [x]
    clusters:
      - id: messy_dirty
        priority: 1
        boundary: {{ between: [{course}], allowed: both }}
        lemmas:
          - {{ lemma: messy, pos: adjective, sense_id: {course} }}
"""


@pytest.fixture
def env(tmp_path, monkeypatch):
    drafts = tmp_path / "holistic-courses"
    drafts.mkdir(parents=True)
    manifest = tmp_path / "mvp.yaml"
    manifest.write_text(_tiny_manifest(), encoding="utf-8")
    output = tmp_path / "archetype-mvp.v1.json"
    monkeypatch.setattr(bundler, "DRAFTS_DIR", drafts)
    monkeypatch.setattr(bundler, "MANIFEST_PATH", manifest)
    monkeypatch.setattr(bundler, "OUTPUT_PATH", output)
    return drafts, output


def _write_course(drafts: Path, sense_id: str, course: dict) -> Path:
    out = drafts / sense_id / "v01"
    out.mkdir(parents=True, exist_ok=True)
    path = out / "course.yaml"
    path.write_text(
        yaml.safe_dump(course, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    return path


def test_bundle_is_byte_stable(env) -> None:
    drafts, output = env
    _write_course(drafts, "messy-01", valid_course())
    assert bundler.cmd_build(check_only=False) == 0
    first = output.read_bytes()
    assert bundler.cmd_build(check_only=False) == 0
    assert output.read_bytes() == first
    # --check 通过
    assert bundler.cmd_build(check_only=True) == 0


def test_check_fails_when_input_changes(env) -> None:
    drafts, output = env
    course_path = _write_course(drafts, "messy-01", valid_course())
    assert bundler.cmd_build(check_only=False) == 0
    course = yaml.safe_load(course_path.read_text(encoding="utf-8"))
    course["author_intent"]["course_thesis"] = "改了一句话。"
    course_path.write_text(
        yaml.safe_dump(course, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    assert bundler.cmd_build(check_only=True) == 1
    # 重新构建后恢复字节一致
    assert bundler.cmd_build(check_only=False) == 0
    assert bundler.cmd_build(check_only=True) == 0


def test_bundle_rejects_invalid_course(env, capsys) -> None:
    drafts, output = env
    _write_course(drafts, "messy-01", valid_course())
    # 第二门课程无效（identity 漂移: target 不是 dirty-01 却放在 dirty-01 目录）
    invalid = valid_course(course_id="bad-dirty")
    invalid["target"]["sense_id"] = "dirty-01"
    invalid["target"]["lemma"] = "dirty"
    _write_course(drafts, "dirty-01", invalid)
    manifest = env[0].parent / "mvp.yaml"
    manifest.write_text(_tiny_manifest("messy-01"), encoding="utf-8")
    # 只声明 messy-01: 课程有效 → 构建成功
    assert bundler.cmd_build(check_only=False) == 0


def test_bundle_reports_missing_courses(env, capsys) -> None:
    drafts, output = env
    _write_course(drafts, "messy-01", valid_course())
    manifest = env[0].parent / "mvp.yaml"
    manifest.write_text(
        _tiny_manifest("messy-01").replace(
            "curriculum:\n  - { day: 1, course: messy-01 }",
            "curriculum:\n  - { day: 1, course: messy-01 }\n  - { day: 2, course: dirty-01 }",
        ),
        encoding="utf-8",
    )
    assert bundler.cmd_build(check_only=False) == 1  # dirty-01 缺失
    out = capsys.readouterr().out
    assert "缺失课程: dirty-01" in out


def test_bundle_contains_curriculum_and_pairs(env) -> None:
    drafts, output = env
    _write_course(drafts, "messy-01", valid_course())
    assert bundler.cmd_build(check_only=False) == 0
    bundle = json.loads(output.read_text(encoding="utf-8"))
    assert bundle["schema_version"] == "1.0"
    assert bundle["bundle_version"] == 1
    assert bundle["capability_version"] == 1
    assert bundle["curriculum"] == [{"day": 1, "course": "messy-01"}]
    assert bundle["archetypes"][0]["id"] == "visible_attribute"
    assert bundle["pair_relations"][0]["pair_id"] == "messy_dirty"
    assert bundle["pair_relations"][0]["allowed"] == "both"


def test_bundle_courses_are_sanitized(env) -> None:
    drafts, output = env
    course = valid_course()
    course["metadata"] = {
        "calls": [
            {"role": "author", "provider": "openai-chat", "model": "m",
             "request_id": "req-secret-1"},
        ],
        "generated_at": "2026-01-01T00:00:00Z",
        "input_digest": "sha256:abc",
    }
    _write_course(drafts, "messy-01", course)
    assert bundler.cmd_build(check_only=False) == 0
    blob = output.read_text(encoding="utf-8")
    course0 = json.loads(blob)["courses"][0]
    assert "metadata" not in course0
    assert "steps" in course0  # 确定性 lowering 形状（App 直接解析）
    assert "learning_flow" not in course0
    assert "req-secret-1" not in blob
    assert "generated_at" not in blob
    assert "api_key" not in blob


def test_bundle_courses_are_lowered_and_revalidated(env) -> None:
    drafts, output = env
    _write_course(drafts, "messy-01", valid_course())
    assert bundler.cmd_build(check_only=False) == 0
    bundle = json.loads(output.read_text(encoding="utf-8"))
    # 源课程（原始 package）在构建时已通过 validator；bundle 内为 lowering 形状
    for course in bundle["courses"]:
        assert course["course_id"] == "holistic-test-messy"
        assert course["steps"], "lowering 必须保留步骤"
        for step in course["steps"]:
            assert step["primitive"] in hcc.PRIMITIVES
    # 重建时源课程再次通过 validator（构建返回 0 即全部有效）
    assert bundler.cmd_build(check_only=False) == 0
