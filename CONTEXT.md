# SceneLex Domain Language

SceneLex 生产可验证的词义、教学场景证据和与其绑定的媒体。这里定义跨语义、导演、渲染与审核各层共同使用的语言。

## Semantic Resources

**WordSense（词义规格）**:
一个可独立教学、引用和版本化的词义身份及其成立条件。词头不是 WordSense。
_Avoid_: 单词、词典条目、视频主题

**SceneSpec（场景证据规格）**:
证明或区分一个 WordSense 的模型无关教学场景。它描述语义事件，不描述模型提示词。
_Avoid_: 视频脚本、镜头表、素材

**Semantic Beat（语义节拍）**:
SceneSpec 中观众必须感知的语义事件单位。它不等于 Shot、Keyframe 或 Clip。
_Avoid_: 镜头、关键帧、视频段

## Execution

**Shot Plan（镜头执行计划）**:
把已冻结的 SceneSpec 编排成连续观察与运动单位的叙事执行权威。它决定镜头与时序，不改变词义或故事。
_Avoid_: Director Prompt、视频提示词

**Keyframe Plan（关键状态计划）**:
在已冻结 Shot 内选择那些缺失后会改变语义判断的视觉状态。它不按角色或固定数量凑帧。
_Avoid_: Storyboard Beat、生成图片清单

**Render Directive（渲染指令）**:
把一个冻结的关键状态翻译为可审计、物理明确的图像编辑要求。它是模型适配 IR，不是新的语义权威。
_Avoid_: SceneSpec、自由提示词

**Motion Segment（运动生成段）**:
一次视频模型调用产生的连续运动区间，通常连接一个或两个已通过图片门的关键状态。一个 Shot 可以由一个或多个 Motion Segment 无叙事切镜地组成。
_Avoid_: Shot、Semantic Beat、含义不明确的 Clip

**Motion Directive（运动指令）**:
把 Shot Plan 的动作、时序和 Keyframe Plan 的状态约束翻译为某个 Motion Segment 的可审计执行要求。它不改变 Shot 边界或语义事件。
_Avoid_: Shot Plan、自由视频提示词

## Evidence and Gates

**Bound Artifact（绑定产物）**:
由 manifest attempt 记录并携带输入、模型、请求和文件引用的生成结果。目录中孤立存在但未被 attempt 引用的文件不是绑定产物。
_Avoid_: 生成过的图、目录里的图片

**Generation Gate（生成执行门）**:
判断一个 Edit Run 是否为全部目标提供了绑定产物。当前字段因历史兼容仍名为 `api_gate`。
_Avoid_: API 可达性、图片语义质量

**Semantic Gate（语义门）**:
人工判断整批绑定产物是否准确呈现目标词义及边界。VLM 结论只能是建议，不能通过该门。
_Avoid_: VLM 分数、生成成功

**Video Semantic Gate（视频语义门）**:
人工判断 Motion Segments 及其组装后的 Shot 是否忠实呈现动作阶段、停顿、速度、结果和连续性。
_Avoid_: 图片语义门、画质评分

**Pipeline-ready（可进入下游）**:
当前层的全部目标具有绑定产物，并通过该层人工语义门。局部成功、未绑定文件或 `pending` 都不算 Pipeline-ready。
_Avoid_: 看起来不错、技术跑通

**Vertical Slice（纵向切片）**:
一个场景从语义规格到最终可播放媒体的完整、可追溯实例。只有中间层成功不构成完成的纵向切片。
_Avoid_: 单次实验、单张好图
