# Phase 1.3 上下文 — Director 中间层

> 创建：2026-07-18
> 简化校准：2026-07-18

## 问题

现有`render-plan`把SceneSpec的semantic beats直接编译为逐beat图片提示词，再尝试逐beat i2v。仓库样片质量较差；桌面Updream素材虽然审美更好，也出现少年开心出门、母亲服装变化、道具断续等问题。

最重要的问题不是先复制传统影视生产流程，而是：视频模型没有收到足够准确的语义导演语言。通用模型容易把`reluctant`画成sad、slow、hesitant、refuse或最后开心行动。

## 核心决策

1. Director Agent是SceneLex当前最重要的媒体能力。
2. 它读取WordSense + SceneSpec，把已设计语义场景翻译为当前视频能力可执行的高质量prompt。
3. `storyboard`是semantic beats，不和clip一一对应。
4. 默认直接T2V；关键图I2V、参考图、首尾帧、拆片和animatic按实际失败使用。
5. 模型无关指语义理解稳定；prompt本身应适配具体模型能力。
6. 生成要尽早发生，视频候选本身就是Director的反馈。
7. 第一版由Director自己查看结果并修正，不预建复杂Production Package、独立Reviewer或状态机。
8. 现有词义场景已经能正确表达词义；Director只做渲染翻译，不重新设计内容或添加记忆点。
9. 渲染层统一采用Pixar-style 3D动画方向，该标签与可观察风格属性一起注入prompt。

## 当前本地能力

- ComfyUI 0.28.0，MPS/32GB。
- 图像：DisneyRealCartoonMix、Animagine XL、DreamShaper。
- 参考一致性：CLIP-ViT-H + IPAdapter Plus。
- 视频：Wan 2.2 TI2V 5B + UMT5 + Wan VAE。

Wan profile应指导Director缩小单clip动作；更强视频模型profile可以允许一个prompt描述完整连续事件。

## 已实现

- `schema/director-prompt.schema.json`
- `prompts/director.md`
- `prompts/video-model-profiles/generic-video.md`
- `prompts/video-model-profiles/wan2.2-ti2v-5b.md`
- `tools/director.py`
- `tests/test_director.py`

权威说明：`docs/production-workflow.md`。
