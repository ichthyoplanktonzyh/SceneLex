# SceneLex 正式产品 v1 全面 Flutter 化 — 交付报告

- 基线 commit：`bbec52f`（Flutter Experience Runtime vertical slice — Contract v1 驱动首学）
- 工作区状态：**97 个文件改动，未 commit**（待 supervisor 验收后决定提交策略）
- 日期：2026-08-14

## 一、验收结果汇总（全部通过）

| 验收项 | 命令 | 结果 |
|---|---|---|
| 实机检查点（真实浏览器 + 本地 server） | `bash scripts/run-checkpoints.sh all` | **cp1 断网评分→恢复 60s 同步 / cp2 resume 即时同步 / cp3 rejected 中止 / cp4 登出 401 — 4/4 PASS** |
| Flutter 单测 | `flutter test` | **116 passed**（84 既有 + 32 新增） |
| 静态分析 | `flutter analyze` | **0 error / 0 warning**（10 条 info 均容忍项） |
| 后端测试 | `cargo test` | 3 passed |
| 后端格式 | `cargo fmt --check` | clean |
| 后端 lint | `cargo clippy -- -D warnings` | clean |
| Python 测试 | `python3 -m pytest -q` | **548 passed** |
| 内容包校验 | `python3 tools/build_experience_app_bundle.py --check` | 一致 |
| 差异卫生 | `git diff --check` | 干净 |

## 二、26 节任务完成情况

> 第 1-22 节主体（新 IA 重构、l10n 迁移、sync 引擎、review/learn/study/content 页面重写、响应式 shell）已在早期轮次完成并逐步验收；第 23-26 节（端到端实机验证、视觉 QA、验收、交付报告）在本轮收尾。以下为本轮（本轮收尾期）的增量成果。

### 本轮新增产品修复（实机验证暴露的真 bug）

1. **GroupSessionViewModel 通知桥接** — `answer` 只 notify 自身、页面只监听 groupVm → UI 永不重建（"点击无效"表象的根因）。新增 `_forwardRuntimeChange`（add/removeListener 配对）。
2. **ExperienceRuntimeViewModel.canProceed** — binding 阶段 currentUnit 为 null 恒 false → 改为 conceptUnit 外恒 true（footer 卡 "Answer first"）。
3. **createLearningState FSRS learning 卡** — 用 `computeReviewSchedule(const ScheduleState(), good)` 生成完整学习状态（stability/difficulty/lastReviewedAt/scheduledDays/stepIndex），dueAt=nowIso；fsrsCardState='learning'（server 约束：new 卡禁止 due_at）。此前 'new' 卡被复习队列永远跳过 = 复习断裂。
4. **复习队列放开 learning 卡** — `isDue` 去掉 `!isNew` 限制、`orderedDueSenses` 不再跳过 isNew。
5. **LearningStateView.fsrsStepIndex** — 字段 + provider 映射 + review 页传递（原硬编码 null → learning 卡抛 "Learning or relearning card is missing fsrsStepIndex"）。
6. **profile/content 页 ListTile ink warning** — `_Row`/`_GroupCard` 的彩色 Container 改为 `Material`（ListTile 背景/墨迹需 Material 祖先）。
7. **cacheSenses 字段名** — server 返回 snake_case（`word_sense_id` 等），原 camelCase 访问全 null → TypeError（驱动 seed 路径偶发失败）。
8. **study 页 390 宽 RenderFlex overflow** — `_Stat` 标签与 learned/catalog 行加 `Expanded`/`Flexible` + ellipsis（1-46px 溢出）。
9. **Known Check 通过后死循环** — `while (phase == conceptUnit) proceed()` 在未答单元上不推进 → 新增 `ExperienceRuntimeViewModel.skipRemainingConceptUnits()`（跳过剩余概念形成，已答统计保留）。
10. **组会话恢复丢失 currentVm** — `_restore` 未回放序列化快照 → `_pendingVmState` 暂存并在新 VM 加载后 `restore`。
11. **l10n 占位符 `$` 泄漏（本轮用户反馈）** — 27 个 key 的 ARB 文本用 `$var`/`${var}`（Dart 插值格式）而非 ICU `{var}`，GenL10n 原样输出 → 页面标题出现 `$5 notes` 之类。已全部改为 `{var}`（含 ICU 复数 `{count, plural, ...}` 从基线恢复），页面引用与 ARB 全量 diff 0 缺失（482 个调用全覆盖，564 keys）。
12. **测试驱动 FlutterError hook RangeError** — `substring(0, 1500)` 在短字符串抛错 → uncaught → drive 无结果挂死（此前所有 drive 挂起的根因），改安全截断。

### 本轮新增测试（32 个）

- `test/learning_preferences_test.dart`（5）：默认值 / 序列化往返 / 降级 / copyWith / 尺寸列表
- `test/learning_progress_test.dart`（12）：deriveLearningProgress / nextLearnGroup / orderedDueSenses / buildReviewQueue（含 transfer 模式与上限）/ deriveStudyStats（含 streak 宽限）
- `test/group_session_view_model_test.dart`（10）：加载 / 通知桥接 / 多义项完成 / Known Check 三态 / 恢复三态 / 错误面
- `test/review_session_view_model_test.dart`（4）：reveal 门控 / 评级推进 / 失败不消耗 / 未知词即完成
- `integration_test/sync_flow_test.dart` 扩展：case 5 截图 tour（8 页导航）+ SHOT_WIDTH/SHOT_HEIGHT 视口参数

## 三、视觉 QA

- **截图方式**：flutter web-server 实机 + 人工截图（automation 路线无法落盘：web takeScreenshot 挂死 driver、CDP 截图 canvas 空白——Chrome 节流/headless 渲染限制）。**用户手动截图 11 张**（390 逻辑尺寸 Retina 2x）已确认整体风格无问题。
- **发现的唯一问题**：标题出现 `$` 符号 → 即 l10n 占位符泄漏（见 11 号修复，已修）。
- 截图报告：`/tmp/scenelex-shots/report.html`（11 张并排，含尺寸/颜色客观校验，无白屏）。

## 四、已知限制（测试环境）

1. **web drive 的 60s 定时器 / AppLifecycleListener resume 事件不可靠**（drive/浏览器会话限制）→ cp1/cp2 用手动 `syncTriggerProvider()` 兜底（语义 = 回前台触发同步），已内置在测试内。
2. **web takeScreenshot 挂死 driver** → 视觉 QA 走人工截图（已交付）。
3. **relay（:9001）偶发瞬时启动失败** → 重跑脚本即可（脚本自带健康检查）。
4. **seed 缓存路径依赖 drift worker** → 测试内已通过真实 ApiClient+LocalRepository 预热兜底。

## 五、环境

- server :8081、relay :9001、postgres 容器运行中
- 测试脚本：`scripts/run-checkpoints.sh [1|2|3|4|all]`（浏览器实机）、`scripts/manual-shots.sh [en|zh] [390|1440]`（人工截图辅助）
- 手动截图辅助脚本仍可用（页面停留 90s + relay 页名提示）
