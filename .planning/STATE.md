---
gsd_state_version: 1.0
milestone: m1
milestone_name: 语义资源与渲染管线纵向切片
status: active
last_updated: "2026-07-18T17:00:00.000+08:00"
---

# SceneLex — 项目活记忆

> 最后更新：2026-07-18 CST
> 更新原因：产品方向变化维护——学习实验退役、渲染管线成为当前主线（见「最近重要决策」）。

## 当前位置

- **当前执行主线**：**Phase 1.3 渲染管线** — 打通"场景规格 → 皮克斯 3D 风短视频（~20-25s）"
  的模型无关成熟工作流。本地(M1 Max/ComfyUI)先跑通，之后换云端 API 或本地模型只替换适配器。
- **并行副线**：语义资源扩产 — 草稿区 6 个新义项在产（`barely/filthy/grimy/hesitant/nearly/refuse`）。
- **重大框架变化**：原 M1「可验证的纵向实验切片」的**学习实验部分已退役**（决策5）；
  纵向切片的终点从"对照实验"改为"渲染成皮克斯短视频"。

## 资源规模

| 资源类型 | 正式库 | 草稿区 |
|---|---|---|
| 义项 (senses) | 4 (`almost/dirty/messy/reluctant-01`) | 6 (`barely/filthy/grimy/hesitant/nearly/refuse-01`) |
| 场景 (scenes) | 21 | 6 义项各有草稿场景 |
| 渲染产物 (renders) | — | `reluctant-01-proto-01`（v03 SD1.5基线 / v04 Animagine） |

## 渲染管线状态（Phase 1.3）

五级：`导演Agent → 角色设定稿 → 逐beat一致关键帧 → 逐beat i2v(Wan) → 拼接+音频`

| 级 | 状态 |
|---|---|
| [0] 导演 Agent | 🟡 设计好未接线（render-plan 雏形 + emotion-to-visual skill v1） |
| [1] 角色设定稿 | 🟡 能力验证（Disney SDXL 直出皮克斯角色） |
| [2] 逐beat关键帧 | 🟡 机制通未调好（一致性✅ 风格✅，**姿势/表情解耦未解**） |
| [3] 逐beat i2v | 🟢 栈验证（Wan2.2-5B M1 可行，皮克斯关键帧→i2v 验证中） |
| [4] 拼接+音频 | 🔴 未搭 |

详见 `.planning/phases/1.3-render-pipeline/PLAN.md`。

## 已完成事项（基础设施与语义层，稳定）

- ✅ Schema 三件套 v1.0（word-sense / scene-spec / resource-bundle）。
- ✅ 语义工具链：draft/validate/export/llm（四协议）、词频表、candidates 队列、batch 断点续跑、审核工作台。
- ✅ 五类场景证据模型（prototype/contrast/counterexample/boundary/transfer）。
- ✅ 渲染层雏形：`tools/render.py`（plan/show/render）、`tools/imagegen.py`（ComfyUI 适配器）、
  render-plan/render-style/render-manifest schema。
- ✅ 渲染技术调研（一手来源）：`docs/render-stack-research.md`。
- ✅ 命门 skill v1：`prompts/director-skills/emotion-to-visual.md`（FACS + 动画原理 + must-not）。

## 下一步工作

1. **[2] 关键帧解耦（头号阻塞）**：降 IPAdapter 权重 / 脸部特写参考 / 加 ControlNet(openpose)，
   让姿势/表情跟提示词走。
2. **[0] 导演 IR 契约**：为"皮克斯 + 运动提示词 + 表情线索"扩 render-plan schema；接入 skill 库。
3. **[3][4]** i2v 运动提示词规范 + ffmpeg/F5-TTS 组装。
4. 端到端产出第一条完整 reluctant 皮克斯短片（Phase 1.3 收口样片）。
5. **副线**：草稿区 6 义项审核 promote（模型审核，决策6）。

## 最近重要决策

1. **2026-07-17** — **核心命题不做实验验证**：「场景即释义」是已确立产品前提，非研究假设；
   `docs/mvp-evaluation.md` 归档；学习实验不再是发布/规模化前置。→ 原 ROADMAP 1.3-1.5 退役。
2. **2026-07-17** — **人工三层审核由模型审核替代**（审核模型宜与起草模型不同）。
3. **2026-07-18** — **渲染层目标=运动视频**（非静图幻灯片）；**统一皮克斯 3D 风**。
4. **2026-07-18** — **已验证渲染方法（模型无关）**：设定稿→一致关键帧→i2v→拼接；
   一致性靠设定稿锚定；语义活在关键帧（钱砸关键帧）；单词视频~20-25s。
5. **2026-07-18** — **导演 Agent = 语义骨架 + 可插拔 skill 库**；命门=关键帧表情语义正确性（差异化落点）。
6. **2026-07**（早期，仍有效）— 资源是核心、产品是消费者；正式资源不含厂商/模型名；生成层模型无关。

## 当前阻塞项

- **[2] 关键帧的身份/姿势解耦**：IPAdapter 高权重会把参考图姿势一起搬来，压掉动作/表情。修法已明确，待做。

## 指标

- STATE.md 维护目标：≤ 200 行。
- Phase 1.3 收口：一条端到端皮克斯短片（角色一致 + 表情语义对 + 运动连贯 + 音频对齐）。
- 语义资源：正式义项 4，草稿 6 扩产中。
