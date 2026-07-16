# SceneLex — 架构骨架

> 最后更新：2026-07-16
> 帮助新会话快速建立对系统结构、数据流和边界的全局理解

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

- SceneLex 当前只维护模型无关的语义与场景中间表示（IR）。
- 图片、动画、视频、TTS 或交互素材都是可替换渲染后端的产物。
- 渲染器是外部适配器，不进入 `schema/` 或正式数据目录。

## 数据不变量（见 DATA-MODEL.md）

- 义项 ID 为 `{word}-{nn}`，场景 ID 为 `{sense_id}-{type}-{nn}`。
- `semantic_skeleton` 与具体渲染解耦。
- `conditions.excluded` 只写真正不适用的情况。
- 五类场景各司其职，对比类场景必须声明 `contrast_relation`。
- 迁移场景至少改变两个表面维度。
- 正式资源包含 `schema_version`、`version` 与 `status`。
