#!/usr/bin/env python3
"""Scene → WordSense 的语义修订绑定。

WordSense 有两个版本概念, 不能混用:

- ``version``: 资源文件自身的普通修订。措辞、拼写、格式、补充解释都递增它,
  已有 Scene 不受影响;
- ``semantic_revision``: 语义契约修订。语义身份、成立条件、边界、causativity、
  valency、参与者角色或视觉证据要求发生实质变化时由人工递增。

Scene 只绑定 ``semantic_revision`` (写在自己的 ``sense_revision`` 里)。是否需要
重新审核由"当前 Scene 的 sense_revision"与"当前 WordSense 的 semantic_revision"
动态比较得出, 不在 Scene 文件里存 stale/needs_review 标记, 也不做内容摘要:
文字润色不是语义变化, 判定语义变化是人的职责, 不是 diff 的职责。
"""

from __future__ import annotations

from dataclasses import dataclass

# 模型"没写"与"写错了"必须区别对待。判定规则与 inventory.detect_identity_drift
# 完全一致 (显式的 null 是一次表态, 不是沉默); 这里保留本地副本而不从 inventory
# 导入, 是因为 inventory 在导入期就依赖 draft, 而 draft 依赖本模块。
_MISSING = object()


def _stated(container: object, field: str) -> object:
    """取模型明确写出的值; 只有 key 不存在才算"未表态"。"""
    if not isinstance(container, dict) or field not in container:
        return _MISSING
    return container[field]


# 新起草的 inventory-driven WordSense 一律从第 1 版语义契约开始。后续语义变化
# 由人工在 WordSense 文件中明确 bump; 本项目不自动判断"什么修改算语义修改"。
NEW_SENSE_SEMANTIC_REVISION = 1

SCENE_SCHEMA_VERSION = "1.1"

CURRENT = "CURRENT"
NEEDS_REVIEW = "NEEDS_REVIEW"
LEGACY = "LEGACY"
INVALID = "INVALID"
MISSING = "MISSING"

STATUSES = (CURRENT, NEEDS_REVIEW, LEGACY, INVALID, MISSING)


@dataclass
class SceneRevisionCheck:
    """一个 Scene 相对当前 WordSense 的语义修订状态。"""

    status: str
    message: str
    scene_revision: object = None
    current_revision: object = None

    @property
    def is_error(self) -> bool:
        return self.status in (INVALID, MISSING)


def _valid_revision(value: object) -> bool:
    """合法修订号是 >= 1 的整数。bool 是 int 的子类, 但 true 不是版本号。"""
    return isinstance(value, int) and not isinstance(value, bool) and value >= 1


def get_wordsense_semantic_revision(sense_doc: object) -> int | None:
    """取 WordSense 的语义契约修订号; 缺失或非法返回 None。"""
    if not isinstance(sense_doc, dict):
        return None
    revision = sense_doc.get("semantic_revision")
    return revision if _valid_revision(revision) else None


def detect_sense_revision_drift(
    raw_sense_doc: dict, expected: int = NEW_SENSE_SEMANTIC_REVISION
) -> list[tuple[str, object, object]]:
    """模型是否篡改了 WordSense 的 semantic_revision。

    semantic_revision 表达"这份语义契约是第几版", 属于人工维护的簿记, 不是模型
    的语义判断: 没写由程序补全, 写错则与身份漂移同等对待 — 一个自称第 3 版语义
    契约的新起草义项, 说明模型在按别的东西理解本次任务。
    """
    stated = _stated(raw_sense_doc, "semantic_revision")
    if stated is _MISSING:
        return []
    # True == 1 在 Python 里成立, 但 true 不是版本号。
    if _valid_revision(stated) and stated == expected:
        return []
    return [("semantic_revision", expected, stated)]


def apply_scene_revision_fields(
    scene_doc: dict, *, sense_id: str, semantic_revision: int
) -> dict:
    """程序写入 Scene 的机器权威依赖字段 (模型写的值一律作废)。"""
    scene_doc["schema_version"] = SCENE_SCHEMA_VERSION
    scene_doc["sense_ref"] = sense_id
    scene_doc["sense_revision"] = semantic_revision
    return scene_doc


def detect_scene_dependency_drift(
    raw_scene_doc: dict, *, sense_id: str, semantic_revision: int
) -> list[tuple[str, object, object]]:
    """在程序覆盖依赖字段之前, 检查模型原始输出是否指向了别的义项或别的修订。

    返回 (字段, expected, actual) 列表; 空列表表示模型要么没表态, 要么表态正确。
    覆盖一个写错的 sense_ref 只会让"按另一个义项写的正文"通过校验并落盘。
    """
    drift: list[tuple[str, object, object]] = []
    for field, expected in (
        ("schema_version", SCENE_SCHEMA_VERSION),
        ("sense_ref", sense_id),
        ("sense_revision", semantic_revision),
    ):
        actual = _stated(raw_scene_doc, field)
        if actual is _MISSING:
            continue
        if field == "sense_revision" and not _valid_revision(actual):
            drift.append((field, expected, actual))
        elif actual != expected:
            drift.append((field, expected, actual))
    return drift


def check_scene_revision(scene_doc: dict, sense_doc: object) -> SceneRevisionCheck:
    """比较一个 Scene 与它引用的 WordSense 的语义修订。"""
    sense_ref = scene_doc.get("sense_ref")
    scene_revision = scene_doc.get("sense_revision")
    scene_schema_version = scene_doc.get("schema_version")

    if not isinstance(sense_doc, dict):
        return SceneRevisionCheck(
            MISSING,
            f"sense_ref '{sense_ref}' 指向的 WordSense 不存在, 无法绑定语义修订",
            scene_revision,
            None,
        )

    if scene_revision is None:
        if scene_schema_version == SCENE_SCHEMA_VERSION:
            return SceneRevisionCheck(
                INVALID,
                f"SceneSpec {SCENE_SCHEMA_VERSION} 必须声明 sense_revision",
                None,
                get_wordsense_semantic_revision(sense_doc),
            )
        return SceneRevisionCheck(
            LEGACY,
            f"SceneSpec {scene_schema_version} 没有语义修订绑定",
            None,
            get_wordsense_semantic_revision(sense_doc),
        )

    if not _valid_revision(scene_revision):
        return SceneRevisionCheck(
            INVALID,
            f"sense_revision {scene_revision!r} 不是 >= 1 的整数",
            scene_revision,
            get_wordsense_semantic_revision(sense_doc),
        )

    if sense_doc.get("schema_version") != "1.1":
        return SceneRevisionCheck(
            INVALID,
            f"引用的 WordSense '{sense_ref}' 是 schema_version "
            f"{sense_doc.get('schema_version')}, 没有语义契约修订可绑定; "
            "请先按 approved Sense Inventory 重新起草该义项",
            scene_revision,
            None,
        )

    current = get_wordsense_semantic_revision(sense_doc)
    if current is None:
        return SceneRevisionCheck(
            INVALID,
            f"引用的 WordSense '{sense_ref}' 缺少合法的 semantic_revision",
            scene_revision,
            sense_doc.get("semantic_revision"),
        )

    if scene_revision == current:
        return SceneRevisionCheck(CURRENT, "与当前语义修订一致",
                                  scene_revision, current)
    if scene_revision < current:
        return SceneRevisionCheck(
            NEEDS_REVIEW,
            f"WordSense 语义契约已更新到第 {current} 版, 本场景基于第 "
            f"{scene_revision} 版生成: 请重新审核视觉证据是否仍能证明该义项, "
            "必要时重新生成场景 (不要只改 sense_revision 数字)",
            scene_revision,
            current,
        )
    return SceneRevisionCheck(
        INVALID,
        f"sense_revision {scene_revision} 超前于 WordSense 的 semantic_revision "
        f"{current}: 依赖关系不成立",
        scene_revision,
        current,
    )
