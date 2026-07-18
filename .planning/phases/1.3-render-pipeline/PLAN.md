# Phase 1.3 — 渲染管线（场景 → 皮克斯短视频）

> 创建：2026-07-18
> 状态：进行中
> 取代：原 ROADMAP 的 1.3 实验材料 / 1.4 对照实验 / 1.5 修订资源
> （已按决策 2026-07-17「核心命题不做实验验证」退役，见 CONTEXT.md）

## 目标

打通并磨熟一条**模型无关的成熟工作流**，把已有的场景规格渲染成
**~20-25 秒的皮克斯 3D 风短视频**，用于教准词义。本地先跑通，之后换云端 API
或本地模型只是替换适配器。

## 五级流水线与状态

```
场景规格 + 语义骨架 + skills
  → [0] 导演 Agent    ── 渲染计划 IR: 角色卡 + 每beat{关键帧提示词, 运动提示词, negative, 音频, 时长}
  → [1] 角色设定稿    ── 每角色一张皮克斯风参考图(一致性锚点)
  → [2] 逐beat关键帧  ── 每beat一张一致皮克斯静图(角色一致 + 表情对)
  → [3] 逐beat i2v    ── 每beat一段~5s会动的皮克斯视频
  → [4] 拼接+音频     ── 一条~20-25s成片
```

| 级 | 状态 | 说明 |
|---|---|---|
| [0] 导演 Agent | 🟡 设计好未接线 | render-plan.md 雏形 + emotion-to-visual skill v1；未接 skill、未产运动提示词/设定稿 spec |
| [1] 角色设定稿 | 🟡 能力验证 | Disney SDXL 直出皮克斯角色 OK；仅单张，未做三视图 |
| [2] 逐beat关键帧 | 🟡 机制通未调好 | Disney+IPAdapter PLUS 一致性✅ 风格✅；**姿势/表情与身份解耦未解决** |
| [3] 逐beat i2v | 🟢 栈验证 | Wan2.2 TI2V-5B 在 M1 出片；皮克斯关键帧→i2v 端到端验证中 |
| [4] 拼接+音频 | 🔴 未搭 | ffmpeg + F5-TTS，未开始 |

## 待办（按依赖）

- [ ] **[2] 关键帧解耦**：降 IPAdapter 权重 / 脸部特写参考 / 加 ControlNet(openpose)，
      让姿势/表情跟提示词走而不被参考图带跑。（当前头号阻塞）
- [ ] **[0] 导演 IR 契约**：定死渲染计划结构——为"皮克斯 + 运动提示词 + 表情线索"
      扩 render-plan schema 三个字段；接入 storyboard-creation + emotion-to-visual skill。
- [ ] **[3] i2v 参数化**：Wan i2v 运动提示词规范（主体→运动→镜头→场景，只动可见元素）。
- [ ] **[4] 组装**：ffmpeg 拼接 + F5-TTS 旁白 + 时长对齐。
- [ ] 端到端跑一条完整 reluctant 短片作为里程碑样片。

## 验收（本 phase 收口条件）

- 用 reluctant-01-proto-01 一个场景，端到端产出一条皮克斯风短视频：
  角色跨 beat 一致、表情语义正确（reluctant 不被画成 annoyed/energetic）、
  运动连贯、音频对齐。
- 工作流每一级都是可替换适配器（本地/云端可切换）。
- 导演 IR 契约成文，可复用于其它场景。

## 本地技术栈（M1 Max 32GB / ComfyUI）

- 图像：`disneyrealcartoonmix_v10`（皮克斯风 SDXL，Civitai）。Animagine 为早期打通管线临时件。
- 一致性：`ComfyUI_IPAdapter_plus`（PLUS 预设，CLIP-ViT-H；**不用 FaceID/PuLID**——对卡通脸失效）。
- 视频：`wan2.2_ti2v_5B_fp16` + `umt5_xxl_fp8` + `wan2.2_vae`（ComfyUI 原生节点）。
- 拼接：ffmpeg；TTS：F5-TTS（待接）。
- 详见 design-notes/ 与 `docs/render-stack-research.md`。
