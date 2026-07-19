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
- `schema/sense-inventory.schema.json`：整词级 Sense Inventory 契约。Wiktionary
  条目是 dictionary evidence，不是 SceneLex sense。
- `data/senses/`、`data/scenes/`：已审核资源，是仓库语义权威。
- `data/inventories/{word}.yaml`：**已批准的 Sense Inventory，是新建 WordSense 的
  唯一身份权威**——sense ID 权威、POS 权威、语义身份（semantic_signature）权威、
  dictionary source mapping 权威。只能由 `tools/inventory.py approve` 写入。
- `data/dictionary-evidence/{word}.yaml`：与已批准 Inventory 配套冻结的词典证据
  快照。entry ID 的含义由它固定，Wiktionary 之后的变化不会静默改写既有引用。
- `data/drafts/`：待审内容，绝不进入默认导出（含 `inventories/` 待审 Sense Inventory 草稿）。
- `prompts/`：起草辅助，不是权威数据。
- `examples/consumer/`：消费者侧示例，不属于 SceneLex 核心身份或学习记录模型。

渲染模型、TTS、图片、视频、HTTP 服务和学习者数据都在适配器或消费者侧。它们可以引用稳定的 `sense_id`、`scene_id` 和资源版本，但不能反过来改变核心词义。

`storyboard` 是语义节拍，不要求与视频 clip 一一对应。进入渲染前，Director Agent
理解词义证据和相邻概念边界，再根据当前视频能力把场景翻译为可直接提交的高质量
提示词；clip 数量由语义场景与 Director 决定。生产默认工序是关键图先行：先文生图
并通过图片语义门，再图生视频；尾帧、animatic 等更多控制是按需工具。权威说明见
[docs/production-workflow.md](docs/production-workflow.md)。

当前渲染层统一使用`Pixar-style 3D animated film`作为全局视觉方向。该风格只进入Director
Prompt和渲染配置；WordSense与SceneSpec保持风格无关，现有词义场景内容不由Director改写。

## 目录结构

```text
schema/                      公开语义契约 + 渲染层内部原型契约
data/senses/                 正式词义资源
data/scenes/{sense_id}/      正式场景证据
data/inventories/            已批准 Sense Inventory (整词级 sense 身份权威)
data/dictionary-evidence/    与已批准 Inventory 配套的冻结词典证据快照
data/drafts/                 隔离草稿 (含 inventories/ 待审 Inventory、renders/{scene_id}/v{NN}/ 渲染版本)
prompts/                     LLM 起草/审核/渲染计划模板与风格配置
docs/                       生产工作流、技术选型与归档评估
tools/inventory.py           整词 Sense Inventory: draft / validate / mark-reviewed / approve / show
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
→ dictionary evidence snapshot
→ inventory draft
→ inventory review
→ inventory approve
→ inventory-driven WordSense draft
→ WordSense validation
→ scene evidence draft
→ 模型审核（可选质量参考, 不阻塞）
→ 隔离目录全量校验 + 人工 promote
→ reviewed resource
→ 渲染与消费端反馈
→ published resource bundle
```

Wiktionary 条目先被当作 `dictionary evidence`，由 `tools/inventory.py draft`
一次性规划整个词，决定哪些意义合并、哪些推迟、哪些拆分，再统一分配
`{word}-01`、`{word}-02` 等 sense ID。人工审阅后 `mark-reviewed`，再 `approve`
写入 `data/inventories/{word}.yaml`。

**只有已批准的 Sense Inventory 能驱动新的 WordSense 起草。** `tools/draft.py sense`
接收的是 SceneLex sense ID（不是词典条目序号）：它读取整个 Inventory，把其中
已冻结的那一条 CURRENT_SENSE 详细化，同时注入全部 ALL_SENSES 以便正确描述边界。
身份字段的处理分两种情况，程序**不会**静默替模型圆场：

- 模型**没写**的机器字段（`schema_version`、`inventory.*` 等簿记信息）由程序按
  Inventory 补全；
- 模型**写了但与 Inventory 冲突**的身份字段（`id`、lemma、`pos`、
  `semantic_identity.*`、`inventory_source_entries`）判定为 **identity drift**：
  本次起草失败、逐项打印 expected / actual、原始输出存到
  `data/drafts/senses/_invalid-{sense_id}-identity-drift.yaml`，已有合法草稿不受影响。

这条区分很重要：模型如果把 `slow-02` 当成及物致使义来写，光把 `valency` 改回
`intransitive` 并不能挽救正文——整篇语义骨架、条件和边界都是按错误义项写的。
与其产出一份"字段正确、内容跑偏"的草稿，不如直接失败。

生成结果携带 Inventory provenance，事后人工改动会被 `tools/validate.py` 抓出。

状态流转：

```text
draft → reviewed → approved
```

常用命令：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt

python3 tools/inventory.py draft slow                    # 起草整词 Sense Inventory
python3 tools/inventory.py validate slow                 # 校验 (draft 优先, 否则正式库)
python3 tools/inventory.py mark-reviewed slow            # 人工审阅通过 → status: reviewed
python3 tools/inventory.py approve slow                  # → data/inventories/slow.yaml
python3 tools/inventory.py show slow                     # 查看原始内容, 不修改文件

python3 tools/draft.py sense slow-02                     # 按已批准 Inventory 起草单个词义
python3 tools/draft.py senses slow                       # 起草该词全部已批准 sense
python3 tools/draft.py senses slow --workers 3           # 并发起草

python3 tools/draft.py backlog
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

已弃用的命令：

```bash
python3 tools/draft.py sense slow --num 02      # 已弃用: 词典条目不是 SceneLex sense
```

按 Wiktionary 条目序号起草会让同一个 `{word}-nn` 编号在不同批次里指向不同意义。
该路径默认直接失败并提示新工作流；确需临时复现历史实验时可加
`--legacy-dictionary-index`，产物写入 `data/drafts/legacy-senses/`，不进入正常
草稿区，也不可 promote。`tools/draft.py batch` 同样改为按已批准 Inventory 枚举，
不再按词典义项数生成 sense ID。

`promote` 会先把候选资源与整个正式库合并到隔离目录中，通过全量校验后再原子移动；不会再出现“先污染正式库、后发现校验失败”。默认导出包含 `reviewed` 与 `published`，发布消费者可使用 `--published-only`。

## WordSense schema 版本

| 版本 | 含义 |
|---|---|
| `1.0` | Inventory 层出现之前的历史资源；不要求 Inventory provenance，继续通过校验 |
| `1.1` | 由已批准 Inventory 驱动生成；**必须**包含 `inventory`、`semantic_identity`、`inventory_source_entries` |

新起草的义项一律是 `1.1`。`inventory.identity_digest` 是对 Inventory 中该 sense
的锁定身份（`id` / `lemma` / `pos` / `semantic_signature` 五个字段）计算的
SHA-256，使用 canonical JSON（`sort_keys`、稳定分隔符、UTF-8），前缀 `sha256:`。
`definition`、`label_zh` 和自由文本理由**不进入**摘要——文字润色不应让已生成的
义项集体失效。

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
- 整词级 Sense Inventory 已打通 draft → reviewed → approved 全流程；
  `data/inventories/` 与 `data/dictionary-evidence/` 是批准后的权威目录。
- WordSense 起草已改为 inventory-driven：`tools/draft.py sense <sense_id>` 与
  `senses <word>` 只接受已批准 Inventory 中的 sense，旧的 `--num` 词典序号路径
  已弃用。

“场景即释义”方法已确立为产品前提，学习实验不再是规模化的前置条件。近期路线：

```text
Director 中间层（语义场景 → 当前视频能力的高质量提示词）
→ 本地 ComfyUI 或云端视频模型快速生成、查看与修正
→ 模型审核（可选质量参考，工作台一键运行）
→ 批量扩产（candidates 队列 + batch 起草）
→ 资源包导出与最小消费端 demo
```
