# SceneLex v1 数据模型映射

> flashcards 数据模型 → SceneLex 数据模型。同步协议与 FSRS 行为照抄(见 behavior-spec),内容模型替换。
> 本文档与 `rewrite-plan.md`、`behavior-spec-flashcards.md` 配套。

## 1. 核心映射

| flashcards | SceneLex | 说明 |
|---|---|---|
| `content.cards` | `content.learning_states` | per (user × word_sense) 的 FSRS 状态 + 学习进度;内容本体从卡片行剥离 |
| `content.review_events` | `content.review_events`(扩展) | 增加 word_sense_id / program_version / experience_unit_id |
| `content.decks` | `content.lists`(词单) | 复用"标签筛选"行为,语义换为词单 |
| 卡片内容(front/back) | ExperienceProgram + 词义库 | 内容通道,单向分发 |
| 卡片创建 | 词义库添加(选已发布 Program) | 无用户生成内容(v1) |
| `org.workspaces` | 不变 | FSRS 设置列沿用 |
| `sync.*` | 不变 | 全套照抄 |

## 2. 复习对象设计(关键决策)

**复习的最小对象是 WordSense,但每次复习的内容是 Program 的一个变体。**

```sql
-- content.review_events(v1 扩展)
review_event_id    UUID PK
workspace_id       UUID
word_sense_id      UUID          -- 复习对象
program_version    INT           -- 本次复习所用的 ExperienceProgram 版本
experience_unit_id UUID          -- 本次复习实际呈现的经验单元(transfer 变体等)
rating             SMALLINT      -- 0..3
reviewed_at_client TIMESTAMPTZ   -- FSRS 时间基准
reviewed_at_server TIMESTAMPTZ
replica_id         UUID
client_event_id    UUID          -- 幂等键
review_sequence    BIGINT        -- append-only 游标
reviewed_time_zone / reviewed_local_date
```

这一设计让复习历史成为**编译器效果实验数据**:可按 program_version 分组分析 retention/transfer 效果、定位最差经验单元——呼应"哪类 experience 效果最好"的长期目标。

## 3. LearningState(进度通道核心表)

```sql
-- content.learning_states
learning_state_id  UUID PK       -- 客户端生成
workspace_id       UUID
user_id            UUID
word_sense_id      UUID
status             TEXT          -- 'new'|'active'|'suspended'|'retired'(v1 简化)
-- FSRS 字段(照抄 flashcards)
due_at             TIMESTAMPTZ
reps               INTEGER
lapses             INTEGER
fsrs_stability     DOUBLE PRECISION
fsrs_difficulty    DOUBLE PRECISION
fsrs_last_reviewed_at TIMESTAMPTZ
fsrs_scheduled_days   INTEGER
fsrs_card_state    TEXT          -- new|learning|review|relearning
fsrs_step_index    INTEGER
-- LWW 元数据(照抄)
client_updated_at  TIMESTAMPTZ
last_modified_by_replica_id UUID
last_operation_id  UUID
deleted_at         TIMESTAMPTZ   -- 墓碑
created_at         TIMESTAMPTZ
```

## 4. 内容通道模型(单向分发)

```sql
-- content.word_senses:词义身份(源自 SceneLex data/senses)
word_sense_id  UUID PK
lemma          TEXT
sense_key      TEXT             -- 如 reluctant-01
pos            TEXT
semantic_type  TEXT             -- 10 类经验分类之一
locale_l1      TEXT             -- L1(如 zh-Hans)

-- content.experience_programs:版本化 Program(源自 compiler 产出)
program_id         UUID PK
word_sense_id      UUID
program_version    INT
compiler_version   TEXT
prompt_version     TEXT
model_provider     TEXT
quality_status     TEXT           -- draft|reviewed|published
created_at         TIMESTAMPTZ
-- 正文:ExperienceUnit 数组(JSONB 或关联表)

-- content.experience_units
experience_unit_id  UUID PK
program_id          UUID
stage               TEXT        -- anchor|variation|perturbation|discrimination|symbol_binding|l2_grounding|transfer
unit_type           TEXT        -- narrative|judgment|recall
content             JSONB       -- 叙事/判断题/回忆题结构
```

- 客户端经**内容通道**获取 program(类似 media:元数据下载 + 按版本缓存),本地不产生内容。
- 新词义学习 = 客户端把 learning_state(new) 加入今日队列;首次学习时拉取对应 program。

## 5. 同步通道映射

| flashcards 实体 | SceneLex 实体 | 通道 |
|---|---|---|
| card | learning_state | 进度通道(双向,同步协议照抄) |
| deck | list(词单) | 进度通道 |
| workspace_scheduler_settings | 不变 | 进度通道 |
| review_event | 扩展版(§2) | 进度通道 append-only |
| media_asset | program / 词义元数据 | 内容通道(下载式,v1 不进 hot_changes 或按 include 标志) |

bootstrap rank 顺序(v1):`0 = workspace_scheduler_settings, 1 = learning_state, 2 = list, 3 = 词义/程序元数据`。

## 6. 与 SceneLex 现有 schema 的关系

- `schema/word-sense.schema.json`、`scene-spec.schema.json`、`resource-bundle.schema.json` 是**语义层权威**,继续有效。
- v1 导入脚本负责:已审核 Program(resource bundle)→ 写入 `content.word_senses` / `experience_programs` / `experience_units`。
- `data/`(senses/scenes/inventories)与 server 数据之间保持**可追溯映射**(sense_id 稳定,program_version 递增)。
