# Phase 1.3 上下文 — 从哪来、关键决策

> 创建：2026-07-18

## 由来

2026-07 语义基础设施成型后，用户判断渲染是下一阶段重点（决策7）。本 phase
承接一连串产品方向决策，把渲染从"低成本实验材料"升级为"皮克斯风运动视频成片"，
并**退役了原 MVP 学习实验**作为发布/规模化前置（决策5）。

## 关键决策（2026-07-17 / 07-18，用户确认）

1. **核心命题不做实验验证**（07-17）——"场景即释义"是已确立的产品前提，不是研究假设。
   `docs/mvp-evaluation.md` 归档；学习实验不再是发布/规模化前置。→ 原 ROADMAP 1.3-1.5 退役。
2. **人工三层审核由模型审核替代**（07-17）——审核模型宜与起草模型不同。
3. **渲染层目标是运动视频，不是静图幻灯片**（07-18）——动作/过程/程度类词的词义活在运动里。
4. **已验证的渲染方法（模型无关）**（07-18，用户用 B 站 updream 的 SeeDream4.5+Wan2.2 素材演示）：
   角色设定稿 → 逐 beat 一致关键帧 → 逐 beat i2v → 拼接+音频。
   - 跨镜头一致性靠"先出角色设定稿再逐镜头锚定"，不靠一镜到底；
   - i2v 运动偏温和，语义主要活在关键帧的表情/姿态里——**钱砸关键帧**；
   - 单词视频 ≈ 4-5 beat × 5s ≈ 20-25s（仍属短视频）。
5. **全项目统一风格 = 皮克斯/迪士尼 3D 动画风**（07-18）。
6. **导演 Agent = 语义骨架驱动的 LLM + 可插拔 skill 库**（07-18）——纯模型弱的领域用
   沉淀好的 skill 显式指导。命门在关键帧的表情语义正确性——通用 Agent（如 updream）在此画偏，
   这是 SceneLex 差异化价值落点。

## 本会话已验证/产出（去风险）

- ✅ **皮克斯风格**：DisneyRealCartoonMix 直出即目标质感。
- ✅ **卡通脸跨镜头一致性成立**：IPAdapter PLUS（CLIP-vision，非 InsightFace）能锁住卡通角色。
  推翻了"用 FaceID/InstantID/PuLID"的常见做法（对卡通脸失效，PuLID 官方明确不支持）。
- ✅ **Wan2.2-5B 在 M1 Max 32GB 可行**：文本编码器+主模型全量载入（~16GB），
  512²/25帧/15步约 254s（含一次性加载）；有真实运动。
- ✅ **命门 skill v1**：`prompts/director-skills/emotion-to-visual.md`（FACS AU + 动画原理 + must-not）。
- ⚠️ **暴露的头号问题**：IPAdapter 高权重+全身参考图会把**姿势/构图**一起搬过来，压掉提示词的
  动作/表情。修法=降权重 / 脸部特写参考 / +ControlNet(pose)，即"身份与姿势解耦"。

## 上游参考

- 技术调研（一手来源）：`docs/render-stack-research.md`
- 渲染工具与提示词：`tools/render.py`、`tools/imagegen.py`、`tools/workflows/`、
  `prompts/render-plan.md`、`prompts/render-style.yaml`、`prompts/director-skills/`
- schema：`schema/render-plan.schema.json`、`schema/render-manifest.schema.json`
