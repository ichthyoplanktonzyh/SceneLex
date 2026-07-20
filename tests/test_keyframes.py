"""Keyframe Plan 与静态 animatic 的判据。

分两类:

1. **结构判据** (用合成 fixture): 绑定、覆盖、时序、唯一性、层级边界 —— 这些是
   任何 Keyframe Plan 都必须成立的事;
2. **真实数据回归** (用 reluctant-01-proto-01 v01): 锁住这条真实样本上已经审过的
   结论, 例如"没有教学 overlay"、"关键帧数量由状态变化决定"。

刻意**不**断言的东西: 每个 Shot 必须有 initial + final、每个 Shot 必须 2–5 帧、
每个 Shot 必须有 semantic_climax、每个 Beat 必须对应关键帧。一个样本不足以把这些
写成不变量; 写死它们等于让测试替内容决定该画几张图。
"""

from pathlib import Path

import copy
import html

import pytest
import yaml

import draft
import keyframe_plan as keyframe_lib

ROOT = Path(__file__).resolve().parent.parent
SCENE_ID = "reluctant-01-proto-01"
PLAN_PATH = (
    ROOT / "data" / "drafts" / "keyframe-plans" / SCENE_ID / "v01" / "keyframe-plan.yaml"
)
SHOT_PLAN_PATH = (
    ROOT / "data" / "drafts" / "shot-plans" / SCENE_ID / "v04" / "shot-plan.yaml"
)


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def shot_plan() -> dict:
    return _load(SHOT_PLAN_PATH)


@pytest.fixture(scope="module")
def plan() -> dict:
    return _load(PLAN_PATH)


@pytest.fixture
def editable(plan) -> dict:
    """可改的副本 —— 失败用例都是在合法产物上制造一处缺陷。"""
    return copy.deepcopy(plan)


@pytest.fixture(scope="module")
def manifest(plan, shot_plan) -> dict:
    return keyframe_lib.build_animatic(plan, shot_plan)


# ------------------------------------------------------- schema / loader

def test_real_plan_passes_schema_and_validators(plan, shot_plan):
    errors = draft.schema_check(
        plan, draft.load_schema("keyframe-plan.schema.json"), "keyframe-plan.yaml"
    )
    errors += keyframe_lib.validate_keyframe_plan(plan, shot_plan)
    assert errors == []


def test_plan_binds_an_existing_shot_plan_version(plan, shot_plan):
    """确定性检查: 引用的 Shot Plan 路径与版本必须真实存在。

    本层刻意不做 digest / SHA / 自动 stale 传播 —— 那是尚无证据支持的基础设施。
    """
    assert PLAN_PATH.exists() and SHOT_PLAN_PATH.exists()
    assert plan["shot_plan_ref"]["scene_id"] == SCENE_ID
    assert plan["shot_plan_ref"]["version"] == shot_plan["version"]


def test_unknown_shot_id_fails(editable, shot_plan):
    editable["shots"][0]["shot_id"] = "shot-09"
    editable["shots"][0]["keyframes"][0]["id"] = "shot-09-kf-01"
    editable["shots"][0]["keyframes"][1]["id"] = "shot-09-kf-02"
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("不存在的 shot" in error for error in errors)


def test_duplicate_keyframe_id_fails(editable, shot_plan):
    editable["shots"][1]["keyframes"][1]["id"] = \
        editable["shots"][1]["keyframes"][0]["id"]
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("重复" in error for error in errors)


def test_time_beyond_shot_duration_fails(editable, shot_plan):
    editable["shots"][0]["keyframes"][-1]["at_seconds"] = 99.0
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("超出" in error for error in errors)


def test_non_increasing_time_fails(editable, shot_plan):
    frames = editable["shots"][1]["keyframes"]
    frames[2]["at_seconds"] = frames[1]["at_seconds"]
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("未严格晚于" in error for error in errors)


def test_first_anchor_must_sit_at_the_shot_start(editable, shot_plan):
    editable["shots"][1]["keyframes"][0]["at_seconds"] = 1.5
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("第一个锚点" in error for error in errors)


def test_shot_without_keyframes_fails(editable, shot_plan):
    """空列表由 schema 的 minItems 拦; 整个 shot 缺席由覆盖检查拦。"""
    editable["shots"][0]["keyframes"] = []
    schema_errors = draft.schema_check(
        editable, draft.load_schema("keyframe-plan.schema.json"), "keyframe-plan.yaml"
    )
    assert schema_errors

    del editable["shots"][0]
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("没有任何关键帧的 shot" in error for error in errors)


def test_shot_order_must_follow_the_shot_plan(editable, shot_plan):
    editable["shots"].reverse()
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("顺序必须与 Shot Plan 一致" in error for error in errors)


def test_wrong_shot_plan_version_fails(editable, shot_plan):
    editable["shot_plan_ref"]["version"] = 3
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("Shot Plan 版本" in error for error in errors)


# --------------------------------------------------------------- 层级边界

def test_target_word_overlay_fails(editable, shot_plan):
    editable["shots"][0]["keyframes"][0]["must_show"].append(
        "The word appears as a text overlay across the lower third."
    )
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("教学包装" in error for error in errors)


def test_psychological_only_visual_state_fails(editable, shot_plan):
    editable["shots"][1]["keyframes"][1]["visual_state"] = (
        "The child feels internal resistance and decides not to move yet."
    )
    errors = keyframe_lib.validate_keyframe_plan(editable, shot_plan)
    assert any("画不出来的内部状态" in error for error in errors)


def test_must_avoid_may_name_what_it_forbids(editable, shot_plan):
    """禁止 disgust / narrator 的那句话本身不能被当成越界。"""
    editable["shots"][1]["keyframes"][0]["must_avoid"].append(
        "No narrator, no subtitle, no overlay of any kind."
    )
    assert keyframe_lib.validate_keyframe_plan(editable, shot_plan) == []


def test_real_plan_has_no_teaching_packaging_or_word_reveal(plan):
    """检查范围是**要画出来的东西**, 与 Shot Plan 层的同名判据一致。

    ``semantic_purpose`` 是写给人看的审核理由, 它当然可以提到 reluctant —— 那是在
    解释这一帧证明了什么, 不是要求画面上出现这个词。执行文本是 ``visual_state``
    与 ``must_show``。
    """
    for _shot_id, keyframe in keyframe_lib.keyframes(plan):
        blob = " ".join([keyframe["visual_state"], *keyframe["must_show"]]).lower()
        assert "reluctant" not in blob, f"{keyframe['id']} 把目标词写进了执行文本"
        for term in keyframe_lib.TEACHING_PACKAGING:
            assert term not in blob, f"{keyframe['id']} 含教学包装用语: {term!r}"


def test_real_plan_never_makes_sensory_disgust_the_evidence(plan):
    """reluctant 是对动作的低意愿, 不是对食物的厌恶; 在 must_avoid 里出现是对的。"""
    for _shot_id, keyframe in keyframe_lib.keyframes(plan):
        blob = " ".join([
            keyframe["visual_state"], *keyframe["must_show"]
        ]).lower()
        for term in ("disgust", "distaste", "gag", "grimace", "revulsion"):
            assert term not in blob, f"{keyframe['id']} 把感官厌恶当成了视觉证据"


# ------------------------------------------------------- animatic 时间轴

def test_total_duration_equals_sum_of_shot_durations(manifest, shot_plan):
    assert manifest["total_duration_seconds"] == pytest.approx(
        sum(keyframe_lib.shot_durations(shot_plan).values())
    )
    assert manifest["total_duration_seconds"] == pytest.approx(
        shot_plan["total_duration_hint"]
    )


def test_shot_order_matches_the_shot_plan(manifest, shot_plan):
    assert [shot["shot_id"] for shot in manifest["shots"]] == [
        shot["id"] for shot in shot_plan["shots"]
    ]


def test_every_keyframe_is_referenced_exactly_once(manifest, plan):
    referenced = [entry["keyframe_id"] for entry in manifest["entries"]]
    expected = [keyframe["id"] for _shot, keyframe in keyframe_lib.keyframes(plan)]
    assert referenced == expected
    assert len(set(referenced)) == len(referenced)


def test_timeline_is_contiguous_and_covers_every_shot(manifest):
    clock = 0.0
    for entry in manifest["entries"]:
        assert entry["start"] == pytest.approx(clock)
        assert entry["hold_seconds"] == pytest.approx(entry["end"] - entry["start"])
        assert entry["hold_seconds"] > 0
        clock = entry["end"]
    assert clock == pytest.approx(manifest["total_duration_seconds"])


def test_shot_boundaries_are_explicit(manifest):
    starts = [e["keyframe_id"] for e in manifest["entries"] if e["starts_shot"]]
    assert len(starts) == len(manifest["shots"])
    assert manifest["shots"][0]["transition_to_next"] == "cut"
    assert manifest["shots"][-1]["transition_to_next"] is None


def test_manifest_is_deterministic(plan, shot_plan):
    """相同输入必须产出同一份 manifest —— 没有时间戳、没有随机顺序。"""
    first = keyframe_lib.build_animatic(plan, shot_plan)
    second = keyframe_lib.build_animatic(copy.deepcopy(plan), copy.deepcopy(shot_plan))
    assert yaml.safe_dump(first, allow_unicode=True, sort_keys=False) == \
        yaml.safe_dump(second, allow_unicode=True, sort_keys=False)


def test_real_manifest_on_disk_matches_regeneration(plan, shot_plan, manifest):
    """提交的时间轴必须是当前工具从当前输入重新生成出来的东西。"""
    committed = _load(PLAN_PATH.parent / "animatic.yaml")
    assert committed == yaml.safe_load(
        yaml.safe_dump(manifest, allow_unicode=True, sort_keys=False)
    )


def test_animatic_validation_catches_a_broken_timeline(plan, shot_plan, manifest):
    broken = copy.deepcopy(manifest)
    broken["entries"].pop()
    assert keyframe_lib.validate_animatic(broken, plan, shot_plan)

    stretched = copy.deepcopy(manifest)
    stretched["total_duration_seconds"] = 99.0
    assert keyframe_lib.validate_animatic(stretched, plan, shot_plan)


# ------------------------------------------------------------ HTML 预览

@pytest.fixture(scope="module")
def preview(plan, shot_plan, manifest) -> str:
    return keyframe_lib.animatic_html(plan, shot_plan, manifest)


def test_preview_contains_every_shot_and_keyframe_id(preview, plan, manifest):
    for shot in manifest["shots"]:
        assert shot["shot_id"] in preview
    for _shot_id, keyframe in keyframe_lib.keyframes(plan):
        assert keyframe["id"] in preview
        # 自由文本经过 HTML 转义后才进页面 (撇号会变成实体), 所以比较转义后的形式。
        assert html.escape(keyframe["visual_state"])[:60] in preview


def test_preview_states_that_it_is_not_a_visual_review(preview):
    """文字卡片不能被当成"视觉审核已经通过"。"""
    assert keyframe_lib.PLACEHOLDER_WARNING in preview
    assert "不能审核" in preview


def test_every_placeholder_card_is_labelled_as_text(preview, plan):
    """每张卡自己就标着"这是文字", 而不是只在页顶写一句免责声明。"""
    assert preview.count("<span class='tag'>TEXTUAL PLACEHOLDER</span>") == len(
        keyframe_lib.keyframes(plan)
    )


def test_preview_needs_no_network_and_no_server(preview):
    """单文件、无 CDN、无外链: 浏览器直接打开即可, 测试也不需要浏览器。"""
    for token in ("http://", "https://", "<img", "src="):
        assert token not in preview
    assert preview.startswith("<!DOCTYPE html>")


def test_preview_is_deterministic(plan, shot_plan, manifest):
    assert keyframe_lib.animatic_html(plan, shot_plan, manifest) == \
        keyframe_lib.animatic_html(plan, shot_plan, manifest)


def test_committed_preview_matches_regeneration(preview):
    assert (PLAN_PATH.parent / "animatic.html").read_text(encoding="utf-8") == preview


# ------------------------------------------------- 真实样本的选帧结论回归

def test_keyframe_count_follows_state_change_not_a_role_template(plan):
    """角色枚举不得逼出重复帧: 不要求每个 Shot 集齐五种角色。

    这里断言的是"没有把模板套上去", 不是"必须正好 2 + 5"。
    """
    per_shot = {
        entry["shot_id"]: [kf["roles"] for kf in entry["keyframes"]]
        for entry in plan["shots"]
    }
    assert per_shot["shot-01"] == [["initial"], ["trigger", "final"]], (
        "shot-01 的请求由首尾两帧建立; 为 trigger 单开一帧会得到重复画面"
    )
    # 一帧承担多个功能时用数组表达, 而不是复制一张几乎相同的图。
    multi = [
        keyframe["id"]
        for _shot_id, keyframe in keyframe_lib.keyframes(plan)
        if len(keyframe["roles"]) > 1
    ]
    assert multi, "roles 是数组的理由必须来自真实内容, 否则应该用单数 role"


def test_shot_02_anchors_the_interior_pauses(plan):
    """两次停顿都必须被显式锚定 —— 首尾两帧无法表达它们。

    缺了中途停住那一帧, 视频模型会生成一次平滑的正常伸手 (= 只是慢);
    缺了送到嘴边停住那一帧, 阻力就只剩启动延迟 (= 犹豫一下然后正常吃)。
    """
    frames = next(e for e in plan["shots"] if e["shot_id"] == "shot-02")["keyframes"]
    roles = [role for keyframe in frames for role in keyframe["roles"]]
    assert "transition" in roles and "semantic_climax" in roles

    interior = [
        keyframe for keyframe in frames
        if keyframe["roles"] not in (["initial"], ["final"])
    ]
    assert len(interior) >= 3, "首尾锚点不足以表达 shot-02 的动作链"


def test_every_keyframe_says_why_it_cannot_be_dropped(plan):
    for _shot_id, keyframe in keyframe_lib.keyframes(plan):
        assert len(keyframe["semantic_purpose"]) > 30, (
            f"{keyframe['id']} 的 semantic_purpose 太短, 说明不了它为何必须存在"
        )
        assert keyframe["must_show"], f"{keyframe['id']} 没有可见证据"


def test_keyframe_plan_does_not_redirect_the_scene(plan, shot_plan):
    """Keyframe Plan 不得重新导演: 镜头数量、顺序与时长仍由 Shot Plan 决定。"""
    assert [entry["shot_id"] for entry in plan["shots"]] == \
        [shot["id"] for shot in shot_plan["shots"]]
    assert set(plan.keys()).isdisjoint({
        "shots_override", "duration", "total_duration_hint", "cast", "location",
    })


def test_keyframe_plan_carries_no_model_or_style_parameters(plan):
    """风格中立、模型中立: 不写 checkpoint / sampler / seed / 最终提示词 / 图片路径。"""
    blob = yaml.safe_dump(plan, allow_unicode=True).lower()
    for token in (
        "checkpoint", "sampler", "seed", "cfg", "comfyui", "negative_prompt",
        "pixar", "lora", "workflow", "image_path", ".png",
    ):
        assert token not in blob, f"Keyframe Plan 含渲染层参数: {token!r}"
