#!/usr/bin/env python3
"""Keyframe Plan 的结构校验、animatic 时间轴与低保真预览。

领域边界:

- Shot 是**视频执行单位**: 一次连续摄像机观察和连续运动 (由 Shot Plan 决定);
- Keyframe 是**必须被显式锚定的视觉状态**: 缺了它, 观众的语义推断会改变。

Keyframe Plan 不重新导演场景 —— 它不能改变镜头数量、顺序或时长, 只能在既定镜头
里选出最少但充分的状态锚点。视觉风格、图像/视频模型、seed 与最终提示词都不属于
这一层。

Animatic 在这里是**确定性时间轴 + 文字占位预览**: 它能审时序、状态覆盖、hold 时
长、镜头边界与动作密度, 不能代替真实画面的语义审核。
"""

from __future__ import annotations

import html

SCHEMA_VERSION = "1.0"
STATUS = "draft"

ROLES = ("initial", "trigger", "transition", "semantic_climax", "final")

# 第一个锚点应当就是镜头的起始状态。留一点容差是因为秒数是人写的, 但 0.2s 之后
# 才出现第一帧意味着镜头开头有一段没有任何锚点的画面。
FIRST_ANCHOR_TOLERANCE = 0.2
DURATION_TOLERANCE = 0.01

PLACEHOLDER_WARNING = "TEXTUAL PLACEHOLDER — NOT A VISUAL SEMANTIC REVIEW"

# 教学包装属于后续音频/剪辑层。与 Shot Plan 同一条边界, 在这里再守一次: 关键帧
# 是"画面里有什么", 一旦出现叠字/旁白/字幕, 说明这一层又开始承担教学职责了。
TEACHING_PACKAGING = (
    "overlay", "added in post", "subtitle", "caption", "narrator",
    "on screen", "on-screen", "text appears", "lower third",
)

# 只在人物脑内发生、画师无从下笔的词。这不是通用语义 lint, 只是把 Shot Plan 那一
# 轮真实出现过的那类表述钉在关键帧层同样不成立。
UNDRAWABLE_STATES = (
    "realizes", "decides", "processes", "feels", "understands",
    "internal resistance", "aware", "knows",
)


def _number(value: object) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)


def _text(value: object) -> str:
    return value.strip() if isinstance(value, str) else ""


def plan_id(scene_id: str, version: int) -> str:
    return f"{scene_id}-keyframe-plan-{version:02d}"


def shot_durations(shot_plan: dict) -> dict[str, float]:
    """Shot Plan 里每个镜头的时长; 顺序即镜头顺序。"""
    durations: dict[str, float] = {}
    for shot in shot_plan.get("shots", []) or []:
        if not isinstance(shot, dict):
            continue
        duration = _number(shot.get("duration_hint"))
        if isinstance(shot.get("id"), str) and duration is not None:
            durations[shot["id"]] = duration
    return durations


def keyframes(plan: dict) -> list[tuple[str, dict]]:
    """(shot_id, keyframe) 扁平序列, 保持文件里的顺序。"""
    flat: list[tuple[str, dict]] = []
    for entry in plan.get("shots", []) or []:
        if not isinstance(entry, dict):
            continue
        shot_id = entry.get("shot_id")
        for keyframe in entry.get("keyframes", []) or []:
            if isinstance(keyframe, dict):
                flat.append((shot_id, keyframe))
    return flat


# ------------------------------------------------------------------ 校验

def validate_keyframe_plan(plan: dict, shot_plan: dict) -> list[str]:
    """Schema 之外的绑定、覆盖、时序与层级边界检查。

    刻意**不**规定的东西: 每个 Shot 必须有 initial + final、每个 Shot 必须 2–5 帧、
    每个 Shot 必须有 semantic_climax、每个 Beat 必须对应关键帧、关键帧数量上限。
    帧数应当由内容的真实状态变化决定, 一个样本不足以把这些写成不变量。
    """
    errors: list[str] = []

    reference = plan.get("shot_plan_ref")
    if not isinstance(reference, dict):
        return ["缺少 shot_plan_ref"]
    if reference.get("scene_id") != plan.get("scene_ref"):
        errors.append(
            f"shot_plan_ref.scene_id {reference.get('scene_id')!r} 与 "
            f"scene_ref {plan.get('scene_ref')!r} 不一致"
        )
    if shot_plan.get("scene_ref") != plan.get("scene_ref"):
        errors.append(
            f"引用的 Shot Plan 属于场景 {shot_plan.get('scene_ref')!r}, "
            f"不是 {plan.get('scene_ref')!r}"
        )
    if shot_plan.get("version") != reference.get("version"):
        errors.append(
            f"引用的 Shot Plan 版本是 v{shot_plan.get('version')}, "
            f"但 shot_plan_ref.version 写的是 v{reference.get('version')}"
        )

    durations = shot_durations(shot_plan)
    planned = [
        entry.get("shot_id")
        for entry in plan.get("shots", []) or []
        if isinstance(entry, dict)
    ]

    unknown = [shot_id for shot_id in planned if shot_id not in durations]
    if unknown:
        errors.append(f"引用了 Shot Plan 中不存在的 shot: {unknown}")

    missing = [shot_id for shot_id in durations if shot_id not in planned]
    if missing:
        errors.append(f"没有任何关键帧的 shot: {missing}")

    covered = [shot_id for shot_id in planned if shot_id in durations]
    expected_order = [shot_id for shot_id in durations if shot_id in set(covered)]
    if covered != expected_order:
        errors.append(
            f"shots 顺序必须与 Shot Plan 一致: 此处是 {covered}, 应为 {expected_order}"
        )

    seen_ids: set[str] = set()
    for entry in plan.get("shots", []) or []:
        if not isinstance(entry, dict):
            continue
        shot_id = entry.get("shot_id")
        duration = durations.get(shot_id)
        previous: float | None = None
        frames = entry.get("keyframes", []) or []

        for index, keyframe in enumerate(frames):
            if not isinstance(keyframe, dict):
                errors.append(f"{shot_id} keyframes[{index}] 必须是对象")
                continue
            label = keyframe.get("id") if isinstance(keyframe.get("id"), str) \
                else f"{shot_id} keyframes[{index}]"

            if isinstance(keyframe.get("id"), str):
                if keyframe["id"] in seen_ids:
                    errors.append(f"{label} keyframe ID 重复")
                seen_ids.add(keyframe["id"])
                if not keyframe["id"].startswith(f"{shot_id}-kf-"):
                    errors.append(f"{label} 的 ID 前缀与所属 shot {shot_id} 不一致")

            at = _number(keyframe.get("at_seconds"))
            if at is None:
                errors.append(f"{label} 缺少数值 at_seconds")
            else:
                if previous is not None and at <= previous:
                    errors.append(
                        f"{label} at_seconds {at}s 未严格晚于上一帧的 {previous}s"
                    )
                previous = at
                if duration is not None and at > duration + DURATION_TOLERANCE:
                    errors.append(
                        f"{label} at_seconds {at}s 超出 {shot_id} 的时长 {duration}s"
                    )
                if index == 0 and at > FIRST_ANCHOR_TOLERANCE:
                    errors.append(
                        f"{label} 是 {shot_id} 的第一个锚点, at_seconds {at}s 却不在"
                        f"镜头起点附近 (≤{FIRST_ANCHOR_TOLERANCE}s)"
                    )

            errors += _content_issues(keyframe, label)

    return errors


def _content_issues(keyframe: dict, label: str) -> list[str]:
    """层级边界: 关键帧只描述画面里有什么。"""
    issues: list[str] = []
    state = _text(keyframe.get("visual_state"))
    # must_avoid 里出现这些词是在**禁止**它们, 不算越界。
    blob = " ".join([
        state,
        _text(keyframe.get("semantic_purpose")),
        *[_text(item) for item in keyframe.get("must_show", []) or []],
    ]).lower()

    for term in TEACHING_PACKAGING:
        if term in blob:
            issues.append(f"{label} 含教学包装用语: {term!r} — 那属于后续剪辑/音频层")
    for word in UNDRAWABLE_STATES:
        if word in state.lower():
            issues.append(
                f"{label} 的 visual_state 含画不出来的内部状态: {word!r}"
            )
    return issues


# ------------------------------------------------------------ animatic

def build_animatic(plan: dict, shot_plan: dict) -> dict:
    """确定性时间轴。相同输入必然得到同一份 manifest。

    hold 是**锚点到锚点的间隔**, 不是最终视频里画面静止的时长: 静态 animatic 用
    一张图占住这段时间, 真实执行时这段时间里画面是从本帧过渡到下一帧。
    """
    durations = shot_durations(shot_plan)
    order = list(durations)
    audio_modes = {
        shot.get("id"): (shot.get("audio") or {}).get("mode")
        for shot in shot_plan.get("shots", []) or []
        if isinstance(shot, dict)
    }
    by_shot = {
        entry.get("shot_id"): entry.get("keyframes", []) or []
        for entry in plan.get("shots", []) or []
        if isinstance(entry, dict)
    }

    shots: list[dict] = []
    entries: list[dict] = []
    clock = 0.0

    for index, shot_id in enumerate(order):
        duration = durations[shot_id]
        shot_start = round(clock, 3)
        shot_end = round(clock + duration, 3)
        shots.append({
            "shot_id": shot_id,
            "start": shot_start,
            "end": shot_end,
            "duration_seconds": duration,
            "audio_mode": audio_modes.get(shot_id),
            # Shot Plan 不描述转场; 镜头之间就是一刀直切。这里写死而不是留空,
            # 是为了让 animatic 明确表达镜头边界, 不是在建设转场系统。
            "transition_to_next": "cut" if index < len(order) - 1 else None,
        })

        frames = by_shot.get(shot_id, [])
        for position, keyframe in enumerate(frames):
            at = _number(keyframe.get("at_seconds")) or 0.0
            start = round(clock + at, 3)
            if position + 1 < len(frames):
                next_at = _number(frames[position + 1].get("at_seconds")) or at
                end = round(clock + next_at, 3)
            else:
                end = shot_end
            entries.append({
                "shot_id": shot_id,
                "keyframe_id": keyframe.get("id"),
                "roles": list(keyframe.get("roles", []) or []),
                "start": start,
                "end": end,
                "hold_seconds": round(end - start, 3),
                "starts_shot": position == 0,
            })
        clock += duration

    return {
        "schema_version": SCHEMA_VERSION,
        "scene_ref": plan.get("scene_ref"),
        "shot_plan_ref": dict(plan.get("shot_plan_ref") or {}),
        "keyframe_plan_version": plan.get("version"),
        "review_scope": (
            "时序、状态覆盖、hold 时长、镜头边界、动作密度 —— "
            "不含构图可读性、表情质量与真实画面连续性"
        ),
        "total_duration_seconds": round(clock, 3),
        "shots": shots,
        "entries": entries,
    }


def validate_animatic(manifest: dict, plan: dict, shot_plan: dict) -> list[str]:
    """时间轴必须完整覆盖关键帧, 且总时长等于各镜头时长之和。"""
    errors: list[str] = []
    entries = manifest.get("entries", []) or []

    referenced = [entry.get("keyframe_id") for entry in entries]
    expected = [keyframe.get("id") for _shot_id, keyframe in keyframes(plan)]
    if referenced != expected:
        errors.append(
            f"animatic entries 未按顺序覆盖全部关键帧: {referenced} != {expected}"
        )

    summed = round(sum(shot_durations(shot_plan).values()), 3)
    total = _number(manifest.get("total_duration_seconds"))
    if total is None or abs(total - summed) > DURATION_TOLERANCE:
        errors.append(
            f"animatic 总时长 {manifest.get('total_duration_seconds')}s 与各镜头之和 "
            f"{summed}s 不一致"
        )

    clock = None
    for entry in entries:
        start, end = _number(entry.get("start")), _number(entry.get("end"))
        if start is None or end is None or end < start:
            errors.append(f"{entry.get('keyframe_id')} 的时间区间非法")
            continue
        if clock is not None and start < clock - DURATION_TOLERANCE:
            errors.append(f"{entry.get('keyframe_id')} 的起点早于上一段的终点")
        clock = end
    return errors


# ------------------------------------------------------------- 人工审核输出

def keyframe_plan_summary(plan: dict, shot_plan: dict, manifest: dict) -> str:
    durations = shot_durations(shot_plan)
    reference = plan.get("shot_plan_ref") or {}
    lines = [
        f"=== {plan.get('scene_ref')} | Keyframe Plan v{plan.get('version', 0):02d} ===",
        f"Shot Plan version: v{reference.get('version')}",
        f"Shots: {len(plan.get('shots', []) or [])}",
        f"Keyframes: {len(keyframes(plan))}",
        f"Total duration: {manifest.get('total_duration_seconds')}s",
    ]
    holds = {
        entry.get("keyframe_id"): entry.get("hold_seconds")
        for entry in manifest.get("entries", []) or []
    }
    for entry in plan.get("shots", []) or []:
        shot_id = entry.get("shot_id")
        frames = entry.get("keyframes", []) or []
        lines += [
            "",
            f"--- {shot_id} | {durations.get(shot_id)}s | {len(frames)} keyframes ---",
        ]
        for keyframe in frames:
            lines += [
                f"  {keyframe.get('id')}  t={keyframe.get('at_seconds')}s  "
                f"hold={holds.get(keyframe.get('id'))}s  "
                f"[{', '.join(keyframe.get('roles', []) or [])}]",
                f"    state:   {keyframe.get('visual_state')}",
                f"    purpose: {keyframe.get('semantic_purpose')}",
            ]
    return "\n".join(lines)


# --------------------------------------------------------------- HTML 预览

_STYLE = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin: 0; padding: 24px; font: 15px/1.55 -apple-system, "Helvetica Neue",
       "PingFang SC", "Microsoft YaHei", sans-serif; background: #14161a; color: #e8eaed; }
h1 { font-size: 19px; margin: 0 0 4px; }
.sub { color: #9aa0a6; font-size: 13px; margin-bottom: 16px; }
.warn { border: 1px solid #b3541e; background: #2a1a0d; color: #ffb782;
        padding: 12px 14px; border-radius: 6px; margin-bottom: 18px; font-size: 13px; }
.warn b { display: block; letter-spacing: .04em; margin-bottom: 6px; color: #ffd0a3; }
.bar { display: flex; align-items: center; gap: 12px; margin-bottom: 18px; }
button { font: inherit; padding: 6px 16px; border-radius: 5px; border: 1px solid #4a5058;
         background: #232830; color: #e8eaed; cursor: pointer; }
button:hover { background: #2c323b; }
#clock { font-variant-numeric: tabular-nums; color: #9aa0a6; font-size: 13px; }
.shot { border-top: 2px solid #3a4048; margin-top: 20px; padding-top: 10px; }
.shot h2 { font-size: 15px; margin: 0 0 10px; }
.shot h2 span { color: #9aa0a6; font-weight: 400; font-size: 13px; margin-left: 8px; }
.cards { display: flex; flex-wrap: wrap; gap: 12px; }
.kf { flex: 1 1 260px; min-width: 240px; max-width: 380px; border: 1px solid #333940;
      border-radius: 6px; padding: 12px; background: #1b1f25; }
.kf.on { border-color: #7aa2f7; background: #1e2633; }
.kf .id { font-family: ui-monospace, Menlo, monospace; font-size: 12px; color: #7aa2f7; }
.kf .t { float: right; font-variant-numeric: tabular-nums; font-size: 12px; color: #9aa0a6; }
.kf .roles { margin: 6px 0 8px; }
.kf .role { display: inline-block; font-size: 11px; padding: 1px 7px; border-radius: 10px;
            background: #2d3440; color: #b8c0cc; margin-right: 4px; }
.ph { border: 1px dashed #4a5058; border-radius: 4px; padding: 10px; margin-bottom: 8px;
      font-size: 13px; color: #cdd2d8; }
.ph .tag { display: block; font-size: 10px; letter-spacing: .08em; color: #8a7050;
           margin-bottom: 6px; }
.why { font-size: 12.5px; color: #9aa0a6; }
.why b { color: #b8c0cc; font-weight: 600; }
ul { margin: 6px 0 0; padding-left: 18px; font-size: 12.5px; color: #9aa0a6; }
.cut { color: #9aa0a6; font-size: 12px; margin-top: 10px; letter-spacing: .04em; }
"""

# 时间由挂钟推导, 不是逐帧累加: 标签页切走时浏览器会限流甚至完全停掉回调,
# 累加式计时会就此失同步, 而按 t0 求差在恢复后自动回到正确位置。
_SCRIPT = """
const TL = %(timeline)s;
const TOTAL = %(total)s;
let t0 = null, timer = null;
const clock = document.getElementById('clock');
const play = document.getElementById('play');
function paint(t) {
  for (const e of TL) {
    document.getElementById(e.id).classList.toggle('on', t >= e.start && t < e.end);
  }
  clock.textContent = t.toFixed(1) + 's / ' + TOTAL.toFixed(1) + 's';
}
function stop() {
  clearInterval(timer); timer = null; t0 = null;
  play.textContent = 'Play timeline';
}
function step() {
  const t = (Date.now() - t0) / 1000;
  if (t >= TOTAL) { paint(TOTAL - 0.001); stop(); return; }
  paint(t);
}
play.onclick = () => {
  if (timer) { stop(); paint(0); return; }
  play.textContent = 'Stop';
  t0 = Date.now();
  paint(0);
  timer = setInterval(step, 50);
};
paint(0);
"""


def _esc(value: object) -> str:
    return html.escape("" if value is None else str(value))


def animatic_html(plan: dict, shot_plan: dict, manifest: dict) -> str:
    """单文件 HTML: 无外部 CDN、无服务器, 浏览器直接打开即可。

    它审的是时序与状态覆盖。占位卡是文字, 不是画面 —— 顶部的警告不是礼貌用语,
    而是这份产物的能力边界声明。
    """
    frames = {
        keyframe.get("id"): keyframe for _shot_id, keyframe in keyframes(plan)
    }
    holds = {entry.get("keyframe_id"): entry for entry in manifest.get("entries", [])}
    shot_meta = {shot.get("shot_id"): shot for shot in manifest.get("shots", [])}
    plan_shots = {
        shot.get("id"): shot
        for shot in shot_plan.get("shots", []) or []
        if isinstance(shot, dict)
    }

    body = [
        f"<h1>{_esc(plan.get('scene_ref'))} — static animatic</h1>",
        f"<div class='sub'>Keyframe Plan v{plan.get('version', 0):02d} · "
        f"Shot Plan v{(plan.get('shot_plan_ref') or {}).get('version')} · "
        f"{len(frames)} keyframes · "
        f"{manifest.get('total_duration_seconds')}s</div>",
        "<div class='warn'>"
        f"<b>{_esc(PLACEHOLDER_WARNING)}</b>"
        "可以审核：镜头顺序与边界、关键帧时序、hold 时长、状态覆盖、动作密度。"
        "<br>不能审核：构图可读性、表情质量、真实画面语义、图片之间的连续性。"
        "这些卡片是文字，不是画面；本页通过不等于视觉语义审核通过。"
        "</div>",
        "<div class='bar'><button id='play'>Play timeline</button>"
        "<span id='clock'></span></div>",
    ]

    for entry in manifest.get("shots", []):
        shot_id = entry.get("shot_id")
        source = plan_shots.get(shot_id, {})
        body.append("<section class='shot'>")
        body.append(
            f"<h2>{_esc(shot_id)}<span>{entry.get('start')}s – {entry.get('end')}s "
            f"({entry.get('duration_seconds')}s) · "
            f"{_esc(source.get('narrative_function'))} · "
            f"audio: {_esc(entry.get('audio_mode'))}</span></h2>"
        )
        body.append("<div class='cards'>")
        for item in manifest.get("entries", []):
            if item.get("shot_id") != shot_id:
                continue
            keyframe = frames.get(item.get("keyframe_id"), {})
            roles = "".join(
                f"<span class='role'>{_esc(role)}</span>"
                for role in keyframe.get("roles", []) or []
            )
            shows = "".join(
                f"<li>{_esc(text)}</li>" for text in keyframe.get("must_show", []) or []
            )
            body.append(
                f"<div class='kf' id='{_esc(item.get('keyframe_id'))}'>"
                f"<span class='id'>{_esc(item.get('keyframe_id'))}</span>"
                f"<span class='t'>{item.get('start')}s → {item.get('end')}s "
                f"· hold {item.get('hold_seconds')}s</span>"
                f"<div class='roles'>{roles}</div>"
                f"<div class='ph'><span class='tag'>TEXTUAL PLACEHOLDER</span>"
                f"{_esc(keyframe.get('visual_state'))}</div>"
                f"<div class='why'><b>Why this frame: </b>"
                f"{_esc(keyframe.get('semantic_purpose'))}</div>"
                f"<ul>{shows}</ul>"
                "</div>"
            )
        body.append("</div>")
        if entry.get("transition_to_next"):
            body.append(
                f"<div class='cut'>— {_esc(entry['transition_to_next']).upper()} —</div>"
            )
        body.append("</section>")

    timeline = "[" + ",".join(
        "{{id:{id!r},start:{start},end:{end}}}".format(
            id=str(item.get("keyframe_id")),
            start=item.get("start"),
            end=item.get("end"),
        ).replace("'", '"')
        for item in manifest.get("entries", [])
    ) + "]"
    script = _SCRIPT % {
        "timeline": timeline,
        "total": manifest.get("total_duration_seconds"),
    }
    return (
        "<!DOCTYPE html>\n<html lang='zh'>\n<head>\n<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        f"<title>{_esc(plan.get('scene_ref'))} animatic</title>\n"
        f"<style>{_STYLE}</style>\n</head>\n<body>\n"
        + "\n".join(body)
        + f"\n<script>{script}</script>\n</body>\n</html>\n"
    )
