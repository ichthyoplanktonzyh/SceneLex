# Handoff:P7 行为完整化 — 复刻原项目所有行为

> 编写:2026-08-11(P6 一期完成后)
> 给下一个会话的完整接力文档。新会话先读本文件,再读 `docs/v1/rewrite-plan.md`、
> `docs/v1/behavior-spec-flashcards.md`、`docs/v1/data-model-mapping.md`、
> `docs/v1/manual-test-phase5.md`,以及 `.planning/STATE.md`。

## 0. 本阶段目标(用户原话)

> "要做到真的能复刻原项目的所有行为。只有学习体验部分可以更换为我们的。"

即:除 Experience Player(学习内容/呈现)外,所有交互行为对齐
flashcards-open-source-app。行为权威仍是 `docs/v1/behavior-spec-flashcards.md`。

## 1. 项目现状

SceneLex:Flutter + Rust 复刻 flashcards 背单词 App,内容替换为 Experience Program。
已完成 P0-P6(git:d5fbf52):

- P0-P4:契约文档、monorepo、server 核心(FSRS-6 黄金向量、OTP、同步协议全套)、
  Flutter 核心闭环、离线优先(Drift + outbox + SyncEngine 双游标)。
- P5:进度界面(Streak+Freeze/四色柱状图/环形图,本地聚合)、设置(FSRS 调度
  outbox、通知、语言)、多语言(en+zh-Hans,gen-l10n)、词表增强(搜索/统计)。
- P6 一期:web/桌面键盘快捷键(空格、1-4)、macOS 构建验证、`scripts/local-dev.sh`。
- 修复:CORS(本地 permissive)、drift web 资产(sqlite3.wasm + drift_worker.js
  已入 `app/web/`)。

## 2. 差距清单(P7 工作范围)

对照行为规格,已复刻 vs 未完成(详细表格见上次会话结论,这里列任务):

### A. 内容呈现层(对学习体验影响最大,优先)

1. **TTS 朗读**:每卡面朗读按钮、自动检测语言、失败瞬态 banner。
   - flashcards 参考:web `apps/web/src/speech/`;iOS AVSpeechSynthesizer。
   - 建议 `flutter_tts`(web 用浏览器 SpeechSynthesis;iOS/Android 原生)。
2. **Markdown/LaTeX 渲染**:叙事/任务内容渲染标题、引用、列表、表格、代码围栏、
   LaTeX(`$..$`/`$$..$$`)。
   - 参考 flashcards web markdown 渲染栈。
   - Flutter 建议 `flutter_markdown` + LaTeX 扩展(如 `markdown_latex` 或 WebView 渲染,先调研)。
   - 注意:当前 ExperienceProgram 的 synopsis/task prompt 是纯文本,渲染层替换,
     内容源不变。
3. **评分反应动画**:开关项(默认开、低电量自动禁用)、同屏最多 3 个、随机变体、
   触摸即取消。
   - 参考 flashcards `apps/web/src/screens/review/reactions/`。

### B. 词单/筛选/管理交互层

4. **词单(lists)UI**:Deck = 智能筛选(名称 + 标签规则,至少选 1 标签;
   "All Cards" 内置不可编辑)。
   - 同步协议已支持 list 实体(bootstrap rank 2、push upsert、LWW)。
   - 客户端缺口:本地 list 表(Drift)+ outbox + SyncEngine apply + UI
     (词单列表/新建/编辑/删除、词单详情:规则/统计/匹配列表/"Review this deck")。
5. **队列筛选菜单**:Review 页筛选(All Cards / 词单列表 / 标签列表,多选带计数),
   筛选持久化。
6. **左滑删除学习状态**:二次确认(文案提示"从本地列表和下次同步中移除")、
   墓碑(deletedAt 置位,仍走 upsert,无独立 delete 操作)。
7. **标签系统**:大小写规范化、计数、deck 即标签规则(至少 1 标签)。
   - SceneLex 词义无用户生成标签 —— 待用户决策标签来源(见 §6)。

### C. 设置/账号完备层

8. **设置项扩充**:
   - Review Animations 开关。
   - 通知模式扩展:Once daily(已有)/ Inactivity 时间窗 + 重复间隔 30-240min /
     严格提醒(睡前 4/3/2h)/ badge。
   - 信息项:Legal、Support、Open Source、Server 信息、Device 信息、分享 App。
9. **账号删除**:必须输入 `delete my account`;服务端 sole-member workspaces
   级联删、user_settings、认证工件、deleted_subjects tombstone;
   客户端清本地但保留安装身份。旧 token → 410 ACCOUNT_DELETED。
10. **工作区管理 UI**:切换/重命名/删除(确认文本 `delete workspace`)/
    reset-progress(确认文本)。
    - **server 缺口**:目前只有 list/create/select,需补 rename/delete/reset-progress
      端点(路由注册 + `infra/aws` 无关,本项目是 `server/src/routes/v1.rs`)。
    - Danger Zone 两项占位(设置页)随之实现。

### D. 队列/细节行为

11. **队列补充**:种子 8 张、低于 4 张后台补充(参考行为规格 §2)。
12. **Hard 用法提醒**:对已会但难的卡选 Hard 时提示
    "If you did not know the answer, choose Again…"(首次出现即提示一次)。
13. **Review 徽章 → Progress 滚动联动**(tab 间跳转;进度徽章可选)。
14. **词表详情只读元数据**(Due/Reps/Lapses)已有,对齐文案即可。

## 3. 已确认维持的裁剪(不要推翻,除非用户另行指示)

- AI chat、MCP/agent API、OAuth、guest 会话、admin 面板、社区排行榜
  (评分榜/连续榜)、社区 catalog、好友邀请、公开资料、flashcards.zip 导入导出、
  反馈表单(可后置)、测试模式设置页、Demo 账号旁路。
- 移动端打包(图标/签名/商店元数据)、上云部署:后置(用户已拍板)。

## 4. 代码地图(P7 相关)

- `server/src/routes/v1.rs`(新端点挂这)、`workspaces.rs`(补 rename/delete/reset)、
  `sync/push.rs` + `entities.rs`(list 实体已支持,见 `upsert_list`)。
- `app/lib/data/local/database.dart`(加 local_lists 表 → schemaVersion 3 + 迁移)、
  `local_repository.dart`(list 读写 + outbox)、`sync_engine.dart`(`_applyEntity`
  已有 `case 'list': break` 占位,接上落盘)。
- `app/lib/features/review/experience_player.dart`(TTS/渲染/动画/快捷键位置)、
  `review_page.dart`(队列补充/筛选菜单)、`cards_page.dart`(删除/词单入口)、
  `settings_page.dart`(扩充)、`progress_page.dart`(徽章联动)。
- l10n 字符串:`app/lib/l10n/app_en.arb` + `app_zh.arb`(所有新文案必须双语)。

## 5. 关键约定(沿用)

1. 行为以 behavior-spec-flashcards.md 为权威;改行为前先查。
2. 本地优先:实体 + outbox 同事务;SyncEngine.runSync() = hydrate → push → pull hot
   → pull history;mutation 后 `ref.read(syncTriggerProvider)()`。
3. FSRS 双实现黄金向量必须 15/15。
4. server 契约:camelCase JSON、ApiError、新端点挂 `routes/v1.rs`。
5. 迁移:改 schema 只加新迁移文件(0004+);Drift 本地库加列 → schemaVersion 3 + onUpgrade。
6. 测试哲学:不写单元测试;核心算法 parity 例外;验收走真实验证
   (curl e2e / 手动步骤 / `flutter test` 黄金向量 + streak parity)。
7. 多语言:新文案必须进 ARB(en + zh-Hans),gen-l10n 后使用。
8. UI:iOS 原生感 / Android Material 3 / web 桌面感,不追求像素一致。
9. iOS simulator / gradle 重活:用户明确允许才跑。

## 6. 待用户决策(P7 期间问)

1. **标签来源**:SceneLex 词义没有用户生成标签。选项:
   a) 用词义元数据(semanticType/pos)预置为只读标签;
   b) 允许用户自定义标签(本地 + 同步到 server,需扩展数据模型);
   c) v1 用 "All Cards" 单筛选,词单规则只按预置标签。
2. TTS 引擎取舍:web 用浏览器 SpeechSynthesis(语言覆盖受限)是否可接受。
3. LaTeX 渲染方案:Flutter 生态无成熟 KaTeX;可接受"代码围栏+公式按文本渲染"
   降级,或引入 WebView(重)。建议先降级。

## 7. 验证方式

- server 改动:`bash scripts/sync-e2e.sh` 全链路;新端点补 e2e 步骤(可扩展脚本)。
- app 改动:`flutter analyze` + `flutter test`(黄金向量/parity)+
  `bash scripts/local-dev.sh` 起全栈,手动验证
  (`docs/v1/manual-test-phase5.md` 增量扩展 P7 章节)。
- web 首次验证注意:drift 需 `web/sqlite3.wasm` + `web/drift_worker.js`(已入库)。
- 本地启动:`bash scripts/local-dev.sh`(web 自动开 :8090)。

## 8. 最近提交

- d5fbf52 fix(web): drift web 支持 — wasm/worker 资产
- 92ee6d5 fix(server): CORS(本地 permissive)
- c4741ba feat(v6): 键盘快捷键 + 桌面端构建 + local-dev.sh
- ea0ff66 feat(v5): 进度/设置/多语言/通知/词表增强

## 9. 下个会话启动指令

`读 /Users/shadow/SceneLex/docs/v1/handoff-phase7.md,然后按 §2 任务清单从 A 组开始工作`
