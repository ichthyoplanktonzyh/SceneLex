# SceneLex v1 重写计划

> 状态:已确认(2026-08-10)
> 参考基线:`kirill-markin/flashcards-open-source-app`(MIT),本地路径 `/Users/shadow/flashcards-open-source-app`

## 1. 任务定义

用 **Flutter + Rust** 复刻 flashcards-open-source-app 的**背单词 App 全部核心行为与体验**,
唯一替换的是**学习内容层**:卡片/翻转学习 → SceneLex 的 WordSense / ExperienceProgram / Experience Player。

- 复刻对象是"行为与体验",不是代码翻译。
- 技术栈全部自建:React/SwiftUI/Compose/TS-Hono 不再使用。
- 三个独立发布流对齐调整为 Flutter 五端(iOS/Android/Web/macOS/Windows/Linux)。

## 2. 已确认的范围决策

| 决策 | 结论 |
|---|---|
| 复刻范围 | 只复刻背单词核心行为。AI chat、MCP/agent API、OAuth、guest 会话、admin 面板、社区排行榜、catalog 目录、flashcards.zip 导入导出 **不进入 v1** |
| 部署目标 | 先 Docker Compose 本地全栈(Postgres + Rust server + Flutter),行为对齐后上云 |
| Program 管道 | ExperienceCompiler 离线产出已审核 Program → 导入脚本写入 server Postgres → 客户端下载。server 预留 Compiler 抽象接口,以后可切换为服务端内联编译 |
| 认证 | 自研 email + OTP(Rust),行为复刻 flashcards(自动注册/限流/5 次锁定/防枚举/会话刷新),不引入 Cognito |
| Rust/Dart 共享 | 第一阶段 Rust = server + core 库;Flutter 侧纯 Dart,暂不引入 flutter_rust_bridge,先保证架构边界正确 |

## 3. 保留 / 重写 / 替换 / 忽略矩阵

### KEEP DESIGN(行为照抄,实现换语言)

- FSRS-6 调度:21 权重、学习/复习/再学习状态机、fuzz、黄金向量测试模式
- ReviewEvent append-only + dedup 键 `(workspace, replica, client_event_id)`
- 同步协议全套:push / pull / bootstrap(双模式)/ review-history pull、hot_changes 增量日志、幂等台账(applied_operations)、LWW 三字段裁决、installation → workspace replica 确定性派生
- Outbox 模式:本地实体先落库 → outbox 记录 → 后台推送,实体与 outbox 同事务
- 复习队列排序策略:最近复习的到期卡 → 到期卡 → 新卡 → 未来卡
- 认证行为:自动注册、OTP 3 分钟生命周期、5 次尝试锁定、限流(邮箱 60s/15min/24h,IP 1h/24h)、随机延迟防枚举
- Workspace 概念:自动创建 "Personal"、切换、重命名、删除(确认文本)、reset-progress
- 账号删除:确认短语 "delete my account"、tombstone 防旧 token
- 进度统计:streak(用户级活跃日 + freeze)、每日柱状图(按本地日期分桶)、复习日程环形图分桶、时区处理
- 客户端缓存:cards/decks/reviewEvents/outbox/meta 的本地存储结构
- 队列预取:"warm next card"、评分后立即展示下一张

### RUST 重写(server + core)

- `server`:auth(OTP/会话/刷新)、workspaces、同步 API、FSRS 计算、进度统计 API、Program 交付 API
- `core`:domain types、FSRS-6、LWW 比较、同步协议验证、ExperienceProgram 验证

### FLUTTER 重写(客户端行为)

- 5-Tab 导航(Review / Progress / Cards / Settings;AI tab 裁剪)
- 复习界面:Front → Show answer → 2×2 评分网格(Again/Hard/Good/Easy + 下次间隔文案)、预取、评分反应动画(开关项)、TTS 朗读、Markdown/LaTeX 渲染
- 词表:Cards 列表、搜索、标签筛选、新建/编辑/删除(墓碑)、编辑内图片插入
- 标签系统:大小写规范化、计数、deck 即标签规则的智能筛选(至少 1 标签)
- Drift/SQLite 本地库 + outbox + 同步引擎 + 游标管理(双游标:hot + review-history)
- 设置 20+ 项(FSRS 设置、通知、动画开关、workspace、账号、Danger Zone 等)
- 进度界面:Streak 卡、Reviews 柱状图卡、Review Schedule 环形图卡
- 空态/加载态/错误态、骨架屏、web 键盘快捷键(空格翻面、1/2/3/4 评分)
- 登录 UI(邮箱 + 8 位码)、退出、账号删除流程(输入短语)、多语言
- 通知:本地通知(每日固定时间 / 不活动窗口 / 严格提醒 / badge)

### SCENELEX 替换(学习内容层)

| flashcards | SceneLex |
|---|---|
| Card(front/back) | WordSense(词义为最小教学单位) |
| 翻转卡片学习界面 | Experience Player(Anchor → Variation → Perturbation → Discrimination → Symbol Binding → L2 Grounding → Transfer) |
| 卡片创建/编辑 | 词义库添加(从已发布 Program 选取) |
| Deck(标签筛选) | 词单/课程(SceneLex 自定分类,复用筛选行为) |
| 复习内容(卡片重放) | 复习时给**新的** transfer 经验(新 experience → recall L2 symbol) |
| card_id 为复习对象 | review 对象 = word_sense + program_version + experience_unit |

### IGNORE(v1 不实现,保留行为参考)

- AI chat(含语音听写、附件、建议 chips)
- MCP server / agent API / OAuth 2.1 / 动态客户端注册
- guest 会话与升级
- admin 面板
- 社区:排行榜(评分榜/连续榜)、好友邀请、公开资料
- catalog 社区目录
- flashcards.zip 导入导出
- 反馈表单(可后置)
- 测试模式设置页、Demo 账号旁路

## 4. v1 Monorepo 架构

```
scenelex/
├── app/              Flutter 客户端(iOS/Android/Web/macOS/Windows/Linux)
│   ├── lib/
│   │   ├── app/          导航、主题、多语言、shell
│   │   ├── features/
│   │   │   ├── today/    今日学习(队列)
│   │   │   ├── learn/    新词义学习
│   │   │   ├── review/   复习流程
│   │   │   ├── vocabulary/ 词表/词单
│   │   │   └── profile/  进度/设置
│   │   ├── experience_player/   Experience Player(核心 UI)
│   │   └── data/         Drift 本地库、outbox、同步引擎
│   ├── core/           Rust 共享核心(经 FRB 边界,暂不启用)
│   └── server/         Rust Axum 服务(独立 crate)
├── core/               Rust:domain types、FSRS-6、sync 协议、LWW、Program 验证
│   ├── domain/  fsrs/  sync/  storage/  flutter_api/
├── server/             Rust Axum:api/ auth/ db/ sync/ content/ progress/
│   └── (Modular Monolith + 预留 worker)
├── compiler/           Experience Compiler(现有 Python 工具链)
│   └── 离线产出 → 导入脚本 → server Postgres
├── contracts/          ExperienceProgram / LearningState / API 契约(schema 优先)
└── docker/             本地全栈:Postgres + server
```

### Server 模块(Axum Modular Monolith)

- `auth`:email OTP、会话 cookie(bearer)、refresh、登出、账号删除
- `workspaces`:列表/创建/切换/重命名/删除/reset-progress
- `content`:词义库、Program 版本交付(内容通道,单向)
- `learning`:LearningState、FSRS 计算、队列查询
- `sync`:push/pull/bootstrap/review-history(进度通道,双向)
- `progress`:streak、每日统计、日程分桶
- `media`:预留(富媒体阶段)

### 两个通道(核心架构决策)

1. **进度通道**(双向同步):LearningState、ReviewEvent、workspace 设置 —— 完整复刻 flashcards 同步协议。
2. **内容通道**(单向分发):ExperienceProgram —— 类似 flashcards 的 media 模式:元数据经同步/下载 API,Program 体按版本缓存到本地,字节不走 JSON 同步。

## 5. 数据模型映射

见 [data-model-mapping.md](data-model-mapping.md)。要点:

- `content.cards` → `content.learning_states`(per user × word_sense,携带 FSRS 状态)
- `content.review_events` 扩展:`word_sense_id` + `program_version` + `experience_unit_id` + rating + reviewed_at_client(支持编译器版本效果分析)
- `org.workspaces` 不变(FSRS 设置列沿用)
- `sync.*` 全套不变(installations / workspace_replicas / hot_changes / applied_operations / workspace_sync_metadata)
- 新增:ExperienceProgram 版本表、词义库表、程序缓存表

## 6. 分阶段实施计划

| 阶段 | 内容 | 验收 |
|---|---|---|
| **P0** | 行为规格书 + 矩阵 + 架构(本文档) | 文档评审通过 |
| **P1** | Monorepo 脚手架:app/core/server/contracts + Docker Compose + CI + Flutter 五端骨架 | 空 shell 五端可跑 |
| **P2** | Rust server:auth(OTP)+ workspaces + me/bootstrap + LearningState + FSRS + 同步 API + Program 导入 | curl 全链路通过;FSRS 黄金向量通过 |
| **P3** | Flutter:登录 → 今日队列 → Experience Player → 复习流程 → 词表(联调 server,先在线模式) | 核心学习闭环可用 |
| **P4** | 离线优先:Drift + outbox + 同步引擎 + 双游标 + 设备模型 | 断网学习 → 联网收敛,多端一致 |
| **P5** | 进度界面(Streak/图表/日程)、设置 20+ 项、多语言、本地通知 | 功能对齐矩阵 |
| **P6** | Web 打磨、桌面端、上云部署 | 发布 |

## 7. 契约与质量约束

- FSRS:以 `tests/fsrs-full-vectors.json` 为黄金向量,Rust 实现必须通过(与 ts-fsrs 5.2.3 对齐)
- 同步协议:以 behavior-spec 字段级规格为准,contracts 中固化 OpenAPI
- 多端对齐:学习行为/同步行为各端一致;UI 不强制一致(iOS 原生感、Android Material、Web 桌面感)
- 多语言:复刻 9 语言机制(语言表可换 SceneLex 目标语言集合)
- 测试:只做真实集成/端到端/手动验证,不为覆盖率写单元测试
