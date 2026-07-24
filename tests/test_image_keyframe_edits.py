"""Wan 2.7 状态编辑实验的结构测试。

这里验证的是:
  15.1  Adapter 层 (imagegen.edit) 的输入验证、请求结构、错误处理
  15.2  编辑指令编译 (compile_edit_instruction) 的边界
  15.3  Manifest 绑定与 gate 枚举
  15.4  历史目录字节保护

全部测试使用 monkeypatch / fake HTTP —— 禁止真实网络访问。
API Key 不出现在测试代码里，只通过 monkeypatch 环境变量注入。
"""

from __future__ import annotations

import base64
import copy
import io
import json
import os
import subprocess
import types
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent

# 测试用常量 —— 不是真实凭据
_FAKE_KEY = "sk-sp-FAKEKEYFORTESTING0000000000000000000"
_SCENE_ID = "reluctant-01-proto-01"

PLAN_V02_PATH = (
    ROOT / "data" / "drafts" / "keyframe-plans" / _SCENE_ID / "v02" / "keyframe-plan.yaml"
)
SHOT_PLAN_V05_PATH = (
    ROOT / "data" / "drafts" / "shot-plans" / _SCENE_ID / "v05" / "shot-plan.yaml"
)
SOURCE_MANIFEST_PATH = (
    ROOT / "data" / "drafts" / "image-keyframes" / _SCENE_ID / "v01" / "image-keyframe-manifest.yaml"
)
SOURCE_IMAGES_DIR = (
    ROOT / "data" / "drafts" / "image-keyframes" / _SCENE_ID / "v01"
)


def _load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def plan() -> dict:
    return _load(PLAN_V02_PATH)


@pytest.fixture(scope="module")
def shot_plan() -> dict:
    return _load(SHOT_PLAN_V05_PATH)


@pytest.fixture(scope="module")
def source_manifest() -> dict:
    if not SOURCE_MANIFEST_PATH.exists():
        pytest.skip("尚未生成 image-keyframe v01 manifest")
    return _load(SOURCE_MANIFEST_PATH)


@pytest.fixture
def fake_png(tmp_path) -> Path:
    """最小合法 PNG (1×1 红色像素)。"""
    png_bytes = bytes([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
        0x44, 0xae, 0x42, 0x60, 0x82,
    ])
    p = tmp_path / "test.png"
    p.write_bytes(png_bytes)
    return p


@pytest.fixture
def fake_png2(tmp_path) -> Path:
    """第二张 fake PNG。"""
    png_bytes = bytes([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
        0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
        0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
        0x44, 0xae, 0x42, 0x60, 0x82,
    ])
    p = tmp_path / "test2.png"
    p.write_bytes(png_bytes)
    return p


@pytest.fixture(autouse=True)
def protocol_env(monkeypatch):
    """所有 15.1 测试默认设 aliyun-token-plan 协议。"""
    monkeypatch.setenv("SCENELEX_IMG_PROTOCOL", "aliyun-token-plan")
    monkeypatch.setenv("SCENELEX_ALIYUN_TOKEN_PLAN_KEY", _FAKE_KEY)


def _ok_response(request_id: str = "req-abc123") -> MagicMock:
    """伪造一个成功的 Token Plan HTTP 响应。"""
    resp = MagicMock()
    resp.status_code = 200
    resp.json.return_value = {
        "request_id": request_id,
        "output": {
            "choices": [
                {
                    "message": {
                        "content": [
                            {"image": "https://tmp.example.com/out.png"}
                        ]
                    }
                }
            ]
        },
        "usage": {"size": "1152*640"},
    }
    return resp


def _img_response(content: bytes = b"\x89PNG...") -> MagicMock:
    resp = MagicMock()
    resp.status_code = 200
    resp.content = content
    return resp


# ================================================================ 15.1 Adapter

class TestAdapterProtocol:
    def test_comfyui_protocol_not_broken(self, monkeypatch):
        """comfyui 协议的 check_protocol() 仍然可用。"""
        monkeypatch.setenv("SCENELEX_IMG_PROTOCOL", "comfyui")
        import imagegen
        importlib_reload(imagegen)
        imagegen.check_protocol()  # 不应抛出

    def test_unknown_protocol_rejected(self, monkeypatch):
        """未知协议应失败（不是静默忽略）。"""
        monkeypatch.setenv("SCENELEX_IMG_PROTOCOL", "openai-images")
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="openai-images"):
            imagegen.check_protocol()

    def test_edit_requires_aliyun_protocol(self, monkeypatch, fake_png):
        monkeypatch.setenv("SCENELEX_IMG_PROTOCOL", "comfyui")
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="aliyun-token-plan"):
            imagegen.edit("test instruction", [fake_png])

    def test_missing_key_raises_error(self, monkeypatch, fake_png):
        """缺少 API Key 必须报有意义的错误，不能是 KeyError。"""
        monkeypatch.delenv("SCENELEX_ALIYUN_TOKEN_PLAN_KEY", raising=False)
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="SCENELEX_ALIYUN_TOKEN_PLAN_KEY"):
            imagegen.edit("test", [fake_png])

    def test_single_image_allowed(self, monkeypatch, fake_png, tmp_path):
        import imagegen
        with (
            patch("requests.post", return_value=_ok_response()),
            patch("requests.get", return_value=_img_response(b"\x89PNG1")),
        ):
            img_bytes, trace = imagegen.edit("test", [fake_png])
        assert img_bytes == b"\x89PNG1"
        assert trace["input_count"] == 1

    def test_nine_images_allowed(self, monkeypatch, tmp_path):
        import imagegen
        imgs = []
        for i in range(9):
            p = tmp_path / f"img{i}.png"
            p.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 60)
            imgs.append(p)
        with (
            patch("requests.post", return_value=_ok_response()),
            patch("requests.get", return_value=_img_response(b"\x89PNG9")),
        ):
            img_bytes, trace = imagegen.edit("test", imgs)
        assert trace["input_count"] == 9

    def test_zero_images_rejected(self, monkeypatch):
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="空"):
            imagegen.edit("test", [])

    def test_ten_images_rejected(self, monkeypatch, tmp_path):
        import imagegen
        imgs = []
        for i in range(10):
            p = tmp_path / f"img{i}.png"
            p.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 60)
            imgs.append(p)
        with pytest.raises(imagegen.ImageGenError, match="9"):
            imagegen.edit("test", imgs)

    def test_nonexistent_file_rejected(self, monkeypatch, tmp_path):
        import imagegen
        ghost = tmp_path / "ghost.png"
        with pytest.raises(imagegen.ImageGenError, match="不存在"):
            imagegen.edit("test", [ghost])

    def test_empty_file_rejected(self, monkeypatch, tmp_path):
        import imagegen
        empty = tmp_path / "empty.png"
        empty.write_bytes(b"")
        with pytest.raises(imagegen.ImageGenError, match="空文件"):
            imagegen.edit("test", [empty])

    def test_oversized_file_rejected(self, monkeypatch, tmp_path):
        import imagegen
        big = tmp_path / "big.png"
        big.write_bytes(b"\x89PNG" + b"x" * (21 * 1024 * 1024))
        with pytest.raises(imagegen.ImageGenError, match="20 MB"):
            imagegen.edit("test", [big])

    def test_unsupported_ext_rejected(self, monkeypatch, tmp_path):
        import imagegen
        bad = tmp_path / "frame.gif"
        bad.write_bytes(b"GIF89a\x01\x00\x01\x00\x00\xff\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x00;")
        with pytest.raises(imagegen.ImageGenError, match=".gif|支持"):
            imagegen.edit("test", [bad])

    def test_base64_data_uri_format(self, monkeypatch, fake_png):
        """Base64 Data URI 格式必须正确。"""
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("test instruction", [fake_png])

        content = captured["body"]["input"]["messages"][0]["content"]
        # image item が最初にある
        img_item = content[0]
        assert "image" in img_item
        assert img_item["image"].startswith("data:image/png;base64,")
        # Base64 部分が正しくデコードできること
        b64_part = img_item["image"].split(",", 1)[1]
        decoded = base64.b64decode(b64_part)
        assert decoded == fake_png.read_bytes()

    def test_image_order_preserved(self, monkeypatch, fake_png, fake_png2):
        """複数画像の順序が保持されること。"""
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("two images", [fake_png, fake_png2])

        content = captured["body"]["input"]["messages"][0]["content"]
        # 2枚の画像 + 1つのテキスト
        img_items = [c for c in content if "image" in c]
        assert len(img_items) == 2
        # 1枚目の画像が fake_png と一致
        b64_0 = img_items[0]["image"].split(",", 1)[1]
        assert base64.b64decode(b64_0) == fake_png.read_bytes()

    def test_text_is_last_in_content(self, monkeypatch, fake_png, fake_png2):
        """text は content の最後の項目でなければならない。"""
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("my instruction", [fake_png, fake_png2])

        content = captured["body"]["input"]["messages"][0]["content"]
        last = content[-1]
        assert "text" in last
        assert last["text"] == "my instruction"

    def test_request_body_model_size_seed_n_watermark(self, monkeypatch, fake_png):
        """リクエストボディの基本フィールド検証。"""
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("test", [fake_png], model="wan2.7-image-pro",
                          size="1152*640", seed=42)

        params = captured["body"]["parameters"]
        assert captured["body"]["model"] == "wan2.7-image-pro"
        assert params["size"] == "1152*640"
        assert params["seed"] == 42
        assert params["n"] == 1
        assert params["watermark"] is False

    def test_no_negative_prompt_in_body(self, monkeypatch, fake_png):
        """negative_prompt は送ってはならない。"""
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("test", [fake_png])

        body_str = json.dumps(captured["body"])
        assert "negative_prompt" not in body_str
        assert "prompt_extend" not in body_str
        assert "thinking_mode" not in body_str

    def test_bbox_list_validated_length_mismatch(self, monkeypatch, fake_png):
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="bbox_list"):
            imagegen.edit("test", [fake_png], bbox_list=[[], []])  # 1 image, 2 bbox lists

    def test_bbox_list_max_two_per_image(self, monkeypatch, fake_png):
        import imagegen
        three_bboxes = [[[0, 0, 10, 10], [20, 20, 30, 30], [40, 40, 50, 50]]]
        with pytest.raises(imagegen.ImageGenError, match="2"):
            imagegen.edit("test", [fake_png], bbox_list=three_bboxes)

    def test_bbox_x2_must_be_greater_than_x1(self, monkeypatch, fake_png):
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="x2"):
            imagegen.edit("test", [fake_png], bbox_list=[[[10, 0, 5, 10]]])

    def test_bbox_y2_must_be_greater_than_y1(self, monkeypatch, fake_png):
        import imagegen
        with pytest.raises(imagegen.ImageGenError, match="y2"):
            imagegen.edit("test", [fake_png], bbox_list=[[[0, 10, 10, 5]]])

    def test_valid_bbox_passes(self, monkeypatch, fake_png):
        import imagegen
        captured = {}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            captured["body"] = json
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
        ):
            imagegen.edit("test", [fake_png], bbox_list=[[[0, 0, 100, 200]]])

        params = captured["body"]["parameters"]
        assert "bbox_list" in params
        assert params["bbox_list"] == [[[0, 0, 100, 200]]]


    def test_success_returns_image_bytes_and_trace(self, monkeypatch, fake_png):
        import imagegen
        result_bytes = b"\x89PNG real content"
        with (
            patch("requests.post", return_value=_ok_response("req-xyz")),
            patch("requests.get", return_value=_img_response(result_bytes)),
        ):
            img_bytes, trace = imagegen.edit("test", [fake_png])
        assert img_bytes == result_bytes
        assert trace["request_id"] == "req-xyz"
        assert trace["protocol"] == "aliyun-token-plan"
        assert trace["model"] is not None

    def test_temporary_url_not_in_trace(self, monkeypatch, fake_png):
        """一時的な URL は trace に含まれてはならない。"""
        import imagegen
        with (
            patch("requests.post", return_value=_ok_response()),
            patch("requests.get", return_value=_img_response()),
        ):
            _, trace = imagegen.edit("test", [fake_png])
        trace_str = json.dumps(trace)
        assert "https://tmp.example.com" not in trace_str
        assert "http://" not in trace_str
        assert ".aliyuncs.com" not in trace_str

    def test_429_triggers_retry(self, monkeypatch, fake_png):
        """429 は再試行を引き起こす。"""
        import imagegen
        call_count = {"n": 0}

        def fake_post(url, headers, json=None, timeout=None, **kw):
            call_count["n"] += 1
            if call_count["n"] < 2:
                resp = MagicMock()
                resp.status_code = 429
                resp.json.return_value = {"code": "RateLimit", "message": "too fast"}
                return resp
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
            patch("time.sleep"),  # スリープを省略
        ):
            img_bytes, trace = imagegen.edit("test", [fake_png])
        assert call_count["n"] >= 2

    def test_500_triggers_retry(self, monkeypatch, fake_png):
        import imagegen
        call_count = {"n": 0}

        def fake_post(url, **kw):
            call_count["n"] += 1
            if call_count["n"] < 2:
                resp = MagicMock()
                resp.status_code = 500
                resp.json.return_value = {"code": "InternalError", "message": "server error"}
                return resp
            return _ok_response()

        with (
            patch("requests.post", side_effect=fake_post),
            patch("requests.get", return_value=_img_response()),
            patch("time.sleep"),
        ):
            imagegen.edit("test", [fake_png])
        assert call_count["n"] >= 2

    def test_400_does_not_retry(self, monkeypatch, fake_png):
        """400 は再試行しない。"""
        import imagegen
        call_count = {"n": 0}

        def fake_post(url, **kw):
            call_count["n"] += 1
            resp = MagicMock()
            resp.status_code = 400
            resp.json.return_value = {"code": "BadRequest", "message": "invalid param"}
            return resp

        with (
            patch("requests.post", side_effect=fake_post),
            patch("time.sleep"),
        ):
            with pytest.raises(Exception, match="400"):
                imagegen.edit("test", [fake_png])
        assert call_count["n"] == 1

    def test_401_does_not_retry(self, monkeypatch, fake_png):
        import imagegen
        call_count = {"n": 0}

        def fake_post(url, **kw):
            call_count["n"] += 1
            resp = MagicMock()
            resp.status_code = 401
            resp.json.return_value = {"code": "AuthError", "message": "invalid key"}
            return resp

        with patch("requests.post", side_effect=fake_post):
            with pytest.raises(Exception, match="401"):
                imagegen.edit("test", [fake_png])
        assert call_count["n"] == 1

    def test_403_does_not_retry(self, monkeypatch, fake_png):
        import imagegen
        call_count = {"n": 0}

        def fake_post(url, **kw):
            call_count["n"] += 1
            resp = MagicMock()
            resp.status_code = 403
            resp.json.return_value = {"code": "Forbidden", "message": "no access"}
            return resp

        with patch("requests.post", side_effect=fake_post):
            with pytest.raises(Exception, match="403"):
                imagegen.edit("test", [fake_png])
        assert call_count["n"] == 1

    def test_key_not_in_logs(self, monkeypatch, fake_png, caplog):
        """ログに API Key が含まれてはならない。"""
        import imagegen
        import logging
        with (
            patch("requests.post", return_value=_ok_response()),
            patch("requests.get", return_value=_img_response()),
            caplog.at_level(logging.DEBUG, logger="imagegen"),
        ):
            imagegen.edit("test", [fake_png])
        assert _FAKE_KEY not in caplog.text

    def test_base64_not_in_logs(self, monkeypatch, fake_png, caplog):
        """ログに Base64 データが含まれてはならない。"""
        import imagegen
        import logging
        with (
            patch("requests.post", return_value=_ok_response()),
            patch("requests.get", return_value=_img_response()),
            caplog.at_level(logging.DEBUG, logger="imagegen"),
        ):
            imagegen.edit("test", [fake_png])
        # Base64 はデータ URI の一部として長い文字列になる
        # ログにそのような長い英数字文字列がないことを確認
        for record in caplog.records:
            assert len(record.getMessage()) < 500 or "data:image/" not in record.getMessage()


# ================================================================ 15.2 Prompt

class TestPromptCompilation:

    def _get_kf_and_shot(self, kf_id: str, plan: dict, shot_plan: dict) -> tuple[dict, dict, dict]:
        import image_keyframe_edit as edit_lib
        shots = edit_lib._shot_index(shot_plan)
        for entry in plan.get("shots", []) or []:
            for kf in entry.get("keyframes", []) or []:
                if isinstance(kf, dict) and kf.get("id") == kf_id:
                    shot = shots.get(entry.get("shot_id"), {})
                    return kf, shot, shot_plan
        pytest.fail(f"找不到 keyframe {kf_id}")

    def test_visual_state_in_instruction(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert kf["visual_state"] in instruction

    def test_must_show_in_instruction(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        for line in kf.get("must_show", []):
            assert line in instruction, f"must_show 行未出现在指令中: {line!r}"

    def test_must_avoid_in_forbidden_outcomes(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "FORBIDDEN OUTCOMES" in instruction
        for line in kf.get("must_avoid", []):
            assert line in instruction, f"must_avoid 行未出现在 FORBIDDEN OUTCOMES: {line!r}"

    def test_preserve_exactly_section_present(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-04", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "PRESERVE EXACTLY" in instruction

    def test_change_only_section_present(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-04", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "CHANGE ONLY" in instruction

    def test_target_frozen_state_section_present(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-03-kf-01", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "TARGET FROZEN STATE" in instruction

    def test_forbidden_outcomes_section_present(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-03-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "FORBIDDEN OUTCOMES" in instruction

    def test_no_teaching_packaging_section_present(self, plan, shot_plan, tmp_path):
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        instruction = edit_lib.compile_edit_instruction(
            kf, shot, sp, identity_ref=None, base_image=fake
        )
        assert "NO TEACHING PACKAGING" in instruction

    def test_reluctant_not_as_visual_element(self, plan, shot_plan, tmp_path):
        """'reluctant' は画面上の語として要求してはならない。"""
        import image_keyframe_edit as edit_lib
        for kf_id in edit_lib.DIAGNOSTIC_KEYFRAME_IDS:
            kf, shot, sp = self._get_kf_and_shot(kf_id, plan, shot_plan)
            fake = tmp_path / f"base_{kf_id}.png"
            fake.write_bytes(b"\x89PNG")
            instruction = edit_lib.compile_edit_instruction(
                kf, shot, sp, identity_ref=None, base_image=fake
            )
            lower = instruction.lower()
            # "reluctant" が "NO TEACHING PACKAGING" の一部以外で出現してはならない
            # 具体的には、ターゲット語が画像に描かれないこと
            assert "show the word 'reluctant'" in instruction or \
                   "reluctant" not in lower.replace(
                       "do not show the word 'reluctant'", ""
                   ).replace(
                       "show the word 'reluctant' or any other vocabulary label", ""
                   ), (
                f"{kf_id}: 'reluctant' が画面要求として現れている"
            )

    def test_instruction_is_deterministic(self, plan, shot_plan, tmp_path):
        """同じ入力は常に同じ指令を生成する。"""
        import image_keyframe_edit as edit_lib
        kf, shot, sp = self._get_kf_and_shot("shot-02-kf-03", plan, shot_plan)
        fake = tmp_path / "base.png"
        fake.write_bytes(b"\x89PNG")
        i1 = edit_lib.compile_edit_instruction(kf, shot, sp, identity_ref=None, base_image=fake)
        i2 = edit_lib.compile_edit_instruction(kf, shot, sp, identity_ref=None, base_image=fake)
        assert i1 == i2


# ================================================================ 15.3 Manifest

class TestManifest:

    def _build_run_doc(self, plan, shot_plan, source_manifest) -> dict:
        import image_keyframe_edit as edit_lib
        return edit_lib.build_edit_run(
            plan,
            shot_plan,
            source_manifest,
            version=1,
            scene_id=_SCENE_ID,
            identity_reference_image="images/shot-02-kf-02.png",
            identity_reference_rationale="test ref",
        )

    def test_bound_to_shot_plan_v05(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        assert run_doc["shot_plan_ref"]["version"] == 5

    def test_bound_to_keyframe_plan_v02(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        assert run_doc["keyframe_plan_ref"]["version"] == 2

    def test_bound_to_image_keyframes_v01(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        assert run_doc["source_image_keyframe_ref"]["version"] == 1

    def test_api_key_not_in_run_doc(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_text = yaml.safe_dump(run_doc, allow_unicode=True)
        assert "sk-sp-" not in run_text
        assert _FAKE_KEY not in run_text

    def test_base64_not_in_run_doc(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_text = yaml.safe_dump(run_doc, allow_unicode=True)
        assert "data:image/" not in run_text

    def test_request_id_in_attempt(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        target = run_doc["targets"][0]
        target["attempts"] = [{
            "attempt": "attempt-01",
            "model": "wan2.7-image-pro",
            "prompt": "prompts/test.txt",
            "image": "images/test.png",
            "request_id": "req-xyz-12345",
            "seed": 42,
            "bbox_list": None,
            "status": "generated",
            "review": edit_lib.blank_attempt_review(),
        }]
        run_text = yaml.safe_dump(run_doc, allow_unicode=True)
        assert "req-xyz-12345" in run_text

    def test_api_gate_valid_enum(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        assert run_doc["api_gate"] in edit_lib.API_GATE_VALUES

    def test_semantic_gate_valid_enum(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        assert run_doc["semantic_gate"] in edit_lib.SEMANTIC_GATE_VALUES

    def test_four_diagnostic_keyframe_ids(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        ids = [t["keyframe_id"] for t in run_doc["targets"]]
        for expected in edit_lib.DIAGNOSTIC_KEYFRAME_IDS:
            assert expected in ids

    def test_selected_attempt_must_exist_in_attempts(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        # 無効な selected_attempt をセット
        run_doc["targets"][0]["selected_attempt"] = "attempt-99"
        run_doc["targets"][0]["attempts"] = [{
            "attempt": "attempt-01",
            "model": "wan2.7-image-pro",
            "prompt": "prompts/test.txt",
            "image": None,
            "request_id": None,
            "seed": 0,
            "bbox_list": None,
            "status": "pending",
            "review": edit_lib.blank_attempt_review(),
        }]
        issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
        assert any("attempt-99" in issue for issue in issues)

    def test_invalid_api_gate_rejected(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_doc["api_gate"] = "unknown_gate"
        issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
        assert any("api_gate" in issue for issue in issues)

    def test_invalid_semantic_gate_rejected(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_doc["semantic_gate"] = "maybe"
        issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
        assert any("semantic_gate" in issue for issue in issues)

    def test_wrong_shot_plan_version_rejected(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_doc["shot_plan_ref"]["version"] = 4
        issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
        assert any("shot_plan_ref" in issue for issue in issues)

    def test_wrong_keyframe_plan_version_rejected(self, plan, shot_plan, source_manifest):
        import image_keyframe_edit as edit_lib
        run_doc = self._build_run_doc(plan, shot_plan, source_manifest)
        run_doc["keyframe_plan_ref"]["version"] = 1
        issues = edit_lib.validate_edit_run(run_doc, plan, shot_plan)
        assert any("keyframe_plan_ref" in issue for issue in issues)


class TestDerivedRunGates:
    @staticmethod
    def _run_with_targets(*targets: dict) -> dict:
        return {"targets": list(targets)}

    @staticmethod
    def _target(
        keyframe_id: str,
        *,
        status: str | None = None,
        selected: bool = False,
    ) -> dict:
        attempts = []
        selected_attempt = None
        if status:
            attempts.append({
                "attempt": "attempt-01",
                "status": status,
                "image": "images/result.png" if status == "generated" else None,
            })
            if selected:
                selected_attempt = "attempt-01"
        return {
            "keyframe_id": keyframe_id,
            "attempts": attempts,
            "selected_attempt": selected_attempt,
        }

    def test_incomplete_run_is_pending(self):
        import image_keyframe_edit as edit_lib
        run_doc = self._run_with_targets(
            self._target("kf-01", status="generated", selected=True),
            self._target("kf-02"),
        )
        assert edit_lib.derive_api_gate(run_doc) == "pending"

    def test_recorded_failure_blocks_incomplete_run(self):
        import image_keyframe_edit as edit_lib
        run_doc = self._run_with_targets(
            self._target("kf-01", status="generated", selected=True),
            self._target("kf-02", status="failed"),
        )
        assert edit_lib.derive_api_gate(run_doc) == "blocked"

    def test_all_targets_need_selected_generated_artifacts_to_pass(self):
        import image_keyframe_edit as edit_lib
        run_doc = self._run_with_targets(
            self._target("kf-01", status="generated", selected=True),
            self._target("kf-02", status="generated", selected=True),
        )
        assert edit_lib.derive_api_gate(run_doc) == "pass"

    def test_no_selected_artifact_means_semantic_gate_not_run(self):
        import image_keyframe_edit as edit_lib
        run_doc = self._run_with_targets(self._target("kf-01"))
        assert edit_lib.derive_semantic_gate(run_doc) == "not_run"

    def test_completed_weak_review_requires_revision(self):
        import image_keyframe_edit as edit_lib
        target = self._target("kf-01", status="generated", selected=True)
        target["attempts"][0]["reviews"] = edit_lib.blank_reviews_v11()
        target["attempts"][0]["reviews"]["human"] = {
            "status": "completed",
            "reviewer": "tester",
            "reviewed_at": "2026-07-24T00:00:00+00:00",
            "verdicts": edit_lib.blank_verdict_set()
            | {"state_fidelity": "weak"},
            "notes": [],
        }
        run_doc = self._run_with_targets(target)
        assert edit_lib.derive_semantic_gate(run_doc) == "revision_required"

    def test_all_completed_human_dimensions_must_pass(self):
        import image_keyframe_edit as edit_lib
        targets = []
        for keyframe_id in ("kf-01", "kf-02"):
            target = self._target(
                keyframe_id,
                status="generated",
                selected=True,
            )
            target["attempts"][0]["reviews"] = edit_lib.blank_reviews_v11()
            target["attempts"][0]["reviews"]["human"] = {
                "status": "completed",
                "reviewer": "tester",
                "reviewed_at": "2026-07-24T00:00:00+00:00",
                "verdicts": {
                    dimension: "pass"
                    for dimension in edit_lib.REVIEW_DIMS
                },
                "notes": [],
            }
            targets.append(target)
        run_doc = self._run_with_targets(*targets)
        assert edit_lib.derive_semantic_gate(run_doc) == "pass"


class TestHumanReviewRecording:
    def test_records_review_and_refreshes_gates(self):
        import image_keyframe_edit as edit_lib
        target = {
            "keyframe_id": "kf-01",
            "selected_attempt": None,
            "attempts": [{
                "attempt": "attempt-01",
                "status": "generated",
                "image": "images/result.png",
                "reviews": edit_lib.blank_reviews_v11(),
            }],
        }
        run_doc = {
            "schema_version": "1.1",
            "api_gate": "pending",
            "semantic_gate": "not_run",
            "targets": [target],
        }

        edit_lib.record_human_review(
            run_doc,
            keyframe_id="kf-01",
            attempt_id="attempt-01",
            reviewer="tester",
            reviewed_at="2026-07-24T00:00:00+00:00",
            verdicts={
                dimension: "pass"
                for dimension in edit_lib.REVIEW_DIMS
            },
            notes=["looks correct"],
        )

        assert target["selected_attempt"] == "attempt-01"
        assert run_doc["api_gate"] == "pass"
        assert run_doc["semantic_gate"] == "pass"
        assert (
            target["attempts"][0]["reviews"]["human"]["reviewer"]
            == "tester"
        )

    def test_rejects_unbound_attempt(self):
        import image_keyframe_edit as edit_lib
        run_doc = {
            "schema_version": "1.1",
            "targets": [{"keyframe_id": "kf-01", "attempts": []}],
        }
        with pytest.raises(ValueError, match="not a bound generated artifact"):
            edit_lib.record_human_review(
                run_doc,
                keyframe_id="kf-01",
                attempt_id="attempt-01",
                reviewer="tester",
                reviewed_at="2026-07-24T00:00:00+00:00",
                verdicts={
                    dimension: "pass"
                    for dimension in edit_lib.REVIEW_DIMS
                },
            )


class TestAttemptPersistence:
    def test_next_attempt_skips_unbound_disk_artifacts(self, tmp_path):
        import image_keyframe_edits

        keyframe_id = "shot-02-kf-03"
        (tmp_path / f"{keyframe_id}-attempt-01.png").write_bytes(b"old-1")
        (tmp_path / f"{keyframe_id}-attempt-02.png").write_bytes(b"old-2")

        attempt_id, output_path = image_keyframe_edits._next_attempt_id(
            {"attempts": []},
            tmp_path,
            keyframe_id,
        )

        assert attempt_id == "attempt-03"
        assert output_path.name == f"{keyframe_id}-attempt-03.png"

    def test_next_attempt_skips_manifest_attempts(self, tmp_path):
        import image_keyframe_edits

        attempt_id, _ = image_keyframe_edits._next_attempt_id(
            {"attempts": [{"attempt": "attempt-01"}]},
            tmp_path,
            "shot-03-kf-01",
        )

        assert attempt_id == "attempt-02"


# ================================================================ 15.4 History Guard

@pytest.mark.parametrize("rel_path", [
    "data/drafts/shot-plans/reluctant-01-proto-01/v05",
    "data/drafts/keyframe-plans/reluctant-01-proto-01/v02",
    "data/drafts/image-keyframes/reluctant-01-proto-01/v01",
])
def test_historical_directories_are_not_modified(rel_path):
    """歴史的なディレクトリはこのブランチで変更されていない。"""
    result = subprocess.run(
        ["git", "diff", "--name-only", "HEAD", "--", rel_path],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        pytest.skip("git コマンドが使えない環境")
    assert result.stdout.strip() == "", (
        f"{rel_path} が変更されています:\n{result.stdout}"
    )


def test_v01_image_keyframe_manifest_not_touched():
    """image-keyframes v01 manifest のバイトが変わっていない。"""
    if not SOURCE_MANIFEST_PATH.exists():
        pytest.skip("manifest が存在しない")
    result = subprocess.run(
        ["git", "diff", "--name-only", "HEAD", "--",
         str(SOURCE_MANIFEST_PATH.relative_to(ROOT))],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        pytest.skip("git コマンドが使えない環境")
    assert result.stdout.strip() == "", "image-keyframe-manifest.yaml が変更されています"


# ================================================================ helper

def importlib_reload(module):
    """モジュールをリロードせずに、単純にチェックする（環境変数はすでに設定済み）。"""
    # monkeypatch が環境変数を書き換えているので、リロードは不要
    return module
