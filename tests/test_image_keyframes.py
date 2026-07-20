"""图片关键帧的判据。

这一层验证的是**结构**, 不是某个模型的主观画质:

- manifest 是否绑定在正确的 Shot Plan / Keyframe Plan 版本上;
- 图片是否与 Keyframe Plan 的关键帧一一对应 (不遗漏、不多出、不共用);
- 提示词是否只由已冻结的上游字段拼装, 没有教学包装;
- 审核页是否可确定性重建。

图片生成本身是非确定性的, 所以这里**不**断言像素。同样刻意不断言的东西:
"每个场景都必须 9 帧"、"每个镜头必须 2/4/3 帧" —— 帧数由 Keyframe Plan 决定,
写死它等于让测试替内容做决定。真实数据回归一律从 v02 计划里**推导**期望值。
"""

from pathlib import Path

import copy
import subprocess

import pytest
import yaml

import image_keyframe as image_lib
import image_keyframes as image_cli

ROOT = Path(__file__).resolve().parent.parent
SCENE_ID = "reluctant-01-proto-01"

PLAN_V02_PATH = (
    ROOT / "data" / "drafts" / "keyframe-plans" / SCENE_ID / "v02" / "keyframe-plan.yaml"
)
PLAN_V01_PATH = (
    ROOT / "data" / "drafts" / "keyframe-plans" / SCENE_ID / "v01" / "keyframe-plan.yaml"
)
SHOT_PLAN_V05_PATH = (
    ROOT / "data" / "drafts" / "shot-plans" / SCENE_ID / "v05" / "shot-plan.yaml"
)
SHOT_PLAN_V04_PATH = (
    ROOT / "data" / "drafts" / "shot-plans" / SCENE_ID / "v04" / "shot-plan.yaml"
)
IMAGES_DIR = ROOT / "data" / "drafts" / "image-keyframes" / SCENE_ID / "v01"
MANIFEST_PATH = IMAGES_DIR / "image-keyframe-manifest.yaml"
REVIEW_PATH = IMAGES_DIR / "review.html"


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def plan() -> dict:
    return _load(PLAN_V02_PATH)


@pytest.fixture(scope="module")
def shot_plan() -> dict:
    return _load(SHOT_PLAN_V05_PATH)


@pytest.fixture(scope="module")
def manifest() -> dict:
    if not MANIFEST_PATH.exists():
        pytest.skip("尚未生成图片关键帧 manifest")
    return _load(MANIFEST_PATH)


@pytest.fixture
def synthetic(manifest: dict) -> dict:
    return copy.deepcopy(manifest)


# ------------------------------------------------------- 提示词编译的边界

def test_prompt_is_assembled_only_from_frozen_upstream_fields(plan, shot_plan):
    """正提示词里的每一句人物状态都必须能在上游字段里找到出处。"""
    shots = image_lib._shot_index(shot_plan)
    for shot_id, keyframe in image_lib.planned_frames(plan):
        compiled = image_lib.compile_prompt(keyframe, shots[shot_id], shot_plan)
        positive = compiled["positive"]
        assert keyframe["visual_state"] in positive
        for line in keyframe.get("must_show", []):
            assert line in positive
        # must_avoid 属于负提示词, 不能混进正提示词 —— 在扩散模型里提到某个
        # 东西本身就会把它召唤出来。
        for line in keyframe.get("must_avoid", []):
            assert line not in positive
            assert line in compiled["negative"]


def test_prompt_never_asks_for_teaching_packaging(plan, shot_plan):
    """画面里不得出现目标词、字幕、词义标签、旁白或 UI。"""
    shots = image_lib._shot_index(shot_plan)
    for shot_id, keyframe in image_lib.planned_frames(plan):
        compiled = image_lib.compile_prompt(keyframe, shots[shot_id], shot_plan)
        lowered = compiled["positive"].lower()
        assert "reluctant" not in lowered  # 目标词本身不得被画出来
        assert image_lib.NO_TEACHING_PACKAGING in compiled["positive"]
        assert "subtitles" in compiled["negative"]


def test_style_comes_only_from_the_repo_wide_render_style(plan, shot_plan):
    """风格只有一个来源, 不在这一层新建 Style Bible, 也不硬编码第二套风格。"""
    style = image_lib.render_style()
    shots = image_lib._shot_index(shot_plan)
    for shot_id, keyframe in image_lib.planned_frames(plan):
        compiled = image_lib.compile_prompt(keyframe, shots[shot_id], shot_plan)
        assert style["positive"].strip() in compiled["positive"]
        assert style["negative"].strip() in compiled["negative"]


def test_prompt_files_are_written_for_every_keyframe(plan, manifest):
    expected = {keyframe["id"] for _shot, keyframe in image_lib.planned_frames(plan)}
    for frame in manifest["frames"]:
        path = IMAGES_DIR / frame["prompt"]
        assert path.exists() and path.stat().st_size
        assert frame["keyframe_id"] in expected


def test_keyframe_workflow_is_explicit_not_inherited_from_the_environment():
    """工作流必须由这一层显式指定。

    第一次真跑就踩过: ``imagegen`` 默认读的是 legacy 的 beat-image SDXL 工作流,
    靠环境变量隐式选模型意味着同一条命令在不同终端里画出完全不同的东西, 而
    manifest 事后分辨不出来。
    """
    workflow = ROOT / image_cli.DEFAULT_WORKFLOW
    assert workflow.exists()
    assert workflow.name != Path(
        __import__("imagegen").DEFAULT_WORKFLOW
    ).name, "关键帧工作流不能就是 legacy beat-image 的那一份"


def test_manifest_records_the_model_that_actually_ran(manifest):
    """事后要能分辨这批图是谁画的; 未知模型不算生产记录。"""
    generation = manifest["generation"]
    assert generation["human_directed"] is True
    assert generation["model"] not in ("", None, "unknown")
    assert generation["workflow"]
    assert generation["seed_policy"]


# ----------------------------------------------------------------- 绑定

def test_manifest_is_bound_to_shot_plan_v05(manifest):
    assert manifest["shot_plan_ref"] == {"scene_id": SCENE_ID, "version": 5}


def test_manifest_is_bound_to_keyframe_plan_v02(manifest):
    assert manifest["keyframe_plan_ref"] == {"scene_id": SCENE_ID, "version": 2}


def test_frames_match_the_keyframe_plan_exactly(manifest, plan):
    """帧集合从 v02 推导, 不写死数量, 也不写死每个镜头几帧。"""
    expected = [keyframe["id"] for _shot, keyframe in image_lib.planned_frames(plan)]
    assert [frame["keyframe_id"] for frame in manifest["frames"]] == expected


def test_cross_shot_boundary_frames_are_not_dropped(manifest, plan):
    """剪辑点两侧的上下游状态都必须有自己的图片, 哪怕两张画面很像。"""
    ids = {frame["keyframe_id"] for frame in manifest["frames"]}
    pairs = image_lib.continuity_pairs(plan)
    assert pairs, "至少存在一个镜头切点"
    for upstream, downstream in pairs:
        assert upstream in ids
        assert downstream in ids


# ------------------------------------------------------- 图片路径与唯一性

def test_every_frame_has_its_own_existing_image(manifest):
    seen: set[str] = set()
    for frame in manifest["frames"]:
        image = frame["image"]
        assert image not in seen, f"{image} 被多个关键帧共用"
        seen.add(image)
        if frame["status"] == "blocked":
            continue
        path = IMAGES_DIR / image
        assert path.exists() and path.stat().st_size, f"{image} 不存在或为空"


def test_shared_image_between_frames_is_rejected(synthetic, plan, shot_plan):
    synthetic["frames"][1]["image"] = synthetic["frames"][0]["image"]
    issues = image_lib.validate_manifest(synthetic, plan, shot_plan)
    assert any("共用同一张图片" in issue for issue in issues)


def test_missing_keyframe_is_rejected(synthetic, plan, shot_plan):
    dropped = synthetic["frames"].pop()
    issues = image_lib.validate_manifest(synthetic, plan, shot_plan)
    assert any(dropped["keyframe_id"] in issue and "缺少" in issue for issue in issues)


def test_unknown_keyframe_is_rejected(synthetic, plan, shot_plan):
    extra = copy.deepcopy(synthetic["frames"][0])
    extra["keyframe_id"] = "shot-09-kf-99"
    extra["image"] = "images/shot-09-kf-99.png"
    synthetic["frames"].append(extra)
    issues = image_lib.validate_manifest(synthetic, plan, shot_plan)
    assert any("shot-09-kf-99" in issue for issue in issues)


def test_wrong_upstream_version_is_rejected(synthetic, plan, shot_plan):
    synthetic["shot_plan_ref"]["version"] = 4
    synthetic["keyframe_plan_ref"]["version"] = 1
    issues = image_lib.validate_manifest(synthetic, plan, shot_plan)
    assert any("shot_plan_ref.version" in issue for issue in issues)
    assert any("keyframe_plan_ref.version" in issue for issue in issues)


def test_missing_image_file_is_reported(synthetic, tmp_path):
    synthetic["frames"][0]["image"] = "images/does-not-exist.png"
    issues = image_lib.missing_files(synthetic, IMAGES_DIR)
    assert any("does-not-exist.png" in issue for issue in issues)


# ------------------------------------------------------------- 审核页

def test_review_page_regenerates_deterministically(manifest, plan, shot_plan):
    first = image_lib.review_html(manifest, plan, shot_plan)
    second = image_lib.review_html(manifest, plan, shot_plan)
    assert first == second
    if REVIEW_PATH.exists():
        assert REVIEW_PATH.read_text(encoding="utf-8") == first


def test_review_page_shows_the_review_layer_and_the_continuity_pair(
    manifest, plan, shot_plan
):
    page = image_lib.review_html(manifest, plan, shot_plan)
    assert image_lib.REVIEW_LAYER in page
    assert image_lib.REVIEW_NOT in page
    for upstream, downstream in image_lib.continuity_pairs(plan):
        assert f"{upstream} → {downstream}" in page
    for check in image_lib.CONTINUITY_CHECKS:
        assert check in page
    # 图片以相对路径引用, 不是 base64 —— 否则页面无法 diff, 图片也会脱离
    # images/ 目录变成不可复用的副本。
    assert "base64" not in page
    for frame in manifest["frames"]:
        if frame["status"] != "blocked":
            assert f"src='{frame['image']}'" in page


def test_regenerating_the_review_page_leaves_no_repo_diff():
    """连跑两次 review, 仓库不应产生任何 diff。"""
    if not MANIFEST_PATH.exists():
        pytest.skip("尚未生成图片关键帧 manifest")
    command = [
        "python3", "tools/image_keyframes.py", "review", SCENE_ID, "--version", "1",
    ]
    before = REVIEW_PATH.read_bytes()
    manifest_before = MANIFEST_PATH.read_bytes()
    renders = []
    for _ in range(2):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        renders.append(REVIEW_PATH.read_bytes())
    # 字节比对是真正的判据: 未跟踪文件不会出现在 git diff 里, 只看 diff 会空转。
    assert renders[0] == renders[1]
    assert renders[0] == before
    # review 只重建页面, 不得回写 manifest —— 否则人工审核结论会被工具改掉。
    assert MANIFEST_PATH.read_bytes() == manifest_before
    diff = subprocess.run(
        ["git", "diff", "--name-only", "--", str(IMAGES_DIR.relative_to(ROOT))],
        cwd=ROOT, capture_output=True, text=True,
    )
    assert diff.returncode == 0
    assert diff.stdout.strip() == "", f"review 重建产生了 diff: {diff.stdout}"


# --------------------------------------------------------- 上游未被改写

@pytest.mark.parametrize("path", [PLAN_V01_PATH, SHOT_PLAN_V04_PATH,
                                  PLAN_V02_PATH, SHOT_PLAN_V05_PATH])
def test_upstream_versions_are_not_rewritten(path):
    """图片证据只能推动**新版本**, 不能静默改写已发布的上游。

    v01 Keyframe Plan 与 v04 Shot Plan 是"审核门确实拦住过东西"的证据, v02 与
    v05 是本轮图片的语义依据 —— 四份都不许被这一轮动过。
    """
    relative = path.relative_to(ROOT)
    tracked = subprocess.run(
        ["git", "diff", "--name-only", "HEAD", "--", str(relative)],
        cwd=ROOT, capture_output=True, text=True,
    )
    if tracked.returncode != 0:
        pytest.skip("不在 git 工作树中")
    assert tracked.stdout.strip() == "", f"{relative} 被修改了"


def test_v01_keyframe_plan_still_binds_shot_plan_v04():
    """两条历史记录都保留: v01 依然指向 v04, 没有被这一轮"顺手修好"。"""
    v01 = _load(PLAN_V01_PATH)
    assert v01["shot_plan_ref"]["version"] == 4
    assert v01["version"] == 1
