# Teaching Archetype MVP — 七类义项 × 十四门课程 × 十四天学习模拟

> 这不是七种用户模式。archetype 只回答"App 如何让学习者经验到这个意义"，
> 它是 Course Author 的建议输入，不是用户可见的类别按钮。

## 1. 这是什么

独立产品原型，验证顶层产品模型：

1. 正式学习对象是 **WordSenseCourse**（一个义项一门课），不是单词卡；
2. 不同义项需要不同的经验微世界与交互 Renderer（18 个 primitive）；
3. 用户不选择"空间类模式""心理类模式"——类别对用户透明，首页只有一个主入口
   **继续今日学习**；
4. Today Session 混合：到期课程复习步骤 + 一门新义项课程的自然章节 +
   Course Author 设计的 Boundary / Transfer / Recall；
5. App 不重新设计课程，只执行 Holistic Course Author 输出的顺序、trigger 与
   自然断点（`can_pause_after`）；
6. 用户按每日时间预算学习（默认 10 分钟），用 mock clock 模拟连续 14 天。

入口：

```bash
flutter run -d chrome \
  --dart-define=SCENELEX_ARCHETYPE_MVP=true
```

生产 App、Journey、Daily Session、Holistic Course 各 preview 均不受影响
（`app/lib/main.dart` 的 flag 优先级：SESSION > JOURNEY > EXPERIENCE >
HOLISTIC > ARCHETYPE_MVP > production）。

## 2. 十四个 WordSense 的精确身份

全部经真实身份链锁定：`data/dictionary-evidence/`（kaikki.org 词典证据）→
`data/inventories/`（approved Sense Inventory，evidence_digest 校验）→
`data/senses/`（inventory-driven WordSense，含 inventory/identity_digest/
provenance）。身份链不可跳过（`tools/teaching_coverage.py` 强制）。

| archetype | lemma | sense_id | 锁定义项说明 |
|---|---|---|---|
| entity_category | cup | cup-01 | 饮用容器实体义项（不透明、常有柄、与 glass 相对） |
| entity_category | mug | mug-01 | 带柄大杯实体义项（厚壁、大容量） |
| visible_attribute | messy | messy-01 | 可见的杂乱无序（位置偏离） |
| visible_attribute | dirty | dirty-01 | 表面污物附着 |
| spatial_path | across | across-01 | 横过/跨越：路径相对区域或表面 |
| spatial_path | through | through-01 | 贯穿的/穿过的（见下方证据缺口） |
| role_perspective | borrow | borrow-01 | 临时物品转移的接收者视角 |
| role_perspective | lend | lend-01 | 临时物品转移的提供者视角 |
| threshold_scale | almost | almost-01 | 接近但未达到阈值 |
| threshold_scale | barely | barely-01 | 刚刚达到/仅够达到阈值 |
| intention_cues | reluctant | reluctant-01 | 负面意愿：不情愿做某事 |
| intention_cues | hesitant | hesitant-01 | 不确定/迟疑的心理状态 |
| cognitive_update | notice | notice-01 | 通过感知意识到（偶然进入意识） |
| cognitive_update | realize | realize-01 | 经过信息更新理解到事实（推理到达） |

**证据缺口（诚实记录）**：仓库只读的词典提取（`tools/dictionary.py`，
`MAX_TEACHABLE_SENSES=8` 截断）对 *through* 只返回形容词条目——介词义项
（*through the tunnel*）未进入可教学证据。因此锁定最近似义项 **through-01**
（adjective，"贯穿的/穿过的：从一侧延伸到另一侧、可被穿透的路径/开口"），
语义上即"路径与内部空间关系"。该缺口记录在
`data/content-plans/mvp-teaching-archetypes.yaml` 的 through lemma `note` 中。

## 3. archetype 如何影响 Course Author

每个 WordSense 携带轻量、非权威的 `teaching_profile`
（`data/senses/*.yaml` 的 G 节），manifest 为每个 archetype 记录
`suggested_capabilities` 与 `special_risks`。Course Author 的输入包含
"教学原型建议（非权威，可采纳可不采纳）"章节，但：

- 没有代码强制 archetype 使用某个 renderer；
- Author 可以混用多个 archetype 的 primitive；
- Validator 不检查任何教学模板（步骤数、misconception 覆盖、Boundary 有无）。

`tools/teaching_coverage.py report` 从真实文件计算每个 archetype 的
suggested/registered/used 差距；`capability-report` 报告 14 门课实际使用的
primitive。

## 4. Renderer 如何组合

`app/lib/features/holistic_course_prototype/renderers/holistic_renderer_registry.dart`
是唯一映射：primitive id → renderer（12 个原始 primitive 仍在
`holistic_course_renderer.dart` 的 `buildStepView`，6 个新 primitive 由 registry
分发）。Renderer 只：展示 learner_content、收集交互、返回标准化结果。
新六组：

- `multi_label_choice`：多选 + 提交后统一反馈 + 提交后锁定；正确集合 =
  `evaluation.correct_option_ids`；both / insufficient evidence 是普通选项
- `object_inspection`：2D 对象卡片 + feature 列表/hotspot + 变体切换 +
  绑定前名称隐藏
- `spatial_stage`：CustomPaint 2D 舞台（区域/容器 + 起点终点 + 候选路径 +
  路径播放动画 + 正确路径反馈）
- `participant_map`：参与者 + 流向箭头 + 视角切换（perspective chips）
- `scalar_threshold`：min..max 标尺 Slider + 阈值标记 + outcome marker
  （"还没到"/"达到了"）
- `information_state`：时间线 beats 逐步推进 + 事实揭示 + 谁知道的点阵

## 5. 14 天模拟如何工作

- 确定性 curriculum（manifest）：第 N 天第 N 门课进入候选范围，只决定候选，
  不决定课程内部结构；
- Today Planner（`today_planner.dart`，纯函数）：到期复习优先（
  `due_after_days` + mock clock）但为新课程保留时间片（不会永久饿死新课）；
  同一门课程未到 Author 声明的自然断点（`can_pause_after: true`）前保持连续；
  不随机抽复习项、不 shuffle；超预算时延后新课并在首页诚实显示原因；
- Course Runner（`learner_state.dart` + session page）：严格按 Author 顺序执行，
  通过 Renderer Registry 渲染；答错时路由到 Author 设计的 `on_error` 步骤，
  没有补救步骤时才记录错误（→ `needs_remediation`，次日作为补救项重做）；
- 课程状态：unseen → in_course → symbol_bound → consolidating → stable，
  以及 needs_remediation；
- 完成页展示能力成果（建立/绑定/区分/迁移），不只展示词数；显示实际时间、
  完成步骤、课程状态变化、下一次预计返回时间；
- 当前**没有**真实 FSRS / server / sync / 登录——调度用 authored
  `due_after_days` + mock clock（代码 seam：`LearnerState.day` 可替换为真实
  日历 + FSRS 决定的具体日期）。

## 6. 哪些课程是真实 LLM 生成

全部 14 门课程由 `tools/holistic_course_compiler.py compile-batch` 真实生成
（openai-chat / deepseek-v4-flash，非流式）。每门课只有课程级调用：
Author ×1 → Critic ×1 → Repair ≤1（格式修复不计入课程级）。调用记录在
`data/drafts/holistic-courses/<sense>/v01/course.yaml` 的 `metadata.calls`
（role/provider/model/request_id，无密钥、无 prompt）。生成顺序与 pair 上下文：
第二门课看到第一门完整课程（避免机械重复 Boundary）。**messy-01 v01 保留为
v1 不覆盖**（其复习项无结构化 `due_after_days`，按规则不计入 MVP 调度——
其余 13 门课程均由 Author 声明了 `due_after_days` 与 `can_pause_after`）。

## 7. capability gap

`python3 tools/holistic_course_compiler.py capability-report --manifest data/content-plans/mvp-teaching-archetypes.yaml`
从真实文件计算：suggested vs registered vs 课程实际使用。当前结果见
`docs/prototypes/archetype-mvp/capability-report.txt`（构建时生成）。

## 8. 已知限制

- through 的介词义项因词典提取截断未锁定（见 §2）；
- messy v1 课程复习项无 `due_after_days`，不进入调度（见 §6）；
- 无真实 FSRS / server / sync / 登录；内存态在刷新后重置；
- object_inspection 用 2D 卡片占位，无图片生成/3D；
- spatial_stage 无物理引擎；information_state 无逻辑推理引擎；
- 截图使用无头 Chrome CDP 从真实 web 运行捕获（390×844 视口），不是 golden。

## 9. 截图与复现

截图在 `docs/prototypes/archetype-mvp/*.png`（见 README 同级目录）。复现：

```bash
cd /Users/shadow/SceneLex/app
flutter run -d web-server --web-port 8766 \
  --dart-define=SCENELEX_ARCHETYPE_MVP=true &
node ../docs/prototypes/archetype-mvp/capture_archetype_mvp_shots.mjs --port 8766
```
