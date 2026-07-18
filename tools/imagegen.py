#!/usr/bin/env python3
"""图像生成适配器 — 按协议兼容, 不绑定厂商 (与 tools/llm.py 同纪律)。

当前实现 comfyui 协议: 加载工作流 API JSON 模板, 自动定位采样器与正负提示词
节点 (跟随 KSampler 的 positive/negative 连线, 不依赖节点标题), 注入提示词与
seed 后提交 /prompt, 轮询 /history 取图。

环境变量:
  SCENELEX_IMG_PROTOCOL   comfyui (默认)
  SCENELEX_IMG_ENDPOINT   ComfyUI 地址 (默认 http://127.0.0.1:8188)
  SCENELEX_IMG_WORKFLOW   工作流 API JSON 路径
                          (默认 tools/workflows/comfyui-text2image.json)
  SCENELEX_IMG_TIMEOUT    单张图超时秒数 (默认 600)
  SCENELEX_IMG_LICENSE    资产许可标注 (默认 unreviewed-local-model)

节点自动定位失败时可显式指定:
  SCENELEX_IMG_SAMPLER_NODE / SCENELEX_IMG_POSITIVE_NODE / SCENELEX_IMG_NEGATIVE_NODE
"""

from __future__ import annotations

import json
import os
import random
import time
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_WORKFLOW = ROOT / "tools" / "workflows" / "comfyui-text2image.json"


class ImageGenError(RuntimeError):
    pass


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
    for node in workflow.values():
        ckpt = node.get("inputs", {}).get("ckpt_name")
        if ckpt:
            return str(ckpt)
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
    """生成一张图, 返回 (png 字节, 追溯信息)。"""
    protocol = os.environ.get("SCENELEX_IMG_PROTOCOL", "comfyui")
    if protocol != "comfyui":
        raise ImageGenError(f"未实现的图像协议: {protocol}")

    template = load_workflow()
    if seed is None:
        seed = random.randrange(2 ** 48)
    wf = prepare_workflow(template, positive, negative, seed)
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
                return data, {
                    "seed": seed,
                    "model": model_name(wf),
                    "workflow": workflow_name(),
                }
        time.sleep(1.0)
    raise ImageGenError(f"等待渲染超时 ({timeout}s): prompt_id={prompt_id}")


def license_note() -> str:
    return os.environ.get("SCENELEX_IMG_LICENSE", "unreviewed-local-model")
