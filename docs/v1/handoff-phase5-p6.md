# Handoff:P5 进度/设置/多语言 + P6 打磨与发布

> 编写:2026-08-10(Phase 4 完成后)
> 给下一个会话的完整接力文档。新会话先读本文件,再读 `docs/v1/rewrite-plan.md`、
> `docs/v1/behavior-spec-flashcards.md`、`docs/v1/data-model-mapping.md`,
> 以及 `.planning/STATE.md`。

## 1. 项目现状

SceneLex:用 Flutter + Rust 复刻 flashcards-open-source-app 的背单词 App,
学习内容替换为 SceneLex 语义资源(Experience Program)。MIT 参考项目
`/Users/shadow/flashcards-open-source-app`(行为规格权威)。

已完成(P0-P4,git log:eb74494 → 3088943):

| Phase | 内容 |
|---|---|
| P0 | 三份契约文档:`docs/v1/`(行为规格/数据模型/计划) |
| P1 | monorepo:core(Rust)/server(Rust Axum)/app(Flutter)/contracts/db/docker |
| P2 | server:FSRS-6(Rust,黄金向量15/15)、OTP 认证、workspaces、同步协议全套、内容通道、Program 导入 |
| P3 | app:登录、词表、今日队列、Experience Player、评分(在线模式) |
| P4 | app:离线优先(Drift SQLite + outbox + SyncEngine 双游标)、Dart FSRS(黄金向量15/15) |

## 2. 代码地图

### server(Rust,`server/`)
- `src/main.rs`:入口,迁移执行(Migrator 运行时读 `../db/migrations`)
- `src/config.rs`:**默认端口 8081**(8080 被用户 python http.server 占用)
- `src/routes/`:v1.rs 挂载;auth.rs / me.rs / workspaces.rs / sync.rs / content.rs / review.rs
- `src/entities.rs`:实体 upsert + 快照(learning_state/list/settings/review_event)
- `src/sync/`:push(push.rs)/ pull(pull.rs)/ bootstrap(bootstrap.rs)/ review_history.rs / lww.rs / replica.rs / changes.rs
- `src/reviews.rs`:POST /workspaces/{id}/review(在线模式复习)
- `src/workspaces.rs`:bootstrap + CRUD
- `src/auth/`:otp.rs / token.rs / email.rs(LogEmailSender 打印验证码到日志)

### core(Rust,`core/`)
- `src/fsrs/`:algorithm.rs + alea.rs(黄金向量 15/15,`core/tests/fsrs_vectors.rs`)
- `src/domain/`:WordSense/ExperienceProgram/ExperienceUnit/LearningState/ReviewEvent/SchedulerSettings

### app(Flutter,`app/`)
- `lib/api/`:api_client.dart(含 apiClientProvider)、models.dart
- `lib/auth/`:auth_controller.dart(会话 token shared_preferences)
- `lib/data/`:providers.dart(workspace/installation/library/addSense/submitReview)、
  fsrs.dart(Dart FSRS)、`local/`(database.dart Drift + local_repository.dart)、
  `sync/`(sync_engine.dart + sync_providers.dart)
- `lib/features/`:login / review(review_page + experience_player)/ cards / progress(占位)/ settings(占位)
- `test/fsrs_vectors_test.dart`:Dart FSRS 黄金向量
- 依赖:riverpod、http、shared_preferences、drift、uuid

### 其他
- `db/migrations/`:0001 占位、0002 核心 schema、0003 去 word_sense FK(进度先于内容)
- `scripts/`:sync-e2e.sh(8 步验证)、import_content.py(导入词义库)
- `docker/`:Postgres 18

## 3. 关键约定(新代码必须遵守)

1. **行为以 flashcards 为权威**:改行为前查 `docs/v1/behavior-spec-flashcards.md`。
2. **本地优先**:所有用户数据写本地(实体 + outbox 同事务),同步引擎负责收敛;
   不要再加直连 server 的写路径(Phase 3 的 /review 端点保留但客户端已不走它)。
3. **同步引擎**:`SyncEngine.runSync()` = hydrate → push outbox → pull hot → pull history。
   mutation 后调 `ref.read(syncTriggerProvider)()` 触发;页面数据从本地 DB 读。
4. **FSRS 双实现**:Rust core 与 Dart 端口,黄金向量都必须 15/15 通过。
5. **server 契约**:所有新端点挂 `routes/v1.rs`,路径 camelCase JSON,错误走 ApiError。
6. **迁移**:改 schema 只加新迁移文件(0004+),不要改已应用文件。
7. **测试哲学**:不写单元测试;核心算法 parity 测试(黄金向量)例外;验收走真实验证
   (curl e2e / 手动步骤,已有 sync-e2e.sh 模式)。
8. **UI**:iOS 原生感 / Android Material 3,不追求跨端像素一致(AGENTS 约定)。

## 4. P5 任务清单(功能完整化)

### 4.1 进度界面(`features/progress/`,替换占位页)
对照行为规格 §5。数据全部从**本地**聚合:
- Streak:从本地 review_events 按 reviewed_local_date 聚合连续天数 + 冻结逻辑
  (策略:容量2、每复习日+1 unit、10 units=1 冻结额度)。
- 每日柱状图:本地 review_events 按天 + rating 四色分桶;周分页、图例过滤。
- Review Schedule 环形图:本地 learning_states 按 due_at 分桶
  (new/today/1-7d/8-30d/31-90d/91-360d/1-2y/later),本地时区。
- 下拉刷新 = 触发同步后重新聚合。
- 注意:本地 review_events 需要补 reviewed_local_date 字段(P4 本地表没有,
  需要迁移本地 schema——Drift schemaVersion 2 + 迁移,或从 reviewedAtClient 现算)。

### 4.2 设置界面(`features/settings/`,替换占位页)
对照行为规格 §7,做 v1 子集(参考 flashcards 但按 SceneLex 简化):
- FSRS 调度设置:desired retention / learning steps / relearning steps /
  max interval / fuzz → 本地写 + outbox(workspace_scheduler_settings upsert,
  需要本地表存 settings——已有 LocalWorkspaceSettings,需要加 outbox 写入路径)。
- 账号:显示 email、同步状态(可选)、退出登录(已有)。
- Danger Zone:Reset Study Progress(清本地 + 服务端重置,可后置)、
  Delete Workspace(可后置)。
- 其余(通知、语言、多语言)见下。

### 4.3 多语言
- 复刻 flashcards 的 9 语言机制:en/ar(RTL)/zh-Hans/de/hi/ja/ru/es-MX/es-ES。
- 用 Flutter 标准 l10n(flutter_localizations + gen-l10n),不需要 9 语全翻,
  可先 zh-Hans + en,机制就位后补其他。
- web 端应用内语言选择器 + 系统跟随(移动端)。

### 4.4 本地通知(移动端)
- 每日固定时间提醒 / 不活动窗口提醒 / 复习后重排(参考行为规格 §2/§7)。
- 用 flutter_local_notifications;web 端降级为设置页说明。
- 注意 AGENTS:iOS 通知为本地通知,无需推送服务。

### 4.5 词表增强
- 行内统计(due/new/reps/lapses)、空态、搜索(本地)。
- 词单(lists)UI 可后置——同步协议已支持,加 UI 工作量独立。

## 5. P6 任务清单(打磨与发布)

- Web 打磨:键盘快捷键(空格翻面、1/2/3/4 评分——参考行为规格 §2)。
- 桌面端:macOS/Windows/Linux 构建检查。
- 上云部署(先本地后上云,用户已确认):
  - Rust server 部署方案自选(如 Fly.io/VPS + systemd/Docker),不做 CDK。
  - CI/CD:现有 pr-checks.yml 保持;发布流后置。
  - 域名、TLS、Postgres 托管。
- 移动端打包:图标、签名、商店元数据(可后置到产品成熟)。

## 6. 需要用户决策的点(P5/P6 期间问)

1. 多语言:是否先只做 en + zh-Hans?
2. 通知:是否需要(iOS 本地通知有系统权限门槛)?
3. 上云选型:Fly.io / Railway / 自建 VPS / 其他?
4. 冻结额度(Streak Freeze)是否进 v1(flashcards 有,社区化概念)?

## 7. 验证方式

- server 改动:`scripts/sync-e2e.sh` 全链路(起 server 后跑)。
- FSRS 改动:`cargo test --workspace` + `cd app && flutter test`。
- app 改动:`flutter analyze` + 手动流程
  (`docs/v1/manual-test-phase4.md` 的断网/收敛流程)。
- 本地启动:
  ```bash
  docker compose -f docker/docker-compose.yml up -d
  cargo run -p scenelex-server          # :8081
  .venv/bin/python scripts/import_content.py   # 首次导入
  cd app && flutter run -d chrome --web-port 8090
  ```

## 8. 最近提交

- 3088943 feat(v4): 离线优先
- 0bce43a feat(v3): Flutter 客户端核心学习闭环
- e53f435 feat(v2): Rust server 核心
- eb74494 feat(v1): monorepo 骨架
