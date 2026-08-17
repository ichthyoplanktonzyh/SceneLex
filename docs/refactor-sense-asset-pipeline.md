# 工作指令：内容生产管线重构（原子 Program → 可增量资产集合）

> 交接人：架构评审
> 执行者：coding agent
> 日期：2026-08-15
> 前置阅读：`CONTEXT.md`、`AGENT.md`、`docs/experience-compiler-v1.md`

---

## 0. 一句话任务

把 `tools/experience_compiler.py` 当前"一次编译产出一个不可分割 ExperienceProgram"的原子管线，
重构为**一个 semantic contract 上游 + 多个可独立运行、可独立重跑、可追加的 producer**，
并新增 boundary（义项对辨析）这一类现有结构装不下的一等资产。

**这次任务只改生产管线。不扩产内容，不改 App，不重写 prompt 文案。**

---

## 1. 为什么要做（不要跳过，这决定了取舍）

当前 `compile_experience_program(sense) → program` 是全或无的原子操作。在只有 4 个义项时无所谓，
扩产时每一条都是硬伤：

1. **无法增量补充**。想给存量 program 多加 4 条 review 场景，必须重跑整个四阶段，
   把已经审过的 units 全部作废重来。
2. **boundary 装不下**。义项辨析属于**一对 sense**，不属于任何单个 program，
   现有结构里没有它的位置。
3. **质量门是整体 verdict**。任一阻塞维度不过，整个 program 不返回——
   transfer 单元写砸了会连带丢掉已经很好的 anchor/variation。
4. **没有 stale 追踪**。`semantic_model` 埋在 program 内部，改了词义规格之后，
   没有任何机制能告诉你哪些下游资产失效了。

重构的目标是**可增量性**，不是"字段更完整"。如果最终只是把 program 改名叫 package
再加几个空数组，这次重构就是失败的。

**时机说明**：现在正式内容只有 4 个义项，schema 变更后全量重跑的成本约等于零。
这是唯一的低成本窗口，所以允许做结构性改动。

---

## 2. 现状事实（已实测，不需要重新调研）

### 2.1 内容存量

正式 bundle：`app/assets/content/experience-programs.v1.json`（87KB，4 个 program）

| program | units（roles） | review_pool | transfer unit | boundary |
|---|---|---|---|---|
| almost-01 | 4（anchor, variation, discrimination, transfer） | **2** | 1 | 0 |
| dirty-01 | 5（anchor, variation, variation, discrimination, transfer） | **2** | 1 | 0 |
| messy-01 | 4（anchor, variation, perturbation, transfer）| **2** | 1 | 0 |
| reluctant-01 | 5（anchor, variation, perturbation, discrimination, transfer） | **2** | 1 | 0 |

草稿：`data/drafts/experience-programs/{sense_id}/v01/`
词义源：`data/senses/{sense_id}.yaml`（4 个）

### 2.2 编译器

- `tools/experience_compiler.py`，1313 行，四阶段串行
- 对外只暴露三个接口：`compile_experience_program` / `validate_program` / `run_regression`
- prompts：`prompts/experience-compiler/{semantic-planner,program-planner,surface-generator,quality-gate}.md`

### 2.3 Schema 关键约束

`schema/experience-program.schema.json`：

- `units`: `minItems: 3`，item `$ref: #/$defs/experience_unit`
- `experience_unit.role`: enum `[anchor, variation, perturbation, discrimination, transfer]`，
  **但 description 明确写着"本契约不规定固定角色组合"**
- `review_pool`: `minItems: 1`，description 要求"必须使用首学未出现的新经验"
- `grounding` required: `source_experience_id, l2_realization, constructions, collocations`

### 2.4 下游消费方（本次不改，但产出要对得上）

`app/lib/features/journey_prototype/` 的 Journey 原型目前用三处凑合逻辑：

- `journey_session_view_model.dart:128` — boundary 场景**借用**新学义项的 `review_pool[0]`
- `views/boundary_task_view.dart:186` — 辨析解释是把两个义项各自的 `invariant` 并排显示
- `journey_session_view_model.dart:209` — 正确答案恒等于"新学的那个"

这三处凑合正是本次要生产的 boundary 资产要取代的东西。**本次不改 App**，
但产出的 boundary 资产结构必须能干净地喂给这三处。

---

## 3. 目标架构

```text
sense (data/senses/{id}.yaml)
  ↓
semantic_contract                 ← 独立资产，唯一上游权威，有 content hash
  ↓ （被下面所有 producer 消费）
  ├─ concept producer      → units + symbol_binding        （一次性）
  ├─ review producer       → review items                  （可追加 N 次）
  ├─ transfer producer     → transfer items                （可追加 N 次）
  ├─ grounding producer    → collocations / constructions   （一次性）
  └─ boundary producer(A,B) → 独立资产，key 是 sense 对，不属于任何单个 package
```

### 3.1 四个必须做到的设计点

**(1) contract hash 写进每个下游资产的 metadata**

hash 不匹配 = stale。不需要建依赖图，一个字段就够。
项目里已有这个模式：`tools/review.py` 的 `content_digest`。**直接复用，不要另造一套。**

**(2) producer 必须支持"追加"，不只是"生成"**

review producer 的能力应该是"再产 N 条，避开已有这些 surface dimension / 已有这些场景"。
这是扩产刚需：先产 4 条上线，用完再补，而不是一次性把成本压在前面。
现有 `tools/draft.py` 的 `scenes <id> --add <type>` 已经是这个思路，**参考它，做成通例**。

**(3) 质量门从整体 verdict 改为逐资产 verdict**

concept_program 没过闸不应该连累已经通过的 review items。
gate 维度按资产类型裁剪——boundary 该查的维度和 concept program 不是一套。

**(4) boundary 是一等资产**

- 存储：`data/boundaries/{sense_a}__{sense_b}.yaml`（sense id 字典序排列，保证唯一 key）
- 输入：两个 sense 的 semantic_contract
- 产出至少包含：
  - **最小对立对场景**：两个义项都"像"、但只有一个成立的场景。
    **不是**从任一义项的 review_pool 里挑一条干净正例。
  - **诊断维度**：沿同一维度对比（例：dirty = contamination / messy = disorder）。
    **不是**把两个 invariant 并排放。
  - **双向判定项**：正确答案必须两个方向都有，不能恒等于某一侧。
    （现在 App 里恒等于"新学的那个"，学习者做两次就学会规律，任务失效。）

---

## 4. 一个已定的设计决策（不要自作主张改）

**units 的自由角色组合是刻意设计，保留。**

schema 里 `role` 有 enum 但不强制组合，description 两处明说这是有意的。
这个决策有道理：标量程度词和心理状态词的教学路径本来就不该一样，
强行要求每个 program 都有 discrimination 只会产出凑数的劣质单元。

因此：**不要加"每个 program 必须含 discrimination"这类约束。**
辨析能力由独立的 boundary 资产提供，不依赖 program 内部恰好有 discrimination unit。

---

## 5. 分步任务

每一步结束时 `run_regression` 必须通过。不允许出现"重构中途 regression 挂着，最后一起修"。

### Step 1 — semantic_contract 上提

- 把 `semantic_model` 从 program 内部抽出为独立资产（建议 `data/contracts/{sense_id}.yaml`，
  若与现有 `contracts/` 目录冲突，另择路径并在 PR 说明里写清楚）
- 为 contract 计算 content hash（复用 `review.py` 的 digest 方式）
- program 内保留 `semantic_model` 字段以兼容现有 App（**App 本次不改**），
  但它变成 contract 的投影而非权威副本，并在 metadata 记录来源 contract 的 hash

### Step 2 — producer 拆分（对外接口不变）

- `compile_experience_program` **签名和行为不变**，变成"装配全套"的便利门面
- 内部拆成上述五类 producer，各自可独立调用
- **先定 producer 接口、用现有四阶段实现填进去，再逐个替换实现。不要一上来重写 prompt。**

### Step 3 — review / transfer producer 支持追加

- 提供"给已有资产追加 N 条"的能力，输入包含已有条目以便避重
- `review_pool` schema `minItems` 由 1 提升至 **6**；transfer items 目标 **3** 条
- 为 4 个现有义项补齐到新下限（这是重跑，不是扩产——不要新增义项）

### Step 4 — boundary producer + 资产

- 按 §3.1(4) 实现
- 第一对做 **dirty-01 ↔ messy-01**（Journey 原型正在用这一对，产出可立即被验证）
- 新建 `schema/boundary-package.schema.json`

### Step 5 — 质量门逐资产化

- gate 结论按资产粒度记录，不再是单一整体 verdict
- 维度集合按资产类型裁剪
- 保持"结论写入 metadata、不泄漏进 learner-visible 内容"这条现有纪律

### Step 6 — 重新导出 bundle

- 用 `tools/build_experience_app_bundle.py` 重新生成 `app/assets/content/experience-programs.v1.json`
- 确认 `app/test/` 下现有测试全部通过（尤其 journey 相关 4 个测试套件）

---

## 6. 必须保留，不得丢失

1313 行里有些不显眼但很值钱的东西，重构最大的风险就是把它们弄丢：

- `_check_l2_leakage` + `_neighbor_symbols` — 揭示前不泄漏目标词**及邻近 L2 词**。
  这是 SceneLex 独有机制，重建很难。
- `_changed_variable_visible` — 声称改变的变量必须在表面可观察，
  防"语义计划与表面文本脱节"。
- `_structure_signature` / `run_regression` — 重构期间唯一能证明没退化的东西。
- 四阶段的语义链路本身（semantic planner → program planner → surface generator）
  和九维质量门的维度定义。**这些是资产，不是要被替换的旧代码。**

---

## 7. 明确不做

- ❌ 不扩产内容（不新增义项，Step 3 的补齐是对现有 4 个义项重跑）
- ❌ 不改 App（`app/` 下只允许因 bundle 重新导出而变化的内容，以及必要的测试修复）
- ❌ 不做 audio / TTS。音频是文本的函数，文本还要改，现在产音频等于按次烧钱
- ❌ 不做 example_pool。它和 review item 的职责边界尚未厘清
  （review item 要学习者做判断，example 只是给他看，质量标准不同），
  贸然建会产出两套内容、双倍成本
- ❌ 不做 authentic corpus
- ❌ 不重写 prompt 文案（Step 2 明确要求先接口后实现）
- ❌ 不改 `units` 的自由角色组合决策（见 §4）

---

## 8. 完成标准

1. `run_regression` 通过
2. 4 个现有义项可从 contract 出发重新装配出完整 program，且 `validate_program` 无阻塞诊断
3. 能对任一现有义项**单独追加** review items，且不触发 units 重新生成
4. `dirty-01 ↔ messy-01` 的 boundary 资产已产出并通过其质量门，
   内容满足 §3.1(4) 三项要求（最小对立对 / 诊断维度 / 双向判定）
5. 修改任一 sense 的 contract 后，其下游资产能被识别为 stale
6. bundle 重新导出，`app/test/` 全绿
7. `CONTEXT.md` 的领域语言更新：新增 semantic contract、producer、boundary package 的定义条目

---

## 9. 遇到以下情况停下来问，不要自行决定

- 需要修改 `compile_experience_program` / `validate_program` / `run_regression` 的对外签名
- 发现必须改动 `units` 自由角色组合的决策才能推进
- boundary 的最小对立对在现有 semantic contract 信息量下无法稳定生成
  （这会反过来要求 contract 增加字段，属于上游变更，需要确认）
- review_pool 提升到 6 条后，生成质量或过闸率显著下降
- 单义项编译成本（token / 时长）出现数量级变化

---

## 10. 顺带记录（下一个任务，本次不做）

管线重构完成后的下一步是让 App 侧消费 boundary 资产，
拆掉 `journey_session_view_model.dart` 里那三处凑合逻辑。
本次产出的 boundary schema 应当预先考虑这个消费场景。
