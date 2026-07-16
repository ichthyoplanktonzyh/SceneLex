import json
from unittest import mock

import pytest
import requests

import llm


class FakeResponse:
    def __init__(self, document=None, lines=None, status_code=200):
        self.document = document
        self.lines = lines or []
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.exceptions.HTTPError(f"HTTP {self.status_code}")

    def json(self):
        return self.document

    def iter_lines(self, decode_unicode=False):
        return iter(self.lines)


def call_with_response(config, response):
    with mock.patch("llm.requests.post", return_value=response) as post:
        output = llm.generate("hello", config)
    return output, post.call_args


def test_responses_protocol_and_text_extraction():
    config = llm.LLMConfig(
        protocol="openai-responses", model="example", api_key="secret"
    )
    output, call = call_with_response(
        config, FakeResponse({"output_text": "result"})
    )
    assert output == "result"
    assert call.args[0] == "https://api.openai.com/v1/responses"
    payload = call.kwargs["json"]
    assert payload["input"] == "hello"
    assert payload["store"] is False
    assert call.kwargs["headers"]["Authorization"] == "Bearer secret"


def test_openai_compatible_chat_uses_custom_endpoint():
    config = llm.LLMConfig(
        protocol="openai-chat",
        model="example",
        endpoint="https://gateway.example/generate",
        api_key="secret",
        stream=False,
    )
    output, call = call_with_response(
        config, FakeResponse({"choices": [{"message": {"content": "result"}}]})
    )
    assert output == "result"
    assert call.args[0] == "https://gateway.example/generate"
    assert "stream" not in call.kwargs["json"]


def test_openai_chat_streams_by_default():
    config = llm.LLMConfig(
        protocol="openai-chat", model="example", api_key="secret"
    )
    sse_lines = [
        'data: {"choices": [{"delta": {"role": "assistant"}}]}',
        "",
        'data: {"choices": [{"delta": {"content": "res"}}]}',
        'data: {"choices": [{"delta": {"content": "ult"}}]}',
        'data: {"choices": [{"delta": {}, "finish_reason": "stop"}]}',
        "data: [DONE]",
    ]
    output, call = call_with_response(config, FakeResponse(lines=sse_lines))
    assert output == "result"
    assert call.args[0] == "https://api.openai.com/v1/chat/completions"
    assert call.kwargs["json"]["stream"] is True
    assert call.kwargs["stream"] is True


def test_openai_chat_stream_surfaces_api_errors():
    config = llm.LLMConfig(
        protocol="openai-chat", model="example", api_key="secret"
    )
    lines = ['data: {"error": {"message": "quota exceeded"}}']
    with mock.patch("llm.requests.post", return_value=FakeResponse(lines=lines)):
        with pytest.raises(llm.LLMResponseError, match="quota exceeded"):
            llm.generate("hello", config)


def test_anthropic_messages_protocol():
    config = llm.LLMConfig(
        protocol="anthropic", model="example", api_key="secret"
    )
    output, call = call_with_response(
        config,
        FakeResponse({"content": [{"type": "thinking", "thinking": "hidden"},
                                  {"type": "text", "text": "result"}]}),
    )
    assert output == "result"
    assert call.args[0] == "https://api.anthropic.com/v1/messages"
    assert call.kwargs["headers"]["x-api-key"] == "secret"
    assert call.kwargs["headers"]["anthropic-version"] == "2023-06-01"


def test_env_configuration_is_explicit(monkeypatch):
    monkeypatch.delenv("SCENELEX_LLM_PROTOCOL", raising=False)
    monkeypatch.delenv("SCENELEX_LLM_BACKEND", raising=False)
    with pytest.raises(llm.LLMConfigurationError):
        llm.LLMConfig.from_env()


def test_env_can_disable_streaming(monkeypatch):
    monkeypatch.setenv("SCENELEX_LLM_PROTOCOL", "openai-chat")
    monkeypatch.setenv("SCENELEX_LLM_MODEL", "example")
    monkeypatch.setenv("SCENELEX_LLM_API_KEY", "secret")
    assert llm.LLMConfig.from_env().stream is True
    monkeypatch.setenv("SCENELEX_LLM_STREAM", "0")
    assert llm.LLMConfig.from_env().stream is False


def test_custom_adapter_can_be_registered():
    llm.register_adapter("test-adapter", lambda prompt, config: prompt.upper())
    config = llm.LLMConfig(protocol="test-adapter")
    assert llm.generate("hello", config) == "HELLO"
