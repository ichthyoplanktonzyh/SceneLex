# SceneLex — 路线图

> 最后更新：2026-07-24
> 当前里程碑：M1 `reluctant` 首个媒体纵向切片

## 路线概览

```text
M0 核心语义基础设施（完成）
→ M1 首个可播放、可追溯、语义正确的纵向切片（当前）
→ M2 跨语义类型泛化
→ M3 规模化生产与消费者集成
```

## M0：核心语义基础设施 ✅

- [x] WordSense / SceneSpec / ResourceBundle Schema。
- [x] Dictionary Evidence → Sense Inventory → WordSense 的身份链。
- [x] LLM 起草、多协议适配、确定性校验、可选审核。
- [x] 原子 promote、正式库验证、确定性导出、审核工作台。
- [x] 正式库 4 个义项、21 个场景。

## M1：`reluctant` 媒体纵向切片 ⏳

目标：完成
`WordSense → SceneSpec → Shot Plan → Keyframe Plan → Images → Video → Final`
的第一个可追溯实例，并证明画面呈现的是 reluctant，而不是 slow、hesitant、
refuse、dislike 或 eager。

### M1.1 语义到镜头 ✅

- [x] `reluctant` approved Inventory、WordSense 1.1、SceneSpec 1.1。
- [x] Shot Plan Schema 与版本绑定。
- [x] Shot Plan v04 → Animatic 反馈 → Shot Plan v05。
- [x] Keyframe Plan v02 与 Animatic v02 通过。

### M1.2 图片执行链 ⏳ ← 当前焦点

- [x] 生成第一批 9 张关键图并由语义门判定 revision required。
- [x] 建立 Source Packet、Render Directive、Visual Compiler Validator。
- [x] 4 个诊断状态编译为已验证 Render Directive。
- [x] 建立 Wan 2.7 状态编辑适配器与 VLM advisory review。
- [ ] 为 4 个诊断 target 生成 manifest 绑定的候选。
- [ ] 完成人工图片语义审核。
- [ ] 达到 `api_gate: pass` + `semantic_gate: pass`。

### M1.3 视频运动与成片 🔒

- [ ] 定义最小 Motion Directive / Video Run 记录。
- [ ] 把 3 个 Shot 映射为一个或多个 Motion Segment，不按模型调用重写 Shot。
- [ ] 选择云端 I2V 能力并使用通过图片门的输入生成候选。
- [ ] 完成人工视频语义门：动作阶段、停顿、速度、边界与跨镜连续性。
- [ ] 最小硬切拼接、音频与目标声音时序。
- [ ] 保存模型、输入版本、请求、候选、选择与审核 provenance。

### M1 退出条件

- 至少一个 `reluctant-01-proto-01` 可播放成片。
- 明确外部任务、可见低意愿、主体仍自主执行。
- 不主要读作 slow、hesitant、refuse、dislike 或 eager。
- 每层输入、输出、版本、模型和人工 Gate 可追溯。
- 失败历史保留，不覆盖、不冒充已通过产物。

## M2：跨语义类型泛化 🔒

- 用 `messy` 验证静态关系型意义。
- 用 `almost` 验证终止点与程度边界。
- 比较不同语义类型的 Shot / Keyframe / Motion 需求。
- 只把重复出现的失败模式沉淀为稳定自动化。

## M3：规模化生产与消费者集成 🔒

- 扩展 approved Inventory 与正式义项覆盖；
- 批量媒体生产、预算与失败恢复；
- 可追溯发布资源包；
- 播放器、词典、课程或 API 的最小消费者集成。
