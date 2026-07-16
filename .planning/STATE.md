---
gsd_state_version: 1.0
milestone: m1
milestone_name: 可验证的纵向实验切片
status: active
last_updated: "2026-07-16T00:00:00.000+08:00"
---

# SceneLex — 项目活记忆

> 最后更新：2026-07-16 CST
> 更新原因：初始化 .planning 体系，记录当前项目状态

## 当前位置

- **当前执行主线**：M1 可验证的纵向实验切片 — 用 6–10 个高价值义项完成"语义规格 → 场景证据 → 可评分任务 → 学习迁移验证 → 资源导出"的完整闭环。
- **当前正式资源**：3 条义项（`messy-01`、`reluctant-01`、`almost-01`），10 条正式场景，`dirty-01` 及其五类场景在草稿区。资源状态均为 `reviewed`，尚未宣称 `published`。
- **基础设施**：Schema（word-sense / scene-spec / resource-bundle）v1.0 已稳定；工具链（draft.py、validate.py、export.py、llm.py）已可用；LLM 适配器支持四种协议。
- **待建义项**：`almost-01` 的场景证据组。

## 资源规模

| 资源类型 | 正式库 | 草稿区 |
|---|---|---|
| 义项 (senses) | 3 (`messy-01`, `reluctant-01`, `almost-01`) | 1 (`dirty-01`) |
| 场景 (scenes) | 10 | 5 |
| LLM 协议适配 | 4 (openai-responses, openai-chat, anthropic, command) | — |

## 已完成事项

- ✅ 词义 Schema v1.0 与场景 Schema v1.0 稳定。
- ✅ 资源包 Schema v1.0 与确定性 JSON 导出 (`tools/export.py`)。
- ✅ 五类场景证据模型 (prototype / contrast / counterexample / boundary / transfer) 已落地。
- ✅ LLM 起草管线：义项草稿 → 场景草稿，适配器支持四协议。
- ✅ 正式库校验 (`tools/validate.py`) 与 promote 原子流程。
- ✅ MVP 实验方案 (`docs/mvp-evaluation.md`)：三层条件对照、六项测量指标、决策规则。
- ✅ 仓库工作约束 (`AGENT.md`)：核心原则、架构边界、数据不变量、工作流程。

## 下一步工作

1. **完成 `almost-01` 的场景证据组**：当前只有义项规格，尚无场景。
2. **完成 `dirty-01` 的审核与 promote**：草稿区待审，是第三个完整义项+场景组。
3. **选择并起草剩余 3–5 个义项**：优先覆盖属性、动作、心理状态、标量/逻辑等不同 semantic_type，至少包含 2–3 组中文母语者易混淆的相邻词对。
4. **制作第一轮实验材料**：为已审核义项准备低成本渲染（连续图片/简单动画），按 `docs/mvp-evaluation.md` 的三层条件组装实验。
5. **运行小样本对照实验并修订资源**：验证场景证据是否提升即时理解、相邻词区分和迁移。

## 最近重要决策

1. **2026-07** — 架构校准：SceneLex 核心定位为"可独立发布、版本化和复用的语言资源"，学习产品是消费者而非资源拥有者。正式语义资源不得包含厂商名、模型名或请求参数。
2. **2026-07** — MVP 策略：先选 6–10 个义项做薄而完整的实验闭环，验证后再扩到 30–50 个义项。规模化的前提不是 Schema 能通过，而是资源在新场景中确实产生了可复现的学习迁移。
3. **2026-07** — 实验设计：第一轮只设三层条件（翻译 / 普通图片 / SceneLex 场景证据），不急于拆分个性化维度。决策规则按效应方向和失败模式迭代，不宣称普遍有效。
4. **2026-07** — 初始化 .planning 体系：参考 LLPlayerNext 的 GSD 文件结构，建立精简适配版的规划中枢。

## 当前阻塞项

- 无外部阻塞。`almost-01` 场景和 `dirty-01` 审核是当前最直接的推进项。

## 指标

- STATE.md 维护目标：≤ 200 行（SceneLex 当前规模远小于 LLPlayerNext）。
- 正式义项目标（M1 收口）：6–10 条。
- 场景/义项目标：每义项至少 4 类证据（原型 + 边界/对比 + 迁移），MVP 阶段保留完整五类生成。
