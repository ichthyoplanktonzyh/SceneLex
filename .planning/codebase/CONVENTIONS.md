# SceneLex — 约定与规范

> 最后更新：2026-07-16
> 命名、格式、工作流和代码风格的权威约定

## 命名约定

### 义项 (sense)

- ID 格式：`{word}-{nn}`。`word` 为小写字母和下划线（如 `run_away` → `run_away-01`）。
- 文件名：`{sense_id}.yaml`。
- 标签：中文简短描述，供内部使用（如 `sense_label: "不情愿/勉强"`）。

### 场景 (scene)

- ID 格式：`{sense_id}-{type_abbr}-{nn}`。type_abbr 为 proto / contrast / boundary / counter / transfer。
- 文件名：`{scene_id}.yaml`。
- 目录：`data/scenes/{sense_id}/`。

### Phase

- 目录名：`{编号}-{短横线分隔的功能描述}`，如 `1.1-complete-existing-scenes`。
- 文件前缀与目录编号一致：`PLAN.md`、`CONTEXT.md`、`CLOSEOUT.md` 放在 phase 目录下。

### 讨论文档

- 命名：`{主题}.md` 或 `{主题}.zh.md`，中文内容用 `.zh.md` 标记。
- 位置：`.planning/discuss/`。

## YAML 格式约束

### 标量与引号

- **无引号标量**：不要包含 ASCII `": "`（冒号+空格），会被解析为键值对。
- **含英文台词**：使用双引号或块标量（`|` 或 `|-`）。
- **含特殊字符**（`#`、`{`、`}`、`[`、`]`、`,`、`&`、`*`、`!`、`>`、`|`、`%`、`@`）：使用引号。

### 缩进与结构

- 缩进：2 空格（不要用 Tab）。
- 列表项使用 `- `（短横线+空格）。
- 多行字符串优先使用块标量 `|-`（保留换行，去掉末尾空行）而不是长行。

### 示例

```yaml
# 好的做法
audio: "Come on, let's go!"
synopsis: |-
  小张的办公桌堆满了文件、咖啡杯和零食包装。
  同事路过时皱了皱眉。

# 避免
audio: Come on, let's go!  # 撇号可能被特殊解析
```

## 工作流约定

### 起草流程

```bash
# 1. 检查 backlog
python3 tools/draft.py backlog

# 2. 生成义项草稿
python3 tools/draft.py sense dirty

# 3. 为义项生成场景草稿
python3 tools/draft.py scenes dirty-01

# 4. 查看当前状态
python3 tools/draft.py list
```

### 审核与发布流程

```bash
# 1. 全量校验（含 backlog）
python3 tools/validate.py --backlog

# 2. 运行测试
python3 -m pytest -q

# 3. promote 到正式库
python3 tools/draft.py promote dirty-01

# 4. 导出消费端资源包
python3 tools/export.py --version 0.2.0 --output dist/scenelex-0.2.0.json
```

### Promote 原子性

`promote` 先把候选资源与整个正式库合并到隔离目录中，通过全量校验后再原子移动。不会出现"先污染正式库、后发现校验失败"。

### 审核清单

每项资源 promote 前检查：

1. 语言准确性（义项定义、台词自然度、搭配真实性）。
2. 语义条件完整性（must_show / must_not 是否覆盖）。
3. 视觉/听觉可观察性（内部状态是否外化）。
4. 相邻词低歧义性（场景不会错误指向另一个义项）。
5. 声画时序（目标声音出现时机是否合理）。
6. L1 教学洞察（`l1_confusables` 是否真实反映母语者混淆）。
7. 迁移性（迁移场景是否真正改变了 ≥2 维度）。
8. 版权/许可（来源是否可追溯）。

## LLM 调用约定

- 所有生成调用统一走 `tools.llm.generate(prompt)`。
- 协议通过 `SCENELEX_LLM_PROTOCOL` 环境变量选择。
- 模型名、API Key、URL 等通过环境变量配置，不进入代码或配置文件的硬编码。
- 支持的协议：`openai-responses`、`openai-chat`、`anthropic`、`command`。
- 不配置协议时工具明确报错，不静默选择某个厂商。
- 供应商特有功能（工具调用、缓存等）应放在新协议适配器中，不污染资源契约。

## Git 约定

- 正式库 (`data/senses/`、`data/scenes/`) 修改需要完整校验通过后提交。
- 草稿区 (`data/drafts/`) 可以随时提交，但提交信息应标明未审核。
- `promote` 操作（草稿 → 正式库）应单独提交，提交信息包含"promote: {sense_id}"。
- Schema 变更需要同步更新：校验器、提示词、范例和 AGENT.md 中的相关约束。

## 代码风格（Python 工具链）

- 工具链 (`tools/`) 保持单文件、无类模块风格。
- 函数使用 type hints。
- 对外接口优先使用 dataclass 或 TypedDict，不引入重型 ORM。
- 测试 (`tests/`) 使用 pytest，每个工具一个测试文件。
- 依赖管理：`requirements.txt`（生产）和 `requirements-dev.txt`（开发含 pytest）。
