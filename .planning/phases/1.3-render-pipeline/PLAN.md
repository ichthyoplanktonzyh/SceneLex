# Phase 1.3 — `reluctant` 媒体纵向切片

> 创建：2026-07-18
> 最后更新：2026-07-24
> 状态：进行中

## 目标

完成 `reluctant-01-proto-01` 从已审核语义规格到可播放、可追溯、语义正确成片的第一条纵向切片。

## 已完成

- [x] Legacy Director Prompt 原型验证。
- [x] Shot Plan 成为 Scene 之后的叙事执行权威。
- [x] Shot Plan v04 经 Animatic 反馈修订为 v05。
- [x] Keyframe Plan v02 与 Animatic v02 通过。
- [x] 第一批 9 张真实关键图生成并被图片语义门拦下。
- [x] 建立 Source Packet → Visual Compiler → Render Directive → Validator。
- [x] 建立 Wan 2.7 图片状态编辑与 VLM advisory review 工具。
- [x] 为 4 个诊断状态生成已验证 Render Directive。

## 当前 P0：关闭图片语义门

- [ ] 重新执行 4 个诊断 target；所有成功与失败都写 manifest attempt。
- [ ] 每个 target 选择一个绑定的 generated attempt。
- [ ] 完成 VLM advisory review。
- [ ] 完成人工五维审核与整批 Semantic Gate。
- [ ] 仅在 `api_gate: pass` 且 `semantic_gate: pass` 后进入视频。

## P1：视频运动

- [ ] 定义最小 Motion Directive 与 Video Run 记录。
- [ ] 将三镜映射为一个或多个 Motion Segment；模型调用边界不得改写 Shot。
- [ ] 明确云端 I2V 适配能力并用已过图片门的输入生成候选。
- [ ] 审核停顿、速度、动作阶段、跨镜连续性和概念边界。
- [ ] 对主要失败做一次最小修订循环。

## P2：成片

- [ ] 三镜最小硬切拼接。
- [ ] 添加必要 SFX、可选对话和目标声音。
- [ ] 记录最终选择与 provenance。
- [ ] 编写 CLOSEOUT.md，并同步 STATE / ROADMAP。

## 验收

- 可播放成片呈现“有外部任务、低意愿可见、主体仍自主执行”。
- 不主要读作 slow、hesitant、refuse、dislike 或 eager。
- 所有进入下游的输入均是 manifest 绑定且通过人工 Gate 的同一文件。
- 失败版本与实验产物保留，不被新产物覆盖。

## 非目标

- 批量扩产；
- 通用资产注册表或依赖 DAG；
- 独立多 Agent Reviewer；
- legacy 场景批量迁移；
- 消费者应用开发。
