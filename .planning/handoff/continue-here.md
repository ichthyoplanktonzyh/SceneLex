# Continue Here — 会话交接

> 最后更新：2026-07-18
> 新会话启动时从这里开始。

## 启动顺序

1. **AGENT.md** — 仓库工作约束、核心原则、架构边界。
2. **.planning/STATE.md** — 当前在哪、下一步干什么、最近决策。
3. **.planning/codebase/ARCHITECTURE.md** — 系统结构、数据流、关键边界。
4. **.planning/codebase/DATA-MODEL.md** — Schema 版本、ID 规则、内容不变量。
5. **.planning/ROADMAP.md** — 里程碑与 phase 路线图。

按需深入：
- `.planning/codebase/CONVENTIONS.md` — 命名、格式、工作流约定。
- `schema/` — 数据契约的具体字段定义。
- `data/` — 实际资源文件。
- `.planning/discuss/` — 方向性讨论文档。

## 当前状态摘要 (2026-07-18)

**主线**：Phase 1.3 渲染管线 — 场景 → 皮克斯 3D 短视频（详见 `phases/1.3-render-pipeline/`）。
**副线**：语义资源扩产（草稿区 6 义项在产）。

**框架变化**：学习对照实验已退役（决策 2026-07-17，`docs/mvp-evaluation.md` 归档）；
纵向切片终点改为"渲染成皮克斯短视频"；审核由模型承担。

**已就绪**：
- Schema 三件套 v1.0；语义工具链（draft/validate/export/llm 四协议 + 扩产工具）。
- 正式库 4 义项 / 21 场景（reviewed）；草稿区 6 新义项。
- 渲染层雏形：render.py / imagegen.py / render 相关 schema 与 prompts / emotion-to-visual skill。
- 本地已验证：皮克斯风(Disney SDXL)、卡通脸一致性(IPAdapter PLUS)、Wan2.2-5B M1 可行。

**待推进（渲染管线）**：
- [2] 关键帧身份/姿势解耦（IPAdapter+ControlNet，头号阻塞）。
- [0] 导演 IR 契约（扩 render-plan schema + 接 skill 库）。
- [3][4] Wan i2v 运动提示词规范 + ffmpeg/F5-TTS 组装。
- 端到端第一条 reluctant 皮克斯短片。

**待推进（语义副线）**：草稿区 6 义项模型审核 promote。

## 常用命令

```bash
source .venv/bin/activate

# 工具链
python3 tools/draft.py backlog
python3 tools/draft.py list
python3 tools/draft.py sense {word}
python3 tools/draft.py scenes {sense_id}
python3 tools/draft.py promote {sense_id}

# 校验与测试
python3 tools/validate.py --backlog
python3 -m pytest -q

# 导出
python3 tools/export.py --version {ver} --output dist/scenelex-{ver}.json
```
