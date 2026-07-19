# SceneLex Agent Notes

这份文件是本仓库的工作约束和快速项目记忆。修改前先读完它；涉及
产品方向、数据模型或生产流程时，再读 `README.md` 与
`一、先明确系统最终要解决什么问题.md` 的相关章节。

## 项目定位

SceneLex 是一个以“场景即释义”为方法的词义语义资源与教学证据系统。
该方法是已确立的产品前提，不再作为研究假设做学习实验验证。
它的基本任务不是给单词附加文字翻译，也不是制作孤立的视频素材，而是：

```text
L2 声音 → 场景与经验 → 概念
```

为每一个可教学的 **词义** 建立可验证的语义规格，并将其编译为一组能建立、
区分和迁移该概念的教学场景证据。核心资产是可独立发布、版本化并由词典、
课程、播放器、API、实验工具等多个消费者复用的资源，而不是某个学习 App 的内部数据。

**资源生成是 SceneLex 的核心定位之一。** 但 SceneLex 当前首先维护的是
模型无关的语义与场景中间表示（IR）；图片、动画、视频、TTS 或交互素材都是
可替换渲染后端的产物，而不是项目的语义权威。

下游词典、播放器、课程、学习实验或 API 都是消费端，不定义 SceneLex 的核心模型。
学习流程是重要消费者，但不拥有这些资源。尤其不要为某一个
下游项目的当前数据形状、UI、用户画像或网络协议扭曲义项身份和场景证据。

## 核心原则

1. **词义，不是词头。** `run` 的不同含义是不同的教学单位；不以“每个单词一个
   视频”替代义项建模。
2. **场景是释义媒介，不是装饰。** 目标词必须由场景中的经验、关系、动作或结果
   不可替代地支持。
3. **先经验与声音，后文字。** 通常先让学习者看见语义事件，再在恰当时机出现 L2
   声音；文字和 L1 可以是辅助，不应抢占默认意义通道。
4. **一个词义需要证据组。** 原型、对比、反例、边界、迁移是五种教学功能；
   当前默认各生成一个，最终数量由证据覆盖决定。
5. **语义骨架与具体渲染解耦。** 词义骨架描述语言共同体中的可检验假设，不绑定某个
   房间、职业或文化脚本；L1、生活经验和学习阶段影响边界重点、场景选择与表面渲染。
6. **生成不等于发布。** LLM 或渲染模型可以起草和生成，但不会自动成为正式内容；
   入库由人工 promote 决定。模型三层审核（语言、场景、教学）是推荐的质量参考
   而非强制门：promote 不要求审核记录，与当前内容匹配的记录会随资源归档。
   审核模型宜与起草模型不同（避免自我确认）。
7. **不把翻译绝对化或妖魔化。** L1 可用于澄清抽象概念、纠正边界误解或提高效率，
   但不能替代声音—经验连接。
8. **相邻概念不必互斥。** 词义可能包含、重叠、处于同一程度轴、属于不同维度或
   只是同形多义；排除条件只写真正不成立的情况，关系逻辑必须显式记录。
9. **API 按协议适配。** 模型名、厂商、URL、认证和生成参数只能存在于适配层；
   正式资源和公开 Schema 不绑定任何模型厂商。

## 当前架构与权威边界

```text
word sense specification
        ↓
semantic skeleton + inclusion/exclusion conditions + L1 confusables
        ↓
teaching-scene evidence specification (model-neutral IR)
        ↓
Director Agent (semantic scene → model-adapted video prompt)
        ↓
renderer adapters (image / video / TTS / interactive)
        ↓
reviewed, versioned semantic resources
        ↓
learning clients, APIs, or content packages
```

目录职责：

- `schema/`：机器可验证的公开数据契约。先改 schema，再改依赖它的数据、提示词、
  校验器与下游编译器。
- `schema/resource-bundle.schema.json`：面向外部消费者的确定性资源包契约。
- `data/senses/`：已审核的正式义项库；文件名必须等于义项 ID。
- `data/scenes/{sense_id}/`：已审核的正式场景规格；一个义项对应一个目录。
- `data/drafts/`：待审草稿隔离区，绝不可被当作已发布内容或默认词典结果。
- `prompts/`：起草辅助，不是数据权威；修改后要检查其是否仍与 schema 一致。
  起草不注入正式库范例做 few-shot（避免锚定表面选择），格式靠规则与校验兜底。
- `prompts/scene-strategies/`：按 `semantic_type` 分化的场景表达策略片段
  （"语义—场景设计手册"的落地）；场景起草与增补时按义项类型注入，schema 的
  semantic_type 枚举每个值必须有对应片段（有测试守护）。
- `tools/draft.py`：词义/场景草稿生产编排（含 batch 批量与 --add 增补）。词义起草
  由已批准 Inventory 驱动：`sense <sense_id>` 详细化单个已冻结 sense，
  `senses <word>` 按 Inventory 枚举整词；每次调用都注入完整 ALL_SENSES。
  旧的 `sense <word> --num <nn>` 词典序号路径已弃用（默认失败；显式
  `--legacy-dictionary-index` 才可用，产物落 `data/drafts/legacy-senses/`，
  不可 promote）。batch 也按已批准 Inventory 枚举，不按词典义项数。
- `tools/review.py`：模型审核（可选质量参考，不是强制门）——语言/场景/教学三层
  审核的执行器，输出结构化审核记录 `data/drafts/reviews/{id}.yaml`（八维度结论 +
  逐条问题 + 内容指纹）。promote 不要求审核；记录与当前内容匹配时随资源归档到
  `data/reviews/`，缺失或过期只提示不阻塞。审核模型经 `SCENELEX_REVIEW_LLM_*`
  单独配置，宜与起草模型不同（避免自我确认）。
- `tools/llm.py`：可替换 LLM 适配器；模型选择不得泄漏到 schema/正式 IR。
- `tools/dictionary.py`：Wiktionary 词典事实源（kaikki.org，CC-BY-SA）。词典事实
  是起草与审核的事实锚点（pos/IPA/义项划分参照），不是内容来源；释义与语义
  骨架必须自行撰写。缓存于 `data/dictionary/`。
- `tools/candidates.py`：扩产候选队列（悬空引用优先 + 词频排序）。注意不可
  命名为 queue.py（遮蔽标准库）。
- `tools/wordbook.py`：内部词目聚合视图（按词聚合本库义项与场景，view/export；
  promote 时同步词目条目）。与外部事实源 dictionary.py 职责不同，勿混淆。
- `schema/sense-inventory.schema.json` + `tools/inventory.py`：整词级 Sense
  Inventory 层，位于 dictionary evidence 与 sense draft 之间。Wiktionary
  条目（`dictionary.get_filtered_entries` 的稳定 entry_id）是起草输入，不是
  最终 SceneLex sense；inventory 一次性规划整个词，决定哪些证据合并、推迟或
  拆分，再统一分配 `{word}-nn` sense ID。状态流转为
  `draft → reviewed → approved`：`data/drafts/inventories/` 是待审草稿区，
  `data/inventories/` 与 `data/dictionary-evidence/` 是批准后的权威目录，
  只能由 `inventory.py approve` 写入（approve 全程离线，不生成 WordSense，
  不删除草稿）。`load_approved_inventory()` 是 sense 起草读取 inventory 的
  唯一入口，绝不回退到草稿。

  **已批准的 Inventory 是新建 WordSense 的唯一身份权威**：sense ID、lemma、
  POS、`semantic_signature` 和 dictionary source mapping 都以它为准。
  硬约束：

  1. 不得根据 dictionary order 或词典条目序号创建 SceneLex sense ID；
     词典条目不是 sense，条目序号也不是 sense 编号。
  2. 没有 approved Inventory 时不得生成新的 WordSense。
  3. 不得重新定义 Inventory 已冻结的 sense identity；起草阶段这些字段由程序
     强制覆盖，人工事后修改会被 `validate.py` 的身份检查拦下。
  4. WordSense 是 approved Inventory sense 的**详细规格**，不是新的义项规划层：
     它不创建、删除、合并、拆分或重新编号 sense。
  5. Inventory 本身有问题时，回到 inventory 层修正或重新走 review/approve，
     不得在 sense draft 中自行修复；模型可返回
     `generation_status: inventory_conflict` 让工具落到 `_conflict-` 文件。
- `docs/production-workflow.md`：Phase 1.3 的 Director 权威说明。Director 负责把模型无关
  的词义与教学场景翻译为适合当前视频能力的高质量提示词。生产默认工序是关键图先行
  （文生图 → 图片语义门 → 图生视频）；尾帧、animatic 等更多控制是遇到实际问题时
  按需调用的工具。
- `tools/director.py`：Director 编排——读取 WordSense + SceneSpec + capability profile，
  生成版本化 `data/drafts/director/{scene_id}/v{NN}/director-prompt.yaml`。
- `schema/director-prompt.schema.json`：轻量内部契约，记录生成策略、一个或多个视频提示词
  （clip 数量由语义场景与 Director 决定，不设固定上限）、关键图提示词和简短语义
  guardrails；不属于公开语义资源。
- `tools/render.py`：当前早期渲染原型——场景规格 → beat 级渲染计划（plan）→ 图像候选
  （render，经 imagegen 适配器）→ playback 组装（待建）。它尚未实现权威生产工作流。版本目录
  `data/drafts/renders/{scene_id}/v{NN}/` 永不覆盖；候选文件按字母递增，
  manifest 随渲染增量更新。
- `tools/imagegen.py`：图像生成适配器（comfyui 协议）——加载
  `tools/workflows/` 下的工作流 API JSON，跟随采样器连线自动定位正负提示词
  节点后注入，`SCENELEX_IMG_*` 配置。模型与工作流名只进 manifest。
- `schema/render-plan.schema.json`：早期 beat 级渲染计划（现状内部 IR，不是未来 Production
  Package 契约）。内容/风格分离：
  beat prompt 只写内容，外观集中在 characters/setting 卡片、以 `{char:id}` 与
  `{setting}` 占位符引用（展开是机械替换，保证跨 beat 一致）；全局风格在
  `prompts/render-style.yaml`，渲染时追加。后续不得直接把该 Schema 扩成供应商 prompt
  大杂烩；先按生产工作流设计独立契约和迁移方式。
- `schema/render-manifest.schema.json`：渲染版本的可追溯清单（渲染器/模型/
  seed/许可/选定资产/审核引用）。模型名只允许出现在 manifest，不得进场景规格。
- `tools/workbench.py` + `tools/webui/`：本地审核工作台；文件库之上的无状态壳，
  promote 一律经由 draft.py，不为正式库提供写口。
- `tools/validate.py`：正式库的最低一致性校验，不替代语言、场景或教学审核。
- `tools/export.py`：只从正式库导出消费者资源包；草稿不得进入默认导出。
- `examples/consumer/`：消费者侧示例，不是 SceneLex 核心身份或学习记录模型。

## 数据与内容不变量

- 义项 ID 为 `{word}-{nn}`，例如 `reluctant-01`；场景 ID 为
  `{sense_id}-{type}-{nn}`。ID 是稳定引用，重命名或重新编号是兼容性变更。
  新建义项的 ID 由已批准的 Sense Inventory 分配，不由词典条目顺序决定。
- WordSense `schema_version` 有两个版本：`1.0` 是 Inventory 层之前的历史资源，
  不要求 Inventory provenance；`1.1` 由已批准 Inventory 驱动生成，必须包含
  `inventory`、`semantic_identity` 和 `inventory_source_entries`，且由
  `validate.py` 持续核对是否仍忠实于 Inventory。新起草一律是 `1.1`；不要通过
  把这些字段对所有版本设为可选来削弱契约。
- `semantic_skeleton` 描述与具体渲染无关、可跨场景和跨文化检验的深层条件；不要把
  某一个房间、职业、人物或文化脚本误写成词义本身，也不要把语言惯例冒充文化真理。
- `conditions.required` 说明词义成立的必要条件；`conditions.excluded` 只写真正不适用
  的情况。更具体、更强烈或可共现的相邻词不能伪装成排除条件；使用
  `relations.boundaries` 记录真实关系与可验证判据。
- `l1_confusables` 记录真实的 L1→L2 概念边界错位，不写成简单双语对照表。通用骨架
  与 L1 特定教学路径必须分离。
- 心理、意图、逻辑和其他不可直接看见的意义，必须通过可观察的行为、目标、压力、
  结果、视线、时间过程或事件关系外化；不要让角色用解释性台词替代画面。
- 五类场景各司其职：`prototype` 建立概念，`contrast` 比较相邻概念，
  `counterexample` 证明某些线索不足，`boundary` 测试临界、包含或偏好，`transfer`
  验证跨表面的泛化。对比类场景必须声明 `contrast_relation`。
- 义项的证据集是扁平、可增长的场景数组：同一类型可以有多个平行场景
  （ID 序号递增，`draft.py scenes <id> --add <type>` 增补），价值在于泛化。
  每个场景以 `surface`（domain / participant_type / setting）声明表面特征；
  同类型场景之间表面必须有差异，surface 完全相同的场景是重复证据而非泛化。
  "场景组"不是实体，只是覆盖清单被凑齐一遍；将来叙事/课程/实验/受众组
  一律做成引用 scene ID 的覆盖层，不拥有场景。
- 原型场景通常遵循“先概念体验、后目标声音命名”的声画顺序。迁移场景至少改变两个
  表面维度并写入 `transfer_dimensions`，避免学习者只记住原始剧情。
- 悬空义项引用是可接受的 backlog 信号；不要为消除校验器的 backlog 而虚构低质量义项。
- YAML 标量遵循 README 的格式约束：无引号标量不要包含 ASCII `": "`；含英文台词时
  使用双引号或块标量。

## 生成、渲染与发布

内容生产遵循下列状态，而不是“输入词 → 立即成为词典内容”：

```text
candidate → sense draft → reviewed sense → scene draft → reviewed scene spec
          → rendered assets → language/scene/pedagogy review → published resource
```

- 自动生成应明确产物层级：仅义项草稿、场景规格草稿、渲染候选或已审核资源，不能混称。
- 正式资源必须包含 `schema_version`、资源 `version` 与 `status`。`published` 要求
  渲染资产齐备、来源可追溯、学习任务可评分；仅有规格的 `reviewed` 资源不要冒充
  `published`。
- 每一份渲染资源必须能够追溯到 `sense_id`、`scene_id`、规格版本、渲染器/模型、
  输入版本、版权/许可和审核结论。
- 先验证语义与教学设计，再优化画面“影视感”。第一版可以是连续图片、动态漫画或
  简单动画；不要为了视频质量牺牲场景可观察性和概念边界。
- `SceneSpec.storyboard` 是语义节拍，不是模型 prompt。Director 可以把多个 beat 写进一个
  连续事件，也可以拆成多个 clip；clip 数量由语义场景与 Director 决定，禁止机械一对一
  转换，也禁止为凑数增删 clip。
- 现有WordSense与SceneSpec是Director的完整内容输入。Director不得重新设计故事、增加所谓
  记忆点、替换人物动机或修改语义外化；只把已有场景忠实翻译为模型可执行的视觉语言。
- 媒体形态、时长和镜头数由语义证据决定，不默认所有词义都是固定长度的 3D 短片。
  生产默认关键图先行：先文生图并通过图片语义门（人物/道具/姿态/视线/构图），再图生
  视频；`direct_t2v` 只在目标能力可靠承载单一连续事件且无跨 clip 一致性需求时使用。
  尾帧、animatic 等更多控制只在结果暴露出相应问题时才增加。
- 关键图直接按视频目标画幅生成；跨 clip 角色一致性靠共用角色设定图作参考输入，
  不靠事后画幅转换。图片语义门审查的图必须与提交图生视频的图是同一张——过门后
  再经任何重新生成类处理（转画幅/outpaint/重绘）都必须重新过门。
- Director 是第一版唯一核心智能中间层：写 prompt、查看结果、指出主要语义偏差并修正。
  不预先拆成 Reviewer、Decision Policy 或复杂生产状态机；重复失败模式出现后再抽象。
- 生成本身也是探索手段。不要因为预设视频昂贵而延迟生成，优先快速取得候选和反馈。
- 渲染层全局视觉方向是`Pixar-style 3D animated film`。该高层标签与具体造型、材质、
  灯光、色彩和表演属性共同写入`prompts/render-style.yaml`和Director Prompt，但不得进入
  WordSense或SceneSpec。具体checkpoint、工作流和供应商能力仍只属于适配层。
- 个性化只改变表面经验、入口和教学顺序；不得改变通用语义骨架、偷换对比词，或让
  个体化样本成为唯一概念证据。
- 任何 API、内容包或下游导出都应区分 `draft`、`reviewed`、`published` 等发布状态，
  不把草稿默认暴露为可信词典内容。

## 与外部消费端集成

SceneLex 可向词典、播放器或课程应用提供两类能力：

1. **检索已发布教学资源**：按语言、lemma、词性、义项、L1 或内容版本查询，返回
   已审核的语义规格摘要、场景组和可下载/播放的资源引用。
2. **异步请求内容生产**：接收词、词性、语境、学习者背景和生成范围，创建可追踪任务；
   结果先进入草稿/审核流，而非绕过质量门直接发布。

集成设计规则：

- “词”不是充分的生成输入；多义词必须允许词性、上下文或用户选择来确定目标义项。
- 外部系统的本地学习记录、用户文件夹或能力画像属于该系统自身的身份权威。SceneLex
  提供稳定的外部 `sense_id` 与内容版本作对齐引用，不接管这些用户资产。
- API 和内容包是适配器层，必须保持模型无关、可版本化且可缓存；不要让 HTTP、某个
  播放器 UI、某家模型 API 或某种视频格式进入 `schema/`。
- 通用分发优先使用 `tools/export.py` 与资源包 Schema。HTTP 服务、数据库索引和 SDK
  是稳定包格式之上的消费者适配器。
- 任何消费端都只能推动新增的适配器、导出格式或元数据；若要求改变核心语义模型，先以
  SceneLex 的教学理论、数据不变量和多消费者价值评审该变化。

## 工作流程

1. 阅读相关 schema、至少一个同类正式义项和对应证据组，再开始修改。
2. 新词先规划整词 Inventory（`inventory.py draft` → 人工审阅 → `mark-reviewed`
   → `approve`），再按 Inventory 起草义项。新义项先进入 `data/drafts/senses/`；
   场景先进入对应 `data/drafts/scenes/`。
3. 运行 `python3 tools/validate.py` 和 `python3 -m pytest -q`；需要排期时运行
   `python3 tools/validate.py --backlog`。
4. 可选：用 `python3 tools/review.py <id>` 或工作台"模型审核"按钮生成审核参考，
   检查：语言准确性、语义条件完整性、视觉/听觉可观察性、相邻词低歧义性、
   声画时序、L1 教学洞察、迁移性和版权/许可。审核不阻塞 promote。
5. promote 由人工决定。promote 必须先在隔离数据根目录执行全量
   校验，成功后再原子移动，禁止先写正式库再校验。
6. 修改 schema、ID 规则、发布状态或生产管线时，更新 README、校验器、提示词、范例和
   必要的迁移/兼容说明；避免只改其中一个。

## 完成前检查

- `python3 tools/validate.py` 通过。
- `python3 -m pytest -q` 通过。
- 新增/修改的场景满足义项的 `must_show` / `must_not`，并且五类场景的职责没有互相混淆。
- 没有把模型名、渲染参数、下游应用专有字段或未审核素材路径写进正式 scene spec。
- 对比关系没有把包含、重叠、程度差异或不同维度误写成互斥。
- `git status --short` 已检查，未覆盖无关改动。
