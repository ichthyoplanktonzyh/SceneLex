# Experience Compiler v1

> 新主线：WordSense → 四阶段编译 → 版本化 ExperienceProgram。
> 本说明记录权威链路、deep module interface、内部阶段、与 SceneSpec 的关系、
> regression fixtures 职责，以及当前接入边界。

## 1. 权威链路

```text
WordSense (data/senses/{sense_id}.yaml, 输入权威)
  → Semantic Planner                 (prompts/experience-compiler/semantic-planner.md v1)
  → Experience Program Planner       (prompts/experience-compiler/program-planner.md v1)
  → Surface Experience Generator     (prompts/experience-compiler/surface-generator.md v1)
  → 装配 + JSON Schema 校验 + 确定性校验
  → Semantic Critic / Quality Gate   (prompts/experience-compiler/quality-gate.md v1)
  → ExperienceProgram (schema/experience-program.schema.json v1.0)
```

- **WordSense 是唯一输入权威**。SceneSpec 不再是经验单元的来源：它不是 Compiler
  的输入。旧 SceneSpec / Shot Plan / 视频切片是历史资产，语义修订过期后由
  `tools/revisions.py` 标记为 stale，不参与新编译。
- 语义意图（semantic_spec / semantic_model）与学习者可见表面经验（episode /
  observable_evidence / interaction）在结构上分离：Program Planner 只产语义计划，
  Surface Generator 才实现表面文本。

## 2. Deep module interface

`tools/experience_compiler.py` 对外只暴露很小的一组入口：

| 入口 | 签名 | 说明 |
| --- | --- | --- |
| `compile_experience_program` | `(sense_id, *, adapter=None, config=None, program_version=1) -> dict` | 输入 sense_id 与可注入生成 adapter，返回已通过 Schema、确定性校验与质量门的完整程序（**只能产出 status=draft**） |
| `validate_program` / `validate_program_file` | `(program) -> list[Diagnostic]` | 完全离线的确定性校验 |
| `run_regression` | `() -> RegressionResult` | 完全离线的四词 fixture 回归 |
| `CompileError` | 聚合领域错误 | 携带 `diagnostics`：每条含 stage / 数据路径 / 可执行问题描述 |

四阶段**不是公共接口**，测试与正式调用者走同一个 `compile_experience_program`。
模型调用统一经 `tools/llm.py`（adapter 缺省时）；测试注入纯内存 fake adapter，
测试路径不触网。每个阶段最多一次重试：首次为空响应、传输失败、JSON 解析失败
或缺少必需结构时，追加明确 repair instruction 后再调用一次；第二次仍失败抛
CompileError。确定性语义失败与 critic 的 fail 判定不重试。

## 3. 四个内部阶段

1. **Semantic Planner**：还原 semantic_model（invariant / necessary_conditions /
   non_entailments / typical_correlates / misconceptions / l1_interference）。
   misconceptions 携带稳定 id，供单元的 `hypothesis_target` 引用。
2. **Experience Program Planner**：规划有序概念单元（id / sequence / role /
   hypothesis_target / preserved_variables / changed_variables / semantic_spec）、
   grounding 计划、review_pool 计划、symbol_binding 计划。不写任何学习者可见文本。
   role 是教学 primitive（anchor / variation / perturbation / discrimination /
   transfer），**不规定固定组合**，禁止按 SceneSpec 五场景机械映射。
3. **Surface Experience Generator**：把语义计划实现为 learner-visible 表面：
   episode、可观察证据、surface dimensions、可评分 interaction、揭示
   （symbol_binding）、L2 落地（grounding.l2_realization）、复习池经验。揭示前
   内容禁止目标词与相邻 L2 词。
4. **Semantic Critic / Quality Gate**：九个固定维度
   （semantic_correctness / sense_purity / prototype_quality / definition_leakage /
   l2_leakage / variable_isolation / accidental_invariant / transfer_novelty /
   cognitive_noise）。任何维度 verdict=fail 时 compile 不返回程序；结果写入
   metadata.quality_gate，不泄漏进 learner-visible 内容。pass 不代表自动发布。

## 4. ExperienceProgram v1 关键决定

- 稳定字符串 ID（program/unit/review/misconception），不要求 UUID。
- `symbol_binding` 独立于 concept units，出现在所有概念单元（含 transfer）之后。
- `grounding.source_experience_id` 必须引用首学真实存在的 unit。
- `review_pool` 只用首学未出现的新经验。
- 确定性校验覆盖：Schema、ID 唯一、sequence 连续、grounding 引用、anchor 存在、
  揭示前 transfer 存在、observable_evidence、**每个 interaction 恰好一个正确
  答案**、misconception 全覆盖、受控变量、**preserved/changed 变量不重叠**、
  **每个 changed_variable 必须在 surface_dimensions 或 semantic_spec 中找到
  对应**、review novelty、揭示前 L2 泄漏（含相邻词派生形式，如
  unwilling → unwillingness）、transfer ≥2 表面维度、同构单元拦截、
  **九维 quality gate 全集/唯一/passed-verdict 一致性**、**target/metadata 与
  WordSense 权威绑定**（sense_id / lemma / pos / semantic_revision）。
- metadata 记录 compiler_version / 四阶段 prompt_version / generated_at /
  source semantic_revision（必需整数；legacy WordSense 按 1）/ model_provider /
  model_name / request_id（非敏感）/ quality gate 结果（scores 为可选的 0-10
  参考分，不是通过依据）。
- 人工发布权保留在契约中（status 枚举 draft/reviewed/published），但编译器只能
  产出 draft；reviewed/published 由未来的独立人工 promotion 流程设置。
- 模型原始输出只落 `data/drafts/experience-programs/{sense_id}/v{NN}/`（目录
  vNN 与 program_version 一致，缺省自动递增且禁止覆盖已有版本），不进入正式
  内容库；`--output` 可显式指定草稿内路径，越界或已存在即报错。

## 5. regression fixtures 职责

`tests/fixtures/experience-programs/` 冻结四词回归集（reluctant-01 / messy-01 /
almost-01 / dirty-01），是**人工可审查的候选程序**，不是模型自动发布的产物：

- 四个 fixture 必须通过新 Schema 与全部确定性校验；
- 程序结构必须真实差异（单元数量 / role 组合 / 变量结构互不相同），防止"同一
  模板替换名词"；
- reluctant-01 必须显式变化 `eventual_action=yes/no` 双值，discrimination 区分
  "积极意愿+不确定"与"消极意愿"，且不得用旁白直陈语义；
- almost-01 围绕明确 threshold / 极度接近 / 未跨越，程序结构呈阈值-进程弧；
- dirty-01 围绕洁净基线 + 外来物质 + 可观察表面证据；
- messy-01 围绕预期排列 + 错位 + 可见组织变化；
- `python3 tools/experience_compiler.py regression` 完全离线地守护这些约束。

## 6. 当前接入边界

- **未接入**：Flutter (`app/`)、Server (`server/`)、数据库 (`db/migrations/`)，
  以及旧的 `scripts/import_content.py`。本阶段只交付契约、编译器、prompt、
  离线回归与 fixture。
- **下一阶段**才替换 `scripts/import_content.py` 与 Runtime adapter，把
  ExperienceProgram 接入学习端。
- 旧视频管线（SceneSpec → Shot Plan → Keyframe → 渲染）保持为 legacy，不受本
  阶段影响；reluctant-01 旧场景绑定语义修订 v1，随 WordSense 升到 v2 显式 stale。

## 7. CLI

```bash
python3 tools/experience_compiler.py validate <program-file>   # 离线
python3 tools/experience_compiler.py regression                # 离线四词回归
python3 tools/experience_compiler.py compile <sense-id> [--output PATH] [--version N]
```

`compile` 在缺少 LLM 配置时以退出码 2 清晰失败；生成结果默认写入
`data/drafts/experience-programs/{sense_id}/v{NN}/program.yaml`（NN 与
program_version 一致），已存在版本禁止覆盖，永不覆盖既有产物。
