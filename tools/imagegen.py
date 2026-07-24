#!/usr/bin/env python3
"""图像生成适配器 — 按协议兼容, 不绑定厂商 (与 tools/llm.py 同纪律)。

支持的协议 (SCENELEX_IMG_PROTOCOL):

  comfyui            本地 ComfyUI — 加载工作流 API JSON 模板, 自动定位采样器与正负提示词
                     节点 (跟随 KSampler 的 positive/negative 连线, 不依赖节点标题),
                     注入提示词与 seed 后提交 /prompt, 轮询 /history 取图。

  aliyun-token-plan  Token Plan 专属 Endpoint — Wan 2.7 图片编辑与多图参考。
                     调用 edit() 函数；generate() 不支持该协议。

环境变量 (comfyui):
  SCENELEX_IMG_ENDPOINT   ComfyUI 地址 (默认 http://127.0.0.1:8188)
  SCENELEX_IMG_WORKFLOW   工作流 API JSON 路径
                          (默认 tools/workflows/comfyui-text2image.json)
  SCENELEX_IMG_TIMEOUT    单张图超时秒数 (默认 600)
  SCENELEX_IMG_LICENSE    资产许可标注 (默认 unreviewed-local-model)

节点自动定位失败时可显式指定:
  SCENELEX_IMG_SAMPLER_NODE / SCENELEX_IMG_POSITIVE_NODE / SCENELEX_IMG_NEGATIVE_NODE

环境变量 (aliyun-token-plan):
  SCENELEX_ALIYUN_TOKEN_PLAN_KEY  Token Plan 专属 API Key (必须以 sk-sp- 开头)
  SCENELEX_IMG_ENDPOINT           覆盖默认 Endpoint URL
  SCENELEX_IMG_MODEL              默认 wan2.7-image-pro
  SCENELEX_IMG_SIZE               默认 1152*640
  SCENELEX_IMG_TIMEOUT            超时秒数 (默认 300)
  SCENELEX_IMG_RETRIES            最大重试次数 (默认 3)
  SCENELEX_IMG_REQUEST_INTERVAL   重试基础间隔秒数 (默认 1.0)

安全约束:
  API Key、Base64 请求体、Authorization Header、临时输出 URL 均不得进入
  trace dict、日志、异常信息、manifest 或 Git 历史。
"""

from __future__ import annotations

import base64
import json
import logging
import math
import os
import random
import time
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_WORKFLOW = ROOT / "tools" / "workflows" / "comfyui-text2image.json"

# Token Plan 北京图片生成 Endpoint
_ALIYUN_DEFAULT_ENDPOINT = (
    "https://token-plan.cn-beijing.maas.aliyuncs.com"
    "/api/v1/services/aigc/multimodal-generation/generation"
)
_ALIYUN_DEFAULT_MODEL = "wan2.7-image-pro"
_ALIYUN_DEFAULT_SIZE = "1152*640"
_ALIYUN_SUPPORTED_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
_ALIYUN_MAX_INPUT_IMAGES = 9
_ALIYUN_MAX_FILE_BYTES = 20 * 1024 * 1024  # 20 MB

logger = logging.getLogger(__name__)


class ImageGenError(RuntimeError):
    pass


# ================================================================ comfyui 协议

def _endpoint() -> str:
    return os.environ.get("SCENELEX_IMG_ENDPOINT",
                          "http://127.0.0.1:8188").rstrip("/")


def load_workflow() -> dict[str, Any]:
    path = Path(os.environ.get("SCENELEX_IMG_WORKFLOW", DEFAULT_WORKFLOW))
    if not path.exists():
        raise ImageGenError(f"工作流文件不存在: {path}")
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def workflow_name() -> str:
    return Path(os.environ.get("SCENELEX_IMG_WORKFLOW", DEFAULT_WORKFLOW)).name


def find_nodes(workflow: dict[str, Any]) -> tuple[str, str, str]:
    """定位 (采样器, 正提示, 负提示) 节点 ID。

    跟随采样器的 positive/negative 输入连线, 不依赖节点标题——任何标准
    文生图工作流都适用; 特殊工作流用 SCENELEX_IMG_*_NODE 显式覆盖。
    """
    env = os.environ
    if env.get("SCENELEX_IMG_SAMPLER_NODE"):
        return (env["SCENELEX_IMG_SAMPLER_NODE"],
                env["SCENELEX_IMG_POSITIVE_NODE"],
                env["SCENELEX_IMG_NEGATIVE_NODE"])
    for node_id, node in workflow.items():
        inputs = node.get("inputs", {})
        if all(k in inputs for k in ("seed", "positive", "negative")):
            positive = str(inputs["positive"][0])
            negative = str(inputs["negative"][0])
            for ref in (positive, negative):
                if "text" not in workflow.get(ref, {}).get("inputs", {}):
                    raise ImageGenError(
                        f"节点 {ref} 不是文本编码节点; 请用 "
                        "SCENELEX_IMG_*_NODE 显式指定节点 ID")
            return node_id, positive, negative
    raise ImageGenError("找不到含 seed/positive/negative 输入的采样器节点")


def model_name(workflow: dict[str, Any]) -> str:
    """权重文件名。checkpoint 与 split 权重 (UNET + 独立文本编码器) 都要认。"""
    for field in ("ckpt_name", "unet_name"):
        for node in workflow.values():
            name = node.get("inputs", {}).get(field)
            if name:
                return str(name)
    return "unknown"


def prepare_workflow(workflow: dict[str, Any], positive: str, negative: str,
                     seed: int) -> dict[str, Any]:
    """注入提示词与 seed, 返回可提交的工作流副本。"""
    wf = json.loads(json.dumps(workflow))
    sampler, pos, neg = find_nodes(wf)
    wf[pos]["inputs"]["text"] = positive
    wf[neg]["inputs"]["text"] = negative
    wf[sampler]["inputs"]["seed"] = seed
    return wf


def generate(positive: str, negative: str,
             seed: int | None = None) -> tuple[bytes, dict[str, Any]]:
    """生成一张图, 返回 (png 字节, 追溯信息)。仅支持 comfyui 协议。"""
    _require_protocol("comfyui")
    template = load_workflow()
    if seed is None:
        seed = random.randrange(2 ** 48)
    wf = prepare_workflow(template, positive, negative, seed)
    return run(wf), {
        "seed": seed,
        "model": model_name(wf),
        "workflow": workflow_name(),
    }


def check_protocol() -> None:
    """现有调用点的兼容入口 (comfyui 专用)。"""
    _require_protocol("comfyui")


def _require_protocol(required: str) -> None:
    protocol = os.environ.get("SCENELEX_IMG_PROTOCOL", "comfyui")
    if protocol != required:
        raise ImageGenError(
            f"当前协议为 {protocol!r}，该操作需要协议 {required!r}")


def upload_image(path: Path, name: str | None = None) -> str:
    """把本地图片推进 ComfyUI 的 input 目录, 返回 LoadImage 用的文件名。

    参考图必须先进 input 目录才能被 LoadImage 读到; 这是参考条件生成与纯文生图
    在协议层唯一的额外步骤。
    """
    check_protocol()
    filename = name or path.name
    with open(path, "rb") as file:
        resp = requests.post(
            f"{_endpoint()}/upload/image",
            files={"image": (filename, file, "image/png")},
            data={"overwrite": "true"},
            timeout=120,
        )
    if resp.status_code != 200:
        raise ImageGenError(f"上传参考图失败 HTTP {resp.status_code}: {resp.text[:400]}")
    body = resp.json()
    subfolder = body.get("subfolder") or ""
    return f"{subfolder}/{body['name']}" if subfolder else body["name"]


def run(wf: dict[str, Any]) -> bytes:
    """提交一张已经装配好的工作流并取回 png 字节。"""
    check_protocol()
    endpoint = _endpoint()
    timeout = int(os.environ.get("SCENELEX_IMG_TIMEOUT", "600"))

    resp = requests.post(f"{endpoint}/prompt", json={"prompt": wf}, timeout=30)
    if resp.status_code != 200:
        raise ImageGenError(f"提交失败 HTTP {resp.status_code}: {resp.text[:400]}")
    prompt_id = resp.json()["prompt_id"]

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        history = requests.get(f"{endpoint}/history/{prompt_id}",
                               timeout=30).json()
        entry = history.get(prompt_id)
        if entry:
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                messages = json.dumps(status.get("messages", []),
                                      ensure_ascii=False)[:600]
                raise ImageGenError(f"ComfyUI 执行出错: {messages}")
            images = [img for out in entry.get("outputs", {}).values()
                      for img in out.get("images", [])]
            if images:
                img = images[0]
                data = requests.get(f"{endpoint}/view", params={
                    "filename": img["filename"],
                    "subfolder": img.get("subfolder", ""),
                    "type": img.get("type", "output"),
                }, timeout=60).content
                return data
        time.sleep(1.0)
    raise ImageGenError(f"等待渲染超时 ({timeout}s): prompt_id={prompt_id}")


def license_note() -> str:
    return os.environ.get("SCENELEX_IMG_LICENSE", "unreviewed-local-model")


# ============================================================ aliyun-token-plan 协议

def _aliyun_key() -> str:
    """读取 Token Plan API Key。不得写入日志或异常信息。"""
    key = os.environ.get("SCENELEX_ALIYUN_TOKEN_PLAN_KEY", "")
    if not key:
        raise ImageGenError(
            "SCENELEX_ALIYUN_TOKEN_PLAN_KEY 未设置。"
            "请先 export SCENELEX_ALIYUN_TOKEN_PLAN_KEY=sk-sp-..."
        )
    return key


def _aliyun_endpoint() -> str:
    return os.environ.get("SCENELEX_IMG_ENDPOINT", _ALIYUN_DEFAULT_ENDPOINT)


def _aliyun_model() -> str:
    return os.environ.get("SCENELEX_IMG_MODEL", _ALIYUN_DEFAULT_MODEL)


def _aliyun_size() -> str:
    return os.environ.get("SCENELEX_IMG_SIZE", _ALIYUN_DEFAULT_SIZE)


def _aliyun_timeout() -> int:
    return int(os.environ.get("SCENELEX_IMG_TIMEOUT", "300"))


def _aliyun_retries() -> int:
    return int(os.environ.get("SCENELEX_IMG_RETRIES", "3"))


def _aliyun_interval() -> float:
    return float(os.environ.get("SCENELEX_IMG_REQUEST_INTERVAL", "1.0"))


def _encode_image(path: Path) -> str:
    """将图片文件编码为 Base64 Data URI。不在日志中暴露编码内容。"""
    ext = path.suffix.lower()
    mime_map = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".bmp": "image/bmp",
    }
    mime = mime_map[ext]
    data = path.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    return f"data:{mime};base64,{b64}"


def _validate_input_images(input_images: list[Path]) -> None:
    """在发送请求前验证所有输入图片。失败立即抛出 ImageGenError。"""
    count = len(input_images)
    if count == 0:
        raise ImageGenError("input_images 不能为空 (至少 1 张)")
    if count > _ALIYUN_MAX_INPUT_IMAGES:
        raise ImageGenError(
            f"input_images 最多 {_ALIYUN_MAX_INPUT_IMAGES} 张，"
            f"收到 {count} 张"
        )
    for path in input_images:
        if not path.exists():
            raise ImageGenError(f"输入图片不存在: {path.name}")
        if path.stat().st_size == 0:
            raise ImageGenError(f"输入图片是空文件: {path.name}")
        if path.stat().st_size > _ALIYUN_MAX_FILE_BYTES:
            mb = path.stat().st_size / (1024 * 1024)
            raise ImageGenError(
                f"输入图片超过 20 MB ({mb:.1f} MB): {path.name}"
            )
        if path.suffix.lower() not in _ALIYUN_SUPPORTED_EXTS:
            raise ImageGenError(
                f"不支持的图片格式 {path.suffix!r}: {path.name}。"
                f"支持: {', '.join(sorted(_ALIYUN_SUPPORTED_EXTS))}"
            )


def _validate_bbox_list(
    bbox_list: list[list[list[int]]] | None,
    image_count: int,
) -> None:
    """校验 bbox_list 的结构约束。"""
    if bbox_list is None:
        return
    if len(bbox_list) != image_count:
        raise ImageGenError(
            f"bbox_list 长度 ({len(bbox_list)}) 必须等于图片数量 ({image_count})"
        )
    for img_idx, bboxes in enumerate(bbox_list):
        if not isinstance(bboxes, list):
            raise ImageGenError(
                f"bbox_list[{img_idx}] 必须是列表，收到 {type(bboxes).__name__}"
            )
        if len(bboxes) > 2:
            raise ImageGenError(
                f"bbox_list[{img_idx}] 最多 2 个 bbox，收到 {len(bboxes)} 个"
            )
        for bbox_idx, bbox in enumerate(bboxes):
            if not isinstance(bbox, list) or len(bbox) != 4:
                raise ImageGenError(
                    f"bbox_list[{img_idx}][{bbox_idx}] 必须是 4 个整数的列表"
                )
            if not all(isinstance(v, int) for v in bbox):
                raise ImageGenError(
                    f"bbox_list[{img_idx}][{bbox_idx}] 坐标必须全是整数"
                )
            x1, y1, x2, y2 = bbox
            if x2 <= x1:
                raise ImageGenError(
                    f"bbox_list[{img_idx}][{bbox_idx}]: x2 ({x2}) 必须大于 x1 ({x1})"
                )
            if y2 <= y1:
                raise ImageGenError(
                    f"bbox_list[{img_idx}][{bbox_idx}]: y2 ({y2}) 必须大于 y1 ({y1})"
                )


def _should_retry(status_code: int) -> bool:
    """判断 HTTP 状态码是否应该重试。"""
    return status_code in (429, 500, 502, 503, 504)


def _download_image(url: str, timeout: int) -> bytes:
    """从临时 URL 下载图片字节。URL 不进入 trace。"""
    resp = requests.get(url, timeout=timeout)
    if resp.status_code != 200:
        raise ImageGenError(
            f"下载生成图片失败 HTTP {resp.status_code}"
        )
    data = resp.content
    if not data:
        raise ImageGenError("下载的图片内容为空")
    return data


def edit(
    instruction: str,
    input_images: list[Path],
    *,
    model: str | None = None,
    size: str | None = None,
    seed: int | None = None,
    bbox_list: list[list[list[int]]] | None = None,
) -> tuple[bytes, dict[str, Any]]:
    """通过 Token Plan Wan 2.7 图片编辑接口编辑图片。

    参数:
        instruction:  编辑指令 (自然语言)。
        input_images: 输入图片路径列表，1-9 张。
                      调用方按语义顺序传入；真正要编辑的基础图放在最后。
                      如果身份参考图与基础图相同，只传一次。
        model:        模型名称，默认 wan2.7-image-pro。
        size:         输出尺寸，默认 1152*640。
        seed:         随机种子，None 时由调用方随机。
        bbox_list:    可选，长度必须等于 input_images 数量，每张最多 2 个 bbox，
                      每个 bbox 为 [x1, y1, x2, y2]，坐标为整数且 x2>x1, y2>y1。

    返回:
        (png 字节, trace 追溯信息)

    trace 包含:
        protocol, provider, model, request_id, seed, requested_size,
        actual_size, input_count, bbox_used
        — 不含 API Key、Base64、Authorization、临时 URL。

    不向请求体写入: negative_prompt, prompt_extend, thinking_mode。
    """
    # 读取协议配置（aliyun-token-plan 才允许此函数）
    protocol = os.environ.get("SCENELEX_IMG_PROTOCOL", "comfyui")
    if protocol != "aliyun-token-plan":
        raise ImageGenError(
            f"edit() 需要协议 'aliyun-token-plan'，"
            f"当前 SCENELEX_IMG_PROTOCOL={protocol!r}"
        )

    # 读取 Key（不暴露到日志）
    key = _aliyun_key()

    # 输入验证（在请求前 fail-fast）
    _validate_input_images(input_images)
    _validate_bbox_list(bbox_list, len(input_images))

    actual_model = model or _aliyun_model()
    actual_size = size or _aliyun_size()
    if seed is None:
        seed = random.randrange(2 ** 48)
    endpoint = _aliyun_endpoint()
    timeout = _aliyun_timeout()
    max_retries = _aliyun_retries()
    base_interval = _aliyun_interval()

    # 构造 content 列表：图片按输入顺序 → text 最后一项
    content: list[dict[str, Any]] = []
    for idx, img_path in enumerate(input_images):
        data_uri = _encode_image(img_path)
        item: dict[str, Any] = {"image": data_uri}
        if bbox_list is not None and bbox_list[idx]:
            item["bbox_list"] = bbox_list[idx]
        content.append(item)
    content.append({"text": instruction})

    body = {
        "model": actual_model,
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": content,
                }
            ]
        },
        "parameters": {
            "size": actual_size,
            "n": 1,
            "watermark": False,
            "seed": seed,
        },
    }
    # 严格不写入：negative_prompt, prompt_extend, thinking_mode

    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }

    last_error: Exception | None = None
    last_status: int = 0
    request_id: str = ""

    for attempt in range(max_retries + 1):
        if attempt > 0:
            wait = min(base_interval * math.pow(2, attempt - 1), 60.0)
            logger.info("重试 %d/%d，等待 %.1fs", attempt, max_retries, wait)
            time.sleep(wait)

        try:
            resp = requests.post(
                endpoint,
                headers=headers,
                json=body,
                timeout=timeout,
            )
        except requests.ConnectionError as exc:
            last_error = exc
            logger.warning("连接错误 (attempt %d): %s", attempt + 1,
                            type(exc).__name__)
            continue
        except requests.Timeout as exc:
            last_error = exc
            logger.warning("请求超时 (attempt %d)", attempt + 1)
            continue

        last_status = resp.status_code

        # 尝试提取 request_id（无论成败都记录，便于追踪）
        try:
            resp_body = resp.json()
        except Exception:
            resp_body = {}
        request_id = resp_body.get("request_id", "")

        if resp.status_code == 200:
            # 解析成功响应
            choices = resp_body.get("output", {}).get("choices", [])
            image_url: str | None = None
            returned_count = 0
            for choice in choices:
                for item in (choice.get("message") or {}).get("content") or []:
                    if "image" in item:
                        returned_count += 1
                        if image_url is None:
                            image_url = item["image"]

            if not image_url:
                raise ImageGenError(
                    f"响应中未找到图片 URL "
                    f"(request_id={request_id or 'unknown'})"
                )

            logger.info(
                "生成成功: returned_image_count=%d selected_index=0 "
                "request_id=%s",
                returned_count, request_id,
            )

            # 立即下载（临时 URL 约 24 小时有效，不持久化 URL 本身）
            img_bytes = _download_image(image_url, timeout)
            # image_url 在此处已使用，不进入返回值

            # 解析实际尺寸（从 usage 字段）
            usage = resp_body.get("usage", {})
            actual_size_out = usage.get("size", actual_size)

            trace: dict[str, Any] = {
                "protocol": "aliyun-token-plan",
                "provider": "aliyun-token-plan",
                "model": actual_model,
                "request_id": request_id,
                "seed": seed,
                "requested_size": actual_size,
                "actual_size": actual_size_out,
                "input_count": len(input_images),
                "bbox_used": bbox_list is not None and any(
                    bool(b) for b in bbox_list
                ),
                "returned_image_count": returned_count,
                "selected_index": 0,
            }
            return img_bytes, trace

        # 不重试的错误
        if resp.status_code in (400, 401, 403, 404):
            # 允许保留：HTTP status、error code、截断 message、request_id
            # 不允许保留：Authorization、Base64、完整请求 JSON
            err_code = resp_body.get("code", "")
            err_msg = str(resp_body.get("message", ""))[:200]
            raise ImageGenError(
                f"HTTP {resp.status_code} {err_code}: {err_msg} "
                f"(request_id={request_id or 'unknown'})"
            )

        # 可重试的错误
        if _should_retry(resp.status_code):
            err_code = resp_body.get("code", "")
            err_msg = str(resp_body.get("message", ""))[:200]
            last_error = ImageGenError(
                f"HTTP {resp.status_code} {err_code}: {err_msg} "
                f"(request_id={request_id or 'unknown'})"
            )
            logger.warning(
                "可重试错误 HTTP %d (attempt %d/%d): %s",
                resp.status_code, attempt + 1, max_retries + 1, err_code,
            )
            continue

        # 其他未预期状态码：不重试
        err_code = resp_body.get("code", "")
        err_msg = str(resp_body.get("message", ""))[:200]
        raise ImageGenError(
            f"HTTP {resp.status_code} {err_code}: {err_msg} "
            f"(request_id={request_id or 'unknown'})"
        )

    # 超过重试上限
    raise ImageGenError(
        f"超过最大重试次数 ({max_retries})，"
        f"最后一次 HTTP {last_status} "
        f"(request_id={request_id or 'unknown'})"
    ) from last_error
