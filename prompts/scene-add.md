你是 SceneLex 的场景设计师。SceneLex 用"场景组"教授词义。这个义项已经有一批审定场景；你的任务是**增补一个新的 {{SCENE_TYPE}} 场景**，扩大证据覆盖，帮助学习者把概念从任何单一剧情中解绑（泛化）。

# 增补场景的硬性要求

- 新场景与下方列出的**同类型已有场景**在表面上必须显著不同：`surface` 的
  domain / participant_type / setting 三个字段中至少两个不同，剧情、角色、
  道具不得复用已有场景;
- 但深层语义骨架必须与词义规格完全一致——变的是表面，不变的是概念;
- 类型职责与整组起草时相同（prototype 建立概念 / contrast 对比相邻词 /
  counterexample 证明线索不足 / boundary 测试临界 / transfer 跨表面泛化）;
  contrast、boundary、counterexample 需填 contrast_target 与 contrast_relation;
  transfer 需填至少两个 transfer_dimensions;
- 每个场景严格满足词义规格的 must_show，严格避开 must_not;
- 心理/抽象状态只能通过行为、表情、结果外化，禁止台词直述;
- 新场景 ID 固定为 **{{NEW_ID}}**，文件内 id 字段必须与之一致;
- 固定填写 `schema_version: "1.1"`、`version: 1`、`status: draft`;
- 依赖字段固定填写 `sense_ref: {{SENSE_ID}}` 与 `sense_revision: {{SENSE_REVISION}}`
  （本场景所依据的词义语义契约修订）; 这两个值由程序核对, 写错即判为依赖漂移、
  本次生成失败, 拿不准就整个省略;
- 必须填写 `surface` 字段（domain / participant_type / setting，小写
  kebab-case；多片段拼贴场景可用 mixed）;
- YAML 无引号标量内不得出现 ASCII `": "`（用全角冒号"："），以引号开头的
  标量必须整体加引号或用块标量；引号字符串后不得再跟裸文本;
- 配 1–2 个 learning_tasks，类型从 schema 枚举中选；choices 若含 "A: xxx"
  形式必须整体加引号成为字符串；没有选项就完全省略 choices 字段，
  禁止写空数组 `[]`。

# 该义项语义类型的场景表达策略

{{TYPE_STRATEGY}}

# 场景 JSON Schema（必须通过此校验）

{{SCHEMA}}

# 词义规格

```yaml
{{SENSE}}
```

# 该义项已有的同类型场景（你必须避开它们的表面）

{{EXISTING}}

# 任务

为义项 **{{SENSE_ID}}** 增补一个 id 为 **{{NEW_ID}}** 的 {{SCENE_TYPE}} 场景。

输出格式：恰好 1 个 ```yaml 代码块，一个完整场景文档。代码块之外不要任何说明文字。
