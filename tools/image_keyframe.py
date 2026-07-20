#!/usr/bin/env python3
"""把 Keyframe Plan 的文字关键状态编译成提示词, 并管理真实图片的 manifest 与审核页。

领域边界:

- 一张图片对应**一个 Keyframe Plan keyframe**, 不是一个 Beat。旧的 beat-based
  render 逻辑不适用于这一层, 所以这里没有复用它;
- 提示词编译器**不重新导演**: 故事、动作阶段、人物位置、谁持有叉子、叉子是否
  已插入食物、哪一帧是语义高潮、镜头切点, 全部来自已冻结的 Shot Plan v05 与
  Keyframe Plan v02。编译器只做机械拼装 —— 换句话说, 它没有任何一处会因为
  "画面这样更好看"而改写上游状态;
- 模型只负责把冻结状态画出来, 不负责教学包装: 目标词、字幕、词义标签、旁白、
  对话气泡、UI overlay 一律不出现在画面里。

这一层只回答一个问题: 这些文字状态能不能变成语义可读、角色一致、道具连续、
跨镜可衔接的真实图片。它不回答运动、节奏、剪辑或音频。
"""

from __future__ import annotations

import html
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
RENDER_STYLE = ROOT / "prompts" / "render-style.yaml"

SCHEMA_VERSION = "1.0"
STATUS = "draft"

REVIEW_LAYER = "REAL IMAGE SEMANTIC REVIEW"
REVIEW_NOT = "NOT VIDEO MOTION REVIEW"

VERDICTS = ("pending", "pass", "weak", "fail")

# 风格只有一个来源: 全库统一的 prompts/render-style.yaml。这一层不新建
# Style Bible, 也不在工具里硬编码另一套风格 —— 风格能改变呈现, 不能改变一个
# 关键帧是"哪一个状态"。
#
# 单帧构图指令 (STILL_DIRECTIVE) 不属于风格, 它只是在说"这是一张静止画面":
# 关键帧是被冻结的单一瞬间, 不是分镜表, 更不是多格拼贴。
STILL_DIRECTIVE = (
    "A single frozen moment from one continuous shot — one image, "
    "one instant, not a storyboard and not a sequence of panels."
)

# 单帧特有的结构性负面词。剧情负面词不写在这里 —— 那必须逐帧来自 must_avoid。
STILL_NEGATIVE = "collage, split screen, multiple panels, storyboard, film strip"


def render_style() -> dict:
    """全库统一渲染风格 (id / positive / negative)。"""
    with open(RENDER_STYLE, encoding="utf-8") as file:
        document = yaml.safe_load(file)
    return document if isinstance(document, dict) else {}

# 画面里不得出现教学包装。与 Keyframe Plan 层同一条边界, 在图像层再守一次。
NO_TEACHING_PACKAGING = (
    "The image contains no words, letters, subtitles, captions, definitions, "
    "vocabulary labels, narration text, speech bubbles or interface overlays."
)


def _text(value: object) -> str:
    return value.strip() if isinstance(value, str) else ""


def _lines(values: object) -> list[str]:
    if not isinstance(values, list):
        return []
    return [_text(item) for item in values if _text(item)]


def _join(values: list[str]) -> str:
    """把逐条要求拼成一句话流, 不引入编号或新语义。"""
    return " ".join(
        value if value.endswith((".", "!", "?")) else value + "." for value in values
    )


# ------------------------------------------------------------ 提示词编译

def _shot_index(shot_plan: dict) -> dict[str, dict]:
    return {
        shot.get("id"): shot
        for shot in shot_plan.get("shots", []) or []
        if isinstance(shot, dict)
    }


def _continuity_block(shot_plan: dict) -> str:
    """cast / location / props 的连续性描述 —— 整场 9 帧共用的常量块。

    这就是本 PR 的一致性策略的一半 (另一半是固定 seed): 不建立仓库级
    Character/Location/Prop Bible, 而是直接复用 Shot Plan 已经写死的那几行。
    """
    parts: list[str] = []
    cast = [
        f"{entry.get('id')} ({entry.get('role')}) — {_text(entry.get('continuity_description'))}"
        for entry in shot_plan.get("cast", []) or []
        if isinstance(entry, dict)
    ]
    if cast:
        parts.append("CAST — " + " ".join(cast))
    location = shot_plan.get("location")
    if isinstance(location, dict):
        parts.append("LOCATION — " + _text(location.get("continuity_description")))
    props = [
        f"{entry.get('id')} — {_text(entry.get('continuity_description'))}"
        for entry in shot_plan.get("props", []) or []
        if isinstance(entry, dict)
    ]
    if props:
        parts.append("PROPS — " + " ".join(props))
    return "\n\n".join(part for part in parts if part.strip(" —"))


def compile_prompt(keyframe: dict, shot: dict, shot_plan: dict) -> dict[str, str]:
    """(positive, negative) —— 纯机械拼装, 输入全部来自已冻结的上游字段。

    正提示词的顺序是: 风格 → 构图/机位 → 全场连续性常量 → 本帧冻结状态 →
    本帧 must_show → 禁止教学包装。冻结状态放在常量块之后, 是因为它必须压过
    常量块里那些"整场都成立"的泛泛描述。
    """
    style = render_style()
    composition = shot.get("composition") or {}
    camera = shot.get("camera") or {}
    continuity = keyframe.get("continuity") or {}

    framing = " ".join(
        value
        for value in (
            f"{_text(composition.get('shot_size'))}, "
            f"{_text(composition.get('angle'))} angle.",
            _text(composition.get("focal_subject")),
            _text(composition.get("staging")),
            f"Camera {_text(camera.get('movement'))}.",
        )
        if value.strip(" .,")
    )

    sections = [
        _text(style.get("positive")),
        STILL_DIRECTIVE,
        "FRAMING — " + framing,
        _continuity_block(shot_plan),
        "FROZEN STATE — " + _text(keyframe.get("visual_state")),
    ]
    shows = _lines(keyframe.get("must_show"))
    if shows:
        sections.append("MUST BE VISIBLE — " + _join(shows))
    # 跨镜连续性契约: 上游状态必须在画面里可核对, 否则剪辑点两侧会跳变。
    carried = _text(continuity.get("from_previous"))
    if carried:
        sections.append("CARRIED OVER FROM THE PREVIOUS FRAME — " + carried)
    sections.append(NO_TEACHING_PACKAGING)

    avoid = _lines(keyframe.get("must_avoid"))
    negative = f"{_text(style.get('negative'))}, {STILL_NEGATIVE}"
    if avoid:
        negative += "\n\nMUST NOT APPEAR — " + _join(avoid)

    return {
        "positive": "\n\n".join(section for section in sections if section),
        "negative": negative,
    }


def prompt_file_text(keyframe_id: str, compiled: dict[str, str]) -> str:
    """写进 prompts/*.txt 的内容 —— 提示词是可审计产物, 不是运行时的临时字符串。"""
    return (
        f"# {keyframe_id}\n"
        "# 由 Shot Plan 与 Keyframe Plan 机械编译; 不要手工改这里, 改上游。\n\n"
        "=== POSITIVE ===\n"
        f"{compiled['positive']}\n\n"
        "=== NEGATIVE ===\n"
        f"{compiled['negative']}\n"
    )


# -------------------------------------------------------------- manifest

def planned_frames(plan: dict) -> list[tuple[str, dict]]:
    """(shot_id, keyframe) 扁平序列, 保持 Keyframe Plan 里的顺序。"""
    flat: list[tuple[str, dict]] = []
    for entry in plan.get("shots", []) or []:
        if not isinstance(entry, dict):
            continue
        shot_id = entry.get("shot_id")
        for keyframe in entry.get("keyframes", []) or []:
            if isinstance(keyframe, dict):
                flat.append((shot_id, keyframe))
    return flat


def blank_review() -> dict:
    return {
        "semantic_readability": "pending",
        "continuity": "pending",
        "composition": "pending",
        "character_consistency": "pending",
        "notes": [],
    }


def image_name(keyframe_id: str) -> str:
    return f"images/{keyframe_id}.png"


def prompt_name(keyframe_id: str) -> str:
    return f"prompts/{keyframe_id}.txt"


def build_manifest(plan: dict, shot_plan: dict, *, version: int, generated_at: str,
                   provider: str, model: str, workflow: str, seed: int,
                   seed_policy: str, reference_strategy: str,
                   notes: str, previous: dict | None = None) -> dict:
    """按 Keyframe Plan 的帧序建 manifest; 已有 manifest 的审核结论会被保留。

    保留旧审核结论是因为重生成通常只重跑其中一两帧 —— 让一次局部重生成清空
    全部人工审核, 会让审核变成不可积累的劳动。
    """
    kept = {
        frame.get("keyframe_id"): frame
        for frame in (previous or {}).get("frames", []) or []
        if isinstance(frame, dict)
    }
    frames = []
    for shot_id, keyframe in planned_frames(plan):
        keyframe_id = keyframe.get("id")
        existing = kept.get(keyframe_id, {})
        frames.append({
            "keyframe_id": keyframe_id,
            "shot_id": shot_id,
            "image": image_name(keyframe_id),
            "prompt": prompt_name(keyframe_id),
            "seed": existing.get("seed", seed),
            "status": existing.get("status", "generated"),
            "review": existing.get("review") or blank_review(),
        })

    reference = plan.get("shot_plan_ref") or {}
    return {
        "schema_version": SCHEMA_VERSION,
        "version": version,
        "status": STATUS,
        "scene_ref": plan.get("scene_ref"),
        "shot_plan_ref": {
            "scene_id": reference.get("scene_id") or plan.get("scene_ref"),
            "version": reference.get("version"),
        },
        "keyframe_plan_ref": {
            "scene_id": plan.get("scene_ref"),
            "version": plan.get("version"),
        },
        "generation": {
            "human_directed": True,
            "generated_at": generated_at,
            "provider": provider,
            "model": model,
            "workflow": workflow,
            "seed_policy": seed_policy,
            "reference_strategy": reference_strategy,
            "notes": notes,
        },
        "frames": frames,
    }


def validate_manifest(manifest: dict, plan: dict, shot_plan: dict) -> list[str]:
    """Schema 之外的绑定、覆盖与唯一性检查 (不含文件是否存在, 见 missing_files)。

    刻意**不**检查的东西: 关键帧总数、每个镜头几帧、画质、构图偏好。帧数由
    Keyframe Plan 决定, 画质由人工审核决定; 在这里写死任何一个都等于让工具替
    内容做决定。
    """
    issues: list[str] = []

    reference = plan.get("shot_plan_ref") or {}
    bound = manifest.get("shot_plan_ref") or {}
    if bound.get("version") != reference.get("version"):
        issues.append(
            f"shot_plan_ref.version {bound.get('version')} 与 Keyframe Plan 锚定的 "
            f"v{reference.get('version')} 不一致"
        )
    plan_ref = manifest.get("keyframe_plan_ref") or {}
    if plan_ref.get("version") != plan.get("version"):
        issues.append(
            f"keyframe_plan_ref.version {plan_ref.get('version')} 与实际读取的 "
            f"Keyframe Plan v{plan.get('version')} 不一致"
        )
    if manifest.get("scene_ref") != plan.get("scene_ref"):
        issues.append(
            f"scene_ref {manifest.get('scene_ref')} 与 Keyframe Plan 的 "
            f"{plan.get('scene_ref')} 不一致"
        )

    planned = planned_frames(plan)
    expected = [keyframe.get("id") for _shot, keyframe in planned]
    expected_shot = {keyframe.get("id"): shot for shot, keyframe in planned}
    actual = [frame.get("keyframe_id") for frame in manifest.get("frames", []) or []]

    for keyframe_id in expected:
        if keyframe_id not in actual:
            issues.append(f"缺少关键帧 {keyframe_id} 的图片")
    for keyframe_id in actual:
        if keyframe_id not in expected:
            issues.append(f"引用了 Keyframe Plan 里不存在的关键帧 {keyframe_id}")
    if actual != expected and not issues:
        issues.append("frames 顺序与 Keyframe Plan 的关键帧顺序不一致")

    seen_ids: set[str] = set()
    seen_images: dict[str, str] = {}
    for frame in manifest.get("frames", []) or []:
        keyframe_id = frame.get("keyframe_id")
        if keyframe_id in seen_ids:
            issues.append(f"关键帧 {keyframe_id} 出现多次")
        seen_ids.add(keyframe_id)
        image = frame.get("image")
        if image in seen_images:
            issues.append(
                f"{keyframe_id} 与 {seen_images[image]} 共用同一张图片 {image}; "
                "每个关键帧必须是各自独立的画面"
            )
        else:
            seen_images[image] = keyframe_id
        shot_id = expected_shot.get(keyframe_id)
        if shot_id is not None and frame.get("shot_id") != shot_id:
            issues.append(
                f"{keyframe_id} 的 shot_id {frame.get('shot_id')} 与 Keyframe Plan 的 "
                f"{shot_id} 不一致"
            )
    return issues


def missing_files(manifest: dict, root) -> list[str]:
    """图片与提示词文件是否真的存在。空文件同样视为缺失。"""
    issues: list[str] = []
    for frame in manifest.get("frames", []) or []:
        for field in ("image", "prompt"):
            value = frame.get(field)
            if not value:
                issues.append(f"{frame.get('keyframe_id')} 缺少 {field} 路径")
                continue
            path = root / value
            if not path.exists():
                issues.append(f"{frame.get('keyframe_id')} 的 {field} 不存在: {value}")
            elif path.stat().st_size == 0:
                issues.append(f"{frame.get('keyframe_id')} 的 {field} 是空文件: {value}")
    return issues


# --------------------------------------------------------- 跨镜连续性对

def continuity_pairs(plan: dict) -> list[tuple[str, str]]:
    """相邻镜头之间的 (上游末帧, 下游首帧)。

    不写死 shot-02 → shot-03: 剪辑点在哪里由 Keyframe Plan 的镜头顺序决定。
    这两张图不要求像素级相同 (构图可以切得更紧), 但动作与道具状态必须相同。
    """
    per_shot: list[tuple[str, list[str]]] = []
    for entry in plan.get("shots", []) or []:
        if not isinstance(entry, dict):
            continue
        ids = [
            keyframe.get("id")
            for keyframe in entry.get("keyframes", []) or []
            if isinstance(keyframe, dict) and keyframe.get("id")
        ]
        if ids:
            per_shot.append((entry.get("shot_id"), ids))
    return [
        (per_shot[index][1][-1], per_shot[index + 1][1][0])
        for index in range(len(per_shot) - 1)
    ]


# 跨镜逐项人工核对清单。它检查的是"动作状态是否被带过剪辑点", 不是像素一致。
CONTINUITY_CHECKS = (
    "same child identity",
    "same right hand on fork",
    "same fork orientation",
    "same fork position near plate rim",
    "tines not yet inserted into food",
    "same torso recline",
    "same gaze direction",
    "same screen direction",
    "same plate position",
    "same food arrangement",
    "mother still at left edge",
    "mother touching nothing",
)


# ------------------------------------------------------------------ 展示

def manifest_summary(manifest: dict, plan: dict) -> str:
    generation = manifest.get("generation") or {}
    lines = [
        f"{manifest.get('scene_ref')} — image keyframes v{manifest.get('version'):02d}",
        f"  shot plan     : v{(manifest.get('shot_plan_ref') or {}).get('version')}",
        f"  keyframe plan : v{(manifest.get('keyframe_plan_ref') or {}).get('version')}",
        f"  provider      : {generation.get('provider')} / {generation.get('model')}",
        f"  workflow      : {generation.get('workflow')}",
        f"  seed policy   : {generation.get('seed_policy')}",
        f"  reference     : {generation.get('reference_strategy')}",
        f"  frames        : {len(manifest.get('frames', []) or [])}",
    ]
    frames = {
        keyframe.get("id"): keyframe for _shot, keyframe in planned_frames(plan)
    }
    current_shot = None
    for frame in manifest.get("frames", []) or []:
        if frame.get("shot_id") != current_shot:
            current_shot = frame.get("shot_id")
            lines += ["", f"--- {current_shot} ---"]
        keyframe = frames.get(frame.get("keyframe_id"), {})
        review = frame.get("review") or {}
        lines += [
            f"  {frame.get('keyframe_id')}  seed={frame.get('seed')}  "
            f"[{', '.join(keyframe.get('roles', []) or [])}]  {frame.get('status')}",
            f"    image  : {frame.get('image')}",
            "    review : "
            + "  ".join(
                f"{key}={review.get(key)}"
                for key in ("semantic_readability", "continuity", "composition",
                            "character_consistency")
            ),
        ]
        for note in review.get("notes") or []:
            lines.append(f"      · {note}")
    lines += ["", REVIEW_LAYER, REVIEW_NOT]
    return "\n".join(lines)


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
.shot { border-top: 2px solid #3a4048; margin-top: 22px; padding-top: 10px; }
.shot h2 { font-size: 15px; margin: 0 0 10px; }
.shot h2 span { color: #9aa0a6; font-weight: 400; font-size: 13px; margin-left: 8px; }
.cards { display: flex; flex-wrap: wrap; gap: 14px; }
.kf { flex: 1 1 330px; min-width: 300px; max-width: 460px; border: 1px solid #333940;
      border-radius: 6px; padding: 12px; background: #1b1f25; }
.kf img { width: 100%; display: block; border-radius: 4px; background: #0e1013; }
.kf .id { font-family: ui-monospace, Menlo, monospace; font-size: 12px; color: #7aa2f7; }
.kf .t { float: right; font-variant-numeric: tabular-nums; font-size: 12px; color: #9aa0a6; }
.kf .roles { margin: 6px 0 8px; }
.kf .role { display: inline-block; font-size: 11px; padding: 1px 7px; border-radius: 10px;
            background: #2d3440; color: #b8c0cc; margin-right: 4px; }
.missing { border: 1px dashed #b3541e; color: #ffb782; padding: 26px 10px; text-align: center;
           border-radius: 4px; font-size: 13px; }
.why { font-size: 12.5px; color: #9aa0a6; margin-top: 10px; }
.why b { color: #b8c0cc; font-weight: 600; }
ul { margin: 6px 0 0; padding-left: 18px; font-size: 12.5px; color: #9aa0a6; }
ul.avoid { color: #d99a9a; }
.neigh { font-size: 12px; color: #7f868e; margin-top: 10px;
         font-family: ui-monospace, Menlo, monospace; }
.verdicts { margin-top: 10px; font-size: 12px; }
.v { display: inline-block; padding: 1px 7px; border-radius: 10px; margin-right: 5px;
     background: #2d3440; color: #b8c0cc; }
.v.pass { background: #1d3324; color: #93d3a6; }
.v.weak { background: #38310f; color: #e2c86a; }
.v.fail { background: #3a1e1e; color: #f09a9a; }
.notes { font-size: 12px; color: #cdd2d8; margin-top: 8px; padding-left: 18px; }
.pair { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 12px; }
.pair figure { flex: 1 1 380px; margin: 0; }
.pair img { width: 100%; border-radius: 4px; display: block; }
.pair figcaption { font-family: ui-monospace, Menlo, monospace; font-size: 12px;
                   color: #7aa2f7; margin-bottom: 6px; }
table.checks { border-collapse: collapse; margin-top: 12px; font-size: 12.5px; }
table.checks td { border: 1px solid #333940; padding: 4px 10px; color: #b8c0cc; }
table.checks td:first-child { color: #9aa0a6; }
"""


def _esc(value: object) -> str:
    return html.escape("" if value is None else str(value))


def _verdict_row(review: dict) -> str:
    labels = (
        ("semantic_readability", "semantic"),
        ("continuity", "continuity"),
        ("composition", "composition"),
        ("character_consistency", "character"),
    )
    return "".join(
        f"<span class='v {_esc(review.get(key, 'pending'))}'>"
        f"{label}: {_esc(review.get(key, 'pending'))}</span>"
        for key, label in labels
    )


def review_html(manifest: dict, plan: dict, shot_plan: dict) -> str:
    """单文件审核页: 无外部 CDN、无服务器, 浏览器直接打开。

    图片以相对路径引用 —— 不把 base64 塞进 HTML, 那会让页面无法 diff, 也会让
    图片脱离 images/ 目录变成不可复用的副本。
    """
    frames = {keyframe.get("id"): keyframe for _shot, keyframe in planned_frames(plan)}
    shots = _shot_index(shot_plan)
    order = [frame.get("keyframe_id") for frame in manifest.get("frames", []) or []]
    by_id = {
        frame.get("keyframe_id"): frame for frame in manifest.get("frames", []) or []
    }
    generation = manifest.get("generation") or {}

    body = [
        f"<h1>{_esc(manifest.get('scene_ref'))} — image keyframes "
        f"v{manifest.get('version', 0):02d}</h1>",
        f"<div class='sub'>Shot Plan v{(manifest.get('shot_plan_ref') or {}).get('version')}"
        f" · Keyframe Plan v{(manifest.get('keyframe_plan_ref') or {}).get('version')}"
        f" · {len(order)} frames · {_esc(generation.get('model'))}"
        f" · {_esc(generation.get('workflow'))}"
        f" · seed policy: {_esc(generation.get('seed_policy'))}</div>",
        "<div class='warn'>"
        f"<b>{_esc(REVIEW_LAYER)} — {_esc(REVIEW_NOT)}</b>"
        "可以审核：单帧语义是否可读、must-show / must-avoid 是否成立、角色与道具"
        "是否一致、跨镜状态是否接得上。"
        "<br>不能审核：动作插值、视频节奏、运动自然度、音频、剪辑、最终学习效果。"
        "本页通过只意味着可以进入运动验证，不意味着片子成立。"
        "</div>",
    ]

    for entry in plan.get("shots", []) or []:
        shot_id = entry.get("shot_id")
        source = shots.get(shot_id, {})
        body.append("<section class='shot'>")
        body.append(
            f"<h2>{_esc(shot_id)}<span>{_esc(source.get('narrative_function'))} · "
            f"{_esc((source.get('composition') or {}).get('shot_size'))} · "
            f"{source.get('duration_hint')}s</span></h2>"
        )
        body.append("<div class='cards'>")
        for keyframe in entry.get("keyframes", []) or []:
            keyframe_id = keyframe.get("id")
            frame = by_id.get(keyframe_id)
            if frame is None:
                continue
            index = order.index(keyframe_id)
            roles = "".join(
                f"<span class='role'>{_esc(role)}</span>"
                for role in keyframe.get("roles", []) or []
            )
            shows = "".join(
                f"<li>{_esc(item)}</li>" for item in keyframe.get("must_show", []) or []
            )
            avoids = "".join(
                f"<li>{_esc(item)}</li>" for item in keyframe.get("must_avoid", []) or []
            )
            notes = "".join(
                f"<li>{_esc(note)}</li>"
                for note in (frame.get("review") or {}).get("notes") or []
            )
            previous = order[index - 1] if index > 0 else None
            following = order[index + 1] if index + 1 < len(order) else None
            body.append(
                f"<div class='kf' id='{_esc(keyframe_id)}'>"
                f"<span class='id'>{_esc(keyframe_id)}</span>"
                f"<span class='t'>t={keyframe.get('at_seconds')}s · "
                f"seed {frame.get('seed')}</span>"
                f"<div class='roles'>{roles}</div>"
                + (
                    f"<img src='{_esc(frame.get('image'))}' "
                    f"alt='{_esc(keyframe_id)}' loading='lazy'>"
                    if frame.get("status") != "blocked"
                    else "<div class='missing'>GENERATION BLOCKED — 无真实图片</div>"
                )
                + f"<div class='verdicts'>{_verdict_row(frame.get('review') or {})}</div>"
                + (f"<ul class='notes'>{notes}</ul>" if notes else "")
                + f"<div class='why'><b>Semantic purpose: </b>"
                f"{_esc(keyframe.get('semantic_purpose'))}</div>"
                f"<div class='why'><b>Must show</b></div><ul>{shows}</ul>"
                f"<div class='why'><b>Must avoid</b></div>"
                f"<ul class='avoid'>{avoids}</ul>"
                f"<div class='neigh'>prev: {_esc(previous or '—')}"
                f" · next: {_esc(following or '—')}</div>"
                "</div>"
            )
        body.append("</div>")
        body.append("</section>")

    for upstream, downstream in continuity_pairs(plan):
        body.append("<section class='shot'>")
        body.append(
            f"<h2>Continuity pair<span>{_esc(upstream)} → {_esc(downstream)} · "
            "跨镜头动作状态必须相同，构图可以更紧</span></h2>"
        )
        body.append("<div class='pair'>")
        for keyframe_id in (upstream, downstream):
            frame = by_id.get(keyframe_id) or {}
            body.append(
                f"<figure><figcaption>{_esc(keyframe_id)}</figcaption>"
                + (
                    f"<img src='{_esc(frame.get('image'))}' alt='{_esc(keyframe_id)}'>"
                    if frame.get("status") != "blocked"
                    else "<div class='missing'>GENERATION BLOCKED</div>"
                )
                + "</figure>"
            )
        body.append("</div>")
        body.append(
            "<table class='checks'>"
            + "".join(
                f"<tr><td>{_esc(check)}</td><td>逐项人工核对</td></tr>"
                for check in CONTINUITY_CHECKS
            )
            + "</table>"
        )
        body.append("</section>")

    return (
        "<!DOCTYPE html>\n<html lang='zh'>\n<head>\n<meta charset='utf-8'>\n"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>\n"
        f"<title>{_esc(manifest.get('scene_ref'))} image keyframes</title>\n"
        f"<style>{_STYLE}</style>\n</head>\n<body>\n"
        + "\n".join(body)
        + "\n</body>\n</html>\n"
    )
