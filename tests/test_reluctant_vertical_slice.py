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
PLANS_DIR = ROOT / "data" / "drafts" / "shot-plans" / SCENE_ID
PROMPT_PATH = ROOT / "prompts" / "shot-plan.md"


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _recommended_plan_path() -> Path:
    """最新版本就是推荐版本 —— 与 director.py show 的默认选择一致。

    历史版本一律保留 (v01 是第一轮问题证据), 所以这里必须取最大版本号,
    不能钉死某个 v0N。
    """
    versions = sorted(PLANS_DIR.glob("v[0-9][0-9]"))
    assert versions, f"{PLANS_DIR} 下没有任何 Shot Plan 版本"
    return versions[-1] / "shot-plan.yaml"


def _shot_text(shot: dict) -> str:
    """一个镜头里所有面向执行的自由文本, 用于层级越界检查。

    刻意**排除** semantic_evidence.must_avoid: 那里出现 disgust / overlay
    这类词是在**禁止**它们, 正是我们想要的。
    """
    parts = [
        shot["visual_start"]["description"],
        shot["trigger"]["description"],
        shot["action"]["description"],
        shot["visual_end"]["description"],
        shot["composition"]["staging"],
        shot["composition"]["focal_subject"],
        *shot["semantic_evidence"]["must_show"],
    ]
    return " ".join(parts).lower()


@pytest.fixture(scope="module")
def sense() -> dict:
    return _load(SENSE_PATH)


@pytest.fixture(scope="module")
def scene() -> dict:
    return _load(SCENE_PATH)


@pytest.fixture(scope="module")
def plan() -> dict:
    return _load(_recommended_plan_path())


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


def test_wordsense_is_still_on_its_first_semantic_contract(sense):
    """措辞与场景约束可以修订 (version 会涨), 语义契约没变则 semantic_revision 不动。

    两者混用会让所有已绑定的 Scene 无谓地变成 NEEDS_REVIEW。
    """
    assert sense["semantic_revision"] == revisions.NEW_SENSE_SEMANTIC_REVISION
    assert sense["version"] >= 1


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


def test_beats_are_introduced_in_storyboard_order(plan, scene):
    """Beat 只能按 storyboard 顺序被首次引入, 镜头序列不能倒着讲这个故事。

    这里刻意**不**断言"至少有一个镜头合并了多个 Beat"。
    "Beat 与 Shot 不要求一一对应"不等于"不允许一一对应": 只要切镜有真实的动作
    边界、构图、空间、语义强调或视频执行理由, 3 Beats → 3 Shots 同样成立。
    把合并写成不变量, 等于让测试逼着内容去证明一个尚未被 animatic 验证的拆法。
    """
    order = shot_plan_lib.scene_beats(scene)
    first_seen = []
    for shot in plan["shots"]:
        for beat in shot["source_beats"]:
            if beat not in first_seen:
                first_seen.append(beat)
    assert first_seen == order


# --------------------------------------------- v05: animatic 审核驱动的上游修订
# 以下断言锁的是**这一条真实样本当前的拆分决定**, 由 Keyframe Plan v01 / Animatic
# v01 的时长证据逼出来 (见 docs/vertical-slices/reluctant-01-keyframe-animatic.md)。
# 它们是数据回归, 不是通用架构规则: 通用校验器仍然不要求三镜、不要求 Beat 与 Shot
# 一一对应, 也不要求任何固定时长。

def test_recommended_plan_is_the_animatic_revised_three_shot_cut(plan):
    """v05 是当前推荐版本, 且历史版本一个都没有被覆盖。"""
    assert plan["version"] == 5
    assert plan["id"] == f"{SCENE_ID}-shot-plan-05"
    for version in range(1, 6):
        assert (PLANS_DIR / f"v{version:02d}" / "shot-plan.yaml").exists()
    assert len(plan["shots"]) == 3, (
        "本场景当前的拆分是三镜: 合并版 (v04) 的 shot-02 装不下自己的动作链"
    )


def test_v05_gives_each_pause_a_shot_that_can_carry_it(plan):
    """时长判据: 每个镜头都回到生产目标区间, 总时长仍是一条短片。

    这里不断言具体秒数 —— 秒数是内容判断, 会随重新审核而变; 断言的是"没有任何一个
    镜头再次越过这一层自己的执行纪律"。
    """
    for shot in plan["shots"]:
        assert shot["duration_hint"] <= shot_plan_lib.WARN_SHOT_DURATION, (
            f"{shot['id']} 又回到了超过生产目标的长度"
        )
    total = plan["total_duration_hint"]
    assert shot_plan_lib.MIN_TOTAL_DURATION <= total <= shot_plan_lib.MAX_TOTAL_DURATION
    assert shot_plan_lib.shot_plan_warnings(plan) == []


def test_v05_hands_the_resistance_state_across_the_cut(plan):
    """切点必须交接状态, 而不是让下一镜重新建立低意愿。

    v02/v03 的真正缺陷就是这一步: 切点位置对, 但跨点状态没写出来。
    """
    shot_02 = next(s for s in plan["shots"] if s["id"] == "shot-02")
    shot_03 = next(s for s in plan["shots"] if s["id"] == "shot-03")

    exits = (shot_02["continuity"]["exits_to_next"] or "").strip()
    enters = (shot_03["continuity"]["enters_from_previous"] or "").strip()
    assert exits and enters
    assert len(exits) > 80 and len(enters) > 80, (
        "'Continue from previous shot.' 这一类交接等于没有交接"
    )

    # 交接的是具体状态: 哪只手、叉子在哪、躯干角度、屏幕方向、动作阶段。
    for text, label in ((exits, "shot-02.exits_to_next"), (enters, "shot-03.enters_from_previous")):
        lowered = text.lower()
        for token in ("right hand", "fork", "lean", "frame right", "plate"):
            assert token in lowered, f"{label} 没有写明 {token!r}"

    # 下一镜的起始画面必须继承同一个状态, 而不是从中立坐姿重开。
    start = shot_03["visual_start"]["description"].lower()
    for token in ("fork", "leaned back"):
        assert token in start, f"shot-03.visual_start 没有继承 {token!r}"


def test_v05_keeps_the_action_self_performed_and_unobstructed(plan):
    """三镜之后仍要能读出: 机会存在、没有外力、孩子自己完成、意愿没有转正。"""
    blob = " ".join(_shot_text(shot) for shot in plan["shots"])
    assert "nothing blocking access" in blob or "nothing stands between" in blob
    assert "no one else's hand" in blob, "没有任何一镜写明这一口是孩子自己吃的"

    final_end = plan["shots"][-1]["visual_end"]["description"].lower()
    assert "leaned back" in final_end or "sitting back" in final_end, (
        "结尾没有保住低意愿姿态"
    )


# --------------------------------------------------------------- 层级边界
# 以下断言锁的是"Shot Plan 只做视觉叙事执行"这条边界。第一轮真实产物
# (v01) 在这几处全部越界, 详见 docs/vertical-slices/reluctant-01-proto-01.md。

TEACHING_PACKAGING = (
    "overlay", "added in post", "subtitle", "caption", "narrator",
    "on screen", "on-screen", "text appears", "lower third",
)


def test_scene_has_no_target_word_reveal_beat(scene):
    """揭词是教学层的事, 不是 Scene 的语义节拍。"""
    for beat in scene["storyboard"]:
        blob = f"{beat['visual']} {beat.get('audio') or ''}".lower()
        assert "reluctant" not in blob, f"beat {beat['beat']} 仍在画面/音轨里揭示目标词"


def test_recommended_plan_has_no_teaching_overlay(plan):
    for shot in plan["shots"]:
        text = _shot_text(shot)
        for term in TEACHING_PACKAGING:
            assert term not in text, f"{shot['id']} 含教学包装用语: {term!r}"


def test_recommended_plan_never_announces_the_target_word(plan):
    """没有旁白报词, 也没有把目标词本身当成要拍的东西。"""
    for shot in plan["shots"]:
        assert "reluctant" not in _shot_text(shot), (
            f"{shot['id']} 把目标词写进了执行文本"
        )
        dialogue = (shot["audio"].get("dialogue") or {})
        assert dialogue.get("speaker") != "narrator", (
            f"{shot['id']} 用旁白承担教学职责"
        )


def test_dialogue_is_never_marked_required(plan):
    """本场景的请求由指示动作建立, 台词只做自然化补充。"""
    for shot in plan["shots"]:
        assert shot["audio"]["mode"] != "required_dialogue", (
            f"{shot['id']} 把可由画面还原的信息标成了 required_dialogue"
        )


def test_meaning_survives_muted_playback(plan):
    """静音播放仍要有承载语义的镜头: 至少一个镜头完全不依赖对白。"""
    silent = [s for s in plan["shots"] if s["audio"]["mode"] in ("silence", "sfx")]
    assert silent, "每个镜头都带对白, 语义可能寄生在声音上"


# 只在人物脑内发生、摄影机拍不到的词。这不是通用语义 lint —— 只是把第一轮
# 真实产物里出现过的那类 trigger 钉住, 防止回归。
INTERNAL_ONLY_VERBS = (
    "realizes", "decides", "processes", "feels", "understands",
    "internal resistance",
)


def test_triggers_are_camera_observable(plan):
    for shot in plan["shots"]:
        trigger = shot["trigger"]["description"].lower()
        for verb in INTERNAL_ONLY_VERBS:
            assert verb not in trigger, (
                f"{shot['id']} 的 trigger 用了不可拍摄的心理动词: {verb!r} — "
                f"{shot['trigger']['description']}"
            )


# visual_start / visual_end 是关键帧的首尾锚点, 必须是能被画出来的状态。
# "aware" 一类的词描述的是脑内状态, 画师无从下笔。
UNDRAWABLE_STATES = INTERNAL_ONLY_VERBS + ("aware", "knows")


def test_visual_states_are_drawable(plan):
    for shot in plan["shots"]:
        for field in ("visual_start", "visual_end"):
            block = shot[field]
            text = " ".join([
                block["description"],
                *(state["state"] for state in block.get("character_states") or []),
            ]).lower()
            for word in UNDRAWABLE_STATES:
                assert word not in text, (
                    f"{shot['id']}.{field} 含无法画成关键帧的内部状态: {word!r}"
                )


# reluctant 是"对行动缺乏意愿", 不是"讨厌这个东西"。这些词出现在 must_avoid
# 里是对的 (那是在禁止它们), 出现在要拍的内容里就是语义漂移。
SENSORY_AVERSION = ("disgust", "distaste", "gag", "grimace", "revulsion")


def test_sensory_aversion_is_not_the_visual_evidence(plan):
    for shot in plan["shots"]:
        text = _shot_text(shot)
        for term in SENSORY_AVERSION:
            assert term not in text, (
                f"{shot['id']} 把感官厌恶当成了视觉证据: {term!r}"
            )


def test_wordsense_bars_object_dislike_and_word_reveal(sense):
    """漂移的根因在上游: WordSense 的场景约束必须先把这两条堵住。"""
    must_not = " ".join(sense["scene_requirements"]["must_not"]).lower()
    assert "disgust" in must_not
    assert "target word" in must_not


# ------------------------------------------------------- prompt contract
# 这些规则是被 v01 的真实失败逼出来的; 删掉它们, 同样的问题会再次生成出来。

@pytest.fixture(scope="module")
def prompt_text() -> str:
    return PROMPT_PATH.read_text(encoding="utf-8").lower()


@pytest.mark.parametrize("rule", [
    "realizes",              # trigger 可观察性: 心理动词黑名单
    "decides",
    "added in post",         # 教学包装禁令
    "overlay",
    "required_dialogue",     # 台词必要性判据
    "disgust",               # 相邻概念不得抢占视觉证据
])
def test_prompt_states_the_rule(prompt_text, rule):
    assert rule in prompt_text, f"prompts/shot-plan.md 缺少约束关键词: {rule!r}"


def test_prompt_ranks_semantic_continuity_over_duration(prompt_text):
    """时长偏好会把'抵抗贯穿动作'切成两个镜头; v02/v03 连续两次如此。"""
    assert "语义连续性优先" in prompt_text
