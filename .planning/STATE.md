---
gsd_state_version: 1.0
milestone: m1
milestone_name: reluctant 首个媒体纵向切片
status: active
last_updated: "2026-07-24T23:30:00.000+08:00"
---

# SceneLex — 项目活记忆

> 当前事实以本文件、`CONTEXT.md`、`ROADMAP.md` 和各版本 manifest 为准。
> 历史评估文档说明当时发生过什么，但不能替代 manifest 的 provenance。

## 当前判断

SceneLex 已完成核心语义基础设施，正在完成第一个
`reluctant-01-proto-01` 媒体纵向切片。工程已经进入图片执行链路后段，
但尚无通过图片语义门的完整关键帧集合，也尚无通过视频语义门的成片。

项目阶段是 **pre-MVP 的纵向切片验证**，不是规模化生产阶段。

## 当前权威生产链

```text
Approved Sense Inventory
→ WordSense
→ SceneSpec
→ Shot Plan
→ Keyframe Plan
→ Animatic Review
→ Source Packet
→ Visual Compiler
→ Render Directive
→ Image Edit Generation
→ Human Image Semantic Gate
→ Motion Directive
→ Cloud I2V Motion Segments
→ Human Video Semantic Gate
→ Edit / Audio / Final Video
```

旧 `Director Prompt` 与 `render.py` 是 legacy 原型，不参与新主线。

## 已成立的事实

### 语义资源层

- M0 已完成：Schema、Inventory、起草、校验、可选模型审核、原子 promote、导出与工作台可用。
- 正式库有 4 个 WordSense、21 个 SceneSpec。
- `reluctant` 是第一个 approved Inventory。
- `reluctant-01` 是 Inventory 驱动的 WordSense 1.1。
- `reluctant-01-proto-01` 是当前纵向切片的 SceneSpec 1.1；其余 20 个场景仍是 legacy 1.0。

### Shot / Keyframe 层

- Shot Plan v04 经 Animatic 暴露动作预算不足，保留为失败证据。
- Shot Plan v05 是当前执行版本：3 个 Shot，总时长 10.8s。
- Keyframe Plan v02 绑定 Shot Plan v05：9 帧（2 / 4 / 3）。
- Animatic v02 通过时序与状态覆盖审核，可进入图片生成。

### 图片层

- Image Keyframes v01 真实生成 9 张图，但人工结论为
  `IMAGE KEYFRAME REVISION REQUIRED`。
- 失败集中在身体抗拒、动作阶段和道具状态；构图大体可执行。
- 这 9 张图不是可进入 I2V 的输入。

### Visual Compiler / Wan 2.7 实验

- 4 个诊断关键帧都有 Qwen3.6-Flash 生成且通过 Validator 的 Render Directive。
- v02 目录存在 `shot-02-kf-03` 的两张 Wan 2.7 图片，说明该 API 与编辑路线曾产出可视结果。
- 这两张图片没有对应的 manifest attempt、request/seed 绑定和 Human Gate；
  因此按 `CONTEXT.md` 属于 **unbound artifacts**，不能计为已完成生成或已通过语义门。
- v02 当前规范状态：
  - `api_gate: pending`：4 个 target 尚未全部绑定成功产物；
  - `semantic_gate: not_run`：没有 manifest 绑定候选可供整批人工判决。

### 视频层

- 本地 Wan 2.2 / ComfyUI / MPS 路径经多轮诊断后判定不可用，不再投入。
- 目标路径是通过图片语义门的关键帧 → 云端 I2V。
- 尚无通过语义验收的视频候选，也没有最终剪辑/音频产物。

## Gate 的唯一含义

- `api_gate` 是历史字段名，语义是 Generation Gate，不表示“网络是否通”。
- `pass`：每个 target 都选择了一个 manifest 绑定的 `generated` attempt。
- `blocked`：存在记录化 failed attempt，且整批尚未完成。
- `pending`：整批未完成，但没有记录化失败。
- `semantic_gate: not_run`：没有绑定候选。
- `semantic_gate: pending`：已有绑定候选，等待整批人工审核。
- `semantic_gate: pass`：只允许在 Generation Gate pass 后由人工给出。
- VLM 只能写 advisory review，不能改变 Human Semantic Gate。

## 当前唯一 P0

完成 `reluctant-01-proto-01` 的图片语义门：

1. 从现有 4 份已验证 Render Directive 重新执行 Wan 2.7。
2. 每次调用结束后立即写入 manifest attempt；失败也必须记录。
3. 4 个诊断 target 都选择绑定产物后，执行 VLM advisory review。
4. 用 `review-human` 记录 semantic readability、state fidelity、
   character consistency、prop continuity 和 composition。
5. 只有整批 `api_gate: pass` 且 `semantic_gate: pass` 才能进入云端 I2V。

## P0 之后

1. 为 3 个 Shot 编译 Motion Directive；按语义需要拆成一个或多个 Motion Segment。
2. 审核动作阶段、停顿、速度、跨镜连续性，以及 reluctant / refuse / hesitant /
   dislike / slow 的边界。
3. 以最小硬切方式拼接，随后补音频与目标声音时序。
4. 完成首个可播放、可追溯、语义正确的 vertical slice。
5. 再用 `messy` 与 `almost` 验证跨语义类型泛化。

## 暂不做

- 批量媒体生成、调度与消费者集成；
- 大规模迁移 legacy SceneSpec；
- 独立多 Agent Reviewer 或复杂自动修正状态机；
- 通用 Character Bible、Asset Registry、依赖 DAG；
- 为消除 backlog 而虚构悬空义项。
