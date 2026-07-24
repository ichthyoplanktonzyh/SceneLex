# SceneLex — 数据模型与不变量

> 最后更新：2026-07-24

## 权威链

```text
DictionaryEvidence
→ SenseInventory
→ WordSense
→ SceneSpec
→ ShotPlan
→ KeyframePlan
→ ImageKeyframeManifest
→ ImageKeyframeEditRun
→ MotionDirective / VideoRun (待建最小契约)
```

## 核心实体

| 实体 | 身份/绑定 | 职责 |
|---|---|---|
| SenseInventory | word + dictionary entry IDs | 冻结 SceneLex sense 身份 |
| WordSense | `{word}-{nn}` | 定义词义、条件、关系与可观察要求 |
| SceneSpec | `{sense_id}-{type}-{nn}` | 定义模型无关教学场景证据 |
| ShotPlan | Scene + Sense revision | 决定镜头与叙事执行 |
| KeyframePlan | Shot Plan version | 选择必要视觉状态与时间位置 |
| SourcePacket | keyframe + frozen upstream | 确定性编译输入 |
| RenderDirective | keyframe + compiler attempt | 物理明确的图片编辑 IR |
| ImageKeyframeEditRun | Shot/KF/source versions | 记录生成、选择、VLM 与人工 Gate |
| MotionDirective | Shot + approved keyframe inputs | 定义一个 Motion Segment 的动作与时序约束 |
| VideoRun | Motion Directive + provider request | 记录视频生成、选择与人工 Gate |

## 当前 Schema

| Schema | 版本 | 状态 |
|---|---:|---|
| `sense-inventory.schema.json` | 1.0 | stable |
| `word-sense.schema.json` | 1.0 / 1.1 | stable |
| `scene-spec.schema.json` | 1.0 / 1.1 | stable |
| `resource-bundle.schema.json` | 1.0 | stable |
| `shot-plan.schema.json` | 1.0 | active internal IR |
| `keyframe-plan.schema.json` | 1.0 | active internal IR |
| `image-keyframe-manifest.schema.json` | 1.0 | active draft manifest |
| `image-render-source-packet.schema.json` | 1.0 | active compiler IR |
| `image-render-directive.schema.json` | 1.0 | active compiler IR |
| `image-keyframe-edit-run-v1.1.schema.json` | 1.1 | active experiment manifest |
| `director-prompt.schema.json` | 1.0 | legacy |
| `render-plan.schema.json` | 1.0 | legacy |

## 版本与身份

- Sense ID 与 Scene ID 是稳定引用，重命名或重新编号是兼容性变更。
- 新 WordSense 只能由 approved Inventory 分配身份。
- WordSense `semantic_revision` 表示语义契约修订，不等于普通资源 `version`。
- SceneSpec 1.1 用 `sense_revision` 绑定 WordSense 语义修订。
- Shot Plan 只能从 `CURRENT` SceneSpec 1.1 编译。
- Keyframe Plan、Image Manifest 和 Edit Run 必须显式绑定上游版本。
- 历史目录永不覆盖。

## 资源状态

| 状态 | 含义 | 可导出 |
|---|---|---|
| `draft` | 未完成或未审核 | 否 |
| `reviewed` | 语义资源经人工审核 | 是 |
| `published` | 所需媒体与追溯、QC 均完整 | 是 |
| `deprecated` | 保留引用兼容，不再使用 | 否 |

媒体实验中的 Gate 不等于资源状态。一个 Edit Run 可以保持 `draft`，同时记录某次
Generation Gate 或 Semantic Gate；只有完整发布流程才能令资源成为 `published`。

## Edit Run Gate

`api_gate` 是 v1.1 的历史字段名，规范含义是 Generation Gate：

- `pass`：每个 target 都有一个被 `selected_attempt` 选中的 `generated` 绑定产物；
- `blocked`：存在记录化 `failed` attempt，且整批未达到 pass；
- `pending`：整批未达到 pass，但没有记录化失败。

`semantic_gate`：

- `not_run`：没有绑定 `selected_attempt`；
- `pending`：已有绑定候选，等待整批人工审核；
- `revision_required`：人工判定至少一个关键要求不成立；
- `pass`：Generation Gate 已 pass，且人工判定整批可进入下游。

VLM 只能写 `reviews.vlm.suggested_verdict`。最终 Gate 只读
`reviews.human`；`semantic_gate` 由这些记录确定性推导。人工结论通过
`tools/image_keyframe_edits.py review-human` 写入，不能只改顶层 Gate。

## 绑定产物不变量

一个生成图片只有同时满足以下条件，才是 Bound Artifact：

1. 出现在某个 attempt 的 `image` 字段；
2. attempt 记录模型、prompt、request ID、seed 与状态；
3. attempt 绑定 Render Directive；
4. target 通过 `selected_attempt` 明确选择它；
5. 文件实际存在。

目录中存在但不满足上述条件的图片是 unbound artifact，只能作为诊断材料，不能进入下游或计入 Gate。

## 语义内容不变量

- 词义条件与具体人物、地点、文化脚本和模型解耦。
- SceneSpec 的 storyboard 是 Semantic Beat，不是 Shot。
- 心理、意图与逻辑必须通过行为、目标、压力、结果、视线或时序外化。
- 对比关系必须如实表达包含、重叠、程度或维度，不默认互斥。
- Transfer 场景至少改变两个表面维度。
- 悬空义项引用是允许的 backlog，不得为清零而虚构资源。
