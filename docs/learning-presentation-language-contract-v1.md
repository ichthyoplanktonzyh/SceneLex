# Learning Presentation Language Contract v1

> 语言呈现合同：规范“在目标 L2 符号绑定之前，learner-visible 内容使用什么语言”。
> 本文件是编译器、质量门、App 渲染与内容迁移的共同依据。

## 0. 定位与问题

ExperienceProgram 的 `semantic_model`、`units`、`symbol_binding`、`grounding`、
`review_pool` 与 Boundary Package 的 `minimal_pairs` 都是**面向学习者的呈现内容**。
在符号绑定（首次展示目标 L2 拼写与发音）之前，若用英语向中文母语者解释英语场景，
实际形成“L2 解释 L2”——学习者被要求先理解目标语言才能学习目标语言。

本合同 v1 规定：对 `zh-CN` 母语学习者、目标 L2 为 `en` 的所有学习内容，
绑定前呈现一律使用**中文经验叙事或非语言资产**；绑定后逐步引入目标 L2。

## 1. 学习者与目标

| 字段 | 值 | 说明 |
|---|---|---|
| `learner_l1` | `zh-CN` | MVP 固定支持的唯一 L1 |
| `target_l2` | `en` | MVP 固定支持的唯一目标语言 |
| `policy_version` | `1` | 合同版本；程序与 boundary 必须声明 |

未来扩展其他 L1 时，合同按语言对复制并独立评审；本版本不做多语言平台。
App locale（ARB）只负责 UI 文案，**与学习内容的语言政策无关**。

## 2. 呈现阶段

### 2.1 pre_binding（绑定前）

- 适用资产：concept units（含 role=transfer 的揭示前单元）、boundary minimal
  pair 的 `experience`（场景、证据、维度）。
- **必须为 L1**：`episode`、`observable_evidence`、`surface_dimensions`
  （name/baseline/deviation）、`interaction.question`、`answers.text`、
  `answers.feedback`、`explanation`。
- 允许：中文描述可观察的场景、动作、变化、空间关系与结果；中文问题、选项与
  反馈；图片、动画与非语言交互；必要的专有名词、数字、单位与极少量符号。
- **禁止（L2 leakage）**：目标 lemma 及其屈折、派生形式；相邻/易混淆 L2 词
  （WordSense relations 中声明的 confusables/synonyms/antonyms/hyponyms 等）。
- **禁止（L1 label leakage）**：直接给出等价中文标签作为定义或答案
  （如“messy 就是凌乱的”“她是不情愿的”）；使用一个中文单词替代场景经验。
  中文只能**描述经验**，不能**命名概念**。

### 2.2 symbol_binding（符号绑定）

- 适用资产：`symbol_binding.reveal`。
- **第一次**出现目标 L2：`l2_word` + `ipa`（本阶段必须恰好首次出现）。
- `presentation` 可以用 L1 说明“把刚才的经验命名为这个符号”。
- `minimal_l1_gloss` 只作**确认**（如“几乎”），不作展开定义；它不得被复制到
  任何绑定前字段。

### 2.3 early_post_binding（绑定后早期）

- 适用资产：review_pool items、boundary 的 `interaction` 与 `explanation`。
- L1 场景或指令 + **已绑定**的目标 L2 符号。
- Review：场景、证据、维度为 L1；reveal 前不得出现目标 L2（复习是反向回忆）。
- Boundary：场景与反馈为 L1；选择项可以显示已绑定的 L2 lemma
  （必须是两个已绑定 sense 的合法符号）；不得把整段解释写成英语。
- review item 可声明 `scaffold_level`（默认 `early_post_binding`），为将来
  脚手架衰减预留表达；MVP 不实现衰减算法。

### 2.4 later_post_binding（绑定后后期）

- 适用资产：`grounding`。
- 保留合同表达能力：为将来逐步转向 mixed/L2-only 预留。
- MVP：grounding 必须实际包含目标 lemma 或其被允许的自然词形，句子为自然 L2
  realization（学习者刚经历过该场景）。

## 3. 术语定义

- **L2 leakage**：绑定前 learner-visible 字段中出现目标 L2 词（含屈折/派生
  形式）或相邻/易混淆 L2 词。
- **L1 label leakage**：绑定前字段中直接使用中文等价标签来定义、命名或充当
  答案，例如“脏乱就是 messy”“他不情愿”，或把 minimal_l1_gloss 原样复制到
  绑定前字段。允许的是**描述**（“东西散在桌上，抽屉也开着”），不是**命名**。
- **成段英语**：一段 learner-visible 文本主要由拉丁字母词构成（见确定性
  检查规则），而不是必要的专有名词、数字与单位。

## 4. 各资产的语言规则速查

| 资产 | 阶段 | episode/evidence/dimensions | question/answers.text | feedback/explanation | 目标 L2 |
|---|---|---|---|---|---|
| concept unit | pre_binding | L1 | L1 | L1 | 禁止 |
| transfer unit | pre_binding | L1 | L1 | L1 | 禁止 |
| symbol_binding.reveal | symbol_binding | — | — | — | 首次出现 |
| minimal_l1_gloss | symbol_binding | — | — | — | —（L1 确认词） |
| grounding | later_post_binding | — | — | — | 必须包含（自然词形） |
| review item | early_post_binding | L1 | —（自评，无选择题） | — | reveal 前禁止 |
| boundary experience | pre_binding | L1 | — | — | 禁止（两个 lemma 均禁） |
| boundary interaction | early_post_binding | — | 选项=已绑定 L2 lemma | L1 | 选项允许；正文禁止 |
| boundary explanation | early_post_binding | — | — | L1 | 禁止 |

内部字段（`semantic_spec`、`semantic_model`、contract、gate notes、metadata）
**不受本合同的 learner-visible 语言规则约束**；它们是教学者/编译器层面语言。

## 5. App 职责

App 只**渲染**已经符合本合同的程序；App 不做运行时翻译，也没有“把英语内容
翻成中文”的能力。内容语言由内容侧（Compiler）保证，UI 文案语言由 ARB 保证，
两者互不替代。

## 6. Schema 表达

- `ExperienceProgram` 顶层声明 `language_policy: {policy_version, learner_l1,
  target_l2}`，并保留 `target.locale_l1`（简写，必须与 `learner_l1` 一致）。
- `BoundaryPackage` 声明相同 `language_policy`。
- review item 可选 `scaffold_level`。
- 不再在单个字符串上重复 locale。

## 7. 兼容策略（可删除）

- 旧 fixture（无 `language_policy`）按 **legacy v0** 处理：语言不受约束，App
  不得渲染。`language_policy` 缺失在确定性校验中直接失败——**不静默猜测**。
- 迁移：为程序显式添加 `language_policy` 并把绑定前内容迁移为 L1 后，才可
  重新进入 bundle。迁移完成后本策略可整体删除。
