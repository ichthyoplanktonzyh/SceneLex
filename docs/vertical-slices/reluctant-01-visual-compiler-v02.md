# reluctant-01 · LLM Visual Compiler 与多模态审核链路 formalization 报告 (v02)

## 概述与工程目标

本报告总结了 SceneLex 生产管线中 **LLM Visual Compiler (物理渲染编译器)** 与 **多模态 VLM 审核链路** 的正式落地成果。

针对 `reluctant-01-proto-01` 场景中的 4 张诊断关键帧（`shot-02-kf-03`, `shot-02-kf-04`, `shot-03-kf-01`, `shot-03-kf-03`），消除了机械字符串拼接提示词导致的语义冲突与鬼影缺陷，建立了确定性 IR 编译与审计流。

---

## 1. 生产管线五层架构 (Pipeline Architecture)

SceneLex 视频教学生成管线正式解耦为以下五层：

```text
[SceneSpec & ShotPlan v05]  <-- 冻结的 SceneLex 语义规格 (Model-Neutral IR)
          │
          ▼
[build_source_packet()]     <-- 确定性提取必须展示/禁止/角色参考
          │
          ▼
[LLM Visual Compiler]       <-- 物理转译器 (翻译为可编辑、可审计的物理渲染指令)
          │
          ▼
[validate_render_directive] <-- 确定性 Validator 校验 (保证 Schema & ID 覆盖率)
          │
          ▼
[Wan 2.7 Serializer & Gen]  <-- BBox 归一化像素转换与 Inpainting 参数构造
          │
          ▼
[VLM Advisory Review]       <-- VLM 多模态评估 (提供建议参考)
          │
          ▼
[Human Final Gate]          <-- 人工判决 Gate (真正决定 pass/fail)
```

---

## 2. 核心数据规格 (Intermediate Representation Schemas)

1. **Source Packet IR (`schema/image-render-source-packet.schema.json`)**:
   - 提取 `scene_ref`, `keyframe_id`, `base_image`, `identity_reference`, `visual_state`, `must_show`, `must_avoid` 等字段，屏蔽所有模糊的故事性文字。
2. **Render Directive IR (`schema/image-render-directive.schema.json`)**:
   - 包含 `edit_mode` (`local_edit` | `full_frame_edit`), `image_roles`, `preserve`, `remove_from_previous_state`, `change`, `must_be_visible`, `forbidden_outcomes`, `edit_regions` (0-1000 归一化 BBox), 以及最终生成的 `wan_prompt`。
3. **Edit Run Manifest (`schema/image-keyframe-edit-run-v1.1.schema.json`)**:
   - 升级至 v1.1，将 `vlm_review`（只读建议）与 `review`（人工判决）完全解耦，审计追溯记录完整的 `compiler` / `vlm` / `human` 痕迹。

---

## 3. 诊断关键帧编译产物与 BBox 统计

在 `data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/` 目录下完成 4 张诊断关键帧的编译：

| 诊断关键帧 ID | 动作状态 | 编辑模式 | 关键 BBox 区域 [x1,y1,x2,y2] | 编译结果 |
| :--- | :--- | :--- | :--- | :--- |
| `shot-02-kf-03` | 伸手悬停 / 不碰叉子 | `local_edit` | `[250, 300, 750, 850]` | **PASS (Compiler Validated)** |
| `shot-02-kf-04` | 孩子手握叉子 / 身体后靠 | `local_edit` | `[250, 300, 750, 850]` | **PASS (Compiler Validated)** |
| `shot-03-kf-01` | 跨镜首帧 / 叉子在盘缘 | `local_edit` | `[250, 300, 750, 850]` | **PASS (Compiler Validated)** |
| `shot-03-kf-03` | 吃完动作结束 / 叉子放回 | `local_edit` | `[250, 300, 750, 850]` | **PASS (Compiler Validated)** |

---

## 4. 产物与测试索引

* **相关代码**：
  * [tools/llm.py](file:///Users/shadow/SceneLex/tools/llm.py) (多模态 LLM 适配层)
  * [tools/image_render_compiler.py](file:///Users/shadow/SceneLex/tools/image_render_compiler.py) (Visual Compiler 中间件)
  * [tools/image_keyframe_edit.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edit.py) (领域业务库)
  * [tools/image_keyframe_edits.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edits.py) (CLI 工具)
* **审查与报告**：
  * [data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/review.html](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/review.html) (HTML 跨镜比较与 VLM/Human 评审面板)
  * [data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/edit-run.yaml](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/edit-run.yaml) (Edit Run v1.1 Manifest)
