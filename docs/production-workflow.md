# SceneLex Director：语义场景到视频提示词

> 状态：Phase 1.3 权威说明（2026-07-18）。

## 核心定位

SceneLex 的核心媒体能力是一个 Director 中间层：

```text
WordSense + SceneSpec
        ↓
Director Agent
        ↓
关键图 prompt + 视频 prompt（clip 数量由语义场景与 Director 决定）
        ↓
关键图生成 → 图片语义门（人物/道具/姿态/视线/构图，便宜且快速）
        ↓
Image-to-Video / Video Model（昂贵工序只接收已过门的输入）
        ↓
Director 查看结果并按需修正（时序语义验收）
```

Director 的价值不是模拟传统动画制片厂，而是理解一个词义必须怎样被看见，并把已经设计好的语义场景翻译成视频模型能够执行的导演语言。

这里的“已经设计好”是硬边界：现有WordSense与SceneSpec已经能准确表达目标词义，Director不得重新设计故事、增加记忆点或修改语义外化，只负责渲染翻译。

## 权威边界

- `WordSense` 与 `SceneSpec` 定义词义、概念边界和教学证据，保持模型无关。
- Director Prompt 是内部、可版本化的模型适配产物，不反向修改语义资源。
- 模型、workflow、seed、参考图接口和生成参数属于渲染与追溯层。
- `SceneSpec.storyboard` 是语义节拍。Director 可以把多个 beat 写进一个连续 prompt，也可以拆成多个 clip。clip 数量不是固定规范：它由语义场景需要多少个可分离的动作阶段、以及目标能力单次能可靠承载多少动作共同决定，禁止机械地按 beat 一对一拆分，也禁止为凑某个数量增删 clip。

## Director 做什么

1. 从语义骨架、成立条件、排除条件、`must_show`、`must_not` 和 `teaching_evidence` 提取视觉责任。
2. 把心理、态度、程度和逻辑翻译为动作时序、表情、视线、身体方向、速度、压力和结果。
3. 忠实保留SceneSpec中的人物、环境、事件因果、动作节拍、声音和教学目的。
4. 根据目标视频能力，把现有事件写成自然、具体、可直接提交的英文提示词。
5. 明确最容易误画的相邻概念和禁止结果。
6. 查看生成结果；若语义不成立，修改提示词或按需增加参考图、尾帧、更细的 clip 划分等
   进一步控制（首帧关键图已是默认工序，不算升级手段）。

Director 不默认创建角色数据库、状态机、正式 animatic、多 Agent 评审或复杂生产包。这些都是遇到实际失败时可以调用的工具，不是所有场景的前置流程。

## 全局视觉方向

SceneLex渲染层统一使用`Pixar-style 3D animated film`作为高信息密度风格锚点，并补充可执行属性：吸引人的风格化3D角色、可读的眼睛和眉部表演、夸张但可信的身体语言、温暖电影化家庭动画灯光、精致3D材质、丰富色彩和清楚的视觉叙事。

该风格只存在于`prompts/render-style.yaml`、Director Prompt和渲染器中，不进入WordSense或SceneSpec。风格只能改变呈现，不能改变已有场景内容。

## 生成策略：关键图先行是生产默认

生产默认工序是"文生图 → 图片语义门 → 图生视频"（关键图先行），理由有三：

1. **Fail-fast。** `must_show` / `must_avoid` 中的大部分条目——人物、道具、姿态、
   视线方向、构图、在场关系——是静态可检的。关键图生成成本是秒级，视频生成成本
   高一到两个数量级；在图片阶段拦截语义错误，昂贵的视频工序就只处理合格输入。
2. **跨 clip 一致性。** 一个场景拆成多个 clip 时，同一人物、环境和道具必须跨 clip
   稳定。从同一角色/环境设定出发生成各 clip 关键图，一致性是结构保证而不是运气。
3. **语义分工。** 首帧负责"画面是什么"（静态语义），视频 prompt 负责"怎样动、
   怎样结束"（时序语义：停顿、速度、方向、结果）。这与语义验收判据的两类天然对应。

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

## Director Prompt 契约

`schema/director-prompt.schema.json` 只保留：

- 目标 capability profile；
- 全局渲染风格标识（当前为`pixar-3d`）；
- `direct_t2v` / `image_guided_i2v` / `split_clips` 策略；
- 一个或多个可直接提交的英文视频 prompt，数量由语义场景与 Director 决定；
- 关键图 prompt（关键图先行策略下每个 clip 都应提供）；
- 简短的 `must_show` 与 `must_avoid`。

它不是公开资源契约，也不是完整制片计划。

## 当前纵向样本

先用 `reluctant-01-proto-01` 验证：Director能否忠实翻译现有场景，并用统一Pixar-style 3D视觉让视频模型准确执行其中的动作时序，同时避免只画成sad、slow、hesitant、refuse或eager。

随后用 `messy` 和 `almost` 检查同一个 Director 是否会根据语义类型自然选择静态关系、状态变化或终止结果，而不是套用同一种短片模板。
