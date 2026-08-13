# SceneLex Domain Language

SceneLex 生产可验证的词义、教学场景证据和与其绑定的媒体。这里定义跨语义、导演、渲染与审核各层共同使用的语言。

## Core Concepts

**Experience Model (经验模型)**:
语言是对经验的符号化编码，词义是经验的范畴化。我们不使用形式化语言描述词义，而是借助 LLM 将词义还原为经验。

**Micro-world (微世界)**:
经验的具体实例承载体，是场景（Scene）的呈现层。微世界可以是视频、交互应用或其他媒体，让学习者能体验语义。

**Semantic Compiler (语义编译器)**:
LLM 在系统中的角色。它接收词汇、分类和学习者状态，利用自身预训练中包含的经验知识，生成微世界构建指令。

**Experience Category (经验分类)**:
10种核心经验类型（如实体型、动作型、状态变化型、心理状态型等）。不同分类对应不同的词义理解和编译策略。

**Compilation Strategy (编译策略)**:
根据经验分类将语义实例转化为微世界的方法。不同的分类对应不同类型的微世界呈现模式。

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

**ExperienceProgram（经验程序）**:
一个 WordSense 编译出的可教学、可引用、可版本化的程序：semantic_model、有序概念
单元（units）、symbol_binding、grounding、review_pool 与 metadata。它是当前新主线
的产物契约（`schema/experience-program.schema.json` v1.0）。
_Avoid_: 五段叙事模板、卡片组、旧 SceneSpec 机械映射

**Experience Compiler（经验编译器）**:
把 WordSense 编译为 ExperienceProgram 的四阶段 deep module
（`tools/experience_compiler.py`）。对外只暴露 `compile_experience_program` /
`validate_program` / `run_regression`；内部阶段不对外。
_Avoid_: 把四阶段分别暴露成公共接口

**Semantic Planner（语义规划器）**:
Compiler 第一阶段。把 WordSense 还原为 semantic_model：invariant、必要条件、
非蕴涵、典型伴随、带稳定 ID 的 misconceptions、L1 干扰。只处理词义，不设计经验。
_Avoid_: 直接生成叙事、单元或学习者可见内容

**Experience Program Planner（程序规划器）**:
Compiler 第二阶段。规划有序概念单元（role、假设目标、受控/变化变量、语义规格）、
grounding 计划、复习池计划与揭示计划。只产出语义计划，不写表面文本。
_Avoid_: 五场景组模板、按 SceneSpec 一一映射

**Surface Experience Generator（表面经验生成器）**:
Compiler 第三阶段。把语义计划实现为 learner-visible 表面经验：episode、可观察
证据、表面维度、可评分 interaction、揭示与 L2 落地。揭示前禁止目标词与相邻 L2 词。
_Avoid_: 旁白直陈语义、语义计划与表面文本混层

**Semantic Critic / Quality Gate（语义批评器）**:
Compiler 第四阶段。按九个固定维度审核程序；任一阻塞维度未过，compile 不返回程序。
结论写入 metadata，不泄漏进 learner-visible 内容；pass 不代表自动发布。
_Avoid_: VLM 结论、生成成功即通过、分数代替 verdict

## Execution

> **Legacy Note**: 随着理论转向“语义教学引擎”和通用微世界架构，此执行层（Shot Plan / Keyframe Plan 等）已降级为特定类型的微世界（视频类）的具体实现细节。


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
