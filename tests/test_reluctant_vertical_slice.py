"""reluctant-01-proto-01 端到端垂直切片的回归判据。

这是仓库里第一条真正走完 Approved Inventory → WordSense 1.1 → SceneSpec 1.1 →
Shot Plan 的链路。这里断言的是**结构与依赖绑定**, 不是模型措辞: 镜头怎么拆、
台词怎么写都可以改, 但身份来源、语义修订绑定与 Beat 覆盖不能悄悄退化。
"""

from pathlib import Path

import pytest
import yaml

import draft
import inventory
import revisions
import shot_plan as shot_plan_lib

ROOT = Path(__file__).resolve().parent.parent
SENSE_ID = "reluctant-01"
SCENE_ID = "reluctant-01-proto-01"

SENSE_PATH = ROOT / "data" / "senses" / f"{SENSE_ID}.yaml"
SCENE_PATH = ROOT / "data" / "scenes" / SENSE_ID / f"{SCENE_ID}.yaml"
INVENTORY_PATH = ROOT / "data" / "inventories" / "reluctant.yaml"
PLAN_PATH = (ROOT / "data" / "drafts" / "shot-plans" / SCENE_ID / "v01"
             / "shot-plan.yaml")


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def sense() -> dict:
    return _load(SENSE_PATH)


@pytest.fixture(scope="module")
def scene() -> dict:
    return _load(SCENE_PATH)


@pytest.fixture(scope="module")
def plan() -> dict:
    return _load(PLAN_PATH)


def test_wordsense_is_inventory_driven(sense):
    """身份来自 approved Inventory, 不是手写的。"""
    approved = _load(INVENTORY_PATH)
    assert approved["status"] == "approved"
    entry = next(s for s in approved["senses"] if s["id"] == SENSE_ID)

    assert sense["schema_version"] == "1.1"
    assert sense["inventory"]["identity_digest"] == (
        inventory.compute_identity_digest(entry)
    )
    assert sense["inventory"]["evidence_digest"] == (
        approved["source"]["evidence_digest"]
    )
    assert sense["inventory_source_entries"] == entry["source_entries"]


def test_wordsense_matches_approved_inventory_identity(sense):
    approved = _load(INVENTORY_PATH)
    entry = next(s for s in approved["senses"] if s["id"] == SENSE_ID)
    assert inventory.validate_sense_against_inventory(sense, approved, entry) == []


def test_wordsense_starts_at_first_semantic_revision(sense):
    assert sense["version"] == 1
    assert sense["semantic_revision"] == revisions.NEW_SENSE_SEMANTIC_REVISION


def test_scene_revision_binding_is_current(scene, sense):
    """Shot Plan 只能从 CURRENT 的 SceneSpec 编译; 这是上游门禁本身。"""
    check = revisions.check_scene_revision(scene, sense)
    assert check.status == revisions.CURRENT, check.message


def test_reluctant_is_bounded_against_refuse(sense):
    """本切片存在的意义之一: reluctant 不能被拍成 refuse。"""
    targets = {b["target"] for b in sense["relations"]["boundaries"]}
    assert "refuse-01" in targets


def test_scene_does_not_rely_on_dialogue_alone(scene):
    """删掉全部台词后, 仍要有承载语义的画面节拍。"""
    silent_beats = [
        beat for beat in scene["storyboard"] if not beat.get("audio")
    ]
    assert silent_beats, "所有 beat 都带台词, 语义可能寄生在对白上"


def test_shot_plan_passes_its_own_validators(plan, scene):
    errors = draft.schema_check(
        plan, draft.load_schema("shot-plan.schema.json"), "shot-plan.yaml"
    )
    errors += shot_plan_lib.validate_shot_plan(plan, scene)
    assert errors == []


def test_shot_plan_binds_the_upstream_it_was_compiled_from(plan, scene, sense):
    assert plan["scene_ref"] == SCENE_ID
    assert plan["scene_version"] == scene["version"]
    assert plan["sense_ref"] == SENSE_ID
    assert plan["sense_revision"] == sense["semantic_revision"]


def test_every_scene_beat_reaches_some_shot(plan, scene):
    covered = {beat for shot in plan["shots"] for beat in shot["source_beats"]}
    assert covered == set(shot_plan_lib.scene_beats(scene))


def test_shots_are_not_a_mechanical_one_to_one_copy_of_beats(plan, scene):
    """Shot 是按连续观察条件编译的, 不是每个 Beat 配一个镜头。

    这条断言锁的是"Director 有权合并 Beat"这个设计事实。真实产物里
    beat 2 (抵抗外化) 与 beat 3 (行动仍然发生) 属于同一段连续动作, 中间切一刀
    会破坏"抵抗贯穿行动"这一核心证据。
    """
    merged = [shot for shot in plan["shots"] if len(shot["source_beats"]) > 1]
    assert merged, "没有任何镜头合并 Beat, 检查是否退化成机械一一对应"
