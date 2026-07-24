import json
from pathlib import Path
from unittest import mock

import pytest
import requests

import llm


class FakeResponse:
    def __init__(self, document=None, lines=None, status_code=200, headers=None):
        self.document = document
        self.lines = lines or []
        self.status_code = status_code
        self.headers = headers or {}

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.exceptions.HTTPError(f"HTTP {self.status_code}")

    def json(self):
        return self.document

    def iter_lines(self, decode_unicode=False):
        return iter(self.lines)


def call_with_response(config, response, system_prompt=None):
    with mock.patch("llm.requests.post", return_value=response) as post:
        res = llm.invoke("hello", config, system_prompt=system_prompt)
    return res, post.call_args


def test_responses_protocol_and_text_extraction():
    config = llm.LLMConfig(
        protocol="openai-responses", model="example", api_key="secret"
    )
    res, call = call_with_response(
        config, FakeResponse({"output_text": "result", "id": "req-123"})
    )
    assert isinstance(res, llm.LLMResult)
    assert res.text == "result"
    assert res.request_id == "req-123"
    assert res.protocol == "openai-responses"
    assert call.args[0] == "https://api.openai.com/v1/responses"
    payload = call.kwargs["json"]
    assert payload["input"] == "hello"
    assert payload["store"] is False
    assert call.kwargs["headers"]["Authorization"] == "Bearer secret"


def test_system_prompt_in_protocols():
    # OpenAI Chat
    config_chat = llm.LLMConfig(protocol="openai-chat", model="gpt-4o", api_key="sk-test", stream=False)
    res_chat, call_chat = call_with_response(
        config_chat,
        FakeResponse({"choices": [{"message": {"content": "chat output"}}]}, headers={"x-request-id": "req-chat"}),
        system_prompt="you are visual compiler"
    )
    assert res_chat.text == "chat output"
    assert res_chat.request_id == "req-chat"
    messages = call_chat.kwargs["json"]["messages"]
    assert messages[0] == {"role": "system", "content": "you are visual compiler"}
    assert messages[1] == {"role": "user", "content": "hello"}

    # OpenAI Responses
    config_resp = llm.LLMConfig(protocol="openai-responses", model="gpt-4o", api_key="sk-test")
    res_resp, call_resp = call_with_response(
        config_resp,
        FakeResponse({"output_text": "resp output", "id": "req-resp"}),
        system_prompt="you are visual compiler"
    )
    assert res_resp.text == "resp output"
    assert call_resp.kwargs["json"]["instructions"] == "you are visual compiler"

    # Anthropic
    config_ant = llm.LLMConfig(protocol="anthropic", model="claude-3-5", api_key="sk-ant")
    res_ant, call_ant = call_with_response(
        config_ant,
        FakeResponse({"content": [{"type": "text", "text": "ant output"}]}, headers={"request-id": "req-ant"}),
        system_prompt="you are visual compiler"
    )
    assert res_ant.text == "ant output"
    assert res_ant.request_id == "req-ant"
    assert call_ant.kwargs["json"]["system"] == "you are visual compiler"


def test_multimodal_invocation(tmp_path):
    img1 = tmp_path / "test1.png"
    img1.write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRtest1")

    config_chat = llm.LLMConfig(protocol="openai-chat", model="gpt-4o", api_key="sk-test", stream=False)
    with mock.patch("llm.requests.post", return_value=FakeResponse({"choices": [{"message": {"content": "vlm output"}}]})) as post:
        res = llm.invoke_multimodal("analyze image", [img1], config_chat, system_prompt="vlm system")
    assert res.text == "vlm output"
    payload = post.call_args.kwargs["json"]
    messages = payload["messages"]
    assert messages[0] == {"role": "system", "content": "vlm system"}
    user_msg = messages[1]
    assert user_msg["role"] == "user"
    assert len(user_msg["content"]) == 2
    assert user_msg["content"][0]["type"] == "image_url"
    assert user_msg["content"][0]["image_url"]["url"].startswith("data:image/png;base64,")
    assert user_msg["content"][1] == {"type": "text", "text": "analyze image"}


def test_multimodal_fails_fast(tmp_path):
    non_existent = tmp_path / "non_existent.png"
    config_chat = llm.LLMConfig(protocol="openai-chat", model="gpt-4o", api_key="sk-test")
    with pytest.raises(llm.LLMResponseError, match="图片文件不存在"):
        llm.invoke_multimodal("hello", [non_existent], config_chat)

    empty_img = tmp_path / "empty.png"
    empty_img.write_bytes(b"")
    with pytest.raises(llm.LLMResponseError, match="图片文件为空"):
        llm.invoke_multimodal("hello", [empty_img], config_chat)

    unsupported = tmp_path / "test.gif"
    unsupported.write_bytes(b"GIF89a")
    with pytest.raises(llm.LLMResponseError, match="不支持的多模态图片格式"):
        llm.invoke_multimodal("hello", [unsupported], config_chat)


def test_unsupported_multimodal_protocols(tmp_path):
    img = tmp_path / "test.png"
    img.write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDRtest")
    config_cmd = llm.LLMConfig(protocol="command", command="cat")
    with pytest.raises(llm.LLMResponseError, match="不支持多模态调用"):
        llm.invoke_multimodal("hello", [img], config_cmd)


def test_multi_level_env_configuration(monkeypatch):
    monkeypatch.setenv("SCENELEX_LLM_PROTOCOL", "openai-chat")
    monkeypatch.setenv("SCENELEX_LLM_MODEL", "gpt-4-default")
    monkeypatch.setenv("SCENELEX_LLM_API_KEY", "sk-default")

    config_generic = llm.LLMConfig.from_env()
    assert config_generic.protocol == "openai-chat"
    assert config_generic.model == "gpt-4-default"

    # Specific override for Visual Compiler
    monkeypatch.setenv("SCENELEX_VISUAL_COMPILER_MODEL", "gpt-4o-compiler")
    config_vc = llm.LLMConfig.from_env(prefix="SCENELEX_VISUAL_COMPILER_")
    assert config_vc.protocol == "openai-chat"  # Falls back to SCENELEX_LLM_PROTOCOL
    assert config_vc.model == "gpt-4o-compiler"  # Overridden
    assert config_vc.api_key == "sk-default"  # Falls back


def test_custom_adapter_can_be_registered():
    llm.register_adapter("test-adapter", lambda prompt, config: prompt.upper())
    config = llm.LLMConfig(protocol="test-adapter")
    assert llm.generate("hello", config) == "HELLO"
