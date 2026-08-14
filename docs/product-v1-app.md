# Product v1 App — 正式产品 Flutter 化映射

> 权威参考优先级：`scenelex-mobile-prototype-revised.html`（产品结构/交互）>
> `schema/experience-program.schema.json`（内容契约）> `CONTEXT.md` / `README.md` /
> `docs/experience-compiler-v1.md`（理论与领域语言）> 已完成的 Vertical Slice。

本文档是正式产品切换的工程契约：屏幕 → 路由/页面、数据来源、状态所有者、
加载/空/错行为、假动作替换、旧页面退役、响应式与设计系统、已知内容语言欠账。

## 1. Prototype screen → Flutter 页面映射

| Prototype screen | Flutter route | 页面 | 数据来源 | 状态所有者 |
|---|---|---|---|---|
| s-home | `/` | HomePage | ContentCatalog + LearningStates + due queue + check-in | HomeViewModel(Notifier) |
| s-learn | `/learn` | LearnSessionPage | GroupSessionCoordinator | GroupSessionViewModel |
| s-review | `/review?mode=due\|transfer` | ReviewSessionPage | ReviewQueueService(FSRS) | ReviewSessionViewModel |
| s-finish | `/finish` | GroupCompletePage / ReviewCompletePage | 会话统计结果 | 由 session VM 传入只读结果 |
| s-map | `/map` | ConceptMapPage | ContentCatalog(WordSense/boundaries) | ConceptMapViewModel |
| s-content | `/content` | ContentLibraryPage | Catalog + Favorites + Notes + LearningStates | ContentLibraryViewModel |
| s-study | `/study?tab=study\|preferences` | StudyPage / PreferencesPage | ProgressAggregation + LocalSessions + LearningPreferences | 各页 Notifier |
| s-profile | `/profile` | ProfilePage | Auth + LearningStates + FSRS 分布 | ProfileViewModel |
| —（新） | `/settings` | SettingsPage | 复用旧 settings 能力 | 既有 Notifiers |
| —（新） | `/content/replay` | ExperienceReplayPage | Catalog + Favorites | ReplayViewModel |
| —（新） | `/content/preview` | ExperiencePreviewListPage（预习） | Catalog（无 learning state 的 sense） | PreviewListViewModel |
| —（新） | `/content/learned` | 已理解列表页 | LearningStates | 列表查询 |
| —（新） | `/content/favorites` | 场景收藏页 | LocalFavorites | 列表查询 |
| —（新） | `/content/notes` | 笔记列表页 | LocalNotes | 列表查询 |
| —（新） | `/content/lists` | 词单（吸收旧 lists） | LocalLists | 既有 ListsPage 迁移 |

## 2. 页面真实数据来源

- **Home 数字**：Learn 数 = `ContentCatalog.senses − 已有 learning_state 的 sense`；
  Review 数 = due queue（`learning_state.due_at <= now` 且未 deleted）。签到 = `LocalDailyCheckins`
  今日记录。禁止 1212/5585 等假数字。
- **概念地图**：catalog 中 WordSense（lemma/pos/semantic_type/词义 invariant）+ l1 混淆（从
  catalog 显式字段读取，来源 `semantic_model.l1_interference` 的抽取，经 bundle 生成器显式建模，
  不直接渲染 semantic_model）。`relations.boundaries` 当前内容未收录 → 明确"待收录"状态，
  不虚构边界。
- **我的内容**：经验回放 = 已学习 sense 的 units（episode 只展示经验，不显示 target 词）；
  预习 = 未学习 sense 的 anchor unit；迁移验收 = 已学习 sense 的 transfer unit（判断作答 +
  FSRS 评级，真实记录）；在学词单 = 有 learning state 的 sense；近日已理解 = 近 7 天有
  learning state 创建的 sense；全部已理解 = 全部学习 state；场景收藏/笔记 = 本地表。
- **我的学习**：计划卡片 = catalog 全部内容为"当前学习范围"（真实数量）；概览 =
  review events 聚合 + `LocalSessions` 时长；签到日历 = check-in/学习事件聚合。
- **个人中心**：账号 = auth email；已理解 = learning states 数；已建立经验 = 已理解 sense
  的 unit 总数；掌握度 = FSRS 状态分布 + 稳定期中位数。

## 3. 状态所有权（模块边界）

```
View（仅布局/局部表现）
  └─ Notifier / ViewModel（页面状态与命令，每页唯一状态权威）
      └─ Repository（数据源、缓存、持久化）
          ├─ ContentCatalogRepository    bundle 优先 → server → cache
          ├─ ExperienceProgramRepository 程序加载（bundle/本地缓存/server）
          ├─ LearningRepository           学习状态/events/sessions（Drift + outbox）
          ├─ PreferencesRepository        强类型 LearningPreferences
          └─ 既有：LocalRepository/SyncEngine/FSRS/TTS
```

禁止：Widget 中读 JSON、执行 SQL、算 FSRS、拼 program。

## 4. Loading / Empty / Error 行为

- 每页有 loading（spinner 或骨架）、empty（产品文案 + 主行动按钮）、error（文案 + retry）。
- 内容目录失败 → 降级使用 bundle 内 catalog，并在页面显示离线徽标；完全不失败才报错。
- 所有列表入口必须有真实页面或真实空态；禁止 toast 冒充功能。

## 5. Prototype 假动作 → 真实行为

| Prototype 假动作 | 真实实现 |
|---|---|
| 假数字（1212/5585/8 等） | catalog/learning_state/events 聚合 |
| PROGRAM/MAP_DATA 硬编码 | bundle 生成器 + catalog repository |
| 随机 review queue | review_pool 轮换（本地已用记录优先未用 item） |
| toast 版"熟"跳过 | Known Check：先一次 concept transfer 检查，通过才跳过，失败回 anchor 流程 |
| toast 收藏/笔记 | Drift 表持久化，可从我的内容重开 |
| 假签到 | LocalDailyCheckins 持久化 |
| 假 VIP/会员 | 无真实支撑，入口不显示 |
| 假消息数/离线包下载/晒成绩 | 无真实支撑，入口不显示 |
| toast 菜单项（纠错/举报/沉浸场景/换词单等） | 无真实支撑的不显示；有支撑的接到真实页面 |
| 完成页假"分钟" | LocalSessions 真实计时 |
| 复习假间隔 | FSRS-6 真实 schedule |

## 6. 旧页面退役/吸收

- 退役：四 Tab AppShell、旧 ReviewPage 主入口、ExperiencePlayer（camelCase consumer）、
  `api/models.dart` 中 camelCase `ExperienceProgram`/`ExperienceUnit`、旧 Cards 页组织。
- 吸收：Cards 目录/标签过滤 → ContentLibrary；Lists → 我的内容"词单"；Progress 聚合 →
  我的学习/个人中心；Settings 子页 → 新 Settings；同步/FSRS/outbox/auth/workspace/通知/TTS
  全部保留复用。
- 开发 preview 入口（`SCENELEX_EXPERIENCE_PREVIEW`）保留，生产入口只保留一条（新 Shell）。

## 7. 内容语言已知限制（P0 上线前欠账，本任务不改内容）

当前 4 份 ExperienceProgram 的 pre-binding 内容主要为英文——这是**内容生成错误**，
不是 L2 沉浸设计。正确政策：Concept Formation 用 `target.locale_l1` 语言、Symbol Binding
首次正式出现目标 L2、Grounding 用 L2 表达、Review 按 ScaffoldPolicy 逐步撤除 L1。

本任务：不改 Compiler prompt、不重写 fixtures、不在 Flutter 中临时翻译；当前内容按原样
作为布局与数据压力测试。`ScaffoldPolicy` seam 已预留：偏好中的 L1 档位是强类型存储，
但运行时按内容包能力显示 capability-aware 状态（当前单 surface → 不谎称已切换文本）。
上线前需 Compiler 内容修复（P0）。

## 8. 响应式策略

以可用宽度（LayoutBuilder）而非设备型号判断：

- `<600dp`：手机。首页沉浸式 + 全屏 sheet/slide 页面；内容最大宽度 720 居中。
- `≥600dp`：NavigationRail（map/content/study/profile）+ 居中内容列（maxWidth 720–840）。
- 验证断点：320×568、390×844、430×932、768×1024、1024×768、1440×900。
- 不限横竖屏；支持鼠标/触控/键盘（Esc 返回、Enter/Space 主操作、数字键 FSRS 评分）。
- 文字放大 200% 不 overflow；48×48 触控；reduced motion。

## 9. 设计系统（SceneLex v1）

集中式 tokens（`ui/theme/scenelex_tokens.dart`），不用页面内零散 `ColorScheme.fromSeed`。

**4–6 核心色**
| Token | 值 | 角色 |
|---|---|---|
| `ember` | `#F2701C` | 行动、签到、概念形成暖信号（prototype 主橙） |
| `tealSignal` | `#0F766E` / 亮 `#0FB99B` | Symbol Binding / Grounding 青绿信号 |
| `ink` | `#1E1E24` | 主文字 |
| `paper` | `#F4F4F6` | 学习/内容页底（明亮阅读） |
| `dusk` | `#2C2C34` | 深色强调、L2 模式 pill、首页文字 |
| `starry` | 首页专属夜色渐变 `#23232B→#0E0E12` + 霞色 `#CFC7E6`/`#F3C078`/`#FFD6A4` | 首页氛围（唯一视觉签名） |

**字体角色**：标题 700（20–46px）、正文 15–16px/1.5–1.78、kicker 11.5–13px 大写标签、
统计数字 24–29px 粗体、IPA 常规。系统字体栈（SF / PingFang），不引入字体资产。

**布局原则**：页面层级 = 沉浸壳（首页/流程页）与阅读页（内容/学习/设置）分离；
卡片圆角 18 / 按钮 26 胶囊 / 小卡 11–13；间距 4-8-12-16-20-24-32；内容列 maxWidth 720；
动态分段进度条；固定底部主操作（Learn/Review 页）。

**唯一视觉签名**：首页"语义星野"——夜色渐变 + 山丘 + 光点呼吸，Flutter 代码原生
（CustomPainter + AnimationController），非截图、非 WebView、尊重 reduced motion。

**动效**：按压/选择 100–150ms、feedback/小组件 180–260ms、页面/sheet 300–450ms、
Binding reveal ≤500ms。用 transform/opacity 低成本动画，不阻塞输入，动画禁用时流程可用。

**为什么属于 SceneLex 而非通用学习 App**：双色信号（暖=概念形成、青绿=符号绑定）直接
编码"先经验后符号"的教学理论；星野 = 语义作为经验星空的隐喻；分段进度条 = 动态 unit
流程而非固定词数；kicker/模式 pill = 阶段透明性，是"可验证词义教学"产品的视觉化。

## 10. 内容通道数据流

```
build_experience_app_bundle.py
  fixture(program, reviewed/published) + data/senses(WordSense 元数据)
  → validate_program + catalog 抽取
  → app/assets/content/experience-programs.v1.json（catalog + programs，字节稳定）

正式 App（无网络可用）
  ContentCatalogRepository: bundle catalog → 首装即建目录
  ExperienceProgramRepository: bundle 程序（本地缓存）
  有网络：server /content/programs/{id}（canonical snake_case）→ 本地缓存覆盖
  网络失败：继续用 bundle/cache；draft 永不可达（bundle 与 endpoint 均 gate）
```

## 11. 首学 Group Session 行为（Learn）

- 组大小 = min(偏好 newGroupSize，可用待学 sense 数)，默认 4，不硬编码。
- 每义项：全部 concept units（动态数量/role 顺序）→ Symbol Binding → Grounding → 下一义项。
- 每题先作答才可继续；选择即锁定并显示正误/答案/反馈；back 保留状态；first-attempt 记录。
- 义项切换清理正确范围内的局部状态；退出确认对话框；可恢复未完成本地 session。
- "熟" = Known Check：一次 concept transfer 检查（role==transfer 的 unit 判断），通过才
  跳过剩余概念形成，失败回 anchor 正常流程，绝不点击即掌握。
- 收藏（当前 unit）/笔记（当前 sense）真实持久化。
- 完成 → 写 learning_state（新词进入 FSRS）+ LocalSessions + 首页统计更新。
- 完成页：完成义项数、完成经验数、first-attempt 判别、实际耗时、返回首页；
  按偏好"符号检索验收时机"决定是否进入延迟检索。

## 12. Review（新经验反向检索）

- 队列：due senses（FSRS due）→ 每个 sense 从 review_pool 轮换 item（本地已用记录，
  优先未用 item；绝不重放首学 unit）。
- 每卡：经验 → 尝试回忆 L2 → reveal（词 + IPA + 最小提示 + 判据）→ Again/Hard/Good/Easy
  → FSRS 真实间隔 → review event + learning state + outbox（单事务）→ 下一张。
- ReviewEvent 携带 word_sense_id / program_version / review_item_id / rating /
  reviewed_at_client（既有表结构已支持 experienceUnitId 存 item id）。
- 迁移验收 mode：用 transfer experience（判断式，记录 first-attempt）→ FSRS 评级 →
  真实记录；与普通复习的差异仅是经验来源与触发时机。
- 空队列 / 全部完成 / 提交失败均有正式状态。

## 13. 已知工程边界

- 概念地图 boundaries 当前无数据源（内容欠账），显示待收录状态。
- 时长统计基于本地 session 记录，跨设备合并不在本任务范围。
- server 无 telemetry 服务端接收；telemetry 以 review event 字段形式保留在本地 outbox。
