# SceneLex — 路线图

> 最后更新：2026-07-18
> 当前里程碑：M1 语义资源与 Director 纵向切片

## 路线概览

```text
M0 核心语义基础设施（已完成）
  ↓
M1 Director：语义场景 → 视频提示词 → 样片（当前）
  ↓
M2 多语义类型与自动修正
  ↓
M3 规模化生产与消费者集成
```

## M0：核心语义基础设施 ✅

Schema、LLM 起草、多协议适配、校验、原子 promote、导出、候选队列和审核工作台已建立。正式库现有4个义项、21个场景。

## M1：Director 纵向切片 ⏳

目标：打通“WordSense + SceneSpec → Director Prompt → 视频模型 → 查看与修正”，证明SceneLex能把精确词义翻译成当前模型能够执行的视频语言。

### Phase 1.2：扩展义项覆盖 ⏳

- [ ] 审核并人工决定是否 promote `barely / filthy / grimy / hesitant / nearly / refuse`。

### Phase 1.3：Director 中间层 ⏳ ← 当前焦点

- [x] 定义轻量 `director-prompt` Schema。
- [x] 建立 Director Prompt 模板和 `generic-video` / `wan2.2-ti2v-5b` capability profiles。
- [x] 建立版本化 `tools/director.py generate/show/list`。
- [x] 将Pixar-style 3D全局风格接入Director和旧图像渲染配置。
- [ ] 用实际 LLM 为 `reluctant-01-proto-01` 生成第一版 Director Prompt。
- [ ] 把 prompt 提交给本地 Wan 或可用强视频模型并查看结果。
- [ ] 让 Director 根据结果修正 prompt，跑通最小循环。
- [ ] 记录真实失败模式，再决定是否需要参考图、独立Reviewer或更多自动化。

### M1 退出条件

- `reluctant` 至少有一个语义正确的视频候选：明确任务、可见抗拒、可能仍执行，不误画为 eager / hesitant / refuse。
- Director Prompt 可针对不同 capability profile 改写，但不改变 WordSense / SceneSpec。
- Director忠实翻译现有场景，不增加新故事；所有输出保持统一Pixar-style 3D方向。
- 直接生成、关键图 I2V、拆片是按需策略，不成为固定管线。

## M2：多语义类型与自动修正 🔒

- 用 `messy`、`almost` 验证不同语义类型的提示词写法。
- 让 Director 读取生成结果并输出简短 `pass/retry + problem + revision`。
- 仅把稳定重复的失败模式沉淀为 skill 或独立Reviewer，不预先机械拆层。

## M3：规模化生产与消费者集成 🔒

- 批量 Director Prompt 与媒体生成；
- 可追溯版本、选择与许可；
- 资源包、播放器或 API 的最小消费者集成；
- 可选个性化场景表面和效果评估。
