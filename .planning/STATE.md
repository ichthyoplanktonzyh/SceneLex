---
gsd_state_version: 1.0
milestone: m1
milestone_name: 语义资源与 Director 纵向切片
status: active
last_updated: "2026-07-19T08:00:00.000+08:00"
---

# SceneLex — 项目活记忆

> 最后更新：2026-07-19 CST（同日第二次修订）
> 更新原因：复盘"方形关键图 → 画幅转换"工序，判定其破坏图片语义门的 fail-fast 逻辑
> （过门后重新生成，送进 I2V 的图不再是过门的那张图），且构图语义本应在目标画幅上
> 设计；决策 13 废弃，改为"关键图直接按视频目标画幅生成 + 角色设定图作 reference
> 保一致性"（见决策 15/16）。画幅转换 workflow 降级为补救工具留档。
> 同日第一次修订：本地图生视频（Wan 2.2 5B）经五轮独立变量排除法测试全部失败，
> 判定为 ComfyUI/PyTorch-MPS 底层问题，非配置可修；图生视频改为云端 API，本地专注
> 关键帧生产。关键图底模从 SDXL 换成 Z-Image Turbo + FLUX.2 Klein 4B，均已验证通过。

## 当前主线（已调整为本地+云端分工）

```text
WordSense + SceneSpec
→ Director Agent
→ 角色设定图（方形，跨场景复用的参考资产，每角色只生成一次）
→ 场景关键图 prompt（本地 Z-Image Turbo / FLUX.2 Klein 4B；挂角色设定图为
  reference，直接按视频目标画幅与云端分辨率生成，如 16:9 / 1280×720）
→ 图片语义门（人物/道具/姿态/视线/构图——审查对象就是将提交图生视频的那张图，
  过门后不得再经任何重新生成类处理；若处理则必须重新过门）
→ 图生视频（云端 API，ComfyUI Partner Node 或直连服务商）
→ 可播放视频产物
```

Director 仍是核心中间层，负责把词义翻译成模型可执行的提示词；渲染层全局风格
仍是 Pixar-style 3D 动画。**关键变化**：图生视频不再默认走本地 ComfyUI + Wan2.2，
因为本地推理链已被判定不可用（见下方"本地视频推理诊断结论"）。关键帧生产仍然
本地完成，效果已验证良好。

## 已完成

- 新增 `schema/director-prompt.schema.json`、`prompts/director.md`。
- 新增 `generic-video` 与 `wan2.2-ti2v-5b` capability profiles。
- 新增 `tools/director.py generate/show/list`，产物版本化写入 `data/drafts/director/`。
- 已为 `reluctant-01-proto-01` 生成完整 Director Prompt，三段视频提示覆盖 SceneSpec
  的1–6号语义节拍。
- **本地视频推理诊断已完结**（五轮独立变量排除法，详见
  `data/drafts/renders/reluctant-01-proto-01/v06/RUN-NOTES.md`）：
  文本编码器精度（fp8/fp16/GGUF Q8）、UNET 量化方式（fp16 safetensors/GGUF Q8）、
  VAE 解码位置与精度（MPS bfloat16/CPU fp32）、动作幅度、生成模式与画幅
  （I2V方形/T2V横向）——五个维度逐一变量隔离测试，全部复现同一种损坏特征
  （模糊、色彩分离、条纹）。**结论：问题出在 ComfyUI 0.28.0 + PyTorch nightly
  + Apple MPS 处理 Wan2.2 架构（很可能是3D/时序注意力或RoPE算子）这个组合本身，
  不是任何单一可替换组件；本地不再投入排查，图生视频改走云端 API。**
- **关键图底模验证：SDXL → Z-Image Turbo / FLUX.2 Klein 4B（均通过）**。用
  v06 中 SDXL 曾经失败的 prompt（"少年+黑色垃圾袋"，SDXL 曾把少年画成背包女孩且
  漏画垃圾袋）做直接对比测试：
  - Z-Image Turbo：人物性别/服装/道具/表情全部正确，Pixar 质感良好。
  - FLUX.2 Klein 4B：同样全部正确，且更精确地还原了"身体朝门、回头看电视"这种
    复合空间指令，指令遵循略强于 Z-Image。
  - 两者共用同一个 Qwen3-4B 文本编码器（原生 bf16，无需 fp8，不会重蹈 Wan2.2 的
    精度坑）。
  - 测试文件：`data/drafts/renders/reluctant-01-proto-01/v06/test-z-image-turbo.json`、
    `test-flux2-klein4b.json`。
- **关键帧画幅转换验证通过（工序已从主线移除，workflow 留档作补救工具）**：用
  FLUX.2 Klein 4B 的 Edit/Reference 能力（`ReferenceLatent` + `VAEEncode` 参考图
  约束），把 1024×1024 方形关键图转成 832×480 横向，角色/服装/道具一致性保持良好，
  场景做了合理扩展（不是硬拉伸裁切）。132秒完成。测试文件：
  `data/drafts/renders/reluctant-01-proto-01/v06/test-flux2-klein-reframe.json`。
  该测试的真正价值是**验证了 Klein reference 能力可保持角色一致性**——这正是新主线
  "角色设定图 → reference → 目标画幅关键图"的机制基础；画幅转换本身不再是常设工序
  （理由见决策 15），仅在手里已有画幅不对的既有素材需要补救时使用。832×480 这个
  目标分辨率是本地 Wan 5B 时代的遗留，云端应按 720p+ 重定。

## 当前能力

- 正式资源：4个义项、21个场景；草稿区6个义项。
- 本地 ComfyUI 0.28.0，MPS/32GB M1 Max，已安装：
  - 图像：SDXL（`disneyrealcartoonmix_v10`，逐步淘汰中）、**Z-Image Turbo**
    （`z_image_turbo_bf16.safetensors`）、**FLUX.2 Klein 4B**
    （`flux-2-klein-4b.safetensors`，含 Edit/Reference 能力）、IPAdapter。
  - 视频：Wan 2.2 TI2V 5B（fp16 + GGUF Q8_0 两种精度均已测试，均判定本地不可用）。
  - 自定义节点：`city96/ComfyUI-GGUF`（用于 Wan2.2 诊断，图像侧未依赖）。
- ComfyUI 官方 Partner Nodes 已安装，可走云端 API：`Wan2TextToVideoApi`/
  `Wan2ImageToVideoApi`、Kling 全系列、Luma、Runway、Flux2Pro/Max、Recraft、
  OpenAI（含Sora2）、Gemini、Seedream 等，默认通过 comfy.org 账户额度计费
  （`extra_data.api_key_comfy_org`），未配置真实 key，尚未实际调用。
- `reluctant` 视频实验已覆盖 I2V复合动作、I2V微动作、无首帧横向T2V、fp16文本编码器、
  GGUF全量化、VAE-on-CPU 六种条件，全部同一种失败特征。
- 旧 `render-plan` / `render.py` 仍是逐 beat 文生图原型，与新 Director 并存，尚未迁移。

## 关键决策

1. `SceneSpec.storyboard` 是语义节拍，不与视频clip一一对应。
2. 生产默认关键图先行：文生图 → 图片语义门 → 图生视频；`direct_t2v` 降级为特例。
3. 模型无关指词义理解稳定；最终prompt应主动适配具体模型能力。
4. 生成应尽早发生，不能因为预设视频昂贵而增加不必要流程。
5. 第一版由同一个Director写prompt并查看结果，不预先拆独立Reviewer、Decision Policy
   或复杂Memory。
6. clip数量由语义场景与目标能力共同决定，禁止机械按beat拆分或凑数增删。
7. Pixar-style 3D是渲染层统一风格锚点，只进入Director/Renderer，不进入语义资源。
8. 当前不建设独立Reviewer或审核循环。
9. 一次真实运行需区分采样完成、VAE解码完成与视觉可用。
10. `reluctant` 三轮初始实验在动作幅度、I2V/T2V和方形/横向画幅变化后仍出现同类
    损坏；不再把继续改prompt作为下一动作。
11. **（2026-07-19新增）图生视频改为云端 API，本地不再投入排查**。理由：五轮独立
    变量排除法测试（文本编码器精度×3、UNET量化×2、VAE位置精度×2）均未能改变损坏
    结果，判定为 ComfyUI/PyTorch-MPS 底层问题，继续排查性价比过低。
12. **（2026-07-19新增）关键图底模从 SDXL 换成 Z-Image Turbo + FLUX.2 Klein 4B**。
    理由：SDXL 指令遵循偏弱是v06关键图失败（少年→女孩、漏画道具）的根本原因；
    两个新模型均验证通过，且共用文本编码器、原生 bf16、Apache 2.0 可商用，同时
    绕开了 Wan2.2 踩过的 fp8-on-MPS 坑。
13. ~~（2026-07-19新增）关键帧统一按方形生成，画幅转换作为独立后处理步骤~~
    **已废弃，被同日决策 15 取代**。废弃理由：画幅转换是过门后的重新生成，会使
    图片语义门失效（审的图和送进 I2V 的图不是同一张）；构图/视线/留白这些语义门
    要审的东西恰恰是画幅相关的，应一开始就在目标画幅上设计；"同一关键图转多种
    画幅"是推测性需求（每个场景实际只有一个目标画幅），而多一次生成的漂移风险和
    重试面是真实代价——该工序也违背"更多控制只在结果暴露出相应问题时才增加"的
    项目原则。其正确内核（角色设定与场景生成分离）由决策 15 以更干净的方式保留。
14. **（2026-07-19新增）云端视频 API 降本策略以"减少迭代次数"为核心**，不是单纯
    比价：关键图先行的语义门本身就是最大的省钱机制（免费本地环节拦截语义错误，
    避免烧钱在注定失败的视频生成上）；Director 的 pass/retry 循环应分级（探索用
    便宜档位，定稿才用贵档位）；按 scene_id+version+seed 去重缓存；不为凑时长/凑
    clip 数扩大计费量。
15. **（2026-07-19修订，取代13）场景关键图直接按视频目标画幅与云端分辨率生成**
    （16:9 / 720p 起，Klein 原生支持多画幅至 2K），画幅转换不再是常设工序，降级为
    既有素材的补救工具。跨场景角色复用改由"角色设定图（方形参考资产，每角色一次）
    + FLUX.2 Klein reference 能力"承担。配套硬规则：**图片语义门审查的图必须与
    提交图生视频的图是同一张**，过门后不得再经任何重新生成类处理（转画幅/outpaint/
    重绘），否则必须重新过门。云端侧依据：Kling 输出画幅直接由输入图画幅决定，
    Runway 对不匹配输入做中心裁切——首帧本来就应该是目标画幅。
16. **（2026-07-19新增）跨 clip 一致性机制 = 共用同一张角色设定图作 reference**
    （结构保证，不靠 prompt 措辞的运气）。此机制目前只有画幅转换测试这一个间接
    证据，"同一参考图 + 不同姿态/构图/场景"的专项验证尚未做，是关键图先行三大
    理由之一的承重墙，优先级高于其他产线定稿工作。附带结论：render-stack-research
    中 IPAdapter PLUS + SDXL 的一致性方案随底模切换已作废（IPAdapter 权重属于
    SDXL/FLUX.1 生态，不适用 Z-Image/FLUX.2 Klein）。

## 下一步

1. **跨 clip 一致性专项验证（承重墙，最优先）**：生成一张角色设定图（方形），用
   Klein reference 挂它生成 3–4 张**目标画幅（16:9/720p+）**、不同姿态/构图/场景的
   场景关键图，验证角色/服装/道具一致性。这是决策 15/16 新主线的机制基础，目前
   只有画幅转换测试这一个间接证据。
2. **云端视频 API 接入**：确认走 ComfyUI Partner Node（comfy.org 账户额度）还是
   直连服务商 API（如阿里 DashScope），对比两者是否有代理加价；配置真实 API key。
   **对照实验注意变量控制**：验证"同一份语义规格在正常后端上能否被正确执行"，
   干净的对照是**云端 Wan2.2 API**（同模型、换后端，可直接复用已保存的
   wan2.2-ti2v-5b profile 的 Director Prompt）；若改走 Kling/Veo/Runway 等强模型，
   则同时换了模型和后端，且 5B profile 的保守拆 clip 策略对强模型很可能次优——
   必须先建对应 capability profile 并重新生成 Director Prompt，不得直接复用旧 prompt。
3. **关键图产线定稿**：Z-Image Turbo 与 FLUX.2 Klein 4B 需在更多语义类型（`messy`、
   `almost` 等）上补测，确认不是只对"reluctant"这一个 case 生效。主备/分工按
   "谁承担参考一致性链路"定：一致性靠 Klein reference，则倾向收敛到 Klein 单模型
   （风格指纹统一，避免跨 clip 混用两个底模引入风格不一致），Z-Image 留作对照/备用。
4. **成片剪辑/拼接层设计**（此前发现的空白，尚未处理）：多个 clip 生成出来后如何
   合成一个连贯成片——转场、时长/帧率对齐、导出格式，目前没有 schema 或工具骨架，
   仅在旧 `render.py` 路径下有"playback 组装（待建）"的占位。最简方案（ffmpeg 硬切
   拼接，不做转场）的骨架应在 clip-02 云端验证**之前**搭好，否则验证通过当天就卡住。
5. **云端 API 成本控制机制**：给渲染工具加显式的每场景最大重试次数/每日花费上限，
   避免失败循环无意识烧钱；Director 的 pass/retry 循环加分级（草稿档→定稿档）。
6. 完成首个可用纵向切片（clip-02 云端验证通过）后，再决定是否扩展批量调度；当前
   不增加审核模块。

## 可参考的候选模型（已评估，暂不采用）

供以后需要时查阅，避免重复调研：

**文生图**：
- FLUX.2 Klein 9B（指令遵循更强，但非商用许可，仅限内部实验，不进入 `published` 产物）
- FLUX.1 dev（12B，指令遵循强但许可非商用友好、比 Klein 4B 慢很多）
- HiDream-O1（8B，MIT许可干净，但无 Mac/MPS 实测数据，风险未知）
- Boogu-Image-0.1（10B，Apache 2.0，独立团队，同样无 Mac 实测，黑马备选）
- Krea 2（12.9B，官方要求24GB+显存，对32GB机器偏重，许可需另核实）
- Qwen-Image（20B）、HunyuanImage 3.0（80B MoE）——体量过大，32GB机器跑不动
- SD3.5、Kolors——中等水平，无差异化优势，不如已验证的两个候选
- Seedream 4.0（ByteDance）——ComfyUI里是云端API节点，非本地权重，跟本地选型不是一回事

**图生视频**（本地，均不建议在此机器投入）：
- Wan2.2 14B（GGUF量化）——同架构问题预期复现，且实测82分钟/2秒clip，不现实
- LTX-2——19B，官方要求32GB+显存+CUDA 11.8+，MPS上有已知NaN问题，比Wan2.2更重更依赖CUDA
- HunyuanVideo / Mochi / CogVideoX——CUDA-first项目，无可信MPS实测
- `mlx-video`（Blaizzy，MLX原生非PyTorch路径）——唯一在架构上有机会绕开我们已确诊的
  PyTorch-MPS问题的方向，因为完全不走同一条底层链路；仍是experimental阶段，值得
  以后单独试，不是当前优先级

**关键帧生成的订阅制备选通道**：
- Codex CLI 内置 `image_gen`（调用 gpt-image-2）——ChatGPT Plus 登录即可用、不计入
  单独API账单，但图像生成消耗配额速度是纯文本操作的3-5倍，配额按5小时窗口+每周
  滚动；且把个人订阅用于持续产出可发布资源的生产管线存在使用条款灰色地带（非明确
  禁止，但性质更接近企业场景）。建议只用于小规模验证/救急，不作主力生产通道。

## 语言无关性理论基础（补充）

**语言是附着在生活经验/语义内容上的标签，不是语义本身**——场景外化出来的语义内容
（如"不情愿"场景里的犹豫、拖延、勉强顺从）独立于用哪种语言标注它，任何语言背景的
使用者都能从场景本身感知这份语义。这是"场景优先于词头"方法论成立的理论根基，判断
场景规格是否合格的标准是"换一个完全不同语言背景的人能否感知到同一份语义"，而不是
"是否精准图解了某个 L2 单词"。详见项目记忆 `project-scenelex-mission`。
