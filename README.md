# SceneLex

> 经验即词义，微世界即体验。

SceneLex 是一个**语义教学引擎 (Semantic Teaching Engine)**。语言是对经验的符号化编码，词义是人类对经验范畴化后的结果。SceneLex 放弃用苍白的形式化语言描述词义，而是利用大语言模型（LLM）作为**语义编译器**，结合词汇的经验分类与学习者状态，将词义即时编译为可体验的**微世界 (Micro-world)** 呈现给学习者。

SceneLex 的核心资产不仅是孤立的素材，而是基于经验模型的词义语义资源与教学证据库。它为每一个可教学词义建立机器可验证的语义规格，并用原型、对比、反例、边界和迁移场景提供可观察的微世界实例。

SceneLex 不是某个学习 App 的内部素材目录，也不由某个词典或模型厂商定义；学习产品是这些微世界与语义资源的消费者。

理论全文见 [一、先明确系统最终要解决什么问题.md](一、先明确系统最终要解决什么问题.md)。仓库约束见 [AGENT.md](AGENT.md)。
跨层统一术语与 Gate 含义见 [CONTEXT.md](CONTEXT.md)。
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

## 系统架构：语义编译引擎

```text
词汇 + 词汇类别 + 学习者状态
         ↓
    LLM（语义编译器）
         ↓
   微世界构建指令
         ↓
    渲染/呈现引擎
```

SceneLex 采用上述核心三层解耦架构：
1. **抽象层**：经验的范畴化（词义）。
2. **语义层**：经验的具体实例（场景 / 微世界）。
3. **呈现层**：场景的载体（多媒体）。

系统根据 10 种核心经验分类（如实体型、动作型、意图与行为型等），采用不同的编译策略，将语义转化为合适的微世界形态，不再局限于单一的视频管线。

### 分阶段演进

```text
阶段 1（当前）：经验叙事（纯文本，LLM 编译）
阶段 2：富媒体增强（叙事 + 配图 + 音频）
阶段 3：交互微世界（3D / 模拟 / 叙事引擎）
```

当前处于阶段 1：LLM 将 WordSense + SceneSpec 编译为学习者可体验的经验叙事，以卡片式学习单元嵌入背单词软件。每个学习单元包含：经验溯源、5 个场景叙事（原型/对比/反例/边界/迁移）、L1 经验对比和自测题。原型验证见 [`prototype/reluctant-demo.html`](prototype/reluctant-demo.html)。

## Legacy：视频管线（从语义到视频）

> **Legacy Note**: 随着理论转向“语义教学引擎”和通用微世界架构，以下基于 Shot Plan / Keyframe 的固定视频生产管线已降级为特定类型的微世界（视频类）的一种具体实现细节。原有 SceneSpec 作为语义层基础设施依然有效。

```text
Dictionary Evidence
→ Approved Sense Inventory
→ Inventory-driven WordSense
→ SceneSpec
→ Shot Plan
→ Keyframe Plan
→ Animatic Review
→ Image Keyframe Generation
→ Source Packet / Visual Compiler / Render Directive
→ Human Image Semantic Gate
→ Motion Directive / AI Motion Segments
→ Human Video Semantic Gate
→ Edit / Audio / Final Video
```

```text
Beat = semantic unit         观众必须看见的事件, 及其在词义证明中的作用
Shot = video execution unit  一次连续摄像机观察和连续运动
```

`SceneSpec.storyboard` 的 beat 与 Shot **不是一一对应**：动作连续时多个 beat 可以
合并成一个镜头，一个 beat 也可以拆成 establishing 与 reaction 两个镜头。硬要求只有
覆盖（每个 beat 至少被一个镜头引用）与时间顺序。

**Shot Plan 是 Scene 之后唯一的叙事执行权威**（`schema/shot-plan.schema.json`）。它
决定镜头拆分、顺序、画面状态变化、构图、摄影机行为、时长、语义证据、连续性与最小
音频意图；它**不**决定视觉风格、具体模型、最终提示词、workflow、关键帧文件、seed
或最终剪辑。后续图像与视频模型只执行 Shot Plan，不再自行重新拆分 Scene。

```bash
python3 tools/director.py plan reluctant-01-proto-01   # Scene + WordSense → Shot Plan
python3 tools/director.py show reluctant-01-proto-01   # 面向人工审核的展开
python3 tools/director.py list                         # Shot Plan 版本一览
```

Shot Plan 只能从语义修订状态为 `CURRENT` 的 SceneSpec 1.1 编译；身份字段由程序写入，
模型写错即 `shot plan identity drift` 并失败。产物落在
`data/drafts/shot-plans/{scene_id}/v{NN}/shot-plan.yaml`，永不覆盖。权威说明见
[docs/production-workflow.md](docs/production-workflow.md)。

## Legacy：Keyframe Plan 与 Animatic

Shot Plan 的下游是 **Keyframe Plan**（`schema/keyframe-plan.schema.json`）：在已定好的
镜头里，选出并描述那些**缺了它观众的语义推断就会改变**的画面状态，并给出它们在镜头
内的时间位置。它不重新导演场景（镜头数量、顺序、时长仍由 Shot Plan 决定），也不写
风格、模型、seed 或图片路径。

```bash
python3 tools/keyframes.py validate reluctant-01-proto-01
python3 tools/keyframes.py show     reluctant-01-proto-01
python3 tools/keyframes.py animatic reluctant-01-proto-01   # 时间轴 + 单文件 HTML 预览
```

`shot_plan_ref` 必须显式写明 Shot Plan 版本；产物落在
`data/drafts/keyframe-plans/{scene_id}/v{NN}/`，永不覆盖。`animatic` 不调用任何模型。

```text
Keyframe Plan     = 选择和描述必要视觉状态
Animatic          = 审核顺序、时长、状态覆盖和镜头边界
Image generation  = 把已批准的视觉状态画出来
Video generation  = 在已批准状态之间生成运动
```

**文字占位卡不是视觉审核。** Animatic 能审时序、状态覆盖、hold 时长、镜头边界与动作
密度，不能审构图可读性、表情质量与真实画面语义。第一条真实审核记录见
[docs/vertical-slices/reluctant-01-keyframe-animatic.md](docs/vertical-slices/reluctant-01-keyframe-animatic.md)。

渲染层的全局视觉方向（当前为 `Pixar-style 3D animated film`）只存在于
`prompts/render-style.yaml` 与渲染适配层；WordSense、SceneSpec、Shot Plan 与 Keyframe
state identity 都保持风格无关。它是渲染层的默认值，不是语义主链的一部分。

**Legacy（保留但不再是新主线）**：`schema/director-prompt.schema.json` +
`prompts/director.md` 是旧的模型提示词原型；`schema/render-plan.schema.json` +
`tools/render.py plan` 是旧的 beat-image 渲染原型（运行时打印一次 legacy warning，
不影响退出码）。历史文件继续保留，不做自动迁移——新的 Keyframe Plan 只读 Shot Plan，
既不读也不修改这两个 legacy 层。

## 目录结构

```text
schema/                      公开语义契约 + Shot Plan 执行契约 + 渲染层原型契约
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
tools/director.py            语义节拍 → 可执行 Shot Plan (plan / show / list)
tools/shot_plan.py           Shot Plan 身份、Beat→Shot 映射与时长/连续性校验
tools/render.py              legacy beat-image 渲染原型 (plan / show / render)
tools/llm.py                 多协议 LLM 适配器
tools/revisions.py           Scene → WordSense 语义修订绑定与状态判定
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
python3 tools/draft.py promote dirty-01 --replace        # 覆盖同名已发布资源 (全量校验照跑)
python3 tools/director.py plan reluctant-01-proto-01     # 场景语义节拍 → Shot Plan
python3 tools/director.py show reluctant-01-proto-01     # 查看最新 Shot Plan
python3 tools/director.py list                           # Shot Plan 版本一览
python3 tools/render.py plan reluctant-01-proto-01       # legacy: beat 级渲染计划
python3 tools/render.py show reluctant-01-proto-01       # 预览展开后的图像提示词与音频指令
python3 tools/render.py render reluctant-01-proto-01     # 经 ComfyUI 渲染图像候选 + manifest
python3 tools/render.py render reluctant-01-proto-01 -b 3 -n 2   # 只补渲 beat 3, 出 2 张候选
python3 tools/workbench.py                               # 审核工作台 http://127.0.0.1:8321

python3 tools/validate.py --backlog
python3 tools/validate.py --scene-revisions              # 场景语义修订状态
python3 tools/export.py --version 0.1.0 --output dist/scenelex-0.1.0.json
python3 -m pytest -q
```

已弃用的命令：

```bash
python3 tools/draft.py sense slow --num 02      # 已弃用: 词典条目不是 SceneLex sense
python3 tools/director.py generate <scene_id>   # 已弃用: plan 的兼容别名
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
| `1.1` | 由已批准 Inventory 驱动生成；**必须**包含 `inventory`、`semantic_identity`、`inventory_source_entries`、`semantic_revision` |

新起草的义项一律是 `1.1`。`inventory.identity_digest` 是对 Inventory 中该 sense
的锁定身份（`id` / `lemma` / `pos` / `semantic_signature` 五个字段）计算的
SHA-256，使用 canonical JSON（`sort_keys`、稳定分隔符、UTF-8），前缀 `sha256:`。
`definition`、`label_zh` 和自由文本理由**不进入**摘要——文字润色不应让已生成的
义项集体失效。

## 语义修订：Scene 如何绑定 WordSense

数据链是：

```text
Dictionary Evidence → Approved Sense Inventory → WordSense → Scene
```

WordSense 有两个互不替代的版本概念：

| 字段 | 含义 | 什么时候递增 |
|---|---|---|
| `version` | 资源文件自身的普通修订 | 措辞、拼写、格式、补充解释、`status` 变化、prompt 或生成元数据变化 |
| `semantic_revision` | 语义契约修订 | 语义身份、成立条件、边界、causativity、valency、参与者角色、视觉证据要求发生实质变化，或义项被拆分/合并/重新定义 |

Scene 用两个字段记录自己的依赖：

- `sense_ref`：稳定的 WordSense ID；
- `sense_revision`：**起草时**所依据的 `semantic_revision`。

Scene 只绑定 `semantic_revision`。普通 `version` 变化、状态变化和文字润色都不会
让已有 Scene 失效——那些修改不改变"这些画面还能不能证明这个义项"。

`semantic_revision` 由人工维护：新起草的 inventory-driven WordSense 一律写入
`semantic_revision: 1`（由程序写，模型写错即判为 identity drift 并失败），之后的
语义变化由开发者在改 WordSense 时自己 bump。本项目**不**用内容摘要、diff 或 LLM
去自动判断"这次改动算不算语义修改"。

### 修订状态检查

```bash
python3 tools/validate.py --scene-revisions              # 全库
python3 tools/validate.py --scene-revisions reluctant-01 # 只看一个义项
```

| 状态 | 含义 |
|---|---|
| `CURRENT` | `sense_revision` 等于当前 `semantic_revision` |
| `NEEDS_REVIEW` | 词义语义契约已更新，本 Scene 基于旧修订生成，需要重新审核 |
| `LEGACY` | SceneSpec 1.0 的旧场景，尚未绑定语义修订 |
| `INVALID` | 修订超前、非法，或 1.1 Scene 缺绑定 / 引用了 1.0 义项 |
| `MISSING` | `sense_ref` 指向的 WordSense 不存在 |

状态不写进 Scene 文件（没有 `stale:` 或 `needs_review:` 字段），每次都由当前两个
数字动态比较得出。规则：

- `NEEDS_REVIEW` 目前只是 **warning**：普通 `validate` 照常成功、退出码 0，语义
  修订不该临时卡住视频生产主线；`--scene-revisions` 也不因它失败；
- `INVALID` 和 `MISSING` 是**错误**，`validate` 与 `--scene-revisions` 均退出非零；
- 处理 `NEEDS_REVIEW` 的正确做法是重新生成 Scene，或人工确认原有视觉证据在新语义
  契约下仍然成立——**不要只把 `sense_revision` 的数字改大**。因此工具链里没有、
  也不会有"一键刷新 revision"的命令；
- SceneSpec 1.0 的历史场景继续兼容，不做批量迁移；新 Scene 只能从 WordSense 1.1
  起草，起草前若义项是 1.0 或缺 `semantic_revision`，在调用模型之前就失败。

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

系统目前正经历重大的底层架构与理论升级：从基于固定视频工作流的“场景即释义”资源库，演进为基于 LLM 和经验分类的**语义教学引擎**和多模态**微世界**架构。

- 原有的 WordSense、SceneSpec、五类场景证据系统作为坚实的语义层基础设施，依然有效且被保留。
- 基于 Shot / Keyframe / Video 的旧生产管线（Phase 1.4）被降级为“视频类”微世界的实现细节。
- 10 种经验分类（实体型、动作型、状态变化型、空间与关系型、心理状态型、意图与行为型、事件逻辑型、时间结构型、认知与话语型等）被确立为语义编译的核心策略依据。

近期路线：
1. 实现并验证基于 LLM 语义编译器的多模态微世界生成。
2. 针对 10 种核心经验分类，分别研发并实装独立的编译策略和呈现模式。
3. 构建全新的微世界渲染引擎，支持视频之外的交互式、图文、动态媒体等多元展现。
