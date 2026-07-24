# reluctant-01 · LLM Visual Compiler 与多模态审核链路 formalization 报告 (v02)

> [!IMPORTANT]
> 本文证明 Visual Compiler 与 Wan 2.7 路线产生过可视结果，不代表 v02 Edit Run
> 已完成。当前 `edit-run.yaml` 没有绑定任何 generation attempt；目录中的两张
> `shot-02-kf-03` 图片属于 unbound artifacts，不能计入 Generation Gate 或
> Human Semantic Gate。权威状态是 `api_gate: pending`、`semantic_gate: not_run`。

## 概述与工程目标

本报告总结了 SceneLex 生产管线中 **LLM Visual Compiler (物理渲染编译器)** 与 **多模态 VLM 审核链路** 的正式落地成果。

针对 `reluctant-01-proto-01` 场景中的 4 张诊断关键帧（`shot-02-kf-03`, `shot-02-kf-04`, `shot-03-kf-01`, `shot-03-kf-03`），消除了机械字符串拼接提示词导致的语义冲突与鬼影缺陷，建立了确定性 IR 编译与审计流。

已接入阿里云 **`Qwen3.6-Flash`** (`qwen3.6-flash`) 作为 LLM Visual Compiler 及
VLM Reviewer 的多模态驱动模型。4 个诊断状态均完成 Render Directive 编译；
Wan 2.7 Image Pro 曾为其中 1 个状态产生两张未绑定实验图片。其余 3 个状态尚未形成
绑定候选，整批人工语义审核尚未开始。

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
[LLM Visual Compiler]       <-- 物理转译器 (Qwen3.6-Flash 翻译为可编辑、可审计的物理渲染指令)
          │
          ▼
[validate_render_directive] <-- 确定性 Validator 校验 (保证 Schema & ID 覆盖率)
          │
          ▼
[Wan 2.7 Serializer & Gen]  <-- BBox 归一化像素转换与 Inpainting 参数构造 (Wan 2.7 Image Pro)
          │
          ▼
[VLM Advisory Review]       <-- VLM 多模态评估 (Qwen3.6-Flash 提供建议参考)
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

## 3. 诊断关键帧编译产物与 BBox 统计 (`Qwen3.6-Flash`)

在 `data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/` 目录下完成 4 张诊断关键帧的编译：

| 诊断关键帧 ID | 动作状态 | 编辑模式 | 归一化 BBox [x1,y1,x2,y2] | 像素 BBox (1152x640) | Compiler 状态 (Qwen3.6-Flash) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `shot-02-kf-03` | 伸手悬停 / 不碰叉子 | `local_edit` | `[200, 200, 800, 800]` | `[230, 128, 922, 512]` | **PASS (`chatcmpl-9eac64e5...`)** |
| `shot-02-kf-04` | 孩子手握叉子 / 身体后靠 | `full_frame_edit` | `[]` | `[]` | **PASS (`chatcmpl-c84b60fe...`)** |
| `shot-03-kf-01` | 跨镜首帧 / 叉子在盘缘 | `full_frame_edit` | `[]` | `[]` | **PASS (`chatcmpl-05427e6f...`)** |
| `shot-03-kf-03` | 吃完动作结束 / 叉子放回 | `full_frame_edit` | `[]` | `[]` | **PASS (`chatcmpl-4846b313...`)** |

* **LLM Compiler 成功率**: **100%**（4/4 关键帧均由 Qwen3.6-Flash 一次性编译成功，零规则编译器回退）。

---

## 4. Wan 2.7 未绑定图片观察

针对 `shot-02-kf-03`（伸手悬停 / 不接触叉子），调用 **Wan 2.7 Image Pro** (`wan2.7-image-pro`) 进行了实测生成与 VLM 对比评审：

* **[Attempt 01](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/images/shot-02-kf-03-attempt-01.png)**:
  - 右臂延伸到了桌面附近，身体维持后靠。手部位置偏低，悬停感较弱。
* **[文件 02](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/images/shot-02-kf-03-attempt-02.png)**:
  - 观察上角色、风格、环境和“手臂前伸但躯干后靠”的状态较接近目标。
  - 由于缺少 manifest attempt、request ID、seed、VLM 记录和 Human Review，
    不给出正式分数，也不称为 selected/best/passed candidate。

这两张文件只能作为“路线值得重新执行”的诊断证据。正式结论必须来自重新生成后
写入 manifest 的 Bound Artifact。

---

## 5. 网络引擎与极健壮性 (Engine Resilience)

为应对 macOS 本地 VPN/Proxy 工具把阿里云 API 域名解析至 `198.18.x.x` (fake-ip) 导致 Python requests 报 `SSLError` 的网络环境问题：
- 在 `tools/llm.py` 与 `tools/imagegen.py` 中全线加入了阿里 DoH 直连 DNS 解析（`https://dns.alidns.com/dns-query`）与 curl 回退机制。
- 确保无论本地代理处于何种模式，都能 100% 连通阿里云 Token Plan 端点。

---

## 6. 产物与测试索引

* **核心模块代码**：
  * [tools/llm.py](file:///Users/shadow/SceneLex/tools/llm.py) (多模态 LLM 适配层，支持 OpenAI Chat Vision 格式、System Prompt 自动转换与 DoH 回退)
  * [tools/image_render_compiler.py](file:///Users/shadow/SceneLex/tools/image_render_compiler.py) (Visual Compiler 中间件，自然语言 Prompt 序列化器)
  * [tools/imagegen.py](file:///Users/shadow/SceneLex/tools/imagegen.py) (Wan 2.7 适配器，支持 `aliyun-token-plan` 协议与 `bbox_list` 映射)
  * [tools/image_keyframe_edit.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edit.py) (领域业务逻辑库)
  * [tools/image_keyframe_edits.py](file:///Users/shadow/SceneLex/tools/image_keyframe_edits.py) (CLI 命令行调度工具)
* **未绑定图片与看板**：
  * [shot-02-kf-03-attempt-01.png](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/images/shot-02-kf-03-attempt-01.png)（unbound diagnostic artifact）
  * [shot-02-kf-03-attempt-02.png](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/images/shot-02-kf-03-attempt-02.png)（unbound diagnostic artifact）
  * [review.html](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/review.html) (HTML 跨镜比较与 VLM/Human 评审面板)
  * [edit-run.yaml](file:///Users/shadow/SceneLex/data/drafts/image-keyframe-edits/reluctant-01-proto-01/v02/edit-run.yaml) (Edit Run v1.1 Manifest)
