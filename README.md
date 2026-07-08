# SceneLex

> 为每个词义建立可验证的语义规格，并用最有效的媒介（场景、对比、必要时包括 L1）把它教准。

SceneLex 是一套"场景即释义"的语言学习系统的**语义骨架层**。它不生成视频、不绑定任何模型——它定义词义的语义规格与场景的教学规格，下游的生成模型只是可替换的渲染后端。

理论全文见 [一、先明确系统最终要解决什么问题.md](一、先明确系统最终要解决什么问题.md)。

## 已定决策

1. **全量覆盖，而非只做"难词"**。系统的差异化价值集中在翻译教不准的词（L1 边界错位词、心理/逻辑词），但 AI 时代材料生成成本低，简单词也纳入——不做全就不成系统。
2. **个性化后置**。先做通用场景。个性化本身需要分层设计（文化/国别层 vs 个人层），属于后期工作；schema 中的 learner-profile 与 target_learner 字段为其预留位置。
3. **句法层后置**。当前只做词义接地层（scene → word）；scene → phrase/sentence/dialogue 是验证词义层之后的扩展。
4. **生成层模型无关**。scene-spec 是纯文本的中间表示（IR），不含任何模型名或生成参数。具体调用哪个大模型/视频模型按需决定，属于适配器层。

## 三层架构

```text
通用语义骨架 (data/senses)   —— 词义的成立/排除条件, 独立于文化
个性化经验渲染 (后置)         —— 同一骨架的不同表面
跨场景概念泛化 (场景组结构)   —— 原型/对比/反例/边界/迁移
```

## 目录结构

```text
schema/
  word-sense.schema.json      词义规格: 语义骨架、成立/排除条件、L1 混淆、场景要求
  scene-spec.schema.json      场景规格: 分镜节拍、声画时序、学习任务 (模型无关 IR)
  learner-profile.schema.json 学习者画像 (个性化后置, 先行预留)
data/
  senses/{word}-{nn}.yaml     词义数据, 文件名 = id
  scenes/{sense_id}/          每个词义一个目录, 五类场景:
    {sense_id}-proto-{nn}.yaml      原型: 首次建立概念
    {sense_id}-contrast-{nn}.yaml   对比: 与近义词切分 (需 contrast_target)
    {sense_id}-counter-{nn}.yaml    反例: 划出概念下界
    {sense_id}-boundary-{nn}.yaml   边界: 接近但不成立的临界案例 (需 contrast_target)
    {sense_id}-transfer-{nn}.yaml   迁移: 跨领域验证抽象
data/drafts/                  起草待审区，与正式库隔离；审阅后 promote 入库
prompts/
  sense-draft.md              词义起草提示词模板
  scene-draft.md              场景组起草提示词模板
tools/
  validate.py                 数据校验器
  llm.py                      生成层适配器（模型无关，后端可换）
  draft.py                    内容起草工具（管线第 2、3 阶段）
```

## 内容生产管线

系统的最简形态就是一条内容生产工作流，学习端是附加层。六阶段：

```text
1 选词      backlog / 词频 → 候选词
2 词义起草  LLM 按 schema+范例起草 → 校验 → 人工定稿
3 场景组起草 LLM 按词义规格编译五类场景 → 校验 → 人工定稿
4 渲染      场景规格 → 适配器层(图像/视频/TTS，按需选模型) → 素材
5 审核      语言/场景/教学三层审核
6 发布      素材与规格绑定入库
```

阶段 2、3 已由 `tools/draft.py` 自动化，人从"作者"变为"编辑"：

```bash
python3 tools/draft.py backlog          # 选词：输出待建义项清单
python3 tools/draft.py sense dirty      # 起草词义 → data/drafts/senses/
python3 tools/draft.py scenes dirty-01  # 起草五场景组 → data/drafts/scenes/
python3 tools/draft.py list             # 列出待审草稿
# —— 人工审阅草稿，改到满意 ——
python3 tools/draft.py promote dirty-01 # 定稿入库并跑全量校验
```

生成层模型无关：调用哪个模型由 `tools/llm.py` 决定，通过环境变量切换，与场景规格（纯文本 IR）解耦。

```bash
SCENELEX_LLM_BACKEND=claude-cli|anthropic   # 默认：有 ANTHROPIC_API_KEY 用 anthropic，否则 claude-cli
SCENELEX_LLM_MODEL=<模型名>                  # 可选，默认 claude-opus-4-8
```

## 校验与手写

```bash
python3 tools/validate.py            # 校验全部数据 (schema/ID 约定/引用完整性/场景组覆盖)
python3 tools/validate.py --backlog  # 输出"被引用但未建"的义项清单 = 下一批选词候选
```

手写路径仍可用：复制 `data/senses/` 下任一文件为模板，按 A–F 分区填写，跑校验。
新增场景：为该词义建目录，五类场景各至少一个；分镜写作规则——
先让观众完成概念体验，再出现目标声音；心理状态必须行为外化，禁止台词直述（如 "I'm reluctant"）。

注意：YAML 无引号标量内不要使用 ASCII `": "`（用中文全角冒号），英文台词一律加双引号。

## 当前状态 (2026-07)

- 词义 3 条：messy-01、reluctant-01、almost-01（覆盖属性/心理状态/标量程度三类）
- 场景组 2 组完整（messy-01、reluctant-01 各 5 场景）；almost-01 场景组待建
- 悬空引用 backlog 34 条，高频者（nearly/dirty/chaotic/refuse/unwilling/untidy）为下一批建库优先
- 下一步：almost-01 场景组 → 按 backlog 扩词义至 30–50 条（MVP 规模）→ 学习流程设计
