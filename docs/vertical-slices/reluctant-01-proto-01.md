# reluctant-01-proto-01 vertical slice

> 状态：2026-07-20（第二轮修订后）。仓库第一条真正走完
> `Approved Inventory → WordSense 1.1 → SceneSpec 1.1 → Shot Plan` 的链路。
> 本记录保留两轮结果：第一轮暴露的问题是第二轮修改的**证据**，因此不删除。

## Inputs

| 环节 | 产物 | 说明 |
|---|---|---|
| Approved Inventory | `data/inventories/reluctant.yaml` | 仓库第一个 approved Inventory；`inventory_version: 1`，2 条词典证据，1 keep + 1 defer |
| Dictionary evidence | `data/dictionary-evidence/reluctant.yaml` | 冻结 snapshot，`evidence_digest: sha256:bfc8a93a…` |
| WordSense | `data/senses/reluctant-01.yaml` | `schema_version 1.1`、`version 2`、`semantic_revision 1` |
| SceneSpec | `data/scenes/reluctant-01/reluctant-01-proto-01.yaml` | `schema_version 1.1`、`version 2`、`sense_revision 1`，状态 `CURRENT` |
| Shot Plan（推荐） | `data/drafts/shot-plans/reluctant-01-proto-01/v04/shot-plan.yaml` | 2 Shots / 7.3s |

被 defer 的是正则语义（"Tending to match as little text as possible"）——缺例句、
领域特定，不构成可教学义项。Inventory 把它挡在链路之外，这一步按设计工作。

`version` 与 `semantic_revision` 是两个概念：本轮修订了 WordSense 的措辞与场景约束
（`version` 1→2），但没有改变语义契约（`semantic_revision` 仍是 1），所以已绑定的
Scene 不会无谓地变成 `NEEDS_REVIEW`。

## First generated result（v01）

- 4 beats → 3 shots，10.5s
- 映射：shot-01←[1]，shot-02←**[2,3]**，shot-03←[4]

正面结果：Director 主动把 beat 2（抵抗外化）与 beat 3（行动仍然发生）合并进同一个
镜头——它们是同一段连续动作，中间切一刀会破坏"抵抗贯穿行动"这一核心证据。
三个镜头全部 `static`，没有习惯性 push-in / pan。

但 v01 有四类问题，全部属于**层级越界**或**语义漂移**：

**1. 教学 overlay 与旁白报词进入了叙事层。**
shot-03 的主要功能是揭词：屏幕浮现 `reluctant`、narrator 念出 "Reluctant."、
`must_show` 要求"目标词清晰可读"、`staging` 写 `added in post`。
这些属于后续音频/剪辑层，不是 Shot Plan 的职责。

**2. 台词被错误标记为不可替代的语义证据。**
shot-01 是 `required_dialogue`，`purpose` 写"没有口头指令观众就无法知道要做什么"——
但**同一个镜头**的 `action` 里妈妈正指着西兰花。判断与自身内容矛盾。

**3. trigger 是纯心理描述。**
shot-02：`Child processes the request and begins to act despite internal resistance.`
schema 对 `trigger` 的定义是"使镜头状态发生变化的**可观察事件**"，这句话拍不出来。

**4. reluctant 漂移成 dislike / disgust。**
shot-02 / shot-03 反复出现 `distaste`、`disgust`、`displeased chewing`，
并把"只咬极小一口"当作最强证据。观众第一个推断会是"这孩子讨厌西兰花"，
而不是"这孩子不愿意执行这个动作"。

（另有两处非阻塞观察：全局禁令 `Any external force or prohibition` 被两个镜头
逐条复述；`continuity.exits_to_next` 基本是 `visual_end` 的改写。见 Deferred。）

## Corrections made upstream

改的是**上游**，不是直接改 Shot Plan 产物——否则同样的问题下次还会生成出来。

**WordSense（`version` 1→2，`semantic_revision` 不变）**

- `scene_requirements.timing` 原文明确要求"在行为呈现后给出目标词（口播或叠字）"。
  **这正是 v01 揭词镜头的根因**——模型是照做的。改为只描述行为时序，并写明
  目标词呈现属于后续教学/剪辑层，不得设计进 beats。
- `must_not` 增加两条：感官厌恶不得成为主要证据（reluctant 是对**动作**的低意愿，
  不是对**物体**的厌恶）；不得出现以展示目标词/字幕/释义为目的的 beat 或 shot。

**SceneSpec（`version` 1→2，4 beats → 3 beats）**

- 删除 beat 4（揭词节拍）。
- beat 2 改为以行动阻力开头（停住 → 后靠 → 视线移开 → 伸手中途停顿），
  不再以"皱眉"领起。
- beat 3 去掉 `嫌弃`、`嘴巴下撇`，去掉"极小的一口"这个最易被读成挑食的表述；
  改为"自己吃下这一口、神情平淡、没有转为享受、身体仍稍微后靠"。
- `teaching_evidence` 与 `learning_tasks` 同步改写，判据明确写成
  "对动作的迟疑，不是对食物的厌恶"。

**Shot Plan prompt（`prompts/shot-plan.md`，只加约束不重写）**

1. `trigger` 必须是摄影机可拍到的事件或状态变化；给出心理动词黑名单
   （realizes / decides / processes / feels / understands / internal resistance）
   与一组正反例；语义判断写进 `semantic_function`，不写进 `trigger`。
2. 禁止教学包装进入 Shot Plan：不得设计以展示目标词、释义、教学字幕或旁白报词
   为主要目的的镜头；不得在 `composition` / `staging` / `must_show` 写
   `added in post`、`text overlay` 之类内容；**即使上游 SceneSpec 里有这样的 beat
   也不为它单开镜头**。
3. 视觉证据必须服务已批准的语义身份：disgust / fear / sadness / anger / dislike
   不得成为最强证据。判断方法是"静音只看画面，观众第一个推断出什么"。
4. `required_dialogue` 的判据：只有当行动、人物关系或话语功能**无法**从可见调度与
   动作中还原时才用；指示动作、道具摆放、视线、轮次交替已经让请求可理解时，
   一律是 `optional_dialogue`。

**第五条约束是被 v02/v03 逼出来的。**
修好上游后重新生成，v02 与 v03 连续两次退化成 3 shots / 一 Beat 一 Shot——
把 beat 2 与 beat 3 切开了。原因是 prompt 原有的"优先 2–5 秒、超过 5 秒通常该拆开"
在与语义连续性冲突时胜出，而合并后的抵抗弧约 8 秒。于是补充：
**语义连续性优先于时长偏好**——当"状态持续存在"本身就是词义证据时，
不要在证据中间切镜头，哪怕超过 5 秒。v04 随即合并成功。

## Revised result（v04，推荐版本）

- Beat count: **3**
- Shot count: **2**
- 映射：shot-01←[1]，shot-02←**[2,3]**
- Total duration: **7.3s**（2.5 + 4.8）
- Dialogue mode: shot-01 `optional_dialogue`（妈妈一句自然请求），shot-02 `silence`
- 目标词 overlay：**无**；narrator 报词：**无**

| Shot | Beats | narrative_function | 时长 | 构图 |
|---|---|---|---|---|
| shot-01 | 1 | `establish_trigger` | 2.5s | medium_wide / eye_level |
| shot-02 | **2, 3** | `semantic_climax` | 4.8s | medium / eye_level |

**静音播放是否仍然成立：是。**
shot-01 的请求由"妈妈伸手指向盘中西兰花 + 视线看向孩子"建立，台词只做自然化补充；
shot-02 全程无对白，证据是停住、后靠、视线移开、伸手中途停顿、送到嘴边再停顿、
平淡咀嚼、结束后身体仍后靠。

四项修正在 v04 中都成立：

- `trigger` 全部可观察（shot-02: `The mother's instruction has been delivered;
  child begins to respond with a full-body pause and a slight backward lean.`）；
- 感官厌恶从"要拍的证据"翻转成 `must_avoid` 守卫
  （`Child showing disgust (wrinkled nose, gagging)`）；
- 台词不再是 `required_dialogue`，`purpose` 如实写"指示动作已经传达了请求"；
- shot-02 的 `camera.motivation` 自己写出了合并理由：
  `any cut would break the evidence that the resistance lasted throughout the
  entire performance` —— 约束被理解了，不只是被满足了。

## 版本保留

四个版本全部保留，**不覆盖历史**：

| 版本 | Shots | 时长 | 作用 |
|---|---|---|---|
| v01 | 3 | 10.5s | 第一轮真实输出，四类问题的证据 |
| v02 | 3 | 11.5s | 上游修好后：overlay/旁白/required_dialogue/disgust 全部消失，但退化成一 Beat 一 Shot |
| v03 | 3 | 11.0s | 同上，确认 v02 不是偶然 —— 这两版共同证明时长规则压过了语义连续性 |
| v04 | 2 | 7.3s | 补充"语义连续性优先"约束后的产物，**推荐版本** |

`director.py show` 默认取最新版本，即 v04。

## What the vertical slice proved

- 真实的 `Inventory → WordSense → Scene → Shot Plan` 链路可以跑通，并且能在真实
  数据上暴露真实缺陷（本轮之前它从未在真实词典数据上跑通过）；
- **Beat 与 Shot 不必一一对应**，且合并需要被明确许可：模型在时长偏好与语义连续性
  冲突时会默认选时长，必须显式排序（v01 合并成功 → v02/v03 退化 → v04 修好）；
- `visual_start` / `visual_end` 是有用的：两轮产物里它们都是真正不同的状态，
  可以直接充当关键帧首尾锚点；
- 这个简单场景的 `continuity` 字段**已经够用**，不需要额外资源层；
- **上游修上游**：v01 的揭词镜头根因在 WordSense 的 `timing` 文案。只改 Shot Plan
  产物不会阻止它重新出现；
- prompt 需要更强的**层级边界**与**可观察性**规则，这两类约束无法靠 schema 表达
  （它们约束的是自由文本的内容，不是结构）。

## Schema / tool changes

**未修改 `schema/shot-plan.schema.json`，未修改 `must_avoid` 的 `minItems: 1`。**

`minItems: 1` 的原始怀疑（会逼出模板废话）两轮真实产物都不支持：v04 两个镜头的
`must_avoid` 都是有内容的语义边界保护。没有证据就不动 schema。

本轮只改了 `prompts/shot-plan.md`（加约束，未重写）与三份数据资源。
上一轮的工具修复（dictionary 用例归一化、YAML 序列化、`promote --replace`）保持不变。

## 测试

`tests/test_reluctant_vertical_slice.py` 新增的断言都是**针对真实数据的回归**，
不是通用自然语言 lint：

- 推荐版本自动取最新版本目录，不钉死 `v01`；
- Scene 的 beats 里不得再出现目标词揭示；
- 推荐 Shot Plan 不含 `overlay` / `added in post` / `narrator` / `on screen` 等教学包装；
- 不含 `required_dialogue`；
- `trigger` 不含心理动词黑名单词；
- `disgust` / `distaste` / `grimace` 等不得出现在"要拍的内容"里
  （出现在 `must_avoid` 里是允许的——那是在禁止它们）；
- prompt contract 静态断言：上述四类规则的关键词必须留在 `prompts/shot-plan.md` 里。

已验证这些断言在 v01 上**全部触发**，即它们确实能捕获第一轮的问题。

## Deferred

- **scene-level constraint inheritance**：全局禁令仍被逐镜头复述。需要 Shot 层能引用
  Scene / WordSense 的 `must_not`，属于表达机制设计，本轮不做。
- **其余 20 个 legacy Scene**：仍是 SceneSpec 1.0 / `LEGACY`，包括 reluctant 自己的
  另外 4 个场景。不做批量迁移。
- **frequency 未与仓库自带词频表对齐**：`data/wordlists/en-top-20000.tsv` 就在仓库里，
  起草却让模型自己编 rank/band（v1 编出 3500，真实 9349）。可程序化消除的幻觉面。
- **词典 quotation 选择策略**：`_example_texts` 只做文本归一化，未区分现代用例与
  古旧文献引文。
- **`data/words/` 未纳入版本控制**：promote 会生成它，`.gitignore` 没写、git 也没跟踪。
- **`continuity` 与 `visual_end` 重合**：目前承担跨镜头双向校验，暂不算废话；
  若长期不提供新信息，可考虑由程序推导。
- **`audio.mode: silence` 却带 `sfx` 列表**：v04 的 shot-02 如此，schema 允许，
  语义上略矛盾。非阻塞。
- **Character / Location / Prop / Style Bible、Camera Preset Library**：无证据支持现在建。
- **Keyframe / Animatic 实现**：本轮不做。

## Keyframe readiness

**READY.**

判断基于最终修订版本 v04，且 v04 已不包含任何一条否决项：

| 否决项 | v01 | v04 |
|---|---|---|
| 教学 overlay | 有 | **无** |
| narrator 报词 | 有 | **无** |
| 纯心理 trigger | 有 | **无** |
| disgust/distaste 主导证据 | 有 | **无**（已翻转为 `must_avoid`） |
| 台词被错标 required | 有 | **无**（`optional_dialogue`） |

支持进入 Keyframe 层的证据：

- 两个镜头的 `visual_start` / `visual_end` 是真正不同的状态，可直接作为关键帧首尾锚点；
- `continuity` 链完整衔接，配合 `cast` / `location` / `props` 的
  `continuity_description`，人物位置、朝向、姿势与道具阶段可延续；
- 两个镜头都是 `static`，对首版关键帧稳定性最友好；
- 计划保持风格中立、模型中立，没有 checkpoint / seed / 最终提示词。

唯一需要在 Keyframe 阶段留意的是 shot-02 的 4.8s 连续动作：它承载
"抵抗贯穿行动"这一核心证据，**不允许**为了迁就视频模型的时长上限而从中间切开。
如果目标模型撑不住 4.8s，正确做法是压缩动作节奏，不是拆镜头。
