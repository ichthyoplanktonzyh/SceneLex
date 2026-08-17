# 交接:Learning Presentation Language Contract v1 + 教学原型覆盖管线

> 交接人:前序 coding agent
> 日期:2026-08-16
> 状态:代码侧全部完成;真实 LLM 内容迁移进行中(卡在概念资产质量门)
> 前置阅读:`docs/learning-presentation-language-contract-v1.md`、
> `docs/refactor-sense-asset-pipeline.md`、`CONTEXT.md`

---

## 0. 任务一句话

在 SceneLex 完成"L1 脚手架内容合同 + 教学原型覆盖管线"纵向切片:建立
`Learning Presentation Language Contract v1`(zh-CN 学习者、绑定前 learner-visible
内容使用中文、目标 L2 首次出现在 symbol binding),把语言协议落实进 schema /
compiler prompts / 自动质量门 / App 渲染与测试,迁移现有四义项,并建立按
teaching_archetype 抽样的 MVP 覆盖清单与机器可读生产队列。

## 1. 当前基线(重要)

- 分支:`feat/learning-journey-prototype`,HEAD `e341957`(本任务**未提交、未 push**)
- 任务开始前工作区已有未提交的 Compiler v2 重构(架构评审交接):
  `schema/experience-program.schema.json`、`tools/experience_compiler.py`、
  `data/contracts/**`、`data/experience-assets/**`、`docs/refactor-sense-asset-pipeline.md`、
  `prompts/experience-compiler/boundary-producer.md`、`schema/boundary-package.schema.json`
- 本任务在这些文件上继续工作(它们本就允许修改),**其余仓库文件不得碰**
- **不提交、不 push**;不降级任何 draft/release gate;不伪造 LLM 产物
- 工作区另有其他进行中的他人改动(如 `data/experience-assets/almost-01`、
  `reluctant-01` 目录等),**不要 reset/checkout/覆盖**

## 2. 已完成(全部验证通过)

### 2.1 语言合同
- `docs/learning-presentation-language-contract-v1.md`:四阶段(pre_binding /
  symbol_binding / early_post_binding / later_post_binding)、L2 leakage 与
  L1 label leakage 定义、Boundary/Review/Transfer 语言规则、App 只渲染不翻译、
  兼容策略(legacy v0 显式拒绝,可删除)

### 2.2 Schema
- `schema/experience-program.schema.json`:顶层 `language_policy`
  (policy_version/learner_l1/target_l2,required);review item 可选
  `scaffold_level`;`target.locale_l1` 必须为 learner_l1 短码
- `schema/boundary-package.schema.json`:同样 `language_policy`(required)
- `schema/teaching-archetype-coverage.schema.json`(新):覆盖清单校验

### 2.3 Compiler(tools/experience_compiler.py,v2.0.0 → 2.1.0)
- `PresentationLanguage` dataclass(默认 zh-CN/en/v1),**贯穿全部 producer**:
  concept / transfer / review / grounding / boundary(含纯函数与对外入口),
  注入 `# Presentation Language Policy` prompt 节
- 资产 `metadata.language_policy` + `_ensure_asset_current` stale 检查
  (legacy v0 资产无声明 → 拒绝装配,需重新生成)
- 确定性语言门(全部带字段路径 + 修复说明):
  1. L2 leakage:目标词含派生/屈折形式(y→i 规则:messier/messiest)、相邻词;
     覆盖 concept units、transfer、review 场景、boundary 场景
  2. Surface language:成段英语检测(实词 token ≥3)
  3. L1 label leakage:minimal_l1_gloss 原样复制、已知 L1 标签
     (sense.relations.l1_confusables.zh[*].l1_term 为权威来源)
  4. Stage consistency:reveal.l2_word==lemma、grounding 必须含目标 L2 或自然词形、
     locale 一致性、scaffold_level 合法
- LLM gate 新维度:`l1_label_leakage`、`surface_language_compliance`
  (concept 10 维 / review 7 / transfer 9 / grounding 2 / boundary 8)
- boundary 语言规则:选项只能是两个已绑定 L2 lemma、场景/问题/反馈/解释中文

### 2.4 Prompts(5 个全部 v2)
`semantic-planner` / `program-planner` / `surface-generator` / `quality-gate` /
`boundary-producer` 均注入语言合同;删除"揭示前选项用日常英语"旧规则。

### 2.5 教学原型覆盖管线
- `data/content-plans/mvp-teaching-archetypes.yaml`(新):7 原型 × 14 义项
  (visible_state: messy/dirty;intention_cues: reluctant/hesitant;
  threshold_scale: almost/barely;spatial_path: across/through;
  role_perspective: borrow/lend;entity_category: cup/mug(both_allowed=true);
  cognitive_update: notice/realize)。未入身份链的词只记录 lemma+pos,**不伪造 sense_id**
- `tools/teaching_coverage.py`(新):`validate` / `report` / `queue` / `queue --json`;
  状态从仓库真实文件计算(inventories/senses/contracts/assets/drafts/fixtures),
  状态链 needs_candidate → … → draft_ready → release_ready;legacy v0 资产
  视为缺失(需按合同重新生成)
- `tests/test_teaching_coverage.py`(10 过)

### 2.6 App
- `LanguagePolicy` 解析(不一致/缺失即抛错)、`ReviewItem.scaffoldLevel`
- `test/fixtures/zh_contract_program.dart`(新):合同合规中文程序 + boundary
- `test/language_contract_acceptance_test.dart`(8 过):5 个验收画面
- `test/language_contract_screenshots_test.dart`(新):5 张验收截图
  `docs/prototypes/daily-session/09~13-language-*.png`
- `test/fixtures/program_factory.dart` 已加 language_policy
- `docs/prototypes/daily-session/README.md` 新增 9.1 节

### 2.7 测试现状
- ✅ `tests/test_language_contract_gates.py`(25 过,自包含,不依赖 fixture)
- ✅ `tests/test_teaching_coverage.py`(10 过)
- ✅ `app/test/language_contract_acceptance_test.dart`(8 过)
- ❌ `tests/test_experience_compiler.py` 目前 51 失败(预期:旧 fixture 无
  language_policy 且绑定前内容为英文,迁移后恢复)
- ❌ app 的 journey/daily_session 测试失败(同上,依赖旧 bundle)

## 3. 卡点:真实 LLM 内容迁移(进行中)

### 3.1 环境事实
- 真实配置在 `/Users/shadow/SceneLex/.env`(SCENELEX_LLM_PROTOCOL=openai-chat,
  MODEL=deepseek-v4-flash,经 opencode.ai 代理)
- **必须 `source .env` 且 `export SCENELEX_LLM_STREAM=0`**:流式对长输出解析
  bug(SSE chunk 解析失败),非流式可用
- 代理偶发 HTTP 500,需重试(现有迁移脚本已带 6 次重试)

### 3.2 进度
- ✅ messy-01 contract(数据/contracts/messy-01.yaml)
- ❌ concept messy-01:被 Semantic Quality Gate 连续拦截 3 次(variable_isolation /
  accidental_invariant),attempt 4 进行中

### 3.3 拦截原因分析(已处理一部分)
1. **提示词缺陷(已修复,重要)**:surface-generator / program-planner 原本没有
   "正确答案位置必须随机分布"与"正例之间 changed_variables 取值必须多样化"
   的规则 → LLM 习惯性把所有正确答案放第二个选项、所有正例都"干净完好"
   (messy 场景全 clean 形成"messy 蕴涵干净"假不变式)。已在三个 prompt 中
   补规则(注意:prompt 内容变更后版本号仍为 v2,这是同一版本的定稿)
2. **残余问题**:即使有规则,LLM 生成的单元设计(尤其 dirty/messy 正交维度、
   正例需含 dirty+messy 组合)仍可能被 gate 判 fail。**这是内容质量问题,
   不是 gate 误判**——gate 的判据与 WordSense(sense 文件里的 relations /
   scene_requirements)一致。不得为通过而降低 gate。

### 3.4 若 concept 持续被拦(给接手者的选项)
- 看 `/tmp/migrate_step.log` 的 gate 诊断,判断是变量设计还是文本细节
- 可把 WordSense 的 `scene_requirements.must_show` 更完整地注入 producer prompt
  (当前 sense yaml 全量传入,规则在 prompt 的"教学结构与纪律"里,可再加一条
  "正例必须覆盖脏乱并存组合")
- 可重试(每次是全新调用);LLM 有随机性,多次采样后通过概率高
- **红线:不要手工改 gate 判据、不要手写冒充 LLM 产物、不要伪造 request id /
  model metadata**

## 4. 剩余步骤(接手者执行清单)

1. **完成迁移**(脚本 `/tmp/migrate.sh` 已写好:带重试、已有合规资产自动跳过):
   - 4 义项(messy/dirty/almost/reluctant)× concept → transfer-add --count 3 →
     review-add --count 6 → grounding
   - boundary: `python3 tools/experience_compiler.py boundary dirty-01 messy-01`
   - 检查点:`data/experience-assets/{sense}/` 四类资产齐 + `data/boundaries/`
2. **迁移 fixture**(脚本已写好 `/tmp/migrate_fixtures.py`):
   - 用 assemble_program 从 contract+assets 重建 4 个 fixture,status 保持
     **reviewed**(语义未变,语言迁移人工审阅),并写入
     `tests/fixtures/boundaries/dirty-01__messy-01.yaml`
   - 运行 `python3 tools/experience_compiler.py regression` 验证
3. **适配旧测试** `tests/test_experience_compiler.py`(51 个失败):
   - fixture 迁移后,`stage_responses` 的 quality_gate 响应来自 fixture 新
     metadata(维度含 l1_label_leakage / surface_language_compliance)
   - `test_gate_single_dimension_is_compile_error` 等断言"九个维度"字样需更新
   - 迁移后先用 pytest 跑一遍,按失败逐项适配,不要跳过
4. **重建 bundle**:`python3 tools/build_experience_app_bundle.py`
   (允许修改 `app/assets/content/experience-programs.v1.json`)
5. **App 侧验证**:journey / daily_session 测试恢复;重新生成 01-08 截图
   (内容变中文,`flutter test test/daily_session_screenshots_test.dart
   --update-goldens --dart-define=SCENELEX_GEN_SHOTS=true`)
6. **全量验证命令**(任务第十二节):
   ```bash
   python3 -m pytest -q tests/test_experience_compiler.py
   python3 -m pytest -q tests/test_teaching_coverage.py
   python3 -m pytest -q tests/test_experience_app_bundle.py
   python3 tools/experience_compiler.py regression
   python3 tools/teaching_coverage.py validate
   python3 tools/teaching_coverage.py report
   python3 tools/teaching_coverage.py queue
   python3 tools/build_experience_app_bundle.py --check
   cd app
   flutter gen-l10n
   dart format <修改的 Dart 文件>
   flutter analyze
   flutter test
   ```
7. **交付汇报**(任务第十四节 12 项)

## 5. 关键技术笔记

- 资产语言政策在 **metadata.language_policy**(不在顶层);
  `_ensure_asset_current` 检查它;`teaching_coverage._asset_ok` 同样
- fixture 通过 validate 的条件:units≥3、review_pool≥6、每个 misconception
  被 hypothesis_target 覆盖、metadata.source_contract_hash 与
  data/contracts/{sense_id}.yaml 的 content_hash 一致、semantic_model 必须
  是 contract 的投影(不能是旧文本)
- 旧 fixture metadata 是 fake-adapter 时代格式,无 asset_gates —— 迁移必须
  完整重建(assemble_program 会重算)
- `run_regression` 要求 `tests/fixtures/boundaries/dirty-01__messy-01.yaml` 存在
- LLM 500:重试 6 次、sleep 20;可用 `tail /tmp/migrate.log` 看进度
- 中文含 "几乎/脏/乱" 等词会触发 L1 label leakage(interaction 字段严格;
  叙事字段短句/直陈式才拦),surface prompt 已指导 LLM 用行为描述
- App 端 zh_contract_program.dart 的 review_pool 只有 1 条,但 App 解析不校验
  minItems(Python 端才校验 6 条),验收测试不受影响

## 6. 红线(再次强调)

- 不提交、不 push Git
- 不碰任务开始前的他人未提交改动(见第 1 节清单;`data/contracts/**` 与
  `data/experience-assets/**` 本任务允许写入)
- 不伪造 LLM 产物、request id、model metadata;数据迁移必须经正式 producer
- 不降低 bundle/import/release gate;`--check` 结果要诚实
- 不跳过 Dictionary → Inventory → WordSense 身份链;不给新 lemma 伪造 sense_id
- 不重新设计 Daily Session 编排 / 发布状态机 / 多语言平台
