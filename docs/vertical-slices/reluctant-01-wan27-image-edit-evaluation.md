# reluctant-01 · 关键帧图像编辑生成缺陷诊断与生成链路升级报告

## 摘要与背景

在 SceneLex 的视频教学资源生成管线中，针对 `reluctant-01` 场景（义项: 不情愿地配合）进行了基于 **Wan 2.7 Image Pro (`wan2.7-image-pro`)** 的关键帧编辑实验（v01 试跑）。实验目标是验证生图模型能否准确执行四个冻结视觉状态，特别是呈现“手在配合但躯干后靠”的不情愿核心语义判据。

本报告记录了现有生成方案中出现的**核心视觉缺陷**、**根源机制诊断**以及**重构后的现代化 AI 视频生产链路标准**。

---

## 1. 现有生成方案缺陷诊断与产物审查

在 `reluctant-01-proto-01` v01 实验的四张诊断关键帧中，审查发现了以下严重质量缺陷：

| 诊断关键帧 ID | 目标视觉状态 | 生成结果与缺陷描述 | 评审结论 |
| :--- | :--- | :--- | :--- |
| `shot-02-kf-03` | 手伸到半空悬停，身体后靠 | 成功分离开伸手与躯干后靠，画面较为干净。 | **PASS** |
| `shot-02-kf-04` | 孩子手握住叉子，身体后靠 | **道具鬼影重影 (Prop Duplication Artifact)**：孩子右手握住叉子，但桌面上原本位置依然残留着另一把叉子；且画面带有高频颜色噪点。 | **FAIL** (prop_continuity) |
| `shot-03-kf-01` | 跨镜首帧，手握叉子近盘 | **画面崩溃与退化 (Color Noise Feedback Loop)**：画面充斥严重的 VAE 噪声与色彩失真，图像完全不可用。 | **FAIL** (semantic_readability) |
| `shot-03-kf-03` | 吃完后叉子放回盘子，动作结束 | **状态偏移 (State Fidelity Failure)**：模型生成了“叉着西兰花停在嘴边（动作高潮）”，而非“吃完放回盘子（动作结束）”。 | **FAIL** (state_fidelity) |

---

## 2. 缺陷根源分析：为什么旧方案会失败？

通过对比代码、 Prompt 与扩散模型工作原理，归纳出旧生成链路的三大架构陷阱：

### (1) 机械拼凑 Prompt 导致的“法条干扰与语义冲突”
* **现象**：Prompt 包含了大量的 `why`（心理因果解释）、`must_avoid`（否定句式模板）以及 `PRESERVE EXACTLY` 常量块。
* **根源**：代码使用 Python 字符串拼接（`compile_edit_instruction`），将写给**人类审核员**看的高阶教学契约直接传给**扩散模型**。Prompt 长度达数以百字，扩散模型注意力被噪声稀释；且 Prompt 既要求“保持桌上的叉子不变”又要求“手拿着叉子”，直接诱发了**双叉子重影**。

### (2) 全图重绘（Full-frame Diffusion）缺少 Mask 保护
* **现象**：连续编辑后，画面高频噪点迅速累积导致 `shot-03-kf-01` 退化崩溃。
* **根源**：未传入 `bbox_list` (Bounding Box / Inpainting Mask)。扩散模型每次编辑都在重新对全图（包括背景、人物面部、衣服）进行重构，导致上一帧微小的 VAE 噪点被放大。

### (3) 混淆了“静态图”与“视频插值”的职责
* **现象**：试图在静态关键帧中画出“手伸到半空的迟疑帧（kf-03）”。
* **根源**：“不情愿/迟疑”属于**时间轴上的时序特征（Timing）**，而非静态几何特征。用 Img2Img 编辑硬画过度细碎的中间帧，既增加了失真概率，也破坏了视频插值模型的下序运动连续性。

---

## 3. 升级后的 AI 视频生成链路标准 (New Pipeline Architecture)

为了彻底解决上述问题，SceneLex 生成链路重构为 **“语义中枢 ➔ 导演编排 ➔ 视觉物理编译 ➔ 局域 Mask 渲染 ➔ VLM 自动打分”** 的五层流水线：

```text
[WordSense & SceneSpec]  <-- 语义契约层 (Model-Neutral IR)
          │
          ▼
[Shot Plan & Keyframe Plan] <-- 导演层 (确定首尾锚点帧, 不做中间微动)
          │
          ▼
[Prompt & BBox Compiler LLM] <-- 物理编译层 (严格要求 LLM 翻译物理描述 + 自动预测 BBox)
          │
          ▼
[Wan 2.7 Inpainting + BBox] <-- 局域渲染层 (90% 背景与主体像素锁死, 消除重影)
          │
          ▼
[VLM Vision Gate Evaluator] <-- 自动评估层 (根据 must_show/must_avoid 自动评估)
```

### 核心改造落地点：
1. **强约束 Prompt Compiler LLM (`image_keyframe_edit.py`)**：
   - 彻底剥离人类心理词汇，将抽象语义翻译为 `<100` 词的纯物理描述。
   - 包含 **Conflict Elimination（显式消去）** 规则：移动道具时必须显式指定 `REMOVE [old_prop]`。
   - **拒绝 Fallback**：若无 LLM 编译直接抛出 `RuntimeError` 终止，保证入库 Prompt 质量。
2. **Auto BBox Inpainting 绑定**：
   - Prompt Compiler LLM 自动预测归一化的 `target_bbox: [x1, y1, x2, y2]`。
   - 传递给 Wan 2.7 API 仅对变动局域做 Inpainting 重绘，锁死无关区域。
3. **VLM Auto Reviewer (Vision Gate)**：
   - 接入多模态视觉大模型对生成图进行 5 维度自动评审，写回 Review YAML 与网页报告。

---

## 4. 产物清单与文件目录

* **代码与 Schema**：
  * [tools/image_keyframe_edit.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edit.py) (编译与评估领域库)
  * [tools/image_keyframe_edits.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edits.py) (CLI 工具)
* **诊断数据与审查报告**：
  * [data/drafts/image-keyframe-edits/reluctant-01-proto-01/v01/edit-run.yaml](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v01/edit-run.yaml)
  * [data/drafts/image-keyframe-edits/reluctant-01-proto-01/v01/review.html](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v01/review.html)
