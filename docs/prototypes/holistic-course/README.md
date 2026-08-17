# Holistic Course 原型 — LLM 整课创作纵向实验

> 实验问题：当 LLM 一次性看到完整 WordSense、相关邻近义项、中文 L1 学习政策
> 和 App 能力时，能否作为课程作者端到端设计一个词义的完整课程？

## 1. 这是什么

`tools/holistic_course_compiler.py` 是一条与 Experience Compiler v2 完全独立的
Holistic 编译路径：

- **一次 Course Author** 看到完整上下文（目标 WordSense + 邻近义项 +
  Language Contract + App Teaching Capabilities），一次性产出完整 Course
  Package（首学 / 绑定 / 边界 / 迁移 / 复习全部由 Author 决定）；
- **一次 Whole-course Critic** 对整门课给出全局 verdict 与 diagnostics；
- Critic fail 时**最多一次 Whole-course Repair**，返回完整修订后的课程；
- 除课程级调用外不调用任何局部 producer LLM，不做逐资产 gate。

代码只做硬约束校验（sense identity、结构可解析、引用/答案合法、renderer
capability、绑定前 L2 泄漏、中文 L1 surface policy、App 可执行）。课程结构、
误解分配、Boundary/Transfer/Review 的取舍是 LLM 的决定，不是结构门。

## 2. 关键文件

| 文件 | 作用 |
|---|---|
| `tools/holistic_course_compiler.py` | Holistic 编译器（validate / compile / compare） |
| `schema/holistic-course-package.schema.json` | Course Package 结构（只保证可执行） |
| `config/app-teaching-capabilities.v1.yaml` | App 当前能渲染的 primitive（不含编排建议） |
| `prompts/holistic-course/*.md` | Author / Critic / Repair 三份 prompt |
| `data/drafts/holistic-courses/messy-01/v01/course.yaml` | 真实生成的课程（LLM 原始产物 + 调用记录） |
| `app/assets/content/holistic-course-preview/messy-01.json` | 确定性 lowering 的预览数据 |
| `app/lib/features/holistic_course_prototype/**` | App 预览（严格按 learning_flow 顺序执行） |

## 3. 命令

```bash
# 离线确定性校验
python3 tools/holistic_course_compiler.py validate \
  data/drafts/holistic-courses/messy-01/v01/course.yaml

# 真实生成（使用 tools/llm.py 配置；调用预算 Author×1 → Critic×1 → Repair≤1）
python3 tools/holistic_course_compiler.py compile messy-01 --neighbor dirty-01

# 与 legacy program 的只读对比报告
python3 tools/holistic_course_compiler.py compare messy-01 \
  --holistic data/drafts/holistic-courses/messy-01/v01/course.yaml \
  --legacy tests/fixtures/experience-programs/messy-01.yaml \
  --output docs/prototypes/holistic-course/compare-messy-01.md
```

App 预览（独立入口，不替换生产 App / Journey / Daily Session）：

```bash
cd app
flutter run -d chrome \
  --dart-define=SCENELEX_HOLISTIC_COURSE_PREVIEW=messy-01
```

预览严格遵守 Author 的 `learning_flow`（再 `review_progression`）顺序执行，
不在 App 端重新编排；Author 没设计的任务类型 App 不会补齐。开发者总览
（author_intent + 每步内部字段）与 trigger 时间跳转只筛选 Author 已设计的
trigger，不改变课程；internal rationale 不显示给学习者。

## 4. 截图

`docs/prototypes/holistic-course/*.png` 由**真实 web 运行**截取：先起
`flutter run -d web-server`（`SCENELEX_HOLISTIC_COURSE_PREVIEW=messy-01`），
再用无头 Chrome（CDP）按 URL 参数定位每张截图（手机视口 780×1688）：
`docs/prototypes/holistic-course/capture_holistic_shots.mjs`。

```bash
cd app
flutter run -d web-server --web-port=8766 \
  --dart-define=SCENELEX_HOLISTIC_COURSE_PREVIEW=messy-01
node docs/prototypes/holistic-course/capture_holistic_shots.mjs 8766 docs/prototypes/holistic-course
```

- `01-course-overview.png` — 课程总览（仅开发者可见，`?view=overview`）
- `02-first-step.png` — 第一个 learner-visible 步骤（`?step=0&dev=0`）
- `03-symbol-binding.png` — Symbol Binding（`?step=4&dev=0`）
- `04-post-binding.png` — 一个绑定后步骤（`?step=5&dev=0`）
- `05-scheduled-review.png` — 一个 scheduled review（`?step=13&dev=0`）
- `06-completion.png` — 完成页（`?step=19&dev=0`）
- `07-boundary.png` — Boundary（**仅当 Author 自主设计了 Boundary 时存在**，
  本课存在：`?step=8&dev=0`）

`app/test/holistic_course_screenshots_test.dart` 保留同场景的 opt-in golden
套件（默认跳过）；本机运行该 golden 套件时单张渲染超 10 分钟，故截图以 web
路线为准。

## 5. 测试

```bash
python3 -m pytest -q tests/test_holistic_course_compiler.py
cd app && flutter test test/holistic_course_models_test.dart \
  test/holistic_course_preview_test.dart
```

覆盖：调用预算（pass=2 次课程级调用 / fail=3 次）、完整上下文输入、无
producer-scope、validator 硬约束与"不强制结构"、lowering 保序、不覆盖 legacy
产物；App 侧严格顺序执行、缺 Boundary/Transfer 正常、绑定前无 L2、internal
notes 不泄漏、时间跳转预览复习。

## 6. 实验结论（messy-01，第一轮）

> 详细数据见 `compare-messy-01.md`（只读对比报告）。

### 6.1 真实生成

- 使用本机 `.env` 的 LLM 配置（openai-chat / deepseek-v4-flash）真实生成。
- 调用记录（见 `data/drafts/holistic-courses/messy-01/v01/course.yaml` 的
  `metadata.calls`）：
  - **课程级调用 3 次**：author → critic（fail）→ repair；
  - 另有 2 次携带完整输出的格式/硬校验修复（author_format_retry、
    repair_format_retry）；
  - 全部调用均为课程级，无任何 producer-scope 调用。
- 产物未人工美化；Course Package 保持 LLM 原始输出，仅附加调用 metadata。

### 6.2 Author 自主设计的完整流程（learning_flow，13 步）

| # | 步骤 | primitive | 处理 |
|---|---|---|---|
| s1 | 观察房间（不命名） | scene_observation | 建立经验 |
| s2 | 外显证据 | evidence_highlight | 建立经验 |
| s3 | 排列 vs 表面维度 | binary_judgment | **misc-1**（绑定前先分离"乱"与"脏"两条维度） |
| s4 | 无序须整体可见 | binary_judgment | **misc-4** |
| s5 | **Symbol Binding** | symbol_reveal | 首次揭示 messy |
| s6 | 发音 | pronunciation | immediate_followup |
| s7 | 锚定房间场景 | l2_grounding | 自然 L2 句/句型/搭配 |
| s7b | 回看 dirty 对照词 | l2_grounding | 为边界准备（dirty 视为系统预绑定词，**不在本课绑定**） |
| s8 | **messy/dirty Boundary** | boundary_choice | **misc-1**（正式固化维度区分） |
| s9 | 抽象"乱"不可迁移 | transfer_judgment | **misc-2** |
| s10 | 正迁移：头发/字迹 | transfer_judgment | 推广到其他可见产物 |
| s11 | 数量多 ≠ 乱 | transfer_judgment | **misc-3**（cluttered） |
| s12 | 表面损坏 ≠ 乱 | transfer_judgment | **misc-5**（wrecked/trashed） |

### 6.3 Author 的选择

- **misconception 分配**：misc-1 分两阶段处理（绑定前维度分离 + 绑定后边界题，
  属明确递进）；misc-4 在首学；misc-2/3/5 全部放在迁移阶段封堵。没有为每个
  misconception 平均分配步骤。
- **dirty/messy Boundary**：**自主加入**。dirty 被设计为"系统预绑定对照词"
  （相关义项材料里明确说明：本课不做 dirty 的独立 symbol binding），在首学
  用一次 boundary_choice，并在 7 天复习里再提取一次。
- **Transfer**：4 次迁移判断（3 负 1 正），不是模板化的一次转移。
- **Review**：6 个复习项按 next_day → 3_days_later → 7_days_later 递进，
  scaffold_level 从 early_post_binding（回忆 + 自评）推进到 later_post_binding
  （L2 句型 grounding + 边界再提取），与首学共用同一条"可见排列无序"主线。
- **未做的事**：没有复制旧课程的"5 个 discrimination"结构；没有机械使用所有
  primitive（无 l1_confirmation、无 recall 之前的单选框重复等）。

### 6.4 与旧 messy program 的结构差异（摘要）

| 维度 | Legacy（v1 fixture） | Holistic（真实生成） |
|---|---|---|
| 步骤数 | 4 units + 2 review = 6 | 13 flow + 6 review = 19 |
| 任务分布 | anchor/variation/perturbation/transfer 各 1 | 判断类 2 + 边界 2 + 迁移 4 + 复习 6 + 观察/绑定/发音/grounding |
| misconception | misc-2（unit-1）、misc-1（unit-3） | misc-1×2、misc-2/3/4/5 各 1，按阶段分配 |
| dirty 侧处理 | 1 个 unit | 4 处（2 次边界题 + 2 次 grounding 回看） |
| Symbol Binding | 4 个 unit 之后 | 第 5 步（4 个经验步骤之后） |
| Boundary | program 内无 | 有（首学 1 次 + 7 天复习 1 次） |
| Transfer | 1 个 role=transfer unit | 4 次迁移判断（3 负 1 正） |
| Review | 2 个 review_pool 项 | 6 项，scaffold 递进（early→later） |
| LLM 设计调用 | 4 阶段 producer 管线 | 3 次课程级调用（author/critic/repair） |
