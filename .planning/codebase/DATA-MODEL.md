# SceneLex — 数据模型与不变量

> 最后更新：2026-07-16
> 记录 Schema 版本、关键数据实体、ID 规则和不变量

## Schema 版本

| Schema | 版本 | 状态 |
|---|---|---|
| `word-sense.schema.json` | 1.0 | stable |
| `scene-spec.schema.json` | 1.0 | stable |
| `resource-bundle.schema.json` | 1.0 | stable |

## 核心实体

### WordSense（词义）

文件：`data/senses/{sense_id}.yaml`，Schema：`word-sense.schema.json`。

**身份**：`{word}-{nn}`，例如 `reluctant-01`、`run-03`。

**关键字段**：

| 字段 | 说明 |
|---|---|
| `semantic_skeleton` | 深层语义假设：participants + propositions，与具体渲染解耦 |
| `conditions` | required（必要条件）+ excluded（排除条件及替代义项） |
| `relations` | synonyms/antonyms/hypernyms/hyponyms/confusables/boundaries/l1_confusables |
| `semantic_type` | 12 类"意义如何被感知"的分类，决定场景设计策略 |
| `scene_requirements` | must_show / must_not / externalization / timing |

### SceneSpec（场景规格）

文件：`data/scenes/{sense_id}/{sense_id}-{type}-{nn}.yaml`，Schema：`scene-spec.schema.json`。

**身份**：`{sense_id}-{type_abbr}-{nn}`，例如 `reluctant-01-proto-01`。

**五种场景类型**：

| 类型 | 缩写 | 职责 |
|---|---|---|
| prototype | proto | 建立概念，典型、清晰、低歧义 |
| contrast | contrast | 区分相邻概念，必须声明 `contrast_relation` |
| boundary | boundary | 测试临界、包含或偏好 |
| counterexample | counter | 证明某些线索不足以支持目标义项 |
| transfer | transfer | 跨至少两个表面维度验证泛化 |

**关键字段**：

| 字段 | 说明 |
|---|---|
| `sense_ref` | 关联义项 ID |
| `contrast_target` | 对比/边界/反例场景中被指向的替代义项 |
| `contrast_relation` | 与 contrast_target 的真实逻辑关系（7 种枚举） |
| `transfer_dimensions` | 迁移场景相对原型改变的表面维度（≥2） |
| `teaching_evidence` | 场景中可观察线索对词义命题或边界判断的支持关系 |
| `storyboard` | 分镜数组：beat → visual + audio + purpose |
| `learning_tasks` | 五种任务类型：scene_recognition / contrast_choice / listen_and_match / produce / transfer_judgment |

### ResourceBundle（资源包）

文件：由 `tools/export.py` 生成，Schema：`resource-bundle.schema.json`。

**结构**：package 元信息 + senses[] + scenes[] + index（按 word 查 sense_ids，按 sense 查 scene_ids）。

**发布状态**：只包含 `reviewed` 与 `published`，不包含 `draft`。

## ID 规则（不变量）

- 义项 ID：`{word}-{nn}`，小写字母和下划线，两位数字。例如 `messy-01`、`run-03`。
- 场景 ID：`{sense_id}-{type_abbr}-{nn}`。例如 `reluctant-01-proto-01`。
- ID 是稳定引用，重命名或重新编号是兼容性变更。
- 文件名必须等于 ID：`{sense_id}.yaml`，`{scene_id}.yaml`。

## 状态枚举

| 状态 | 含义 | 可导出 |
|---|---|---|
| `draft` | 起草中，未审核 | 否 |
| `reviewed` | 专家审核通过，未经过学习实验 | 是（默认导出包含） |
| `published` | 实验验证通过，来源可追溯 | 是 |
| `deprecated` | 已废弃，保留引用兼容 | 否 |

## 内容不变量

1. `semantic_skeleton.propositions` 必须 ≥ 2 个命题，共同定义义项成立。
2. `conditions.required` 必须 ≥ 1 条必要条件。
3. `conditions.excluded` 只填真正不适用的情况。包含、重叠、程度差异或不同维度不得伪装成排除条件。
4. `relations.boundaries` 必须为每个 target 显式声明 `relation` 枚举值，不能默认互斥。
5. `l1_confusables` 记录真实的 L1→L2 概念边界错位，不写成简单双语对照表。
6. 心理、意图和逻辑等不可直接看见的意义，必须通过可观察的行为、目标、压力、结果、视线、时间过程或事件关系外化。
7. 对比场景（`scene_type=contrast`）必须填写 `contrast_target` 和 `contrast_relation`。
8. 迁移场景（`scene_type=transfer`）必须填写 `transfer_dimensions`（≥2 项）。
9. 原型场景通常遵循"先概念体验、后目标声音命名"的声画顺序。
10. `storyboard` 必须 ≥ 2 个节拍。
11. `learning_tasks` 必须 ≥ 1 个任务。选择题必须有 `choices` 和 `expected_answer`，开放输出必须有 `scoring_note`。

## YAML 格式约定（见 CONVENTIONS.md）

- 无引号标量不要包含 ASCII `": "`。
- 含英文台词时使用双引号或块标量。
- 缩进使用 2 空格。

## 悬空引用

- 义项中可以引用尚未创建的义项 ID（如 `relations.confusables`）。
- 场景中引用的 `sense_ref` 必须是已存在的义项。
- 悬空义项引用是可接受的 backlog 信号，不要为消除校验器 backlog 而虚构低质量义项。
