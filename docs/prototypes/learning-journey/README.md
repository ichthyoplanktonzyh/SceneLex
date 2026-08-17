# Learning Journey Prototype

> `--dart-define=SCENELEX_JOURNEY_PREVIEW=true` — 一个完整、可点击、可实际走完的
> "今日学习旅程"产品原型。这不是 LearningPath / Curriculum Engine 的最终实现，
> 而是用现有真实内容验证产品方向的纵向切片。

## Prototype hypothesis

我们正在验证：

> SceneLex 的核心日常体验是否应该从 "Learn / Review 两个工具入口"，
> 转变为 "系统自动编排的一次 Daily Semantic Learning Journey"。

即用户打开 SceneLex 后不再自己选择 "今天学什么 / 复习什么"，
而是系统基于他的语义状态编排一次混合了不同认知任务的旅程：

```
Recall（回想） → Discover（发现） → Boundary（辨析） → Transfer（迁移） → …
```

## What is real

本原型中的教学内容全部来自真实仓库数据，没有任何为原型重写的教学文案：

| 层 | 数据 |
| --- | --- |
| WordSense catalog | `experience-programs.v1.json` 中的 4 个 sense（reluctant / dirty / messy / almost），含 lemma、IPA、invariant、L1 confusables |
| ExperienceProgram | 每个 sense 的完整程序（units、symbol_binding、grounding、review_pool、transfer unit） |
| Recall 场景 | 真实 `review_pool` item 的 episode |
| Discover 流程 | 真实 `ExperienceRuntimeViewModel` 状态机 + ConceptUnitView / SymbolBindingView / GroundingView，unit 数量完全由程序决定 |
| Boundary 场景 | messy 的 `review_pool` 场景（办公室桌面） |
| Boundary 解释 | dirty / messy 两个 catalog entry 的真实 `invariant` 文案 |
| Transfer 场景 | reluctant 的 `role == transfer` unit（Maya 会议场景）+ 其真实 feedback |
| 词义状态 | catalog 中的 real sense id（不是假设 id == lemma） |

## What is mocked

只有以下三样是 prototype 层 mock，且与生产代码完全隔离
（全部在 `app/lib/features/journey_prototype/`，可整目录删除）：

| Mock | 说明 |
| --- | --- |
| `PrototypeLearnerState` | 明确构造的学习者起点：reluctant 已学且今日到期、dirty 已学且稳定、messy/almost 未学 |
| `PrototypeJourneyPlanner` | 确定性编排：recall reluctant → discover messy → boundary dirty/messy → transfer reluctant → discover almost |
| `PrototypeSemanticGraph` | 学习者语义地图节点状态 + dirty↔messy 原型边界关系（catalog 的 `boundaries_status` 仍为 not_collected，未被污染） |

## How to run

```bash
cd app
flutter run -d chrome --dart-define=SCENELEX_JOURNEY_PREVIEW=true
# 或
flutter run -d macos --dart-define=SCENELEX_JOURNEY_PREVIEW=true
```

不需要登录、server、workspace、sync。正式 App 入口行为完全不变。

## Screenshots

截图来自真实运行的 Web 原型（1200×870 视口），
按用户实际走完旅程的顺序编号：

| 文件 | 状态 |
| --- | --- |
| `01-journey-home.png` | Journey Home：夜空中唯一强 CTA "今日旅程"（约 10 分钟、1 回想 · 2 新概念 · 1 辨析 · 1 迁移），下方安静的 Semantic Map / Explore 次要入口 |
| `02-recall-before-reveal.png` | Recall：新的 review-pool 场景（健身房里反复系鞋带的新会员），目标词未显示，先让用户在脑中回想 |
| `03-recall-revealed.png` | Recall 揭示：reluctant + IPA + 最小 L1 提示，下方 Forgot / Hard / Got it 轻量自评 |
| `04-discover-before-binding.png` | Discover：messy 的概念形成（初次遇见 / 书桌场景），符号绑定前任何地方都看不到 "messy" 一词 |
| `05-symbol-reveal.png` | 符号揭示：messy + IPA + L1 提示（4 个 concept units 全部作答之后才出现） |
| `06-boundary-challenge.png` | Boundary 辨析：办公室桌面场景（办公用品错位但纸张整齐），选择 dirty 还是 messy |
| `07-boundary-explained.png` | 辨析后：关键区别卡片，dirty / messy 的真实 invariant 并排对照 |
| `08-transfer.png` | Transfer：reluctant 的全新 transfer unit（Maya 走向会议室），"概念是否还能迁移" |
| `09-transfer-feedback.png` | Transfer 作答后：真实 feedback（慢下脚步、叹气都是负面信号，即使她最终去了） |
| `10-journey-complete.png` | Journey Complete：今日成果清单（唤醒 reluctant / 建立 messy / 区分 dirty-messy / 迁移 reluctant / 建立 almost）+ 长大的语义地图小图（messy NEW、almost NEW、dirty↔messy 边界） |
| `11-semantic-map.png` | Semantic Map：可拖拽的图结构（InteractiveViewer + CustomPaint），节点状态区分 已掌握/学习中/新建立/未学习，新边界高亮 |

## Questions to evaluate

1. **Today's Journey 是否比 Learn / Review 更自然？**
   首页只有一个主 CTA，信息密度低；但"旅程"概念是否真的降低了选择负担，
   需要真人测试确认。
2. **不同任务混合在一个 session 中是否连贯？**
   5 个任务在同一 shell 中切换流畅；但 Discover（4-6 分钟）与 Recall（1 分钟）
   的时长落差明显，节奏感待观察。
3. **Discover → Boundary 的衔接是否合理？**
   messy 绑定后立刻进入 dirty/messy 辨析，教学上顺理成章；
   但辨析场景与刚学的 messy 完全同向（办公室桌面就是 messy 场景），
   挑战性偏低，未来应使用真正双维度的场景。
4. **Semantic Map Growth 是否产生学习进展感？**
   完成页 + 地图的 "NEW" 徽标与边界高亮有成长感；
   但 4 个节点太少，长期价值需要更大语料验证。
5. **用户是否仍需要显式看到 Learn / Review？**
   原型里完全隐藏了工具入口；复习（recall）被编排进旅程。
   需验证用户是否会因失去控制感而焦虑。
6. **Journey 是否应该成为未来 Home 的唯一主 CTA？**
   本原型倾向于是；但 Explore / Semantic Map 的位置与权重仍需迭代。

## Walkthrough notes（走查中观察到的 UX 问题）

- **Recall 自评与旅程进展脱节**：Forgot / Hard / Got it 不改变今日后续编排
  （原型明确不做 FSRS），但用户会期待"忘了"之后有补救任务。
- **Boundary 场景单一**：只有一个 messy 向场景，dirty 向或双维度场景缺失，
  辨析的判别力不足。
- **Discover 内部无 undo**：journey shell 未提供单元级回退
  （LearnSessionPage 有 undo），答错后只能继续。
- **Complete 页 CTA 之后回不到地图的上下文**：查看语义地图是新开页面而非
  替换，返回后回到完成页，路径感尚可但可以更顺滑。
