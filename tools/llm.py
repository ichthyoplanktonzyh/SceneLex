"""Vendor-neutral text generation adapters for SceneLex authoring tools.

The public contract of this module is deliberately small: ``generate(prompt)``.
Provider names, model names, credentials and transport details stay here and
must never leak into sense or scene resource schemas.

Supported wire protocols:

* ``openai-responses``: OpenAI Responses API compatible JSON
* ``openai-chat``: OpenAI Chat Completions compatible JSON (streams by
  default so slow long generations are not killed by idle-timeout gateways;
  set ``SCENELEX_LLM_STREAM=0`` to disable)
* ``anthropic``: Anthropic Messages compatible JSON
* ``command``: any local command that accepts the prompt on stdin

OpenAI-compatible endpoints cover OpenAI itself as well as gateways, local
servers, and providers exposing the same protocol. Exact endpoints and auth
headers are configuration, not hard-coded provider registrations.
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Callable

import requests


class LLMConfigurationError(ValueError):
    """Raised when an adapter is not fully configured."""


class LLMResponseError(RuntimeError):
    """Raised when an endpoint returns an error or an unreadable response."""


@dataclass(frozen=True)
class LLMConfig:
    protocol: str
    model: str | None = None
    base_url: str | None = None
    endpoint: str | None = None
    api_key: str | None = None
    api_key_header: str = "Authorization"
    auth_scheme: str = "Bearer"
    max_tokens: int = 32_000
    timeout: int = 900
    stream: bool = True
    extra_headers: dict[str, str] | None = None
    command: str | None = None

    @classmethod
    def from_env(cls) -> "LLMConfig":
        protocol = os.environ.get("SCENELEX_LLM_PROTOCOL")
        # Backwards-compatible name. New documentation uses PROTOCOL because
        # the value describes a wire format, not a vendor.
        if not protocol:
            protocol = os.environ.get("SCENELEX_LLM_BACKEND")
        aliases = {"claude-cli": "command", "openai": "openai-responses"}
        protocol = aliases.get(protocol or "", protocol or "")
        if not protocol:
            raise LLMConfigurationError(
                "未配置 SCENELEX_LLM_PROTOCOL；可选 openai-responses、"
                "openai-chat、anthropic、command"
            )

        extra_headers: dict[str, str] = {}
        raw_headers = os.environ.get("SCENELEX_LLM_HEADERS_JSON")
        if raw_headers:
            try:
                parsed = json.loads(raw_headers)
            except json.JSONDecodeError as exc:
                raise LLMConfigurationError(
                    "SCENELEX_LLM_HEADERS_JSON 必须是 JSON 对象"
                ) from exc
            if not isinstance(parsed, dict) or not all(
                isinstance(k, str) and isinstance(v, str)
                for k, v in parsed.items()
            ):
                raise LLMConfigurationError(
                    "SCENELEX_LLM_HEADERS_JSON 的键和值都必须是字符串"
                )
            extra_headers = parsed

        api_key = os.environ.get("SCENELEX_LLM_API_KEY")
        if not api_key:
            if protocol.startswith("openai"):
                api_key = os.environ.get("OPENAI_API_KEY")
            elif protocol == "anthropic":
                api_key = os.environ.get("ANTHROPIC_API_KEY")

        command = os.environ.get("SCENELEX_LLM_COMMAND")
        if protocol == "command" and not command:
            # Preserve the old claude-cli configuration without making it the
            # project default.
            if os.environ.get("SCENELEX_LLM_BACKEND") == "claude-cli":
                command = "claude -p"
                if os.environ.get("SCENELEX_LLM_MODEL"):
                    command += " --model {model}"
            else:
                raise LLMConfigurationError(
                    "command 协议需要 SCENELEX_LLM_COMMAND"
                )

        return cls(
            protocol=protocol,
            model=os.environ.get("SCENELEX_LLM_MODEL"),
            base_url=os.environ.get("SCENELEX_LLM_BASE_URL"),
            endpoint=os.environ.get("SCENELEX_LLM_ENDPOINT"),
            api_key=api_key,
            api_key_header=os.environ.get(
                "SCENELEX_LLM_API_KEY_HEADER", "Authorization"
            ),
            auth_scheme=os.environ.get("SCENELEX_LLM_AUTH_SCHEME", "Bearer"),
            max_tokens=_positive_int("SCENELEX_LLM_MAX_TOKENS", 32_000),
            timeout=_positive_int("SCENELEX_LLM_TIMEOUT", 900),
            stream=os.environ.get("SCENELEX_LLM_STREAM", "1").lower()
            not in ("0", "false", "no"),
            extra_headers=extra_headers,
            command=command,
        )


Adapter = Callable[[str, LLMConfig], str]
ADAPTERS: dict[str, Adapter] = {}


def register_adapter(name: str, adapter: Adapter) -> None:
    """Register an in-process adapter without changing SceneLex schemas."""
    if not name or not callable(adapter):
        raise ValueError("adapter name and callable are required")
    ADAPTERS[name] = adapter


def _positive_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise LLMConfigurationError(f"{name} 必须是正整数") from exc
    if value <= 0:
        raise LLMConfigurationError(f"{name} 必须是正整数")
    return value


def _url(config: LLMConfig, default_base: str, path: str) -> str:
    if config.endpoint:
        return config.endpoint
    return f"{(config.base_url or default_base).rstrip('/')}/{path.lstrip('/')}"


def _headers(config: LLMConfig, *, anthropic: bool = False) -> dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if config.api_key:
        if anthropic and config.api_key_header == "Authorization":
            headers["x-api-key"] = config.api_key
        else:
            prefix = f"{config.auth_scheme} " if config.auth_scheme else ""
            headers[config.api_key_header] = f"{prefix}{config.api_key}"
    headers.update(config.extra_headers or {})
    return headers


def _post_json(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> dict[str, Any]:
    try:
        return _post_json_requests(url, payload, headers, timeout)
    except (requests.exceptions.ConnectionError,
            requests.exceptions.ChunkedEncodingError,
            requests.exceptions.ReadTimeout) as exc:
        # Sandbox / proxy environments may break large chunked responses.
        # Fall back to curl which often handles these more reliably.
        print(f"  (requests 失败, 尝试 curl 回退: {exc})", file=sys.stderr)
        return _post_json_curl(url, payload, headers, timeout)


def _post_json_requests(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> dict[str, Any]:
    response = requests.post(
        url,
        json=payload,
        headers=headers,
        timeout=timeout,
    )
    response.raise_for_status()
    doc = response.json()
    if not isinstance(doc, dict):
        raise LLMResponseError("LLM JSON 响应根节点必须是对象")
    return doc


def _run_curl(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
    *,
    stream: bool = False,
) -> str:
    """POST via curl and return the response body (HTTP errors raise)."""
    header_args: list[str] = []
    for key, value in headers.items():
        header_args.extend(["-H", f"{key}: {value}"])
    # Preserve known env so curl can see TLS roots etc.
    env = os.environ.copy()
    # Strip proxy vars so curl connects directly when the sandbox proxy
    # is the root cause of chunked-encoding breakage.
    for name in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY",
                 "all_proxy", "ALL_PROXY", "no_proxy", "NO_PROXY"):
        env.pop(name, None)
    try:
        result = subprocess.run(
            [
                "curl", "-s", *(["-N"] if stream else []),
                "-w", "\n%{http_code}", "-X", "POST", url,
                "--max-time", str(timeout),
                "-d", json.dumps(payload),
                *header_args,
            ],
            capture_output=True,
            text=True,
            timeout=timeout + 5,
            env=env,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise LLMResponseError(f"curl 执行失败: {exc}") from exc
    output = result.stdout
    stderr_tail = result.stderr.strip()[-200:] if result.stderr else ""
    if not output:
        raise LLMResponseError(
            f"curl 无输出 (rc={result.returncode}): {stderr_tail}"
        )
    # Last line is the HTTP status code we appended via -w.
    lines = output.rsplit("\n", 1)
    if len(lines) == 2 and lines[1].strip().isdigit():
        status_code = int(lines[1].strip())
        body = lines[0]
    else:
        body = output
        status_code = 0
    if status_code >= 400:
        raise LLMResponseError(f"LLM HTTP {status_code}: {body[:1000]}")
    return body


def _post_json_curl(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> dict[str, Any]:
    body = _run_curl(url, payload, headers, timeout)
    try:
        doc = json.loads(body)
    except json.JSONDecodeError as exc:
        raise LLMResponseError(f"LLM 返回了非 JSON 响应: {body[:200]}") from exc
    if not isinstance(doc, dict):
        raise LLMResponseError("LLM JSON 响应根节点必须是对象")
    return doc


def _sse_chat_delta(line: str) -> str | None:
    """Extract the text delta from one Chat Completions SSE line, if any."""
    if not line.startswith("data:"):
        return None
    data = line[len("data:"):].strip()
    if not data or data == "[DONE]":
        return None
    try:
        doc = json.loads(data)
    except json.JSONDecodeError as exc:
        raise LLMResponseError(f"流式响应块不是 JSON: {data[:200]}") from exc
    if not isinstance(doc, dict):
        raise LLMResponseError("流式响应块必须是 JSON 对象")
    if doc.get("error"):
        raise LLMResponseError(f"LLM 流式错误: {json.dumps(doc['error'])[:500]}")
    choices = doc.get("choices") or []
    if not choices or not isinstance(choices[0], dict):
        return None
    delta = choices[0].get("delta") or {}
    content = delta.get("content")
    return content if isinstance(content, str) else None


def _collect_sse_text(lines: Any) -> str:
    texts = [t for t in (_sse_chat_delta(line) for line in lines if line) if t]
    if not texts:
        raise LLMResponseError("流式响应中没有文本输出")
    return "".join(texts)


def _post_sse(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> str:
    """POST a streaming Chat Completions request and join the text deltas.

    Streaming keeps bytes moving on the connection, so idle-timeout
    middleboxes (gateways, proxies) do not kill slow long generations the
    way they kill non-streaming requests.
    """
    try:
        response = requests.post(
            url, json=payload, headers=headers, timeout=timeout, stream=True
        )
        response.raise_for_status()
        return _collect_sse_text(response.iter_lines(decode_unicode=True))
    except (requests.exceptions.ConnectionError,
            requests.exceptions.ChunkedEncodingError,
            requests.exceptions.ReadTimeout) as exc:
        print(f"  (requests 失败, 尝试 curl 回退: {exc})", file=sys.stderr)
        body = _run_curl(url, payload, headers, timeout, stream=True)
        return _collect_sse_text(body.splitlines())


def _require_api(config: LLMConfig) -> None:
    if not config.model:
        raise LLMConfigurationError("API 协议需要 SCENELEX_LLM_MODEL")
    if not config.api_key and not (config.extra_headers or {}):
        raise LLMConfigurationError(
            "API 协议需要 SCENELEX_LLM_API_KEY，或通过 "
            "SCENELEX_LLM_HEADERS_JSON 提供认证头"
        )


def _openai_responses(prompt: str, config: LLMConfig) -> str:
    _require_api(config)
    doc = _post_json(
        _url(config, "https://api.openai.com/v1", "responses"),
        {
            "model": config.model,
            "input": prompt,
            "max_output_tokens": config.max_tokens,
            "store": False,
        },
        _headers(config),
        config.timeout,
    )
    if isinstance(doc.get("output_text"), str):
        return doc["output_text"]
    texts = []
    for item in doc.get("output") or []:
        for content in item.get("content") or []:
            text = content.get("text")
            if isinstance(text, str):
                texts.append(text)
    if not texts:
        raise LLMResponseError("Responses 响应中没有文本输出")
    return "".join(texts)


def _openai_chat(prompt: str, config: LLMConfig) -> str:
    _require_api(config)
    url = _url(config, "https://api.openai.com/v1", "chat/completions")
    payload: dict[str, Any] = {
        "model": config.model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": config.max_tokens,
    }
    if config.stream:
        payload["stream"] = True
        return _post_sse(url, payload, _headers(config), config.timeout)
    doc = _post_json(url, payload, _headers(config), config.timeout)
    try:
        content = doc["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMResponseError("Chat Completions 响应结构不完整") from exc
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = [part.get("text", "") for part in content if isinstance(part, dict)]
        if any(texts):
            return "".join(texts)
    raise LLMResponseError("Chat Completions 响应中没有文本输出")


def _anthropic_messages(prompt: str, config: LLMConfig) -> str:
    _require_api(config)
    headers = _headers(config, anthropic=True)
    headers.setdefault("anthropic-version", "2023-06-01")
    doc = _post_json(
        _url(config, "https://api.anthropic.com/v1", "messages"),
        {
            "model": config.model,
            "max_tokens": config.max_tokens,
            "messages": [{"role": "user", "content": prompt}],
        },
        headers,
        config.timeout,
    )
    texts = [
        block.get("text", "")
        for block in doc.get("content") or []
        if isinstance(block, dict) and block.get("type") == "text"
    ]
    if not any(texts):
        raise LLMResponseError("Anthropic Messages 响应中没有文本输出")
    return "".join(texts)


def _command(prompt: str, config: LLMConfig) -> str:
    if not config.command:
        raise LLMConfigurationError("command 协议需要 SCENELEX_LLM_COMMAND")
    cmd = shlex.split(config.command)
    if any("{model}" in part for part in cmd):
        if not config.model:
            raise LLMConfigurationError(
                "SCENELEX_LLM_COMMAND 使用了 {model}，但未配置 SCENELEX_LLM_MODEL"
            )
        cmd = [part.replace("{model}", config.model) for part in cmd]
    try:
        result = subprocess.run(
            cmd,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=config.timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise LLMResponseError(f"本地模型命令执行失败: {exc}") from exc
    if result.returncode != 0:
        raise LLMResponseError(
            f"本地模型命令退出码 {result.returncode}: {result.stderr.strip()[:1000]}"
        )
    return result.stdout


register_adapter("openai-responses", _openai_responses)
register_adapter("openai-chat", _openai_chat)
register_adapter("anthropic", _anthropic_messages)
register_adapter("command", _command)


def generate(prompt: str, config: LLMConfig | None = None) -> str:
    config = config or LLMConfig.from_env()
    adapter = ADAPTERS.get(config.protocol)
    if not adapter:
        raise LLMConfigurationError(
            f"未知协议 '{config.protocol}'，可选: {', '.join(sorted(ADAPTERS))}"
        )
    return adapter(prompt, config)
