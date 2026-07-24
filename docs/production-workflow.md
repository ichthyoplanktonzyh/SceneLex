# SceneLex 生产工作流：从语义节拍到可执行镜头

> 状态：Phase 1.4 权威说明（2026-07-20）。Shot Plan 取代旧的 Director Prompt
> 成为 Scene 之后的执行权威。

## 生产链

```text
Dictionary Evidence
→ Approved Sense Inventory
→ Inventory-driven WordSense
→ SceneSpec
→ Shot Plan                     ← 叙事执行权威
→ Keyframe Plan                 ← 选择并描述必要的视觉状态
→ Animatic Review               ← 审核顺序、时长、状态覆盖与镜头边界
→ Image Keyframe Generation     ← 把已批准的视觉状态画出来
→ AI Video Shots                ← 在已批准状态之间生成运动
→ Edit / Audio / Final Video
```

四层的职责边界不可互换：

```text
Keyframe Plan     = 选择和描述必要视觉状态
Animatic          = 审核顺序、时长、状态覆盖和镜头边界
Image generation  = 把已批准的视觉状态画出来
Video generation  = 在已批准状态之间生成运动
```

Director 的职责是这条链上的一步：

```text
WordSense + SceneSpec → Shot Plan
```

Director 的价值不是模拟传统动画制片厂，而是理解一个词义必须怎样被看见，并把已经设计好的语义场景拆分成可审核、可执行的镜头。

这里的“已经设计好”是硬边界：现有 WordSense 与 SceneSpec 已经能准确表达目标词义，Director 不得重新设计故事、增加记忆点或修改语义外化，只决定这段事件**怎样被镜头看见**。

## Beat 与 Shot

```text
Beat = semantic unit         观众必须看见的事件, 及其在词义证明中的作用
Shot = video execution unit  一次连续摄像机观察和连续运动
```

**二者不是一一对应的。** 构图与动作连续时，多个 beat 可以合并成一个 4–5 秒的镜头；一个 beat 同时要求先看外部压力、再看人物反应时，可以拆成 establishing/trigger shot 与 reaction shot。校验器不要求 Shot 数量等于 Beat 数量，只要求：

- 每个 storyboard beat 至少被一个 Shot 覆盖；
- Shot 序列不逆转 beat 的时间线；
- Shot ID 从 `shot-01` 起连续编号。

## Shot Plan 的权威边界

Shot Plan **决定**：

- shot segmentation（叙事拆分）；
- temporal order（镜头顺序）；
- state change（起始状态 / 触发 / 动作 / 结束状态）；
- composition（景别、角度、焦点主体、调度）；
- camera（运动与动机）；
- duration（每镜头时长与总时长）；
- semantic evidence（本镜头的 must_show / must_avoid）；
- continuity（人物位置、朝向、姿势、道具的进出交接）；
- minimal audio intent（silence / sfx / optional / required dialogue）。

Shot Plan **不决定**：

- visual style（任何风格锚点，包括 Pixar-style）；
- specific model、供应商、checkpoint、sampler、seed；
- final prompts、negative prompt；
- workflow（ComfyUI node 等）；
- keyframe files、音频文件；
- final edit（最终剪辑时间轴）。

后续图像与视频模型只执行 Shot Plan，不再自行重新拆分 Scene。

## 上游绑定与权威字段

Shot Plan 记录 `scene_ref` / `scene_version` / `sense_ref` / `sense_revision`，依赖链保持
`Shot Plan → Scene → WordSense → Approved Inventory`，不直接依赖 Inventory，也不使用内容摘要。

- 这些身份字段与 `schema_version` / `version` / `status` / `id` / `total_duration_hint` 一律由程序写入。模型**省略**可补全；模型**显式写错**判定为 `shot plan identity drift`，本次编译失败并保留原始输出。
- Shot Plan 只能从语义修订状态为 `CURRENT` 的 SceneSpec 1.1 编译。`LEGACY` / `NEEDS_REVIEW` / `INVALID` / `MISSING` 一律在调用模型之前失败，且没有 `--allow-stale` 之类的逃生通道——普通 `validate.py` 容忍旧场景，但新的视频执行计划不应建立在已知过时的语义契约上。
- `scene_version` 只用于提示上游动过：`director.py show` 在当前 Scene 版本与计划记录不一致时打印 `source Scene version has changed; review this Shot Plan`，不是失效判定，也不进入发布门。

## 命令

```bash
python3 tools/director.py plan reluctant-01-proto-01   # Scene + WordSense → Shot Plan
python3 tools/director.py show reluctant-01-proto-01   # 面向人工审核的展开
python3 tools/director.py list                         # Shot Plan 版本一览
```

`data/drafts/shot-plans/{scene_id}/v{NN}/shot-plan.yaml` 永不覆盖，重编即新版本。解析失败与校验失败的模型输出进旁路文件（`_unparsed-shot-plan.txt` / `_invalid-shot-plan.yaml`），正常路径只接收通过全部检查的产物。

`director.py generate` 是已弃用的兼容别名：它打印弃用提示后执行与 `plan` 完全相同的实现，不再生成旧的 `director-prompt.yaml`。

## Legacy：旧 Director Prompt 与 beat-image 渲染计划

以下产物继续保留以便追溯历史，但都**不是**新架构的权威层：

- `schema/director-prompt.schema.json` + `prompts/director.md` + `data/drafts/director/`：旧的“场景 → 模型提示词”原型。`director.py show-legacy` 可以查看历史产物；新的 `plan` 不再生成它们。
- `schema/render-plan.schema.json` + `prompts/render-plan.md` + `tools/render.py plan`：旧的 beat-image 渲染原型。它仍可运行（运行时打印一次 legacy warning，不影响退出码），但不消费也不修改 Shot Plan，也不会被自动迁移。

Shot Plan 的下游是 Keyframe Plan（见下一节），不是这两个 legacy 层。

## Keyframe Plan 与 Animatic

`schema/keyframe-plan.schema.json` + `tools/keyframe_plan.py` + `tools/keyframes.py`。

Keyframe Plan 只做一件事：在 Shot Plan 已经定好的镜头里，选出并描述那些**缺了它观众的语义推断就会改变**的画面状态，并给出它们在镜头内的时间位置。它**不重新导演场景**——镜头数量、顺序与时长仍由 Shot Plan 决定；它也不写视觉风格、模型、checkpoint、sampler、seed、最终提示词或图片路径。

```bash
python3 tools/keyframes.py validate reluctant-01-proto-01
python3 tools/keyframes.py show     reluctant-01-proto-01
python3 tools/keyframes.py animatic reluctant-01-proto-01
python3 tools/keyframes.py list
```

- 产物落在 `data/drafts/keyframe-plans/{scene_id}/v{NN}/`，永不覆盖；
- `shot_plan_ref` 必须显式写明 scene ID 与 Shot Plan **版本**——草稿目录里历史版本全部保留，下游不得默默跟着"最新目录"漂移。校验是确定性的：引用的版本目录必须存在（不做 digest / SHA / 自动 stale 传播）；
- 第一份 Keyframe Plan 由人工按真实内容选帧，工具负责校验、时间轴、预览与展示。因此没有 `plan` 子命令：**让模型按角色枚举给每个镜头凑五张关键帧，正是这一层要避免的失败模式。**

`keyframes.py animatic` 确定性生成 `animatic.yaml`（机器可校验的时间轴）与 `animatic.html`（单文件预览，无 CDN、无服务器，浏览器直接打开），全程不调用任何模型。

**文字占位卡不是视觉审核。** Animatic 能审时序、状态覆盖、hold 时长、镜头边界与动作密度；**不能**审构图可读性、表情质量、真实画面语义与图片之间的连续性。预览页顶部与每张卡都标着 `TEXTUAL PLACEHOLDER — NOT A VISUAL SEMANTIC REVIEW`，不要把它读成"视觉审核已通过"。

校验刻意**不**规定：每个 Shot 必须有 `initial` + `final`、每个 Shot 必须 2–5 帧、每个 Shot 必须有 `semantic_climax`、每个 Beat 必须对应关键帧、关键帧数量上限。帧数由内容的真实状态变化决定；一个样本不足以把这些写成不变量。

第一条真实审核记录见 [docs/vertical-slices/reluctant-01-keyframe-animatic.md](vertical-slices/reluctant-01-keyframe-animatic.md)，它同时记录了这条链上的**第一次反馈循环**：

```text
Shot Plan v04 → Keyframe Plan v01 → Animatic v01 → 审核发现动作装不下时长
              → Shot Plan v05 (人工修订, 三镜) → Keyframe Plan v02 → Animatic v02
```

三件事因此成为这一层的既定做法：

- **上游问题在上游修。** Animatic 发现的是时长不足，修的是 Shot Plan，不是靠删关键帧或压缩停顿把它掩盖过去。Keyframe Plan 不重新导演场景这条边界，在真实反馈里也不能被绕过。
- **历史版本全部保留，绑定必须显式。** Keyframe Plan v01 仍绑定 Shot Plan v04，v02 绑定 v05；失败的那一轮不是废稿，而是这道审核门确实拦住过东西的证据。下游用 `shot_plan_ref.version` 锁版本，CLI 用 `--version` 选版本，任何一层都不跟着「最新目录」漂移。
- **人工修订是允许的，但必须说明。** `director.py plan` 只能调用模型；当修订依据来自人工 animatic 审核时，直接新建版本目录并在 `shot_plan_ref.human_revised` 与切片记录里写清楚，不为 provenance 扩 schema，也不把人工产物伪装成模型输出。

## 图片关键帧（Keyframe Plan 之后）

`schema/image-keyframe-manifest.schema.json` + `tools/image_keyframe.py` + `tools/image_keyframes.py`。

这一层只回答一件事：Keyframe Plan 里的文字关键状态，能不能变成语义可读、角色一致、道具连续、跨镜可衔接的真实图片。**一张图片对应一个 keyframe，不是一个 beat**——所以它不复用 legacy 的 beat-image render 逻辑，也不修改它。

```bash
python3 tools/image_keyframes.py prompts  reluctant-01-proto-01 --keyframe-plan-version 2
python3 tools/image_keyframes.py generate reluctant-01-proto-01 --keyframe-plan-version 2
python3 tools/image_keyframes.py generate reluctant-01-proto-01 --only shot-02-kf-03 --force
python3 tools/image_keyframes.py review   reluctant-01-proto-01 --version 1
python3 tools/image_keyframes.py validate reluctant-01-proto-01 --version 1
```

产物落在 `data/drafts/image-keyframes/{scene_id}/v{NN}/`，永不覆盖；`shot_plan_ref` 与 `keyframe_plan_ref` 都必须显式写明版本。manifest 刻意保持最小：没有 digest / SHA、没有依赖 DAG、没有自动 stale、没有通用 asset ID、没有各类 Bible。图片本身已经是具体资产，不为将来的系统预埋抽象。

提示词由 `compile_prompt` **机械拼装**，输入全部来自已冻结的上游字段（Shot Plan 的 `composition` / `camera` / `cast` / `location` / `props`，Keyframe 的 `visual_state` / `must_show` / `must_avoid` / `continuity`）。编译器不重新决定故事、动作阶段、谁持有叉子、叉子是否已插入食物、哪一帧是语义高潮或镜头切点。风格只有一个来源：`prompts/render-style.yaml`。`must_avoid` 只进负提示词——在扩散模型里提到某个东西本身就会把它召唤出来。

第一轮真实图片的审核记录见 [docs/vertical-slices/reluctant-01-image-keyframes.md](vertical-slices/reluctant-01-image-keyframes.md)。结论是 **IMAGE KEYFRAME REVISION REQUIRED**：9 张图全部生成成功，但没有构成可进入运动验证的语义证据。这一轮真实得到的工作流认识有四条：

- **模型的选择必须是产物的一部分，不能是终端状态的一部分。** 第一次真跑因为 `imagegen` 的工作流来自环境变量默认值，用成了 legacy 的 beat-image SDXL 工作流，画出的东西与预期毫无关系，而 manifest 事后分辨不出来。关键帧层现在显式指定工作流并把实际模型写进 `generation`。
- **构图字段能被稳定执行，人物状态字段不能。** `composition` / `staging` 几乎全部通过；失败集中在"某个动作还没有发生"这类否定式中间状态上——手尚未碰到叉子、叉齿尚未插入食物、双手仍平放桌面。文生图模型会用"吃饭场景"的先验直接覆盖它们。
- **`must_avoid` 是否真的到达了模型，必须逐工作流确认。** Z-Image Turbo 是 CFG 蒸馏模型，cfg=1.0 时采样器不走负分支；负提示词被完整编译，却没有一条生效。在这种工作流下 `must_avoid` 只是人工审核清单，不能声称它是生成约束。
- **固定 seed + 连续性描述常量块不足以锁住角色身份。** 逐帧提示词变化时，角色外观会漂移。是否需要 Character Bible 等这一条被单独验证后再决定，不因一次漂移就建结构。

审核层级在产物里是硬标注：`review.html` 顶部写着 `REAL IMAGE SEMANTIC REVIEW — NOT VIDEO MOTION REVIEW`。它审的是单帧语义、must-show / must-avoid、角色与道具一致性、跨镜状态衔接；**不**审动作插值、视频节奏、运动自然度、音频、剪辑与最终学习效果。

跨镜连续性对（上游镜头末帧 ↔ 下游镜头首帧）在审核页里并排显示并逐项核对。这两张图不要求像素级相同——构图可以切得更紧——但动作状态与道具状态必须相同。剪辑点在哪里由 Keyframe Plan 的镜头顺序决定，不写死在工具里。

## 下游渲染层的既有经验（Shot Plan 之后）

以下内容描述 Shot Plan 下游的图像/视频工序。它们不改变 Shot Plan 的内容，只说明镜头计划最终如何被执行。

## 全局视觉方向

SceneLex渲染层统一使用`Pixar-style 3D animated film`作为高信息密度风格锚点，并补充可执行属性：吸引人的风格化3D角色、可读的眼睛和眉部表演、夸张但可信的身体语言、温暖电影化家庭动画灯光、精致3D材质、丰富色彩和清楚的视觉叙事。

该风格只存在于 `prompts/render-style.yaml` 和渲染适配层，**不进入 WordSense、SceneSpec、Shot Plan 或 Keyframe state identity**。风格只能改变呈现，不能改变已有场景内容，不能改变镜头拆分，也不能改变一个关键帧是"哪一个状态"。它是渲染层的当前默认值，不是新语义主链的一部分。

## 生成策略：关键图先行是生产默认

生产默认工序是"文生图 → 图片语义门 → 图生视频"（关键图先行），理由有三：

1. **Fail-fast。** `must_show` / `must_avoid` 中的大部分条目——人物、道具、姿态、
   视线方向、构图、在场关系——是静态可检的。关键图生成成本是秒级，视频生成成本
   高一到两个数量级；在图片阶段拦截语义错误，昂贵的视频工序就只处理合格输入。
2. **跨 clip 一致性。** 一个场景拆成多个 clip 时，同一人物、环境和道具必须跨 clip
   稳定。机制是结构性的：每个角色先生成一张**角色设定图**（方形参考资产，只生成
   一次），各 clip 关键图以它为 reference 输入（当前经 FLUX.2 Klein 的 Edit/Reference
   能力）生成——一致性由共用参考图保证，而不是靠 prompt 措辞的运气。
3. **语义分工。** 首帧负责"画面是什么"（静态语义），视频 prompt 负责"怎样动、
   怎样结束"（时序语义：停顿、速度、方向、结果）。这与语义验收判据的两类天然对应。

两条硬规则：

- **关键图直接按视频目标画幅与目标分辨率生成**（如 16:9 / 1280×720 起）。构图、
  视线空间、留白方向这些语义门要审的东西是画幅相关的，必须一开始就在目标画布上
  设计；且云端 I2V 的输出画幅通常直接由输入图画幅决定（Kling）或对不匹配输入做
  中心裁切（Runway），首帧本来就应该是目标画幅。不采用"先生成方形再转画幅"的
  流程；画幅转换（reference 约束下的重新生成）只是既有素材画幅不对时的补救工具，
  不是常设工序。
- **图片语义门审查的图必须与提交图生视频的图是同一张。** 过门之后不得再经任何
  重新生成类处理（转画幅、outpaint、重绘）；确需处理时，处理后的图必须重新过门。
  否则 fail-fast 失效——昂贵工序接收的就不再是"已过门的输入"。

三种策略标识的含义：

### `image_guided_i2v`

生产默认。先写关键图 prompt 锁定人物、道具、姿态、视线与构图，关键图通过图片
语义门后，再以运动 prompt 做图生视频。

### `split_clips`

场景需要多个 clip 时使用；通常每个 clip 都配 `image_prompt`，即"关键图先行"在
多 clip 下的形态。按动作和模型能力拆，不按 semantic beat 一对一拆；clip 数量由
语义场景与 Director 决定，文档与 schema 不设固定数量。

### `direct_t2v`

特例。仅当目标能力明确能可靠承载单个连续多阶段事件、且没有跨 clip 一致性需求时，
用一个高质量 prompt 直接描述完整事件。强模型可以理解多个动作阶段时，不要因
storyboard 有多个 beat 而机械拆分。

## 模型适配

模型无关意味着“词义理解不依赖模型”，不意味着给所有模型写同一种 prompt。

- 强多模态模型：可以直接接收完整事件、连续动作、简单镜头变化和声音指令。
- 本地 Wan 2.2 TI2V 5B：更适合短、单一主要动作、简单机位；每个 clip 的动作要小，
  clip 划分按动作承载能力决定。
- 新模型出现时：新增或更新轻量 capability profile，不改变 WordSense 与 SceneSpec。

当前 profile 位于 `prompts/video-model-profiles/`。它们只告诉 Director 当前能力适合怎样接收指令，不包含语义规则。

## 最小反馈循环

```text
Director 写关键图 prompt + 视频 prompt
→ 生成关键图候选（便宜、快速、可并行）
→ 图片语义门：人物/道具/姿态/视线/构图是否成立
   ├── 不成立：修改关键图 prompt，重新生成关键图
   └── 成立：进入图生视频
→ 视频生成候选
→ 视频语义门：时序判据（动作阶段、速度、停顿、结果）是否让目标词义被正确看见
   ├── 正确：接受
   └── 不正确：指出最主要的问题并修改运动 prompt / 控制方式
→ 再生成
```

第一版不建设独立 Reviewer、Decision Policy 或复杂 Memory。先让同一个 Director 完成生成前翻译和生成后语义修正；当真实生产中出现稳定、重复的失败模式，再决定是否拆出评审组件。

生成应尽早发生。提示词、参考图、关键帧和视频本身都可以用于探索，不因为担心成本而预先增加不必要流程。

## Shot Plan 契约

`schema/shot-plan.schema.json` 保留：

- 上游绑定（`scene_ref` / `scene_version` / `sense_ref` / `sense_revision`）；
- 跨镜头连续性资源（`cast` / `location` / `props`）；
- 镜头序列：`source_beats`、叙事与语义功能、时长、`visual_start` / `trigger` / `action` / `visual_end`、`composition`、`camera`、`semantic_evidence`、`audio`、`continuity`。

时长纪律：每镜头 1–8 秒（生产目标 2–5 秒；>5 秒 warning，>8 秒 error），`total_duration_hint` 由程序按各镜头求和权威写入。

它不是公开资源契约，也不是完整制片计划，更不是模型提示词。

`schema/director-prompt.schema.json` 是它的 legacy 前身，只描述模型提示词原型，已不参与新主线。

## 当前纵向样本

先用 `reluctant-01-proto-01` 验证：Director 能否把现有语义节拍拆成可审核的执行镜头，让动作时序被正确看见，同时避免只画成 sad、slow、hesitant、refuse 或 eager。

该样本已经跑通：`reluctant` 是仓库第一个 approved Sense Inventory，`reluctant-01` 已按它重新起草为 WordSense 1.1，`reluctant-01-proto-01` 是第一条语义修订状态为 `CURRENT` 的 SceneSpec 1.1，并编译出真实 Shot Plan。当前推荐版本是 v04（3 个 Beat → 2 个 Shot，7.3s）；v01–v03 作为问题证据保留，不覆盖。逐项审查记录见
[docs/vertical-slices/reluctant-01-proto-01.md](vertical-slices/reluctant-01-proto-01.md)。其余 20 个场景仍是 SceneSpec 1.0（`LEGACY`），本轮不做批量迁移。

该样本随后走到了 Keyframe / Animatic 层：`data/drafts/keyframe-plans/reluctant-01-proto-01/v01/` 是第一份真实关键帧计划（7 帧 = 2 + 5，锚定 Shot Plan v04）。Animatic 审核的结论是 **SHOT PLAN REVISION REQUIRED BEFORE IMAGE GENERATION**——选帧成立，但 shot-02 的 4.8s 装不下它自己的动作链，建议在"握住叉子之后"的自然动作边界改成 3 个镜头。审核记录见 [docs/vertical-slices/reluctant-01-keyframe-animatic.md](vertical-slices/reluctant-01-keyframe-animatic.md)。该建议随后被执行：Shot Plan v05（人工修订，三镜）与 Keyframe Plan v02（9 帧 = 2 + 4 + 3）已生成，v04 与 v01 原样保留不覆盖。

该样本随后走到了图片关键帧层：`data/drafts/image-keyframes/reluctant-01-proto-01/v01/` 是第一批真实图片（9 张，锚定 Shot Plan v05 + Keyframe Plan v02）。审核结论是 **IMAGE KEYFRAME REVISION REQUIRED**——图全部生成成功，构图与场景关系成立，但抵抗状态（躯干后靠、手停在半途、叉齿尚未插入）一张都没有画出来，`reluctant` 与普通配合无法区分。失败的是执行不是计划，v05 与 v02 均未修改。记录见 [docs/vertical-slices/reluctant-01-image-keyframes.md](vertical-slices/reluctant-01-image-keyframes.md)。

随后用 `messy` 和 `almost` 检查同一个 Director 是否会根据语义类型自然选择静态关系、状态变化或终止结果，而不是套用同一种短片模板。

针对图片关键帧层 IMAGE KEYFRAME REVISION REQUIRED 的结论，启动了 Token Plan Wan 2.7 状态编辑实验（`feat/reluctant-wan27-image-edit-prototype`）：用图片编辑而非文生图，以 v01 图为基础输入，通过编辑指令强制指定冻结状态（躯干后靠、手停在半途等），直接回答"wan2.7-image-pro 能否通过图片编辑准确执行 reluctant 核心判据"。该实验增加了 `aliyun-token-plan` 适配器协议（`tools/imagegen.py`）、编辑指令编译库（`tools/image_keyframe_edit.py`）、CLI 工具（`tools/image_keyframe_edits.py`）与对应 schema 和测试（59 tests pass）。本次执行因运行环境网络代理阻断 `*.maas.aliyuncs.com` TLS 握手，api_gate: blocked，semantic_gate: not_run；代码与工具框架已就绪，在可连接 Token Plan Endpoint 的网络环境中可立即执行。记录见 [docs/vertical-slices/reluctant-01-wan27-image-edit.md](vertical-slices/reluctant-01-wan27-image-edit.md)。
