---
gsd_state_version: 1.0
milestone: m1
milestone_name: 理论框架与系统架构重设计
status: active
last_updated: "2026-08-10T22:50:00+08:00"
---

# SceneLex — 项目活记忆

> 当前事实以本文件、`CONTEXT.md`、`ROADMAP.md` 和各版本 manifest 为准。
> 历史评估文档说明当时发生过什么，但不能替代 manifest 的 provenance。

## 当前判断

SceneLex 已经历重大理论转向：由早期的“场景即释义”及“视频生成链路”演变为“经验即词义，微世界即体验”的语义教学引擎。

语言被定义为一种符号系统，词义是人类经验的范畴化。系统的新核心是**三层解耦**：
1. **抽象层**：词义 ≈ 经验的范畴化
2. **语义层**：场景 = 经验的具体实例
3. **呈现层**：媒体 = 场景的载体

当前阶段的重点不再是死磕视频渲染，而是**理论框架的全面文档对齐**，并将架构转向 LLM 语义编译器与微世界构建指令。视频生成被归为 legacy，作为“视频型微世界”的一种具体实现予以保留。

系统已确定分阶段演进策略：以“经验叙事”（纯文本微世界）作为第一阶段产品形态，直接嵌入背单词软件产生用户价值。已通过 reluctant-01 HTML 原型验证。

## 理论重构下的核心链路

```text
词汇 + 10大经验类别 + 学习者状态
↓
LLM（语义编译器：依赖隐式语义理解，不使用形式化语言）
↓
微世界构建指令 (Micro-world Specification)
↓
多媒体/渲染呈现引擎
```

## 已成立的事实

### 语义资源层（依然有效）

- M0 建设的语义基础设施（WordSense, SceneSpec）作为**语义层基础设施**完全保留并继续有效。
- 5 种场景类型（原型、对比、反例、边界、迁移）依然是核心的证据功能。
- 语义骨架、L1 混淆对比、学习单元设计、质量审核框架继续有效。
- 正式库包含 4 个 WordSense、21 个 SceneSpec。

### 产品形态与原型验证

- 分阶段演进策略已确定：经验叙事（当前）→ 富媒体增强 → 交互微世界。
- 学习单元结构已确定：经验溯源 + 5 场景叙事 + L1 对比 + 自测。
- 10 类经验 → 5 种底层引擎能力的映射已确定。
- reluctant-01 HTML 原型已完成并确认（`prototype/reluctant-demo.html`）。

### 遗留视频层 (Legacy)

- 曾经推进的 `reluctant-01-proto-01` 视频纵向切片（包括 Shot Plan, Keyframe Plan, Image Generation, Wan 2.7 实验等）已归档为 `M1.legacy`。
- 这些工作验证了媒体呈现的困难度，促成了系统向“多媒体、微世界”及“媒体无关”的底层逻辑转向。
- 这些组件不再是当前主线任务。

### 经验分类

10 大经验类别依然是系统基石：
1. 实体型 (entity)
2. 动作型 (action)
3. 属性型 (attribute)
4. 状态变化型 (state_change)
5. 空间与关系型 (spatial_relation)
6. 心理状态型 (mental_state)
7. 意图与行为型 (intentional_behavior)
8. 事件逻辑型 (causal_logic)
9. 时间结构型 (temporal_relation)
10. 认知与话语型 (cognitive_change / discourse_function)

## 当前唯一 P0

**构建经验叙事编译器**：

1. 将经验叙事学习单元结构（经验溯源 + 5 场景 + L1 对比 + 自测）固化为编译器输出格式。
2. 自动将 WordSense + SceneSpec 输入给 LLM，批量生成学习单元。
3. 用已有 4 个词义验证泛化能力。

## P0 之后

1. 设计微世界构建指令 Schema。
2. 重构从 WordSense/SceneSpec 到微世界指令的 LLM 编译器逻辑。
3. 挑选特定经验类别，完成首个与具体承载媒体解耦的“微世界”原型的纵向切片 (M2)。

## 暂不做

- 继续死磕未完成的遗留 Wan 2.7 视频动作生成与关键帧重绘。
- 建立复杂的自研渲染管线。
- 虚构形式化的语义描述语言。

## 产品应用层（v1 重写，2026-08-10 启动）

决定用 **Flutter + Rust** 自建学习产品（应用层），行为基线参考
`flashcards-open-source-app`（MIT），学习内容替换为 SceneLex 语义资源。
规划文档：`docs/v1/`（rewrite-plan / behavior-spec-flashcards / data-model-mapping）。

已确认决策：

- 只复刻背单词核心行为（AI chat / MCP / guest / admin / 社区排行榜不进入 v1）。
- 先本地 Docker 全栈，后上云。
- ExperienceProgram 离线导入 server + 预留 Compiler 接口。
- 认证自研 email OTP（不引入 Cognito）。
- 第一阶段 Rust = server + core，Flutter 侧纯 Dart，暂不引入 flutter_rust_bridge。

当前进度（Phase 1 完成）：

- monorepo 骨架：`core/`（domain types）、`server/`（Axum + health + 迁移）、
  `app/`（Flutter 五端 4-Tab 壳）、`contracts/`、`db/`（迁移）、`docker/`。
- 本地全栈可跑：Postgres 18（docker compose）+ server（迁移 + /health）。
- CI：PR 检查（cargo check/test + flutter analyze/test）。

Phase 2 完成（Rust server 核心）：

- FSRS-6 在 core 实现，15 条黄金向量全过（`core/tests/fsrs_vectors.rs`）。
- 迁移链：org/content/sync/auth 核心表（workspaces、user_settings、learning_states、
  review_events、word_senses、programs、units、lists、installations、replicas、
  hot_changes、applied_operations、OTP 表）。
- 认证：email OTP（自动注册、8 位码、3 分钟过期、5 次锁定、限流、防枚举延迟）。
- me/bootstrap：首次请求自动创建 user_settings + Personal workspace。
- workspaces：列表/创建/选择。
- 同步协议全套：push（幂等 + LWW 三字段）、pull（hot 增量）、bootstrap（pull/push
  双模式 + 不透明游标）、review-history pull（append-only）。
- 内容通道：GET /v1/content/senses + GET /v1/content/programs/{id}。
- Program 导入：`scripts/import_content.py`（幂等 UUIDv5 派生），已导入
  4 词义 / 4 program / 21 单元。
- e2e 验证脚本：`scripts/sync-e2e.sh`（认证 → bootstrap → push → pull → 幂等 →
  review 提交 → review-history → 全量 bootstrap，8 步全过）。

Phase 3 完成（Flutter 客户端核心学习闭环，在线模式）：

- server 新增 `POST /v1/workspaces/{id}/review`（服务端算 FSRS + 双写 review_event/
  learning_state + hot change）；默认端口改 8081（8080 被本地 python http.server 占用）。
- app：Riverpod + http + shared_preferences。
  - 登录页（邮箱 + 8 位验证码，错误场景展示）
  - 词表页（senses 目录 + 添加学习 → push learning_state）
  - 今日队列（bootstrap 水合 → 按 due/new 排序，新词优先）
  - Experience Player（按 stage 播放 units：原型/变式/边界扰动/区分/词义揭示/
    语言用法/迁移判断，含 learning_tasks 判断与选项）
  - 评分（Again/Hard/Good/Easy → POST /review → 队列推进）
- 手动验证指引：`docs/v1/manual-test-phase3.md`。

Phase 4 完成（离线优先）：

- Dart FSRS 端口（`app/lib/data/fsrs.dart`），黄金向量 15/15 通过（与 Rust core 一致）。
- Drift/SQLite 本地库：learning_states / review_events / outbox / sync_state（双游标）/
  senses / programs / workspace_settings 缓存。
- 本地优先写入：实体 + outbox 同事务；review 提交产生两条 outbox 记录
  （review_event append + learning_state upsert），FSRS 本地计算。
- SyncEngine：bootstrap 水合（分页+不透明游标）→ push outbox（100/批、幂等 ack）→
  pull hot（DISTINCT ON 增量、推进游标）→ pull review history（keyset）。
- 内容缓存：program 本地缓存优先（离线可播放 Experience Program）。
- 同步触发：mutation 后 + 页面加载时 best-effort（离线安全）。
- 手动验证指引：`docs/v1/manual-test-phase4.md`（断网学习 → 联网收敛 → 多端一致）。

下一步：Phase 5 — 进度/统计（streak、图表、日程分桶）、设置 20+ 项、多语言、本地通知。
