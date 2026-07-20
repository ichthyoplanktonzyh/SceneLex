# reluctant-01-proto-01 vertical slice

> 状态：2026-07-20。仓库第一条真正走完
> `Approved Inventory → WordSense 1.1 → SceneSpec 1.1 → Shot Plan` 的链路。
> 本记录的目的不是宣布这层做完了，而是留下判断"要不要进入 Keyframe / Animatic"
> 所需的真实证据。

## Inputs

| 环节 | 产物 | 说明 |
|---|---|---|
| Approved Inventory | `data/inventories/reluctant.yaml` | 仓库第一个 approved Inventory；`inventory_version: 1`，2 条词典证据，1 keep + 1 defer |
| Dictionary evidence | `data/dictionary-evidence/reluctant.yaml` | 冻结 snapshot，`evidence_digest: sha256:bfc8a93a…` |
| WordSense | `data/senses/reluctant-01.yaml` | `schema_version: 1.1`、`version: 1`、`semantic_revision: 1` |
| SceneSpec | `data/scenes/reluctant-01/reluctant-01-proto-01.yaml` | `schema_version: 1.1`、`sense_revision: 1`、修订状态 `CURRENT` |
| Shot Plan | `data/drafts/shot-plans/reluctant-01-proto-01/v01/shot-plan.yaml` | v01，`scene_version: 1`、`sense_revision: 1` |

被 defer 的是正则语义（"Tending to match as little text as possible"）——缺例句、
领域特定，不构成可教学义项。Inventory 把它挡在链路之外，这一步按设计工作。

## Resulting shot structure

- Beat count: **4**
- Shot count: **3**
- Total duration: **10.5s**（2.5 + 5.0 + 3.0）

| Shot | Beats | narrative_function | 时长 | 构图 |
|---|---|---|---|---|
| shot-01 | 1 | `establish_trigger` | 2.5s | medium_wide / eye_level |
| shot-02 | **2, 3** | `semantic_climax` | 5.0s | medium / over_shoulder |
| shot-03 | 4 | `confirm_outcome` | 3.0s | medium_wide / eye_level |

场景内容：饭桌上妈妈要求孩子吃一口西兰花；孩子皱眉、后靠、视线回避、动作延迟，
最终仍然吃了极小的一口，抵抗贯穿整个动作。

## What worked

**1. Shot 拆分不是机械对应 Beat。**
Director 把 beat 2（抵抗外化）与 beat 3（行动仍然发生）合并进同一个 5 秒镜头。
这是本次最重要的正面结果：这两个 Beat 属于同一段连续动作、同一主体、同一空间，
中间切一刀恰好会破坏"抵抗贯穿行动"这一核心语义证据。合并有真实观察理由，
不是为了展示"Beat 与 Shot 不必一一对应"而硬凑。两处切镜也各有构图理由
（建立要求 → 贴近观察微表情 → 拉开呈现目标词）。

**2. 语义没有塌成 refuse。**
孩子最终执行了动作，抵抗以延迟、停顿、最小接触呈现，而不是拒绝。
learning_task 的三个选项正好是 refuse / reluctant / eager 的三分，
判据写在 `scoring_note` 里，可机器评分。

**3. 删掉台词后语义仍然成立。**
shot-01 的要求由"妈妈指向西兰花"承载；shot-02 全程无台词。
去掉全部音轨后，`请求 → 身体抵抗 → 仍然执行` 的证据链完整。

**4. 摄影机没有被模型习惯性加戏。**
三个镜头全部 `movement: static`，没有出现无动机的 push-in / pan / tracking。
`camera.motivation` 也不是套话（"静态让观众专注于微表情"是真实理由）。

**5. continuity 足以推导首尾状态。**
`exits_to_next` 与下一镜头的 `enters_from_previous` 在三个镜头间严格衔接
（后靠皱眉 → 后靠皱眉；叉子放下、嘴角下撇 → 叉子放下、嘴角下撇）。
顶层 `cast` / `location` / `props` 的 `continuity_description` 提供了人物外观、
座位关系与道具位置，关键帧的首尾状态基本可以推导。

## Problems observed

**P1（非阻塞）· shot-02 的 trigger 是心理描述，不是可观察事件。**
实际产出：`Child processes the request and begins to act despite internal resistance.`
schema 对 `trigger` 的定义是"使镜头状态发生变化的**可观察事件**"，这句话违反了
schema 自己写明的意图，却能通过类型校验。这是提示词问题，不是 schema 问题。

**P2（非阻塞）· shot-03 的 trigger 是模板话术。**
实际产出：`No new trigger; the action is complete.`
但 schema 对 trigger 的描述明确写着"纯建立镜头写明没有新触发事件, 但不得省略"——
这是**设计如此**，不是缺陷。记录在此是为了说明：预判中的"No new trigger 废话"
确实出现了，但它是被规范要求的，不构成改 schema 的理由。

**P3（非阻塞）· 全局禁令被逐镜头复述。**
`Any external force or prohibition` 同时出现在 shot-01 与 shot-02 的 `must_avoid`。
它来自 WordSense 的 `scene_requirements.must_not`，是整场约束，不是单镜头约束。
Shot 层缺少"继承场景级禁令"的表达方式，模型只能逐条复制。

**P4（非阻塞）· shot-01 把台词标成 `required_dialogue`，理由不成立。**
它给出的 `purpose` 是"没有口头指令观众就无法知道要做什么"，但**同一个镜头**的
`action` 里妈妈正指着西兰花。SceneSpec 本就是按"无台词也成立"设计的，
Shot Plan 却把台词升级成必需。这是 Shot 层与 Scene 层设计意图的冲突。

**P5（非阻塞）· 语义有向"厌恶食物"漂移的风险。**
shot-02 / shot-03 反复出现 `distaste` / `disgust`。reluctant 的证据应当是
"不愿意执行动作"，而不是"不喜欢这个食物的味道"。真正的抵抗证据（延迟、停顿、
最小接触）是充分的，但吞咽后的嫌弃表情把重心往 taste aversion 拉。
西兰花题材天然带这个风险，换题材或收紧措辞都能缓解。

**P6（非阻塞）· `must_show` 里出现"看不见的东西"。**
shot-01 的 `No immediate positive response from child` 是一个"缺席"。
`must_show` 应该是可拍摄的正面画面，缺席无法被拍出来，也无法被审核。

**P7（观察，非缺陷）· continuity 与 visual_end 大量重合。**
`exits_to_next` 基本是 `visual_end.description` 的改写。目前不算废话——它承担
跨镜头核对的职责，且与下一镜头的 `enters_from_previous` 形成双向校验——
但如果后续证明它从不提供新信息，可以考虑由程序推导而不是让模型重写。

## Schema/tool changes made

本 PR **没有修改 shot-plan schema**。

特别说明 `must_avoid` 的 `minItems: 1`：预设怀疑它会逼出模板废话，真实产物
**不支持**这个怀疑——三个镜头的 `must_avoid` 都是有内容的（"大口吃"、"动作迅速"、
"吃完后表情变高兴"都是真实的语义边界保护）。唯一的问题是 P3 的全局禁令复述，
那是"缺少继承机制"，不是"被 minItems 逼着编"。没有证据就不动 schema。

为跑通链路所做的最小修复（都是真实缺陷，不是为本任务开的口子）：

1. **`tools/dictionary.py`：词典用例归一化为文本。**
   kaikki 的 `examples` 是对象（`{text, type, bold_text_offsets, ref}`），
   而 evidence snapshot 的 schema 要求字符串数组。仓库里 11 个缓存词典文件
   **全部**是对象形态，测试 fixture 却是字符串——所以这条链路从未在真实词典
   数据上跑通过，`data/inventories/` 一直是空的。新增 `_example_texts()`
   在唯一的抽取处归一化。

2. **`tools/wordbook.py`：标量字段改用 yaml 序列化。**
   `write_word_entry` 用 f-string 插值，把 `schema_version: "1.0"` 写成裸
   `1.0`，读回来是 float，过不了 `word-entry.schema.json` 的字符串常量。
   promote 的发布前全量校验因此整体失败。新增 `_scalar_line()`。

3. **`tools/draft.py promote --replace`。**
   promote 拒绝覆盖已发布资源，而本切片需要把同一个 sense ID 的 legacy 1.0
   资源升级为 1.1。`--replace` **只**放宽"目标已存在"这一条，隔离目录全量校验
   一律照跑，与 `inventory.py approve --force` 同义。缺省 False，且进程内直接
   调用（无该属性）也不会意外获得覆盖能力。

内容侧的人工审查修正（WordSense 起草稿 → 定稿）：

- definition 原文用 "visible reluctance" 定义 reluctant，循环定义，已重写；
- `frequency` 模型给的是 `band: high / rank: 3500`，与仓库自带的
  `data/wordlists/en-top-20000.tsv` 不符（真实 rank 9349），已改为 `low / 9349`；
- 补上 refuse / 单纯缓慢 / 未理解请求 / 泛化恐惧 四条 exclusion；
- 补 `refuse-01` 边界。模型最初没有这条边界，而它正是本切片要检验的核心区分；
- `hesitant-01` 从模型给的 `degree_neighbor` 改回 `overlaps`，
  `refuse-01` 从我初稿的 `mutually_exclusive` 改为 `different_dimension`。
  后者是我自己的判断错误：refuse 是**行为**，reluctant 是**意愿状态**，两者可以
  共现，legacy 1.0 在这一点上的推理比模型和我的初稿都更准确。

## Deferred issues

- **P1 / P4 的提示词修正**：一个样本不足以支撑对 `prompts/shot-plan.md` 动刀。
  再积累 2–3 条真实 Shot Plan，确认这两个失败模式是否稳定复现。
- **P3 的场景级禁令继承**：需要 Shot 层能引用 Scene/WordSense 的全局 `must_not`，
  而不是逐镜头复制。这是表达机制问题，本 PR 不设计。
- **frequency 未与仓库自带词频表对齐**：`data/wordlists/en-top-20000.tsv` 就在仓库里，
  但 WordSense 起草让模型自己编 rank/band。这是可以程序化消除的幻觉面。
- **`data/words/` 未纳入版本控制**：promote 会生成它，但 `.gitignore` 没写、
  git 也没跟踪，状态含糊。
- **词典 quotation 类用例质量**：`_example_texts` 只做了文本归一化，没有区分
  `type: example`（现代用例）与 `type: quotation`（古旧文献引文）。reluctant 的
  证据里混进了 17 世纪引文。属于证据选择策略，不是本 PR 的 bug 修复范围。
- **其余 20 个 legacy 场景**：仍是 SceneSpec 1.0 / `LEGACY`，包括 reluctant 自己的
  另外 4 个场景。本轮不做批量迁移。
- **上游 WordSense 升级会使 legacy 兄弟场景失效**：本次把 reluctant-01 升到 1.1 时，
  `contrast_relation` 与新 WordSense 的边界关系冲突，promote 的发布前校验直接拦下。
  门禁工作正常，但说明"升级一个义项"的真实成本包含它的全部下游场景。

## Readiness for Keyframe design

**ready（有条件）。**

支持进入 Keyframe 层的证据：

- Shot 的 `visual_start` / `visual_end` 在三个镜头里都是**真正不同的状态**，
  不是同一句话的两次改写，可以直接充当关键帧的首尾锚点；
- `continuity` 链完整衔接，配合顶层 `cast` / `location` / `props`，
  人物位置、朝向、姿势与道具阶段可延续；
- 构图与摄影机是模型中立、风格中立的，没有混入 checkpoint、seed 或最终提示词；
- 三个镜头全部 static，对首版关键帧稳定性最友好——没有需要运动补偿的镜头。

进入 Keyframe 前应当先处理的（都不需要新架构层）：

- P1 / P4 属于 Shot Plan 内容质量，会直接污染关键帧提示词；
- P5 的语义漂移如果带进关键帧，会得到"讨厌西兰花的孩子"而不是"不情愿的孩子"。

明确**不**构成 ready 前提的：Character Bible、Location Bible、Prop Library、
Style Bible、Camera Preset Library。本次单场景的连续性信息由 Shot Plan 自带字段
承载已经够用，没有真实证据支持现在就建资源层。
