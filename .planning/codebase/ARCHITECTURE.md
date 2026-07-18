# SceneLex — 架构骨架

> 最后更新：2026-07-18
> 帮助新会话快速建立对系统结构、数据流和边界的全局理解
> 2026-07 新增：渲染管线（场景 → 皮克斯短视频）作为适配器层落地，见「渲染管线」节

## 系统身份

SceneLex 是一个**资源生产系统**，不是一个学习应用。它的核心产出是版本化的语义资源，学习产品只是消费者之一。

```text
SceneLex (资源生产)
  ├── 词义建模（语义骨架、条件、关系）
  ├── 场景证据设计（原型/对比/反例/边界/迁移）
  ├── LLM 辅助起草（多协议适配器）
  ├── 三级审核门（结构校验 → 专家审核 → 学习实验）
  └── 确定性导出（resource-bundle JSON）

Consumer (外部)
  ├── 词典产品
  ├── 课程系统
  ├── 播放器
  ├── API 服务
  ├── 学习实验
  └── 研究工具
```

## 内容生产管线

```text
candidate word/context
        ↓
sense draft (LLM → tools/draft.py)
        ↓
人工语义审核
        ↓
reviewed sense (data/senses/)
        ↓
scene evidence draft (LLM → tools/draft.py)
        ↓
语言 / 场景 / 教学审核
        ↓
隔离目录全量校验 (tools/validate.py)
        ↓
reviewed scenes (data/scenes/{sense_id}/)
        ↓
学习实验验证
        ↓
published resource bundle (tools/export.py)
```

## 目录与职责

```text
SceneLex/
├── schema/                     ← 机器可验证的公开数据契约（先改 schema，再改依赖方）
│   ├── word-sense.schema.json     词义对象契约
│   ├── scene-spec.schema.json     场景规格契约
│   └── resource-bundle.schema.json 消费者资源包契约
│
├── data/
│   ├── senses/                 ← 已审核正式义项（权威数据）
│   │   └── {sense_id}.yaml
│   ├── scenes/{sense_id}/      ← 已审核正式场景（权威数据）
│   │   └── {sense_id}-{type}-{nn}.yaml
│   └── drafts/                 ← 隔离草稿区（绝不进入默认导出）
│       ├── senses/
│       └── scenes/
│
├── prompts/                    ← LLM 起草模板（辅助，非权威）
│   ├── sense-draft.md
│   └── scene-draft.md
│
├── tools/                      ← 工具链
│   ├── draft.py                ← 起草与发布前编排
│   ├── llm.py                  ← 多协议 LLM 适配器
│   ├── validate.py             ← 正式库发布门校验
│   └── export.py               ← 确定性消费端 JSON 导出
│
├── tests/                      ← 回归测试
│   ├── test_draft.py
│   ├── test_llm.py
│   ├── test_validate.py
│   └── test_export.py
│
├── examples/consumer/          ← 消费者示例（非核心身份）
├── docs/mvp-evaluation.md      ← 实验方案
│
├── AGENT.md                    ← 仓库工作约束（权威行为规则）
├── README.md                   ← 项目对外门面
└── 一、先明确系统最终要解决什么问题.md  ← 理论全文
```

## 关键边界

### 资源 vs 消费者

| 属于 SceneLex | 属于消费者 |
|---|---|
| 义项 ID、语义骨架、边界条件 | 学习者身份与学习记录 |
| 场景分镜、教学证据、学习任务 | UI 布局、播放器控制 |
| 资源版本、审核结论 | 个性化渲染参数 |
| 导出 JSON 的 Schema | HTTP 路由、数据库 Schema |

### LLM 适配层边界

- `tools/llm.py` 是唯一的 LLM 调用入口。
- 模型名、API Key、URL 和认证通过环境变量配置。
- 支持四种协议：`openai-responses`、`openai-chat`、`anthropic`、`command`。
- 正式资源（`data/senses/`、`data/scenes/`）绝不包含厂商名、模型名或请求参数。

### 渲染边界

- 正式**语义资源**（`schema/`、`data/senses`、`data/scenes`）保持模型无关，绝不含厂商/模型名。
- 图片、动画、视频、TTS 都是可替换渲染后端的产物；渲染产物落 `data/drafts/renders/`，不污染正式库。
- 渲染器是**适配器层**：虽在本仓库内实现，但与语义层严格解耦，换模型不动语义资源。

## 渲染管线（适配器层，2026-07 起）

把场景规格渲染成**皮克斯 3D 风短视频（~20-25s）**。五级、模型无关、本地(M1/ComfyUI)先跑通：

```text
场景规格 + 语义骨架 + skills
  → [0] 导演 Agent    渲染计划 IR（角色卡 + 每beat{关键帧提示词, 运动提示词, negative, 音频, 时长}）
  → [1] 角色设定稿    皮克斯风参考图（一致性锚点）
  → [2] 逐beat关键帧  一致皮克斯静图（Disney SDXL + IPAdapter PLUS）
  → [3] 逐beat i2v    ~5s 会动视频（Wan2.2 TI2V-5B）
  → [4] 拼接+音频     成片（ffmpeg + F5-TTS）
```

**相关文件**：
- `tools/render.py`（plan/show/render 编排）、`tools/imagegen.py`（ComfyUI 图像适配器，协议无关）。
- `prompts/render-plan.md`（导演编译）、`render-style.yaml`（统一风格）、
  `director-skills/emotion-to-visual.md`（FACS 表情外化 skill）。
- `schema/render-plan.schema.json`、`schema/render-manifest.schema.json`。
- `tools/workflows/`（ComfyUI 工作流 JSON）。
- 技术调研：`docs/render-stack-research.md`。

**当前进度与设计**：见 `.planning/phases/1.3-render-pipeline/`。

## 数据不变量（见 DATA-MODEL.md）

- 义项 ID 为 `{word}-{nn}`，场景 ID 为 `{sense_id}-{type}-{nn}`。
- `semantic_skeleton` 与具体渲染解耦。
- `conditions.excluded` 只写真正不适用的情况。
- 五类场景各司其职，对比类场景必须声明 `contrast_relation`。
- 迁移场景至少改变两个表面维度。
- 正式资源包含 `schema_version`、`version` 与 `status`。
