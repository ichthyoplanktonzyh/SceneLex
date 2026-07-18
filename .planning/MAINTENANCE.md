# SceneLex — 文档体系维护规则

> 最后更新：2026-07-18
> 参考 LLPlayerNext 的 GSD 文件结构体系，按 SceneLex 当前规模精简制定

---

## 一、文件职责速查

| 文件 | 更新频率 | 职责 | 语气 |
|---|---|---|---|
| `STATE.md` | 每个 phase 完成时 | 记录现在在哪、下一步干什么。项目活记忆。 | 情境描述 |
| `PROJECT.md` | 产品方向变化时 | 战略描述：愿景、定位、原则、非目标 | 宏观 |
| `ROADMAP.md` | 路线调整时 | 阶段管理：里程碑划分、优先级、依赖关系 | 规划 |
| `MAINTENANCE.md` | 体系调整时 | 文档体系自身的维护规则 | 元规则 |

> SceneLex 当前规模暂不需要 `REQUIREMENTS.md` 和 `MILESTONES.md`。需求在 ROADMAP 中按 phase 描述；里程碑在 ROADMAP 中随 phase 收口。

## 二、目录职责

### `.planning/` — 项目管理中枢

| 目录 | 存放内容 | 生命周期 |
|---|---|---|
| `phases/XX-phase-name/` | phase 的计划、上下文、收口。**一个 phase 一个文件夹。** | 完成 → 冻结 |
| `codebase/` | 系统架构骨架：ARCHITECTURE / DATA-MODEL / CONVENTIONS。**帮助新会话快速建立全局理解。** | 随架构演进更新 |
| `discuss/` | 自由讨论。灵感、技术调研、方案对比。**不要求结构规范。** | 落地 → 迁入对应 phase；纯参考 → 保留 |
| `handoff/` | 会话交接记录。精简为一个 `continue-here.md`，核心信息在 STATE.md 中。 | 按需更新 |

### `docs/` — 长期参考（面向外部/最终用户）

| 目录 | 存放内容 | 规则 |
|---|---|---|
| `docs/production-workflow.md` | Director中间层权威说明。 | Director职责或提示词契约变化时更新 |
| `docs/render-stack-research.md` | 模型与 ComfyUI 技术选型记录。 | 能力事实变化时更新；不定义生产架构 |
| `docs/mvp-evaluation.md` | 已归档的效果评估方案。 | 仅在重新启动效果研究时更新 |

## 三、Phase 生命周期

### 3.1 创建 phase

```bash
# 约定：phase 目录名 = 编号 + 短横线 + 功能描述
.planning/phases/1.1-complete-existing-scenes/
```

### 3.2 phase 标准文件

```
XX-phase-name/
├── PLAN.md          ← 执行计划（必须）
├── CONTEXT.md       ← 上下文：从哪些讨论来、关键决策（按需）
├── CLOSEOUT.md      ← 完成收口（完成时必须）
└── design-notes/    ← 上游设计参考（按需）
```

### 3.3 phase 完成流程

1. 所有任务完成。
2. 撰写 `CLOSEOUT.md`。
3. 更新 `STATE.md`（当前状态、下一步）。
4. 更新 `ROADMAP.md`（勾选对应 phase）。
5. **phase 文件夹冻结**，不再修改。

## 四、文档迁移规则

### 何时迁移

| 场景 | 操作 |
|---|---|
| `discuss/` 中的讨论落地为正式 phase | 链接或提炼到 phase 的 CONTEXT.md，原文保留在 discuss/ |
| 功能设计文档需要归入 phase | 移入 phase 的 `design-notes/` |
| 新的 phase 开始 | 从 discuss/ 和旧 phase 中收集相关上下文 |

### 何时不动

| 场景 | 规则 |
|---|---|
| 已完成的 phase 文件 | 冻结不动 |
| 根目录 `AGENT.md` | 是仓库工作约束，保持独立维护 |
| 根目录 `README.md` | 是项目对外门面，保持独立维护 |

## 五、禁止事项（反模式）

| 反模式 | 正确做法 |
|---|---|
| 把实现细节写入 PROJECT.md | 战略级描述，不涉及具体实现 |
| 同一 phase 的文档散落在多个目录 | 一个 phase 的所有产物放在一个 phase 文件夹下 |
| 修改已冻结的 phase 文件 | 冻结即历史事实。新发现写入新 phase 的 CONTEXT.md |
| STATE.md 写得像 CHANGELOG | STATE 是当前状态机，不是历史列表 |
| STATE.md 长期堆积已完成 phase 全文 | STATE 目标 ≤ 200 行；已完成 phase 只保留索引行 |
| codebase/ 写成 README 的翻版 | codebase/ 是架构骨架（数据模型+流程+约定），不是使用说明 |
| handoff 文件堆积过多 | 精简为一个 `continue-here.md`，核心交接信息已在 STATE.md |

## 六、日常维护 checklist

### 每次 phase 完成
- [ ] 撰写 `CLOSEOUT.md`
- [ ] 更新 `STATE.md`：当前位置、下一步、最近决策
- [ ] 将该 phase 的 STATE section 压缩为一两行已完成索引
- [ ] 更新 `ROADMAP.md` 勾选对应 phase

### 产品方向变化
- [ ] 更新 `PROJECT.md`（战略层面）
- [ ] 更新 `ROADMAP.md`（阶段重排）
- [ ] 更新 `AGENT.md`（如果涉及工作约束变化）
- [ ] 在 `STATE.md` 中记录变化摘要和时间戳

### 架构变化
- [ ] 更新 `codebase/ARCHITECTURE.md`
- [ ] 更新 `codebase/DATA-MODEL.md`（Schema 版本、数据不变量变化）
- [ ] 更新 `codebase/CONVENTIONS.md`（命名、格式约束变化）

### 新会话启动
1. 先读 `AGENT.md` — 了解仓库工作约束
2. 再读 `.planning/STATE.md` — 了解当前在哪
3. 然后 `.planning/codebase/ARCHITECTURE.md` + `DATA-MODEL.md`
4. 最后按需深入具体 phase 文件夹
