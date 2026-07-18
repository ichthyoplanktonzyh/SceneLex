# SceneLex

> 可验证的词义边界 + 能证明学习迁移的场景证据。

SceneLex 是一套可独立发布、版本化和复用的**词义语义资源与教学证据库**。它为每个可教学词义建立机器可验证的语义规格，并用原型、对比、反例、边界和迁移场景提供可观察证据。

SceneLex 不是某个学习 App 的内部素材目录，也不由某个词典、播放器、课程或模型厂商定义。“场景即释义”是本产品已确立的核心方法与卖点，不是待验证的研究假设；学习产品是资源消费者之一。

理论全文见 [一、先明确系统最终要解决什么问题.md](一、先明确系统最终要解决什么问题.md)。仓库约束见 [AGENT.md](AGENT.md)。
历史效果评估方案（已归档，非发布前提）见 [docs/mvp-evaluation.md](docs/mvp-evaluation.md)。

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

五类场景是五种教学证据功能，不是永远固定为“一类一条”的产品限制。当前起草工具默认生成完整五类场景组；发布门按证据覆盖决定所需数量。

## 权威边界

- `schema/word-sense.schema.json`：词义、概念关系、来源与版本契约。
- `schema/scene-spec.schema.json`：模型无关的场景与学习任务契约。
- `schema/resource-bundle.schema.json`：给外部消费者的资源包契约。
- `data/senses/`、`data/scenes/`：已审核资源，是仓库语义权威。
- `data/drafts/`：待审内容，绝不进入默认导出。
- `prompts/`：起草辅助，不是权威数据。
- `examples/consumer/`：消费者侧示例，不属于 SceneLex 核心身份或学习记录模型。

渲染模型、TTS、图片、视频、HTTP 服务和学习者数据都在适配器或消费者侧。它们可以引用稳定的 `sense_id`、`scene_id` 和资源版本，但不能反过来改变核心词义。

`storyboard` 是语义节拍，不要求与视频 clip 一一对应。进入渲染前，Director Agent
理解词义证据和相邻概念边界，再根据当前视频能力把场景翻译为一个或少量可直接提交的
高质量提示词。参考图、首尾帧、拆片和 animatic 都是按需工具，不是固定流程。权威说明见
[docs/production-workflow.md](docs/production-workflow.md)。

当前渲染层统一使用`Pixar-style 3D animated film`作为全局视觉方向。该风格只进入Director
Prompt和渲染配置；WordSense与SceneSpec保持风格无关，现有词义场景内容不由Director改写。

## 目录结构

```text
schema/                      公开语义契约 + 渲染层内部原型契约
data/senses/                 正式词义资源
data/scenes/{sense_id}/      正式场景证据
data/drafts/                 隔离草稿 (含 renders/{scene_id}/v{NN}/ 渲染版本)
prompts/                     LLM 起草/审核/渲染计划模板与风格配置
docs/                       生产工作流、技术选型与归档评估
tools/draft.py               起草与发布前编排
tools/review.py              模型审核 (可选质量参考)
tools/director.py            语义场景 → 模型适配的视频提示词
tools/render.py              渲染层编排 (plan / show / render / assemble)
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
→ scene evidence draft
→ 模型审核（可选质量参考, 不阻塞）
→ 隔离目录全量校验 + 人工 promote
→ reviewed resource
→ 渲染与消费端反馈
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
python3 tools/candidates.py --count 20                   # 扩产候选队列 (悬空引用+词频)
python3 tools/dictionary.py nearly                       # Wiktionary 词典事实 (起草锚点)
python3 tools/draft.py batch --count 4                   # 批量起草, 断点可续
python3 tools/draft.py list
python3 tools/review.py dirty-01                         # 模型审核 (可选参考, 写审核记录)
python3 tools/review.py --all                            # 审核草稿区全部义项
python3 tools/draft.py promote dirty-01                  # 隔离校验后原子入库; 审核可选不阻塞
python3 tools/director.py generate reluctant-01-proto-01 # 场景 → 通用视频模型提示词
python3 tools/director.py generate reluctant-01-proto-01 --profile wan2.2-ti2v-5b
python3 tools/director.py show reluctant-01-proto-01     # 查看最新视频提示词
python3 tools/render.py plan reluctant-01-proto-01       # 场景规格 → 渲染计划 (新版本目录)
python3 tools/render.py show reluctant-01-proto-01       # 预览展开后的图像提示词与音频指令
python3 tools/render.py render reluctant-01-proto-01     # 经 ComfyUI 渲染图像候选 + manifest
python3 tools/render.py render reluctant-01-proto-01 -b 3 -n 2   # 只补渲 beat 3, 出 2 张候选
python3 tools/workbench.py                               # 审核工作台 http://127.0.0.1:8321

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

模型审核（`tools/review.py`，可选质量参考）可用 `SCENELEX_REVIEW_LLM_*` 前缀
单独配置审核模型（逐项覆盖同名 `SCENELEX_LLM_*` 配置）。建议审核模型与起草
模型不同，避免模型自我确认；未配置时回退到起草模型并给出警告。

图像渲染（`tools/imagegen.py`，comfyui 协议）：`SCENELEX_IMG_ENDPOINT`（默认
`http://127.0.0.1:8188`）、`SCENELEX_IMG_WORKFLOW`（工作流 API JSON，默认
`tools/workflows/comfyui-text2image.json`）、`SCENELEX_IMG_TIMEOUT`、
`SCENELEX_IMG_LICENSE`。适配器跟随采样器连线自动定位提示词节点，特殊工作流
用 `SCENELEX_IMG_SAMPLER_NODE` 等显式指定。

`command` 中可使用 `{model}` 占位符，例如
`SCENELEX_LLM_COMMAND='my-llm --model {model} --print'`。适配器不会假设任意 CLI
都支持 `--model`，完整参数由调用者控制。

不配置协议时工具会明确报错，不会静默选择某个厂商。供应商特有的工具调用、缓存、推理参数等高级能力应放在新的协议适配器中，不能污染资源契约。

协议实现参考官方文档：[OpenAI Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create)、[Anthropic Messages API](https://platform.claude.com/docs/en/api/messages)、[Gemini 的 OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai)。兼容层只承诺当前内容起草所需的单轮文本生成；多模态、工具调用和厂商特有能力需要单独的能力测试。

## 当前状态与近期路线

- 正式义项 4 条：`messy-01`、`reluctant-01`、`almost-01`、`dirty-01`，共 21 个场景。
- 草稿区 6 个义项（filthy / nearly / barely / refuse / grimy / hesitant）及其场景组待审。
- 当前正式资源状态为 `reviewed`，尚未宣称 `published`。

“场景即释义”方法已确立为产品前提，学习实验不再是规模化的前置条件。近期路线：

```text
Director 中间层（语义场景 → 当前视频能力的高质量提示词）
→ 本地 ComfyUI 或云端视频模型快速生成、查看与修正
→ 模型审核（可选质量参考，工作台一键运行）
→ 批量扩产（candidates 队列 + batch 起草）
→ 资源包导出与最小消费端 demo
```
