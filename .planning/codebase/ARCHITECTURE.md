# SceneLex — 架构骨架

> 最后更新：2026-07-18

## 系统身份

SceneLex 是词义语义资源、教学场景证据和可追溯媒体的生产系统，不是学习应用。

```text
语义资源层
  WordSense + SceneSpec
        ↓
Director 中间层
  semantic scene → model-adapted prompt
        ↓
模型适配与媒体层
  video/image/TTS/interactive + manifest
        ↓
消费者
  dictionary/course/player/API
```

## 内容生产

```text
candidate → sense/scene draft → 可选模型审核 → 校验 + 人工 promote
→ reviewed semantic resource
→ Director Prompt
→ 视频模型候选
→ Director 查看与修正
→ selected/published media
```

学习实验可以优化资源，但不是发布或规模化前置。

## 语义资源层

- `schema/word-sense.schema.json`、`data/senses/`：义项权威。
- `schema/scene-spec.schema.json`、`data/scenes/`：教学场景证据权威。
- `schema/resource-bundle.schema.json`、`tools/export.py`：确定性分发。
- `tools/draft.py`、`tools/review.py`、`tools/validate.py`：起草、可选审核与校验。

`SceneSpec.storyboard` 是semantic beats。它告诉Director事件和证据怎样发展，但不是需要机械逐项执行的视频clip列表。

## Director 中间层

权威说明：`docs/production-workflow.md`。

输入：

```text
WordSense
SceneSpec
video capability profile
```

输出：

```text
strategy: direct_t2v | image_guided_i2v | split_clips
style: pixar-3d
video_prompts[]
optional image_prompt
semantic_guardrails: must_show / must_avoid
```

Director默认最简单的 `direct_t2v`。只有模型能力或实际结果要求更多控制时，才加入关键图、参考图、首尾帧、拆片或animatic。

Director不负责内容创作：WordSense与SceneSpec已经完成词义和场景设计，它只能忠实翻译。全局`pixar-3d`风格由`prompts/render-style.yaml`注入Director和Renderer。

相关文件：

- `schema/director-prompt.schema.json`
- `prompts/director.md`
- `prompts/video-model-profiles/`
- `tools/director.py`
- `data/drafts/director/{scene_id}/v{NN}/director-prompt.yaml`

## 模型适配层

模型无关不等于prompt无差别：词义和证据保持稳定，Director根据能力profile改变表达粒度。

- 强视频模型可以接收完整连续事件和多个动作阶段。
- 本地Wan 2.2 TI2V 5B更适合短、单一主要动作，必要时关键图I2V或少量拆片。
- 模型、workflow、seed、分辨率和供应商参数只进入内部Director/renderer产物与manifest，不进入正式语义资源。

当前本地ComfyUI是首个执行后端，已具备SDXL、CLIP Vision/IPAdapter和Wan 2.2能力。

## 反馈循环

第一版由同一个Director完成：

```text
写prompt → 查看视频 → pass或指出主要语义偏差 → 改prompt
```

不预先建设独立Reviewer、复杂决策规则或生产状态机。真实重复失败出现后，再抽象出稳定skill或评审组件。

## 旧渲染原型

`schema/render-plan.schema.json`、`prompts/render-plan.md`、`prompts/render-style.yaml`和`tools/render.py`是早期逐beat文生图管线。它们暂时保留，但不再代表目标架构；后续根据Director实际接入方式决定迁移或删除。

## 不变量

- 语义骨架与人物、地点、媒体和模型解耦。
- Director不得改变must-show、must-not和概念关系。
- semantic beats与video clips不要求一一对应。
- 生成应尽早发生；控制工具按失败需要逐步增加。
- 生成不等于审核，审核不等于发布。
