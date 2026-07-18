# SceneLex 渲染流水线技术调研

> **状态：技术选型调研稿（2026-07-18）。** 本文记录模型与 ComfyUI 能力，不再定义生产架构。
> 权威生产流程见 `docs/production-workflow.md`。文中“逐 beat”“20–25 秒”和具体模型组合是
> 当时的验证假设，不是当前生产不变量。凡标注“未证实”处均为查不到一手依据，勿当结论用。

## 一句话结论

**本地 M1 Max 32GB 上，用 ComfyUI 完全能跑通"文生图设定稿 → 图生一致关键帧 → 图生视频"这条链；
其中"跨镜头角色一致性"应走 CLIP-vision 系的 IPAdapter（style/subject）而不是 FaceID/InstantID/PuLID
——后者依赖 InsightFace，只认写实人脸，对皮克斯卡通脸基本失效；本地 i2v 首选 Wan2.2 TI2V-5B，
质量顶格时再上云端 Kling / Runway Gen-4 / Veo / Seedance（它们原生支持角色参考图，且能做口型对话）。**

## 流水线总表（每一级 × 推荐方案 × 现在可用性）

| 流水线级 | 本地 M1 Max 方案（现可用） | 云端方案（现可用） | 现在可用性 |
|---|---|---|---|
| 导演 / 分镜（Skill+Agent） | Claude `storyboard-creation` skill + FACS/动画原理清单（纯提示词，无算力） | 同左 | ✅ 立即 |
| 角色三视图设定稿（文生图） | SDXL 皮克斯风 checkpoint 或 FLUX.1-dev(GGUF Q5-Q8) + turnaround 提示 | SeeDream / Midjourney / Nano-banana(Gemini) | ✅ 本地立即；云端立即 |
| 逐 beat 一致关键帧（图生图 + 一致性） | **IPAdapter PLUS / Full-Face（CLIP-vision，非 InsightFace）** + ControlNet(openpose/depth) | Kling/Runway/Seedance 的多图参考 | ✅ 本地需装自定义节点 |
| 图生视频 i2v | **Wan2.2 TI2V-5B**（720P，官方称 8GB 显存可跑，M1 靠 MPS 慢但可行）；LTX-Video 备选 | Kling 2.1 / Runway Gen-4 / Veo 3.x / Seedance 2.0 / Hailuo 02 | ✅ 本地慢；云端立即 |
| 拼接 + 音频 + TTS + 口型 | ffmpeg 拼接 + F5-TTS + LatentSync/Sonic 口型节点 | Kling/Seedance 自带 lip-sync + 对白 | ✅ 本地需装节点；云端立即 |

---

## 第 1 块 Skill / 提示词框架（导演 Agent 的命门）

### 1.1 影视分镜 / 镜头语言：已有现成一手框架

- **Claude 生态里已有 `storyboard-creation` skill**（本机已装，属可直接调用的一手资源）。其覆盖：
  景别（shot types）、机位角度（camera angles）、运镜（movement）、**180° 轴线规则**、连续性规则
  （continuity）、分镜格排布（panel layout）与标注格式（annotation format）。
  这正是"纯模型做不好、需要成体系清单"的那部分，可直接挂到导演 Agent 的系统提示里。
  来源：本机 skill 描述 `storyboard-creation`（Anthropic/Claude 官方 skill 生态）。
- **结论**：分镜/镜头语言这块**不用自己造框架**，直接复用该 skill 的 shot vocabulary + 连续性规则清单。

### 1.2 角色设定稿 / turnaround 的行业约定

- turnaround（转身图 / 三视图 / 多视图）是动画行业标准角色设定物料，用于锁定角色跨镜头一致。
  在扩散模型语境下，社区做法是"一次生成多视图角色表 + 稳定描述符（stable descriptors）"，
  再逐镜头以该图为参考锚定。ComfyUI 社区有 SDXL/PuLID-Flux/ControlNet 生成多视图角色表的公开工作流。
  来源：ComfyUI 一致角色工作流综述（RunComfy，社区二手，仅作存在性佐证）
  <https://www.runcomfy.com/comfyui-workflows/create-consistent-characters-within-comfyui>
- **一手佐证缺口**：turnaround 的"标准三视图规范"没有单一权威一手文档；它是动画行业长期美术惯例，
  非某份可引用的规范。写角色设定稿提示词时应把"稳定描述符"显式化（发色/发型/脸型/服装/配色/比例的
  固定措辞），这是社区经验，**不是可引用的一手规范，标注：约定而非标准**。

### 1.3 情绪 → 可画视觉线索的映射（本项目的核心价值）

- **FACS（Facial Action Coding System，面部动作编码系统）** 是把情绪拆成可观察面部肌肉动作（Action Units）
  的权威体系，Ekman & Friesen 1978 首版、2002 大改。用 44 个 AU 描述面部动作的位置与强度
  （强度 A=trace 到 E=maximum 五级）；EMFACS 把 AU 组合映射到具体情绪类别。
  这正好能把"精确词义 → 面部具体可画线索 + must-not 边界"落成清单（例如 reluctant：眉内聚+嘴角下拉+
  身体后倾/回避，而非 anger 的皱眉瞪眼）。
  来源（系统综述，含 AU 结构与强度分级）：Frontiers in Psychology 系统综述
  <https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2020.00920/full>
  （FACS 官方手册本身为 Ekman 团队出版物 paulekman.com，需购买；系统本身即行业权威。）
- **肢体语言 / 动画表演**：迪士尼"动画十二原则"（Thomas & Johnston《The Illusion of Life》）是把
  表演/时序落成可画动作的权威美术体系，适合作为"body language → 关键帧姿态"的映射底座。
  **一手佐证缺口**：该书为出版物，无免费一手 URL，标注：权威出版物、非在线一手。
- **结论**：情绪→视觉线索**有权威体系可借**（FACS + 动画十二原则），应把它编成"每个词义的
  面部 AU 清单 + 肢体姿态 + must-not 边界"结构化字段，喂给设定稿/关键帧提示。这是 SceneLex 最该
  自建、且最有壁垒的一层 Skill。

### 1.4 皮克斯风图像 & i2v 运动提示的官方最佳实践

- **Wan2.2 官方 i2v 提示结构**（一手，来自官方 ComfyUI 教程与 Wan 官方指南）：
  提示分层"主体 → 运动 → 镜头 → 场景"，模型对提示**开头权重更高**；i2v 只描述"怎么动"而非"有什么"、
  用具体动词、只动画面里已可见的元素、配负向提示去伪影；建议长度约 80-120 词。
  来源（官方工作流页）：<https://docs.comfy.org/tutorials/video/wan/wan2_2>
  ；官方提示指南入口 <https://wan2.video/wan2.2-guide>（Alibaba Wan 第一方）。
- **皮克斯风图像提示**：无单一官方"皮克斯 prompt guide"（皮克斯不出模型）；一手依据来自
  各 Civitai 模型卡自带的 trigger word / 用法（见第 3 块）。**标注：无第一方通用规范，按模型卡走。**

---

## 第 2 块 工作流（ComfyUI 及更广）

### 2.1 角色一致性技术横评（重点：对"皮克斯 3D 卡通角色"是否有效）

**关键分水岭：是否依赖 InsightFace（写实人脸检测）。**

| 技术 | 原理 | 对卡通脸是否有效 | ComfyUI 接法 / 需装 |
|---|---|---|---|
| **IPAdapter 基础/PLUS/Full-Face** | CLIP-vision 编码，迁移**主体或风格**，不做人脸识别 | ✅ **有效**（不依赖 InsightFace，卡通角色可用） | `ComfyUI_IPAdapter_plus` + CLIP-ViT-H/bigG + ipadapter 权重 |
| IPAdapter **FaceID / FaceID-Plus** | 叠加 InsightFace 人脸识别 embedding | ⚠️ 面向写实肖像，卡通脸检测不稳 | 需装 `insightface` 库 |
| **InstantID** | InsightFace + 参考人脸 | ⚠️ 比 PuLID 灵活，**能检测部分动漫脸**，但仍偏写实 | 需 InsightFace + ControlNet |
| **PuLID / PuLID-Flux** | InsightFace + EvaCLIP 恢复面部 ID | ❌ **不支持动漫/卡通/动物脸**（官方 issue 明确"No faces detected"） | 需 InsightFace |
| Reference-only / 角色 LoRA / ControlNet | 风格锚定 / 训练专属角色 / 骨架深度约束 | ✅ 有效（LoRA 需为角色单独训练；ControlNet 管姿态不管身份） | ControlNet 需 openpose/depth 权重 |

来源（一手）：
- IPAdapter 变体与依赖（PLUS/Full-Face 不需 InsightFace；FaceID 需 InsightFace）：
  `cubiq/ComfyUI_IPAdapter_plus` README <https://github.com/cubiq/ComfyUI_IPAdapter_plus>
- PuLID 不支持动漫/动物脸（官方仓库 issue）：
  <https://github.com/ToTheBeginning/PuLID/issues/123>

**结论（推翻常见拍脑袋）**：网上"角色一致性"教程默认 FaceID/InstantID/PuLID，但那是为**写实人脸**设计的。
SceneLex 是皮克斯卡通角色，**应走 IPAdapter PLUS / Full-Face（subject/style 迁移）+ ControlNet 管姿态
+（可选）为主角训练专属 LoRA**。社区当前对"插画/卡通跨场景一致"的实践确实以 IPAdapter 为主
（存在性佐证，社区二手：<https://extra-ordinary.tv/2025/08/02/comfyui-ipadapter-first-attempt-for-consistent-images/>）。

### 2.2 "角色设定稿 → 逐镜头一致关键帧"的公开工作流

- 存在公开 ComfyUI 一致角色工作流（IPAdapter/InstantID/ControlNet/FaceDetailer 组合、SDXL 多视图角色表），
  但多为写实向、且以人脸为核心。**没有找到一份直接面向"皮克斯 3D 卡通 + 逐 beat 锚定"的一手权威工作流。**
  来源（社区，仅证实"这类工作流存在、组件成熟"）：
  <https://www.runcomfy.com/comfyui-workflows/create-consistent-characters-within-comfyui>
- **结论**：**没有现成能直接抄的皮克斯向工作流，需要自己搭**：设定稿出图 → 以设定稿为 IPAdapter 参考 +
  ControlNet(pose) 逐 beat 生成关键帧。这与项目现有方案一致（先设定稿再逐镜头锚定），**方案被验证**。

### 2.3 图生视频（i2v）官方 ComfyUI 工作流与参数

- **Wan2.2 官方在 ComfyUI 内置原生工作流**，提供 TI2V-5B、I2V-A14B、T2V-A14B 及首尾帧 FLF2V 变体。
  官方说明：**5B 版本配合 ComfyUI 原生 offload"8GB 显存即可良好运行"**；14B 用 fp8 缩放；
  FLF2V 默认小分辨率防低显存爆内存，显存够可上 720P。
  来源（一手）：<https://docs.comfy.org/tutorials/video/wan/wan2_2>
  ；官方示例 <https://comfyanonymous.github.io/ComfyUI_examples/wan22/>
- 官方仓库补充参数：TI2V-5B 用 16×16×4 高压缩 VAE，支持 720P@24fps，单张消费级 GPU 约 9 分钟出 5 秒。
  来源（一手）：<https://github.com/Wan-Video/Wan2.2> ；模型卡 <https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B>
- **M1 可行性**：ComfyUI 官方支持 Apple Silicon / MPS（标准 PyTorch wheel 即带 MPS，有 macOS 桌面版）。
  统一内存被 ComfyUI 视为 SHARED，32GB M1 Max 可加载 5B 模型；但 MPS 比同级 NVIDIA 慢约 3-5×，
  按分钟计每片。来源（ComfyUI 官方支持 Mac）：<https://github.com/comfyanonymous/ComfyUI/discussions/63>
  （M1 具体出片时长为社区经验，标注：未有官方基准，按分钟级预期）。

### 2.4 拼接 / 音频 / 对口型 / TTS

- **拼接**：ffmpeg（成熟，无需赘述）。
- **本地 TTS**：F5-TTS（可声音克隆），可与口型节点串联生成"会说话的角色"。
- **本地口型（lip-sync）ComfyUI 节点**：
  - **LatentSync**（ByteDance 开源，音频条件潜扩散，端到端口型）：
    <https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper>
  - **Sonic**（全局音频感知的肖像动画，静图+音频→等长说话视频）。
  来源（一手仓库）：LatentSync 见上；Sonic 为 ComfyUI 自定义节点（社区托管）。
- **云端一体化**：Kling、Seedance 2.0 自带对白 + lip-sync（见第 3 块），省去本地口型链。
- **结论**：本项目多为**旁白教学**（中文讲解词义）而非角色对口型，口型不是硬需求；若某些 beat 要角色开口，
  本地用 LatentSync/Sonic、云端用 Kling/Seedance 均可。**标注：口型对卡通脸的贴合度未做一手验证。**

---

## 第 3 块 模型

### 3.1 皮克斯 / 3D 卡通风图像模型

| 模型 | 类型 | 本地 M1 可行性 | 一手来源（模型卡） |
|---|---|---|---|
| FLUX Pixar Cartoon 3D Style (LH) | FLUX.1 checkpoint | ✅ 需 FLUX 底座（见下） | <https://civitai.com/models/1024253/flux-pixar-cartoon-3d-style-by-lh> |
| Jixar 3D Pixar Style | FLUX LoRA（强表情/角色设计） | ✅ 叠在 FLUX 上 | <https://civitai.com/models/650251> |
| DisneyRealCartoonMix | SDXL checkpoint（trigger "modisn disney"） | ✅ SDXL M1 轻松 | <https://civitai.com/models/212426/disneyrealcartoonmix> |
| Pixar Style (SDXL) LoRA | SDXL LoRA | ✅ | <https://civitai.com/models/188525/pixar-style-sdxl> |

- **FLUX.1-dev 本地可行性**：12B DiT + T5-XXL(4.7B) + CLIP-L。FP16≈24GB、FP8≈12GB、GGUF Q4≈6-8GB；
  Apple Silicon 走 MPS，**16GB 为实际下限，32GB 舒适**，1024² 约 1-3 分钟/张。已有人在 **M1 Max 32GB** 实跑。
  来源：FLUX.1-dev 参数（一手 HF 讨论）<https://huggingface.co/black-forest-labs/FLUX.1-dev/discussions/1>
  ；M1 可行性（社区，标注非官方基准）<https://www.apatero.com/blog/flux-apple-silicon-m1-m2-m3-m4-complete-performance-guide-2025>
- **云端**：SeeDream / Midjourney / Nano-banana(Gemini 图像) 皮克斯风质量高、一致性好，但为闭源 API。
  **一手能力细节未逐一核验，标注：未证实其具体一致性上限。**
- **结论**：本地首选 **SDXL 皮克斯 checkpoint（轻、快、M1 友好）** 打底出设定稿；追求更高质感/表情时用
  **FLUX + Jixar/Pixar LoRA（GGUF 量化）**。表情丰富度上 FLUX+专用 LoRA 更强，代价是速度。

### 3.2 图生视频模型对比

| 模型 | 部署 | 支持角色参考图 | 时长 / 分辨率 | 运动 | M1 可行性 | 一手来源 |
|---|---|---|---|---|---|---|
| **Wan2.2 TI2V-5B** | 本地 | 起始帧(i2v)；专用一致性靠关键帧 | ~5s / 720P@24fps | 复杂运动，官方主打美学控制 | ✅ 8GB 即可（官方），M1/MPS 慢 | Wan2.2 GitHub / ComfyUI docs |
| Wan2.2 I2V-A14B / T2V-A14B | 本地 | i2v 起始帧 | 480P/720P | 更强 | ❌ 官方要 ≥80GB 显存，M1 不现实 | 同上 |
| Wan2.2-Animate-14B | 本地 | ✅ 参考图做角色动画/替换 | — | 角色驱动 | ❌ 14B 重 | Wan2.2 GitHub |
| LTX-Video / LTX-2 | 本地 | i2v + 多关键帧条件 | 快、可延长 | 快但细节弱于 Wan | ✅ 内置 ComfyUI 核心 | <https://github.com/Lightricks/LTX-Video> |
| HunyuanVideo 1.5 | 本地 | i2v | — | 强 | ⚠️ FP8≈14-16GB，M4 Pro 24GB 为实际下限 | <https://huggingface.co/tencent/HunyuanVideo> |
| CogVideoX-5B | 本地 | i2v | — | 中 | ✅ FP8≈16GB | 社区（标注：以官方 diffusers 卡为准） |
| Mochi 1 | 本地 | 主要 t2v | — | 强 t2v | ⚠️ FP8≈20GB | 社区（标注：需核官方卡） |
| **Kling 2.1 / 3.0** | 云端 | ✅ 最多 4 图多参考；3.0 主打多镜头+口型 | 5/10s(2.1)，最高 1080p；3.0 称 15s/4K | 物理/表情强 | 云端 | <https://kling.ai/blog/kling-3-subject-binding-character-consistency> |
| **Runway Gen-4 / 4.5** | 云端 | ✅ References（角色/场景一致） | 5/10s，720p→可 4K | 世界一致性强，图=首帧、文管运动 | 云端 | <https://help.runwayml.com/hc/en-us/articles/37327109429011-Creating-with-Gen-4-Video> |
| **Google Veo 3.x** | 云端 | ✅ 最多 3 张主体参考图 + 1 张风格图 | — | 高 | 云端 | <https://docs.cloud.google.com/vertex-ai/generative-ai/docs/video/use-reference-images-to-guide-video-generation> |
| **Seedance 2.0（即梦/ByteDance）** | 云端 | ✅ 最多 9 参考图+3 视频+3 音频，角色一致+口型+运动迁移 | 最高 ~15s / 720p | 强、可控 | 云端 | fal API 文档 <https://fal.ai/models/bytedance/seedance-2.0/image-to-video> |
| Hailuo 02（MiniMax/海螺） | 云端 | i2v | 6s@768/1080p，10s@768p | 强 | 云端 | <https://fal.ai/models/fal-ai/minimax/hailuo-02/standard/image-to-video> |
| Vidu Q1 | 云端 | ✅ reference-to-video 模式 | — | 中 | 云端 | Vidu（fal/官方，标注：细节未逐项核验） |

来源补充（一手）：
- Wan2.2 全系规格 / Apache 2.0 / 显存：<https://github.com/Wan-Video/Wan2.2>
- Runway Gen-4：图作首帧、文本主导运动、5/10s、720p 可升 4K：见上 help.runwayml.com
- Kling 2.1 多图参考（最多 4 图）、5/10s、1080p：Kling 官方博客（版本更迭快，部分为厂商宣传，标注需按当期文档复核）

**结论**：
- **本地唯一现实的高质 i2v = Wan2.2 TI2V-5B**（5B/720P/8GB，M1 可跑但慢）。14B 系列和 Wan-Animate
  在 32GB M1 上**不现实**（官方要 ≥80GB 显存）。LTX 作为"快出草稿"备选。
- **角色参考图能力是云端的核心优势**：Kling(4图)/Veo(3+1)/Seedance(9图) 原生吃多张角色参考并保持一致，
  这正是本项目"跨镜头同一角色"的痛点。**本地 i2v 无等价的多图角色参考**，一致性只能靠"关键帧阶段
  锚定 + i2v 温和运动"来保。

### 3.3 一致性 / 参考类模型对卡通风适配

- 已在 2.1 表中给出：**IPAdapter PLUS/Full-Face（CLIP-vision）适配卡通；FaceID/InstantID/PuLID（InsightFace）
  不适配卡通脸**。PuLID 官方明确不支持动漫/动物脸。
  来源：<https://github.com/cubiq/ComfyUI_IPAdapter_plus> ；<https://github.com/ToTheBeginning/PuLID/issues/123>

---

## 与当前拍脑袋方案的出入

**被验证（继续做）**
1. "先出角色设定稿再逐镜头锚定同一角色"——公开一致性工作流确实这么搭，且没有一镜到底的稳妥替代。✅
2. "i2v 运动温和、语义主要活在关键帧里"——与 Wan/Runway 官方"图定内容、文管运动"的定位一致；
   本地 i2v 也确实更适合小幅运动。✅
3. "本地先跑通、云端/本地可替换"——Wan2.2 TI2V-5B 让本地跑通成立；云端在一致性上更强，替换路径合理。✅

**被推翻 / 需纠偏**
1. ⚠️ **角色一致性别用 FaceID/InstantID/PuLID**。这些是写实人脸方案，对皮克斯卡通脸失效（PuLID 直接
   "No faces detected"）。**改用 IPAdapter PLUS/Full-Face + ControlNet(pose) + 主角专属 LoRA。**
2. ⚠️ **本地不要指望 Wan2.2 14B / HunyuanVideo FP16**。32GB M1 只能舒服跑 5B 级 i2v 与 SDXL/量化 FLUX；
   14B 系列官方要 ≥80GB 显存。
3. ⚠️ **"皮克斯风有现成工作流可抄"不成立**：现成一致性工作流都是写实向，皮克斯向要自己搭。

**更好的做法（原方案没想到的）**
1. 💡 **把 FACS（面部 AU）+ 动画十二原则编成结构化"情绪→可画线索+must-not"字段**，直接接到设定稿/关键帧
   提示。这是把 SceneLex "语义精确性"落地的最关键、最有壁垒的一层，且有权威体系背书。
2. 💡 **直接复用 Claude `storyboard-creation` skill** 做镜头语言/180°/连续性，不用自造。
3. 💡 **一致性可"云端补位"**：难保一致的角色，用 Kling/Veo/Seedance 的多图角色参考直接出 i2v，
   跳过本地 IPAdapter 调参。
4. 💡 **本地首选 SDXL 皮克斯 checkpoint 而非一上来就 FLUX**：SDXL 在 M1 上更快、生态（IPAdapter/ControlNet
   权重）最全；FLUX 留给"要极致表情质感"的设定稿。

---

## 下一步建议（M1 上最该先落地的组合）

**先落地一个"设定稿 → 关键帧"的本地闭环（不碰视频）：**
1. **导演/分镜 Skill**：接入 `storyboard-creation` skill；另起一份 SceneLex 专属 `emotion-to-visual` 清单
   （FACS AU + 肢体 + must-not，按词义查表）。纯提示词，零算力，**今天就能做**。
2. **图像底座**：ComfyUI(MPS) + 一个 SDXL 皮克斯 checkpoint（如 DisneyRealCartoonMix）出角色三视图设定稿；
   固定"稳定描述符"措辞。
3. **一致性节点**：装 `ComfyUI_IPAdapter_plus`（CLIP-ViT-H/bigG + ipadapter PLUS/Full-Face 权重）
   + ControlNet(openpose/depth)；以设定稿为参考逐 beat 出一致关键帧。**先不碰 FaceID/PuLID。**

**再落地本地 i2v：**
4. Wan2.2 **TI2V-5B**（ComfyUI 官方原生工作流，fp8/量化，接受慢速），把关键帧动成 ~3-5s 片段；
   提示遵循官方"主体→运动→镜头→场景、80-120 词、只动可见元素"。

**质量顶格 / 一致性打不住时，云端补位：**
5. 角色一致性要求高的镜头，改走 **Kling 2.1（≤4 参考图）/ Veo（3+1）/ Seedance 2.0（≤9 图，带口型）**
   的多图参考 i2v。

**拼接与音频：**
6. ffmpeg 拼接；旁白用 F5-TTS；确需角色开口的 beat 用 LatentSync/Sonic（或直接用 Kling/Seedance 的
   一体化 lip-sync）。

**待补验证（本调研未拿到一手结论）**
- 皮克斯卡通脸在 IPAdapter PLUS 下的跨镜头一致度到底够不够（需自测）。
- 本地 Wan2.2 TI2V-5B 在 M1 Max 32GB 的实际出片时长（无官方基准）。
- SeeDream / Midjourney / Nano-banana 的角色一致性上限（闭源，未逐项核验）。
- 口型节点对卡通脸的贴合度。

---

### 来源清单（一手为主）

- Claude `storyboard-creation` skill（本机 Anthropic 官方 skill）
- FACS 系统综述（含 AU 结构/强度分级）：https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2020.00920/full
- ComfyUI Wan2.2 官方工作流：https://docs.comfy.org/tutorials/video/wan/wan2_2
- Wan2.2 官方仓库：https://github.com/Wan-Video/Wan2.2
- Wan2.2-TI2V-5B 模型卡：https://huggingface.co/Wan-AI/Wan2.2-TI2V-5B
- Wan2.2 ComfyUI 官方示例：https://comfyanonymous.github.io/ComfyUI_examples/wan22/
- Wan 官方提示指南：https://wan2.video/wan2.2-guide
- ComfyUI Apple Silicon 官方支持：https://github.com/comfyanonymous/ComfyUI/discussions/63
- IPAdapter 变体与依赖：https://github.com/cubiq/ComfyUI_IPAdapter_plus
- PuLID 不支持卡通/动漫脸（官方 issue）：https://github.com/ToTheBeginning/PuLID/issues/123
- LTX-Video 官方仓库：https://github.com/Lightricks/LTX-Video
- HunyuanVideo 模型卡：https://huggingface.co/tencent/HunyuanVideo
- FLUX.1-dev 参数（官方 HF 讨论）：https://huggingface.co/black-forest-labs/FLUX.1-dev/discussions/1
- Civitai 皮克斯风模型卡：https://civitai.com/models/1024253/flux-pixar-cartoon-3d-style-by-lh ；
  https://civitai.com/models/212426/disneyrealcartoonmix ；https://civitai.com/models/650251
- Runway Gen-4（官方 help）：https://help.runwayml.com/hc/en-us/articles/37327109429011-Creating-with-Gen-4-Video
- Google Veo 参考图（Vertex AI 官方文档）：https://docs.cloud.google.com/vertex-ai/generative-ai/docs/video/use-reference-images-to-guide-video-generation
- Kling 角色一致性（官方博客）：https://kling.ai/blog/kling-3-subject-binding-character-consistency
- Seedance 2.0 API（fal）：https://fal.ai/models/bytedance/seedance-2.0/image-to-video
- Hailuo 02 API（fal）：https://fal.ai/models/fal-ai/minimax/hailuo-02/standard/image-to-video
- LatentSync ComfyUI 节点：https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper
