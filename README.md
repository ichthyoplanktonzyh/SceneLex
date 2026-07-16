# SceneLex

> 可验证的词义边界 + 能证明学习迁移的场景证据。

SceneLex 是一套可独立发布、版本化和复用的**词义语义资源与教学证据库**。它为每个可教学词义建立机器可验证的语义规格，并用原型、对比、反例、边界和迁移场景提供可观察证据。

SceneLex 不是某个学习 App 的内部素材目录，也不由某个词典、播放器、课程或模型厂商定义。学习产品是资源消费者之一，同时也是验证这些资源是否真的产生理解、区分和迁移效果的重要实验端。

理论全文见 [一、先明确系统最终要解决什么问题.md](一、先明确系统最终要解决什么问题.md)。仓库约束见 [AGENT.md](AGENT.md)。
第一轮实证方案见 [docs/mvp-evaluation.md](docs/mvp-evaluation.md)。

## 核心产物

```text
word sense specification
  ├── 成立条件与真正的排除条件
  ├── 包含、重叠、程度、正交和多义关系
  ├── L1 特定混淆
  └── 可由场景验证的边界判据
              ↓
teaching-scene evidence
  ├── prototype      建立概念
  ├── contrast       区分相邻概念，也允许明确共现
  ├── counterexample 证明某些线索不足以支持目标义项
  ├── boundary       测试临界、包含和用词偏好
  └── transfer       跨至少两个表面维度验证泛化
              ↓
reviewed / published resource bundle
              ↓
词典 · 课程 · 播放器 · API · 学习实验 · 研究工具
```

五类场景是五种教学证据功能，不是永远固定为“一类一条”的产品限制。当前起草工具仍生成完整五类场景组，便于 MVP 比较；未来发布门应按证据覆盖与实验结果决定所需数量。

## 权威边界

- `schema/word-sense.schema.json`：词义、概念关系、来源与版本契约。
- `schema/scene-spec.schema.json`：模型无关的场景与学习任务契约。
- `schema/resource-bundle.schema.json`：给外部消费者的资源包契约。
- `data/senses/`、`data/scenes/`：已审核资源，是仓库语义权威。
- `data/drafts/`：待审内容，绝不进入默认导出。
- `prompts/`：起草辅助，不是权威数据。
- `examples/consumer/`：消费者侧示例，不属于 SceneLex 核心身份或学习记录模型。

渲染模型、TTS、图片、视频、HTTP 服务和学习者数据都在适配器或消费者侧。它们可以引用稳定的 `sense_id`、`scene_id` 和资源版本，但不能反过来改变核心词义。

## 目录结构

```text
schema/                      核心公开数据契约
data/senses/                 正式词义资源
data/scenes/{sense_id}/      正式场景证据
data/drafts/                 隔离草稿
prompts/                     LLM 起草模板
tools/draft.py               起草与发布前编排
tools/llm.py                 多协议 LLM 适配器
tools/validate.py            正式库发布门
tools/export.py              面向消费者的确定性 JSON 导出
examples/consumer/           非权威消费者示例
tests/                       工具链回归测试
```

## 内容工作流

```text
candidate
→ sense draft
→ 人工语义审核
→ scene evidence draft
→ 语言 / 场景 / 教学审核
→ 隔离目录全量校验
→ reviewed resource
→ 学习实验与外部反馈
→ published resource bundle
```

常用命令：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt

python3 tools/draft.py backlog
python3 tools/draft.py sense dirty
python3 tools/draft.py scenes dirty-01
python3 tools/draft.py scenes dirty-01 --add prototype   # 增补一个新表面的场景
python3 tools/draft.py list
python3 tools/draft.py promote dirty-01

python3 tools/validate.py --backlog
python3 tools/export.py --version 0.1.0 --output dist/scenelex-0.1.0.json
python3 -m pytest -q
```

`promote` 会先把候选资源与整个正式库合并到隔离目录中，通过全量校验后再原子移动；不会再出现“先污染正式库、后发现校验失败”。默认导出包含 `reviewed` 与 `published`，发布消费者可使用 `--published-only`。

## LLM API：按协议兼容，不绑定厂商

所有生成调用只依赖 `tools.llm.generate(prompt)`。模型名、API Key、URL、认证头和协议只存在于适配层，不进入 Schema 或正式资源。

支持的协议：

| `SCENELEX_LLM_PROTOCOL` | 协议 | 典型用途 |
|---|---|---|
| `openai-responses` | Responses 风格 | OpenAI 或实现该格式的网关 |
| `openai-chat` | Chat Completions 风格 | OpenAI-compatible 厂商、网关、本地服务；Gemini 兼容入口也可使用 |
| `anthropic` | Messages 风格 | Anthropic 或兼容代理 |
| `command` | stdin/stdout | 任意本地 CLI |

OpenAI Responses 示例：

```bash
export SCENELEX_LLM_PROTOCOL=openai-responses
export SCENELEX_LLM_MODEL=<model-id>
export SCENELEX_LLM_API_KEY=<api-key>
export SCENELEX_LLM_BASE_URL=https://api.openai.com/v1
```

任意 OpenAI-compatible Chat Completions 示例：

```bash
export SCENELEX_LLM_PROTOCOL=openai-chat
export SCENELEX_LLM_MODEL=<model-id>
export SCENELEX_LLM_API_KEY=<api-key>
export SCENELEX_LLM_BASE_URL=<compatible-v1-base-url>
```

Anthropic Messages 示例：

```bash
export SCENELEX_LLM_PROTOCOL=anthropic
export SCENELEX_LLM_MODEL=<model-id>
export SCENELEX_LLM_API_KEY=<api-key>
export SCENELEX_LLM_BASE_URL=https://api.anthropic.com/v1
```

DeepSeek 示例（OpenAI-compatible Chat Completions）：

```bash
export SCENELEX_LLM_PROTOCOL=openai-chat
export SCENELEX_LLM_BASE_URL=https://api.deepseek.com
export SCENELEX_LLM_API_KEY=<your-deepseek-api-key>
export SCENELEX_LLM_MODEL=deepseek-v4-pro
```

> `SCENELEX_LLM_BASE_URL` 填 `https://api.deepseek.com` 即可（不要 `/v1`），适配器会自动拼接 `/chat/completions`。模型名可选 `deepseek-v4-pro`、`deepseek-v4-flash`。

特殊网关可以使用：

- `SCENELEX_LLM_ENDPOINT`：覆盖完整请求地址；
- `SCENELEX_LLM_API_KEY_HEADER`：修改认证头名；
- `SCENELEX_LLM_AUTH_SCHEME`：修改或清空 `Bearer` 前缀；
- `SCENELEX_LLM_HEADERS_JSON`：增加字符串类型的自定义请求头；
- `SCENELEX_LLM_MAX_TOKENS`、`SCENELEX_LLM_TIMEOUT`：控制输出和超时；
- `SCENELEX_LLM_STREAM`：`openai-chat` 默认走流式（SSE），长生成不会被网关的
  空闲超时掐断；设为 `0` 可回退到非流式（仅适合短输出或不支持流式的网关）；
- `SCENELEX_LLM_COMMAND`：配置本地命令。

`command` 中可使用 `{model}` 占位符，例如
`SCENELEX_LLM_COMMAND='my-llm --model {model} --print'`。适配器不会假设任意 CLI
都支持 `--model`，完整参数由调用者控制。

不配置协议时工具会明确报错，不会静默选择某个厂商。供应商特有的工具调用、缓存、推理参数等高级能力应放在新的协议适配器中，不能污染资源契约。

协议实现参考官方文档：[OpenAI Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create)、[Anthropic Messages API](https://platform.claude.com/docs/en/api/messages)、[Gemini 的 OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)。兼容层只承诺当前内容起草所需的单轮文本生成；多模态、工具调用和厂商特有能力需要单独的能力测试。

## 当前状态与近期路线

- 正式义项 3 条：`messy-01`、`reluctant-01`、`almost-01`。
- 正式场景 10 条；前两个义项有完整五类证据，`almost-01` 待建。
- `dirty-01` 及其五类场景位于草稿区。
- 当前正式资源状态为 `reviewed`，尚未宣称 `published`。

近期不以扩到 30–50 个义项为第一目标。先选择 6–10 个高价值义项做薄而完整的实验闭环：

```text
资源规格 → 低成本渲染 → 可评分任务
→ 翻译/普通图片/场景证据对照
→ 即时理解、相邻词区分、迁移和延迟保持
→ 修订资源 → 再扩库
```

规模化的前提不是“Schema 能通过”，而是资源在新场景中确实产生了可复现的学习迁移。
