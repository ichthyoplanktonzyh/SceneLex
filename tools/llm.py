"""SceneLex 生成层适配器 — 模型无关。

后端通过环境变量选择, 默认自动探测:
  SCENELEX_LLM_BACKEND = claude-cli | anthropic   (默认: 有 ANTHROPIC_API_KEY 用 anthropic, 否则 claude-cli)
  SCENELEX_LLM_MODEL   = 模型名 (可选; claude-cli 默认用 CLI 自身默认模型,
                          anthropic 后端默认 claude-opus-4-8)

新增后端只需在 BACKENDS 中注册一个 (prompt: str) -> str 函数。
"""

import os
import subprocess


def _claude_cli(prompt: str) -> str:
    cmd = ["claude", "-p"]
    model = os.environ.get("SCENELEX_LLM_MODEL")
    if model:
        cmd += ["--model", model]
    result = subprocess.run(
        cmd, input=prompt, capture_output=True, text=True, timeout=900)
    if result.returncode != 0:
        raise RuntimeError(f"claude CLI 调用失败: {result.stderr.strip()}")
    return result.stdout


def _anthropic_sdk(prompt: str) -> str:
    import anthropic
    client = anthropic.Anthropic()
    model = os.environ.get("SCENELEX_LLM_MODEL", "claude-opus-4-8")
    with client.messages.stream(
        model=model,
        max_tokens=32000,
        thinking={"type": "adaptive"},
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        message = stream.get_final_message()
    return "".join(b.text for b in message.content if b.type == "text")


BACKENDS = {
    "claude-cli": _claude_cli,
    "anthropic": _anthropic_sdk,
}


def generate(prompt: str) -> str:
    backend = os.environ.get("SCENELEX_LLM_BACKEND")
    if not backend:
        backend = "anthropic" if os.environ.get("ANTHROPIC_API_KEY") else "claude-cli"
    if backend not in BACKENDS:
        raise ValueError(f"未知后端 '{backend}', 可选: {', '.join(BACKENDS)}")
    return BACKENDS[backend](prompt)
