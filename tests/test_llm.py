import json
from unittest import mock

import pytest

import llm


class FakeResponse:
    def __init__(self, document):
        self.document = document

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        return json.dumps(self.document).encode()


def call_with_response(config, document):
    with mock.patch("llm.request.urlopen", return_value=FakeResponse(document)) as urlopen:
        output = llm.generate("hello", config)
    return output, urlopen.call_args


def test_responses_protocol_and_text_extraction():
    config = llm.LLMConfig(
        protocol="openai-responses", model="example", api_key="secret"
    )
    output, call = call_with_response(config, {"output_text": "result"})
    assert output == "result"
    request_object = call.args[0]
    payload = json.loads(request_object.data)
    assert request_object.full_url == "https://api.openai.com/v1/responses"
    assert payload["input"] == "hello"
    assert payload["store"] is False
    assert request_object.headers["Authorization"] == "Bearer secret"


def test_openai_compatible_chat_uses_custom_endpoint():
    config = llm.LLMConfig(
        protocol="openai-chat",
        model="example",
        endpoint="https://gateway.example/generate",
        api_key="secret",
    )
    output, call = call_with_response(
        config, {"choices": [{"message": {"content": "result"}}]}
    )
    assert output == "result"
    assert call.args[0].full_url == "https://gateway.example/generate"


def test_anthropic_messages_protocol():
    config = llm.LLMConfig(
        protocol="anthropic", model="example", api_key="secret"
    )
    output, call = call_with_response(
        config,
        {"content": [{"type": "thinking", "thinking": "hidden"},
                     {"type": "text", "text": "result"}]},
    )
    assert output == "result"
    request_object = call.args[0]
    assert request_object.full_url == "https://api.anthropic.com/v1/messages"
    assert request_object.headers["X-api-key"] == "secret"
    assert request_object.headers["Anthropic-version"] == "2023-06-01"


def test_env_configuration_is_explicit(monkeypatch):
    monkeypatch.delenv("SCENELEX_LLM_PROTOCOL", raising=False)
    monkeypatch.delenv("SCENELEX_LLM_BACKEND", raising=False)
    with pytest.raises(llm.LLMConfigurationError):
        llm.LLMConfig.from_env()


def test_custom_adapter_can_be_registered():
    llm.register_adapter("test-adapter", lambda prompt, config: prompt.upper())
    config = llm.LLMConfig(protocol="test-adapter")
    assert llm.generate("hello", config) == "HELLO"
