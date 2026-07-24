# SceneLex — 架构骨架

> 最后更新：2026-07-24

## 系统身份

SceneLex 是词义语义资源、教学场景证据和可追溯媒体的生产系统，不是学习应用。

```text
语义权威
  Inventory → WordSense → SceneSpec
                         ↓
执行计划
  Shot Plan → Keyframe Plan → Animatic
                         ↓
图片执行
  Source Packet → Render Directive → Image Candidate → Human Gate
                         ↓
视频执行
  Motion Directive → I2V Motion Segment → Human Video Gate → Edit / Audio / Final
                         ↓
消费者
  dictionary / course / player / API
```

## 权威边界

- WordSense 定义词义身份、条件与边界。
- SceneSpec 定义证明该词义的模型无关教学事件。
- Shot Plan 决定镜头、时序、构图与连续性，不改变故事。
- Keyframe Plan 选择必要视觉状态，不重新导演。
- Source Packet 是从冻结上游确定性提取的编译输入。
- Render Directive 是模型适配的物理编辑 IR，不是语义权威。
- Motion Segment 是一次视频模型生成单位，不等于 Shot；一个 Shot 可由多个 Segment 连续组装。
- 图像和视频候选只有绑定 manifest attempt 后才是可追溯产物。
- VLM 只提供建议；人工 Gate 决定能否进入下游。

## 当前主线

```text
reluctant-01-proto-01 SceneSpec 1.1
→ Shot Plan v05
→ Keyframe Plan v02
→ Image Keyframes v01 (revision required)
→ 4 diagnostic Source Packets
→ 4 validated Render Directives
→ Wan 2.7 bound candidates (pending)
→ Human Image Semantic Gate
→ Motion Directive / Video Run (待建)
→ Cloud I2V Motion Segments
→ Human Video Semantic Gate
→ Final video
```

## 模型适配

- Qwen3.6-Flash 当前承担 Visual Compiler 与 VLM advisory review。
- Wan 2.7 Image Pro 当前承担关键状态图片编辑。
- 本地 Wan 2.2 / MPS 视频路径已判定不可用。
- 视频目标是云端 I2V；具体供应商尚未成为语义或执行契约的一部分。
- 模型、endpoint、seed、BBox、request ID 只进入适配层和 manifest。

## Gate

- Generation Gate（历史字段 `api_gate`）只描述整批绑定生成覆盖。
- Image Semantic Gate 描述静态语义、状态、角色、道具与构图。
- Video Semantic Gate 描述动作阶段、停顿、速度、结果与跨镜连续性。
- 任一层未通过，不得把产物交给下一昂贵层。

## Legacy

- `director-prompt.schema.json`、`prompts/director.md`、`data/drafts/director/` 是旧提示词原型。
- `render-plan.schema.json` 与 `tools/render.py` 是旧 beat-image 原型。
- 历史产物保留用于追溯，但不参与当前生产主线。

## 不变量

- 语义层不绑定人物表面、视觉风格、模型或供应商。
- Beat、Shot、Keyframe 与 Motion Segment 是不同单位，不要求一一对应。
- 上游问题在上游修，下游不得静默重写。
- 历史版本不覆盖；下游显式绑定版本。
- 裸文件不等于绑定产物，生成成功不等于语义通过。
- 通过图片门后如发生重绘、转画幅或 outpaint，必须重新审核。
