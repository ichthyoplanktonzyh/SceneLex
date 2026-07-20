# reluctant-01-proto-01 — 图片关键帧原型（第一轮真实图像）

这一轮只回答一个问题：

> Keyframe Plan v02 里的 9 个文字关键状态，能否转化为**语义可读、角色一致、道具连续、跨镜可衔接**的真实图片？

它不是视频生成，不是通用资产基础设施，也不是最终学习效果验证。审核层级是：

```text
REAL IMAGE SEMANTIC REVIEW
NOT VIDEO MOTION REVIEW
```

## 输入版本

| 层 | 版本 | 路径 |
|---|---|---|
| Shot Plan | **v05** | `data/drafts/shot-plans/reluctant-01-proto-01/v05/shot-plan.yaml` |
| Keyframe Plan | **v02** | `data/drafts/keyframe-plans/reluctant-01-proto-01/v02/keyframe-plan.yaml` |
| 上游审核结论 | Round 2：`READY FOR IMAGE KEYFRAME GENERATION` | `docs/vertical-slices/reluctant-01-keyframe-animatic.md` |

v04 Shot Plan 与 v01 Keyframe Plan 未被读取、未被修改，作为"审核门确实拦住过东西"的证据保留。

## 产物

```text
data/drafts/image-keyframes/reluctant-01-proto-01/v01/
  image-keyframe-manifest.yaml
  review.html
  images/   9 张 PNG
  prompts/  9 份编译后的提示词
```

一张图片对应**一个 keyframe**，不是一个 beat——所以这一层没有复用 legacy 的 beat-image render 逻辑，也没有改写它。

## 生成方式

| 项 | 实际值 |
|---|---|
| provider | 本地 ComfyUI（`comfyui` 协议，`tools/imagegen.py`） |
| 模型 | `z_image_turbo_bf16`（Z-Image Turbo，Qwen3-4B 文本编码器） |
| 工作流 | `tools/workflows/comfyui-zimage-keyframe.json` |
| 分辨率 | 1152×640（16:9） |
| 采样 | `res_multistep` / `simple` / 8 steps / cfg 1.0 / shift 3 |
| 是否使用参考图 | **否** |
| 一致性策略 | 固定 seed + Shot Plan 的 `cast` / `location` / `props` 连续性描述常量块 |
| 风格来源 | `prompts/render-style.yaml`（全库统一 `pixar-3d`），本层不新建 Style Bible |

选 Z-Image Turbo 而不是仓库既有的 SDXL 工作流，理由是这一轮的成败取决于**指令遵循**：
"手停在离叉子三分之二处、躯干仍然后靠"、"叉子停在嘴前但嘴未张"这类冻结中间状态，
SDXL / SD1.5 级别的 CLIP 编码器基本画不出来。旧的 `comfyui-text2image.json` 保留不动。

### 提示词编译原则

`tools/image_keyframe.py` 的 `compile_prompt` 是**纯机械拼装**，正提示词的顺序固定为：

```text
风格 (render-style.yaml)
→ 单帧指令 (这是一张静止画面，不是分镜表)
→ FRAMING  (Shot Plan 的 composition + camera)
→ CAST / LOCATION / PROPS (Shot Plan 的连续性描述常量块)
→ FROZEN STATE (Keyframe 的 visual_state)
→ MUST BE VISIBLE (Keyframe 的 must_show)
→ CARRIED OVER FROM THE PREVIOUS FRAME (Keyframe 的 continuity.from_previous)
→ 禁止教学包装
```

`must_avoid` 只进负提示词，不进正提示词——在扩散模型里提到某个东西本身就会把它召唤出来。

编译器**不重新决定**：故事、动作阶段、人物位置、谁持有叉子、叉子是否已插入食物、
孩子是否已经吃下、哪一帧是语义高潮、Shot 2 → Shot 3 的切点。模型只负责把冻结状态画出来。
画面里也不得出现目标词 `reluctant`、字幕、定义、词义标签、旁白、对话气泡或 UI overlay。

## 生成情况

9 张图片**全部生成成功**，没有一张因为技术原因缺失。失败发生在语义层，不在生成层。
逐帧结论同时写在 `image-keyframe-manifest.yaml` 的 `frames[].review` 里，
并排审核页是 `review.html`。

### 一个先踩到的坑：工作流不能靠环境变量隐式选

第一次真跑画出来的是动漫风格、七个人围坐、带日文对话气泡的图。原因不是提示词，
而是 `tools/imagegen.py` 的工作流来自 `SCENELEX_IMG_WORKFLOW` 环境变量，默认值是
legacy 的 beat-image SDXL 工作流。关键帧层没有显式指定，于是**用错了模型而 manifest
事后分辨不出来**。

现在工作流由 `tools/image_keyframes.py` 的 `--workflow` 显式给出（默认 Z-Image
关键帧工作流），并有回归测试盯着。这条经验与模型无关：**图像层的模型选择必须是产物
的一部分，不能是终端状态的一部分。**

## 逐帧审核结果

| 关键帧 | semantic | continuity | composition | character | 主要问题 |
|---|---|---|---|---|---|
| shot-01-kf-01 | fail | fail | pass | weak | t=0 孩子已握叉、母亲已指完 |
| shot-01-kf-02 | weak | fail | pass | fail | 母亲看盘子不看孩子；孩子仍握叉 |
| shot-02-kf-01 | fail | fail | weak | fail | 叉齿已插入食物；左缘人物不是母亲 |
| shot-02-kf-02 | fail | fail | pass | fail | 在伸手而不是收回；躯干未后撤 |
| shot-02-kf-03 | fail | fail | pass | fail | 判据帧：手已握叉、躯干前倾带笑 |
| shot-02-kf-04 | weak | weak | pass | fail | 最接近规格，但躯干未后靠 |
| shot-03-kf-01 | fail | fail | pass | weak | 空叉已送进嘴里，剪辑点跳变 |
| shot-03-kf-02 | weak | weak | pass | fail | 最强一张，但视线转向母亲 |
| shot-03-kf-03 | fail | fail | pass | fail | 没有吃下、叉子没放回 |

构图几乎全部通过：`medium_wide` / `medium_close`、母左子右、盘子与叉子可读、
孩子与盘子之间无遮挡。**Shot Plan 的 `composition` 与 `staging` 是这一批里唯一被
稳定执行的字段。**失败全部集中在人物状态与道具阶段。

## 语义判据

### Silent read — 不成立

静音条件下能读出的只有两件事：母亲指着西兰花（`shot-01-kf-02`）、孩子把西兰花举到
嘴边停住（`shot-03-kf-02`）。读不出低意愿的行为链，因为链条中间的每一个抵抗状态都
没有被画出来。

### reluctant vs refuse — 未证成

没有出现任何 refuse 的禁止项：没有推开盘子、没有丢下叉子、没有手向后缩、没有母亲
喂食、没有母亲把叉子塞给孩子。这一半是成立的。

但区分 refuse 需要正面证据"他最终自己吃下了"，而收尾帧 `shot-03-kf-03` 的叉子仍然
举在半空、西兰花仍在叉齿上，这一口根本没有发生。**因此也无法检验"吃完之后意愿没有
转正"**——动作没完成，就没有"完成之后"的状态可看。

### reluctant vs 普通慢动作 — 完全未证成

这是本轮最严重的失败。判据是：

```text
手开始配合，但身体和视线仍然表现出阻力
```

**9 张图里没有任何一张出现后靠的躯干。** `shot-02-kf-03` 要求"手停在离叉子约三分之二
处、没有碰到叉子、躯干仍然后靠"，实际画成手已握叉、叉齿已插入西兰花、躯干前倾并带
轻微笑意。得到的不是一个不情愿的孩子，是一个平静配合的孩子。

## 跨镜审核 Shot 2 → Shot 3

`shot-02-kf-04` 与 `shot-03-kf-01` 并排见 `review.html`。

| 检查项 | 结果 |
|---|---|
| same child identity | weak（服装细节不一致） |
| same right hand on fork | pass |
| same fork orientation | fail |
| same fork position near plate rim | fail（下游帧的叉子已在嘴里） |
| tines not yet inserted into food | fail |
| same torso recline | fail（两帧都没有后靠） |
| same gaze direction | fail |
| same screen direction | pass |
| same plate position | pass |
| same food arrangement | pass |
| mother still at left edge | pass |
| mother touching nothing | pass |

场景级的东西（盘子、食物、银幕方向、母亲不触碰）守住了；**动作状态与道具阶段全部
没守住**。而这一对帧存在的唯一理由就是动作状态——所以这一项判定为 fail。

## 病因分析

三条，都不是画质问题：

1. **模型用"吃饭场景"先验覆盖了被冻结的动作前状态。** 只要画面里同时出现孩子、盘子
   和叉子，模型就画"正在吃"。`visual_state` 里"手尚未碰到叉子""叉齿尚未插入食物"
   "双手平放桌面"这类**否定式的中间状态**被系统性忽略。指令遵循在名词和构图上很强，
   在"某个动作还没有发生"上很弱。
2. **`must_avoid` 在本工作流里根本没有生效。** Z-Image Turbo 是 CFG 蒸馏模型，
   cfg=1.0 时采样器不走负分支。负提示词被完整编译进 `prompts/*.txt`，但没有任何一条
   到达模型。**这一轮的 must_avoid 实际上只是人工审核清单，不是生成约束。**
3. **固定 seed + 常量块不足以稳住角色。** 母亲在 9 帧里换了 4 次外观，其中 3 帧被画
   成了另一个男孩。固定 seed 在提示词逐帧变化时不提供身份锁定。

## 上游修订建议

**没有。** 图片没有证明上游状态不可画或语义不清。

失败的是执行，不是计划：Keyframe Plan v02 的 9 个状态描述本身清楚、可判定、可逐条
核对——正因为它们足够具体，才能明确指出每一张图错在哪里。Shot Plan v05 与 Keyframe
Plan v02 **均未修改**，v04 与 v01 也未被触碰。

## 下一轮要改的是生成侧

按病因对应，不按"多试几次"：

1. **需要能真正约束否定状态的手段。** 单纯文生图不够。候选：走支持参考图/编辑的模型
   （如 Flux.2 Klein 的 image-edit 变体），用上一帧作为下一帧的输入做**状态编辑**，
   而不是每帧从噪声重画。这与"一张图片对应一个 keyframe"不冲突。
2. **`must_avoid` 必须落到采样器上。** 要么换非蒸馏、cfg>1 可用的模型，要么改用支持
   负面约束的工作流。否则不要声称 must_avoid 被执行了。
3. **角色一致性需要比固定 seed 更强的手段。** 本轮已经证明常量块不够。是否需要建立
   Character Bible，等这一条被单独验证后再决定——本 PR 仍然不建。

## Gate

```text
IMAGE KEYFRAME REVISION REQUIRED
```

不是 `GENERATION BLOCKED`：环境可用，9 张图全部真实生成，问题被真实看见了。

也**不是** `READY FOR VIDEO MOTION PROTOTYPE`：这批图没有构成准确、连续、可进入运动
验证的视觉语义证据。把它们送进图生视频，只会得到一个平静吃西兰花的孩子的高质量动画。

本轮的价值不在图，在于它精确定位了三条病因，并且证明了**图片语义门确实能拦住东西**
——就像 animatic 门拦下了 Shot Plan v04 一样。9 张图作为失败证据保留，不覆盖、不删除。
