#!/usr/bin/env python3
"""Shot Plan 的身份、结构与语义校验。

领域边界:

- ``SceneSpec.storyboard`` 的 beat 是**语义单位**: 观众必须看见的事件, 以及它在
  词义证明中的作用;
- Shot 是**视频执行单位**: 一次连续摄像机观察和连续运动。

两者不要求一一对应 — 构图与动作连续时几个 beat 可以合并成一个 4 秒镜头, 一个
beat 需要先看外部压力再看人物反应时也可以拆成两个镜头。因此这里唯一的硬要求是
**覆盖**(每个 beat 至少被一个 Shot 引用)与**时间顺序**(镜头序列不能明显逆转
beat 时间线), 而不是数量相等。

本模块只服务 Shot Plan, 不是通用制片 DAG 框架。
"""

from __future__ import annotations

import revisions

# 与 revisions.py 一致: 模型"没写"与"写错了"必须区别对待。
_MISSING = object()

SCHEMA_VERSION = "1.0"
STATUS = "draft"

# 生产目标是 2–5 秒的连续动作原子。超过 5 秒仍可执行但值得人看一眼; 超过 8 秒
# 说明这个镜头其实是两段动作, 应该拆开而不是交给视频模型自行理解。
MIN_SHOT_DURATION = 1.0
WARN_SHOT_DURATION = 5.0
MAX_SHOT_DURATION = 8.0

# 一条教学场景通常是十几秒的短片; 越界只提示, 不在本阶段硬卡。
MIN_TOTAL_DURATION = 6.0
MAX_TOTAL_DURATION = 30.0

# 浮点数求和不要求绝对相等。
DURATION_TOLERANCE = 0.1

SHOT_ID = "shot-{:02d}"

IDENTITY_DRIFT_KEYWORD = "shot plan identity drift"


def _stated(container: object, field: str) -> object:
    """取模型明确写出的值; 只有 key 不存在才算"未表态"。"""
    if not isinstance(container, dict) or field not in container:
        return _MISSING
    return container[field]


def _number(value: object) -> float | None:
    """合法时长是数值。bool 是 int 的子类, 但 true 不是秒数。"""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _text(value: object) -> str:
    return value.strip() if isinstance(value, str) else ""


def plan_id(scene_id: str, version: int) -> str:
    return f"{scene_id}-shot-plan-{version:02d}"


def scene_beats(scene: dict) -> list[int]:
    """SceneSpec.storyboard 中真实存在的 beat 序号。"""
    beats = []
    for entry in scene.get("storyboard", []) or []:
        if isinstance(entry, dict):
            beat = entry.get("beat")
            if isinstance(beat, int) and not isinstance(beat, bool):
                beats.append(beat)
    return beats


def sum_shot_durations(plan: dict) -> float:
    total = 0.0
    for shot in plan.get("shots", []) or []:
        if isinstance(shot, dict):
            value = _number(shot.get("duration_hint"))
            if value is not None:
                total += value
    return round(total, 2)


# ------------------------------------------------------------ 身份与权威字段

def check_shot_plan_identity(
    raw_plan: dict,
    *,
    scene: dict,
    sense: dict,
    version: int,
) -> list[str]:
    """在程序覆盖之前, 检查模型是否显式写错了由程序控制的字段。

    缺失可补(那是簿记), 正确可接受, 显式写错必须失败: 一个自称属于别的场景、别的
    义项或别的语义修订的 Shot Plan, 说明模型在按别的东西理解本次任务, 覆盖字段只
    会把这个误解藏进一份看似合法的产物里。
    """
    scene_id = scene.get("id")
    expected = {
        "schema_version": SCHEMA_VERSION,
        "version": version,
        "status": STATUS,
        "id": plan_id(scene_id, version) if isinstance(scene_id, str) else None,
        "scene_ref": scene_id,
        "scene_version": scene.get("version"),
        "sense_ref": scene.get("sense_ref"),
        # 依赖链是 Shot Plan → Scene → WordSense: 语义修订以 WordSense 当前值为准,
        # Director 只在 Scene 与它一致 (CURRENT) 时才允许编译。
        "sense_revision": revisions.get_wordsense_semantic_revision(sense),
    }

    drift: list[str] = []
    for field, want in expected.items():
        actual = _stated(raw_plan, field)
        if actual is _MISSING or actual == want:
            continue
        drift.append(f"    {field}:\n      expected: {want!r}\n      actual:   {actual!r}")

    # total_duration_hint 是各 Shot 时长之和, 不是模型的创作判断。写错说明拆分与
    # 时长自己就没对上 (planning drift), 不能静默用求和覆盖了事。
    stated_total = _stated(raw_plan, "total_duration_hint")
    if stated_total is not _MISSING:
        want_total = sum_shot_durations(raw_plan)
        value = _number(stated_total)
        if value is None or abs(value - want_total) > DURATION_TOLERANCE:
            drift.append(
                f"    total_duration_hint:\n      expected: {want_total!r}"
                f"\n      actual:   {stated_total!r}"
            )
    return drift


def apply_authoritative_fields(
    plan: dict,
    *,
    scene: dict,
    sense: dict,
    version: int,
) -> dict:
    """程序写入身份、版本与总时长 (模型写的值一律作废)。"""
    plan["schema_version"] = SCHEMA_VERSION
    plan["version"] = version
    plan["status"] = STATUS
    plan["id"] = plan_id(scene["id"], version)
    plan["scene_ref"] = scene["id"]
    plan["scene_version"] = scene.get("version")
    plan["sense_ref"] = scene.get("sense_ref")
    plan["sense_revision"] = revisions.get_wordsense_semantic_revision(sense)
    plan["total_duration_hint"] = sum_shot_durations(plan)
    return plan


# ------------------------------------------------------------ 结构与语义校验

def validate_shot_plan(plan: dict, scene: dict) -> list[str]:
    """Schema 之外的 Beat→Shot 映射、时长、状态变化与连续性检查。"""
    errors: list[str] = []
    shots = plan.get("shots")
    if not isinstance(shots, list) or not shots:
        return ["shots 必须是非空数组"]

    expected_beats = scene_beats(scene)
    known = set(expected_beats)
    covered: set[int] = set()
    seen_beats: set[int] = set()
    # expected_beats 中下一个允许被首次引入的位置。
    next_intro = 0

    for index, shot in enumerate(shots):
        if not isinstance(shot, dict):
            errors.append(f"shots[{index}] 必须是对象")
            continue
        label = shot.get("id") if isinstance(shot.get("id"), str) else f"shots[{index}]"

        wanted_id = SHOT_ID.format(index + 1)
        if shot.get("id") != wanted_id:
            errors.append(
                f"{label} shot ID 必须从 shot-01 起连续编号, 此处应为 {wanted_id}"
            )

        beats = shot.get("source_beats")
        if not isinstance(beats, list) or not beats:
            errors.append(f"{label} 缺少 source_beats")
        else:
            clean = [b for b in beats if isinstance(b, int) and not isinstance(b, bool)]
            if len(clean) != len(beats):
                errors.append(f"{label} source_beats 只能是整数 beat 序号")
            if clean != sorted(clean):
                errors.append(f"{label} source_beats 必须升序: {beats}")
            unknown = sorted(set(clean) - known)
            if unknown:
                errors.append(f"{label} 引用了场景中不存在的 beat: {unknown}")
            covered.update(clean)
            # 判据是 beat 的**首次出现顺序**, 不是每个镜头的最大引用: 已经出现过的
            # beat 可以在后续镜头继续延续 (shot-01 [1,2] → shot-02 [2,3] 合法),
            # 但新 beat 必须按 storyboard 顺序被首次引入 — 先引入 beat 2 再引入
            # beat 1, 或者跳过 beat 2 先引入 beat 3, 都是在倒着讲这个故事。
            for beat in sorted(set(clean)):
                if beat in seen_beats or beat not in known:
                    continue
                due = expected_beats[next_intro] if next_intro < len(expected_beats) else None
                if beat != due:
                    errors.append(
                        f"{label} 违反 beat 首次出现顺序: 此处首次引入 beat {beat}, "
                        f"但尚未出现的最早 beat 是 {due}"
                    )
                seen_beats.add(beat)
                while next_intro < len(expected_beats) \
                        and expected_beats[next_intro] in seen_beats:
                    next_intro += 1

        duration = _number(shot.get("duration_hint"))
        if duration is None:
            errors.append(f"{label} 缺少数值 duration_hint")
        elif duration < MIN_SHOT_DURATION:
            errors.append(f"{label} duration_hint {duration}s 短于 {MIN_SHOT_DURATION}s")
        elif duration > MAX_SHOT_DURATION:
            errors.append(
                f"{label} duration_hint {duration}s 超过 {MAX_SHOT_DURATION}s: "
                "这是两段动作, 应拆成多个镜头"
            )

        for field in ("visual_start", "trigger", "action", "visual_end"):
            node = shot.get(field)
            if not isinstance(node, dict) or not _text(node.get("description")):
                errors.append(f"{label} {field}.description 不能为空")

        errors += _audio_issues(shot, label)
        errors += _continuity_issues(shot, label, index, len(shots))

    missing = sorted(set(expected_beats) - covered)
    if missing:
        errors.append(f"未被任何镜头覆盖的 storyboard beats: {missing}")

    total = _number(plan.get("total_duration_hint"))
    summed = sum_shot_durations(plan)
    if total is None:
        errors.append("缺少数值 total_duration_hint")
    elif abs(total - summed) > DURATION_TOLERANCE:
        errors.append(
            f"total_duration_hint {total}s 与各镜头之和 {summed}s 不一致"
        )
    return errors


def _audio_issues(shot: dict, label: str) -> list[str]:
    """visual-first: 台词只能澄清, 不能成为唯一语义证据。"""
    audio = shot.get("audio")
    if not isinstance(audio, dict):
        return [f"{label} 缺少 audio"]
    if audio.get("mode") != "required_dialogue":
        return []
    issues = []
    dialogue = audio.get("dialogue")
    if not isinstance(dialogue, dict) or not _text(dialogue.get("speaker")) \
            or not _text(dialogue.get("text")):
        issues.append(f"{label} required_dialogue 必须写明 speaker 与 text")
    if not _text(audio.get("purpose")):
        issues.append(f"{label} required_dialogue 必须说明为何画面本身不足以成立")
    evidence = shot.get("semantic_evidence")
    must_show = evidence.get("must_show") if isinstance(evidence, dict) else None
    if not isinstance(must_show, list) or not [x for x in must_show if _text(x)]:
        issues.append(
            f"{label} required_dialogue 仍必须有独立于台词的 must_show 视觉证据"
        )
    return issues


def _continuity_issues(shot: dict, label: str, index: int, count: int) -> list[str]:
    """结构检查而非自然语言比对: 中间镜头不能两头都不交代。"""
    continuity = shot.get("continuity")
    if not isinstance(continuity, dict):
        return [f"{label} 缺少 continuity"]
    if index == 0 or index == count - 1:
        return []
    if not _text(continuity.get("enters_from_previous")) \
            and not _text(continuity.get("exits_to_next")):
        return [
            f"{label} 是中间镜头, enters_from_previous 与 exits_to_next 不能同时为空"
        ]
    return []


def shot_plan_warnings(plan: dict) -> list[str]:
    """不阻塞编译, 但值得人看一眼的地方。"""
    warnings: list[str] = []
    for shot in plan.get("shots", []) or []:
        if not isinstance(shot, dict):
            continue
        duration = _number(shot.get("duration_hint"))
        if duration is not None and WARN_SHOT_DURATION < duration <= MAX_SHOT_DURATION:
            warnings.append(
                f"{shot.get('id')} duration_hint {duration}s 超过生产目标 "
                f"{WARN_SHOT_DURATION}s, 确认视频模型能连续承载这段动作"
            )
    total = _number(plan.get("total_duration_hint"))
    if total is not None and not MIN_TOTAL_DURATION <= total <= MAX_TOTAL_DURATION:
        warnings.append(
            f"总时长 {total}s 不在 {MIN_TOTAL_DURATION}–{MAX_TOTAL_DURATION}s 的"
            "常规教学短片区间"
        )
    return warnings


# ------------------------------------------------------------ 人工审核输出

def shot_plan_summary(plan: dict) -> str:
    """面向人工审核的展开, 不是视频模型提示词。"""
    lines = [
        f"=== {plan.get('scene_ref')} | Shot Plan v{plan.get('version', 0):02d} ===",
        f"Scene version: {plan.get('scene_version')}",
        f"Sense revision: {plan.get('sense_revision')}",
        f"Shots: {len(plan.get('shots', []) or [])}",
        f"Estimated duration: {plan.get('total_duration_hint')}s",
    ]
    if plan.get("title"):
        lines.insert(1, plan["title"])

    for shot in plan.get("shots", []) or []:
        composition = shot.get("composition", {}) or {}
        camera = shot.get("camera", {}) or {}
        evidence = shot.get("semantic_evidence", {}) or {}
        audio = shot.get("audio", {}) or {}
        lines += [
            "",
            f"--- {shot.get('id')} | {shot.get('duration_hint')}s | "
            f"beats {shot.get('source_beats')} ---",
            f"Narrative: {shot.get('narrative_function')}",
            f"Semantic: {shot.get('semantic_function')}",
            f"Start: {(shot.get('visual_start') or {}).get('description', '')}",
            f"Trigger: {(shot.get('trigger') or {}).get('description', '')}",
            f"Action: {(shot.get('action') or {}).get('description', '')}",
            f"End: {(shot.get('visual_end') or {}).get('description', '')}",
            f"Composition: {composition.get('shot_size')} / {composition.get('angle')}",
            f"Camera: {camera.get('movement')}",
            f"Audio: {audio.get('mode')}",
        ]
        dialogue = audio.get("dialogue")
        if isinstance(dialogue, dict):
            lines.append(f"  {dialogue.get('speaker')}: {dialogue.get('text')}")
        lines.append("Must show:")
        lines += [f"  + {item}" for item in evidence.get("must_show", []) or []]
        lines.append("Must avoid:")
        lines += [f"  - {item}" for item in evidence.get("must_avoid", []) or []]
    return "\n".join(lines)
