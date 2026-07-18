# Phase 1.3 — Director 中间层

> 创建：2026-07-18
> 状态：进行中

## 目标

让Director把`WordSense + SceneSpec`稳定翻译为当前视频模型能执行的高质量提示词，并通过一次真实生成—查看—改写循环验证价值。

```text
semantic scene
→ Director Prompt
→ video model
→ Director pass/retry
→ revised prompt
```

## P0：Director MVP ✅

- [x] 轻量Director Prompt Schema。
- [x] 通用Director提示模板。
- [x] `generic-video`和`wan2.2-ti2v-5b` capability profiles。
- [x] `pixar-3d`全局渲染风格接入Director和旧render流程。
- [x] `generate/show/list`命令和版本化草稿目录。
- [x] Schema、元数据强制、beat覆盖和策略一致性测试。

## P1：`reluctant`真实Prompt

- [ ] 用可用LLM分别生成`generic-video`与`wan2.2-ti2v-5b`版本。
- [ ] 检查prompt是否明确：任务进入考虑、意愿抗拒、可见外化、结果不定义词义。
- [ ] 检查是否排除：仅慢、仅悲伤、只犹豫、明确拒绝、开心主动执行。
- [ ] 检查Director是否忠实保留原场景，没有擅自增加情节或记忆点。
- [ ] 检查图片与视频prompt是否明确包含Pixar-style 3D方向。
- [ ] 根据检查修改Director模板或profile，而不是手工美化单个输出。

## P2：尽早生成视频

- [ ] 先把最简单可行prompt提交给本地Wan或可用强视频模型。
- [ ] 每轮生成多个候选，不因预设成本而延迟尝试。
- [ ] 保存模型、prompt版本、结果和选择；不要求先搭完整编辑系统。

## P3：最小反馈循环

- [ ] 让Director查看候选，输出`pass/retry`、一个主要问题和修改后的prompt。
- [ ] 只在结果暴露实际问题时升级控制：构图→首帧，身份→参考图，终点→尾帧，复杂度→拆片。
- [ ] 跑通至少一次自动或半自动改写并验证是否改善语义。

## 验收

- Director Prompt能直接用于目标视频能力，不含“参考上文”等内部依赖。
- `reluctant`候选呈现明确外部要求、可见抗拒和非主动执行，不把最终执行当成词义定义。
- generic和Wan版本可有不同粒度，但语义guardrails一致。
- 只有真实失败才触发额外控制；没有强制animatic或固定镜头数。

## 暂不做

- 完整Production Package或传统制片状态机；
- 独立多Agent Reviewer/Decision Policy；
- 固定所有词义为同一种视频格式；
- 在第一轮真实生成前扩充大量workflow和模型。
