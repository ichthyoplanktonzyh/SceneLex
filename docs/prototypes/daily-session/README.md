# Daily Learning Session 原型(混合学习流程)

`--dart-define=SCENELEX_SESSION_PREVIEW=true` 下的独立产品原型:在固定 Journey 原型
旁,验证第三种产品形态 —— **统一入口 + 动态任务编排 + 专项模式**。全部代码在
`app/lib/features/daily_session_prototype/`,与生产 App、Journey 原型互不干扰,可整体删除。

---

## 1. 这个原型验证的产品假设

| # | 假设 | 原型中的体现 |
|---|------|--------------|
| 1 | 首页只有一个强主入口 | 首页只有一张主卡片:今日学习 + 主 CTA;「调整本次学习 / 语义地图 / 自由探索」都是次级入口,不再把 Learn 和 Review 做成两张同等权重的大卡片 |
| 2 | 主入口明确展示预计时间与任务组成 | 卡片展示 `约 8 分钟` + `1 个待复习 · 1 个新义项 · 1 个辨析` |
| 3 | 系统默认替用户编排任务 | 默认标准模式由 Planner 根据学习者状态生成计划 |
| 4 | 用户仍可选择「只复习」或「只学新内容」 | 「调整本次学习」底部弹层提供三种互斥模式,模式是 Planner 的输入,不是 UI 过滤 |
| 5 | Session 由可组合任务构成,不是写死的 Journey 脚本 | 计划由 recall / discover / boundary / transfer 四类产品层任务按模式组合;Forgot 会动态插入 Transfer 任务,任务总数会变化 |
| 6 | 退出后可从原进度继续 | memory-only store 持有 active plan、当前任务下标与已产生结果;首页 CTA 变为「继续本次学习」,再次进入不从头开始 |
| 7 | Recall 结果至少影响一次后续任务 | Forgot → 本次 Session 追加一次该义项的迁移加练 |

## 2. 与生产 Learn / Review 双入口的区别

- 生产 App 把「学新」(Learn)和「复习」(Review)拆成两个独立工具入口;本原型只有一个
  主入口,系统先把两者编排进同一次 Session。
- 本原型不接入服务器、数据库、FSRS 与同步;学习者状态是原型 mock,内容全部是真实
  bundled catalog / ExperienceProgram。
- 生产 App 默认行为完全不变(无 preview flag 时走原入口)。

## 3. 与固定 Journey 原型的区别

| | 固定 Journey(`SCENELEX_JOURNEY_PREVIEW`) | 本原型(`SCENELEX_SESSION_PREVIEW`) |
|---|---|---|
| 计划来源 | 写死的五段序列(recall→discover→boundary→transfer→discover) | Planner 按 **模式 + 到期/未学内容** 实时生成 |
| 任务模型 | Journey 领域词(recall/newConcept/discrimination/transfer) | 产品层中性任务(recall/discover/boundary/transfer) + 区块(快速唤醒/核心义项/边界辨析/迁移加练) |
| 模式 | 无 | 标准 / 只复习 / 只学新内容 三种互斥模式 |
| 动态调整 | 无 | Forgot 会在本次 Session 插入一次 Transfer |
| 退出恢复 | 无(重新进入从头开始) | memory-only store,继续原任务;Discover 中断可恢复到同一题 |
| 估计时长 | `tasks.length * 2` | 集中定义的每任务权重(Recall 1′ / Discover 5′ / Boundary 2′ / Transfer 2′),见 `kDailySessionTaskMinutes` |

两个 preview 完全独立;若两个 flag 同时设置,`SESSION_PREVIEW` 优先(见 `main.dart` 注释)。

## 4. 哪些数据是真实的

- bundled WordSense catalog(`assets/content/experience-programs.v1.json` 的 `catalog` 段)
- ExperienceProgram(review_pool、symbol_binding、invariant、`role == transfer` 的 unit)
- Discover 任务完整委托真实 `ExperienceRuntimeViewModel` 及其 views,未伪造任何教学文案
- Recall / Boundary / Transfer 的题目与反馈均来自真实 program 内容

## 5. 哪些状态是 mock 的

- 学习者状态:`SessionLearnerState`(默认:reluctant 已学且今日到期、dirty 已学稳定、
  messy/almost 未学),通过薄适配器复用 Journey 的 demo 状态
- 边界关系:`messy ↔ dirty` 是原型级关系(catalog 的 `relations.boundaries` 尚为空)
- 任务编排、自评(Forgot/Hard/Got it)、时长权重、语义图:原型逻辑
- Session 进度:memory-only store,刷新页面即丢失(不持久化)

## 6. 三种 Session mode

- **标准模式**:到期 Recall → 一个新义项 Discover → 必要时 Boundary(新义项与已学义项
  存在可用边界时)
- **只复习**:只包含到期 Recall;无到期内容时进入明确的 empty 页(不崩溃)
- **只学新内容**:一个 Discover(+ 可用边界);无未学内容时进入明确的 empty 页;不包含 Recall

切换模式会重新规划(首页摘要与时长同步变化);存在未完成 Session 时会先确认再丢弃。

## 7. Forgot 如何影响本次计划

Recall 选择 **Forgot** 后,本次 Session 会在当前任务之后插入一次该义项的 **Transfer 加练**:

- 按任务 id 去重,同一义项不会被插入两次
- 首页 / Session 进度中的任务总数与时长会随之更新
- **Hard / Got it 不会插入额外任务**(规则写在 `DailySessionViewModel.gradeRecall` 注释中)
- 已作答的任务不会重复计分或重复插入补救任务

## 8. 如何启动

```bash
cd app
flutter run -d chrome --dart-define=SCENELEX_SESSION_PREVIEW=true
# 或任意设备:
flutter run -d macos --dart-define=SCENELEX_SESSION_PREVIEW=true
```

其他入口不受影响:

```bash
flutter run -d chrome --dart-define=SCENELEX_JOURNEY_PREVIEW=true   # 固定 Journey
flutter run -d chrome                                                # 生产 App
```

Web 构建还支持 `?shot=<name>` 参数(仅本原型预览入口内):`home` / `mode` /
`recall` / `discover` / `boundary` / `transfer` / `continue` / `completion`,
用于固定状态展示(由 `screenshot_driver.dart` 提供)。

## 9. 截图

所有截图由 `app/test/daily_session_screenshots_test.dart` 生成:真实页面状态
(与 `?shot=` 一致)、手机视口 390×844 @2x(输出 780×1688)、真实系统字体。
常规测试套件会跳过这些用例;重新生成:

```bash
cd app
flutter test test/daily_session_screenshots_test.dart \
  --update-goldens --dart-define=SCENELEX_GEN_SHOTS=true
```

| 文件 | 内容 |
|------|------|
| `01-home.png` | 首页(标准模式:预计时间 + 任务摘要 + 主 CTA) |
| `02-mode-sheet.png` | 调整本次学习(三种互斥模式) |
| `03-recall.png` | Recall(快速唤醒区块) |
| `04-discover.png` | Discover(核心义项区块,委托真实 ExperienceRuntime) |
| `05-boundary.png` | Boundary(边界辨析区块) |
| `06-transfer-inserted.png` | Forgot 后动态插入的 Transfer 加练 |
| `07-continue.png` | 中途退出后的首页「继续本次学习」状态 |
| `08-completion.png` | 完成页(基于真实结果的任务总结 + 语义图) |

> 说明:golden 路径为绝对路径(本机 `LocalFileComparator` 对相对路径写入不可靠),
> 因此该生成脚本仅在本仓库本机使用;文档截图本身已随仓库提交。

## 10. 已知限制

- Session 进度仅存内存:刷新/重启原型即丢失(不持久化,符合原型范围)
- 学习者状态不会跨天演化:完成一次 Session 后语义图按结果增长,但原型状态固定
- Discover 恢复支持同一题级(通过 `ExperienceRuntimeViewModel.toJson/restore` 快照),
  但其它任务(recall/boundary/transfer)恢复为任务级
- 语义地图为简化静态呈现,不支持拖拽
- 不计算、不展示 FSRS/长期记忆分数;完成页明确标注为原型总结
- 时长为原型权重(非真实耗时统计)

## 11. 后续需要产品决策的问题

- 到期义项数量较多时,Session 是否应限制 Recall 数量(而非全量)?
- Forgot 的补救 Transfer 是否应只出现在标准模式,还是也要出现在「只复习」模式?
- Discover 与 Boundary 是否需要跨义项调度(多新义项时谁先学)?
- 完成后的「重新体验」与次日 Session 的关系(原型中是直接重跑同一计划)
- 语义地图在真实产品中由谁维护(compiler 边界数据就绪前仅演示用)
- 预计时间的权重是否需要根据学习者历史校准
