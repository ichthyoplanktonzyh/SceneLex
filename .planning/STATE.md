---
gsd_state_version: 1.0
milestone: m1
milestone_name: 语义资源与 Director 纵向切片
status: active
last_updated: "2026-07-18T19:10:00.000+08:00"
---

# SceneLex — 项目活记忆

> 最后更新：2026-07-18 CST
> 更新原因：完成 reluctant Director 纵向切片与本地 ComfyUI 三轮真实生成。

## 当前主线

```text
WordSense + SceneSpec
→ Director Agent
→ 当前视频能力的高质量 prompt
→ 视频模型
→ 可播放视频产物
```

Director 是核心中间层，不模拟完整动画制片厂。它负责理解词义必须怎样被看见、排除哪些相邻概念，再写成模型可以执行的英文导演提示词。当前阶段不建设独立审核模块；先跑通稳定的视频生成后端。

现有WordSense与SceneSpec已经能正确表达词义。Director不得重新设计场景或增加记忆点，只做忠实渲染翻译；渲染层全局风格确定为Pixar-style 3D动画。

## 已完成

- 新增 `schema/director-prompt.schema.json`。
- 新增 `prompts/director.md`。
- 新增 `generic-video` 与 `wan2.2-ti2v-5b` capability profiles。
- 新增 `tools/director.py generate/show/list`，产物版本化写入 `data/drafts/director/`。
- 新增 Director 测试，当前6项通过。
- 权威说明：`docs/production-workflow.md`。
- 已为 `reluctant-01-proto-01` 生成完整 Director Prompt，三段视频提示覆盖 SceneSpec 的1–6号语义节拍。
- 已通过本地 ComfyUI 实际运行SDXL关键图与三轮Wan 2.2生成，工作流、关键图、MP4和运行记录保存在 `data/drafts/renders/reluctant-01-proto-01/v06/`。
- 已验证Director Prompt符合Schema；实验MP4均为合法H.264文件，生成链路可以执行并落盘。

## 当前能力

- 正式资源：4个义项、21个场景；草稿区6个义项。
- 本地 ComfyUI 0.28.0，MPS/32GB，已安装SDXL、IPAdapter和Wan 2.2 TI2V 5B。
- `reluctant` 实验已覆盖I2V复合动作、I2V微动作、无首帧横向T2V三种条件。
- 旧 `render-plan` / `render.py` 仍是逐 beat 文生图原型，与新 Director 并存，尚未迁移。

## 关键决策

1. `SceneSpec.storyboard` 是语义节拍，不与视频clip一一对应。
2. Director默认 `direct_t2v`；关键图I2V和拆片只在模型/结果需要时使用。
3. 模型无关指词义理解稳定；最终prompt应主动适配具体模型能力。
4. 生成应尽早发生，不能因为预设视频昂贵而增加不必要流程。
5. 第一版由同一个Director写prompt并查看结果，不预先拆独立Reviewer、Decision Policy或复杂Memory。
6. 角色设定、首尾帧、animatic、连续状态都是可选工具，不是强制前置。
7. Pixar-style 3D是渲染层统一风格锚点，只进入Director/Renderer，不进入语义资源。
8. 当前不建设独立Reviewer或审核循环；稳定生成视频是优先事项。
9. 一次真实运行不能只记录“生成成功”，还要区分采样完成、VAE解码完成与视觉可用。
10. `reluctant` 三轮实验在动作幅度、I2V/T2V和方形/横向画幅变化后仍出现同类条纹、色彩分离、人体断裂和漂移；不再把继续改prompt作为下一动作。

## 下一步

1. 使用已保存的同一份Director Prompt，在一个已知正常的视频推理后端上做对照运行，优先验证CUDA环境、可用的其他本地视频模型或更强模型。
2. 检查当前Wan 2.2 5B权重、VAE、ComfyUI版本和Apple MPS数值兼容性，确认画面损坏来自模型权重还是本地运行时组合。
3. 后端稳定后，重新生成 `reluctant` 的核心clip-02，并以“停顿/叹气/最小接触/缓慢行动/回望”作为语义验收标准。
4. clip-02稳定后，再按现有Director Prompt补齐clip-01和clip-03，验证完整自动化渲染路径。
5. 完成首个可用纵向切片后，再决定是否扩展批量调度；当前不增加审核模块。

## 当前阻塞

Director Prompt已经实际提交给本地视频后端，ComfyUI能够完成采样、解码和MP4封装，但三轮输出均视觉不可用。相同损坏同时出现在I2V大动作、I2V微动作和原生横向T2V，当前阻塞定位为本地 `Wan 2.2 TI2V 5B + ComfyUI 0.28.0 + Apple MPS` 推理链（或其权重/运行时组合），而不是词义场景缺失或尚未编写提示词。详见 `data/drafts/renders/reluctant-01-proto-01/v06/RUN-NOTES.md`。
