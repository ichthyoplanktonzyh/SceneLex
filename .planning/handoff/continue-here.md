# Continue Here — 会话交接

> 最后更新：2026-07-16
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

## 当前状态摘要 (2026-07-16)

**主线**：M1 可验证的纵向实验切片。

**已就绪**：
- Schema 三件套 v1.0。
- 工具链（draft / validate / export / llm）可用。
- 3 条正式义项 + 10 条正式场景（均为 reviewed）。
- LLM 适配器支持四协议。
- MVP 实验方案已定稿。

**待推进**：
- `almost-01` 的五类场景证据。
- `dirty-01` 审核 promote。
- 扩展 3–5 个新义项。
- 制作实验材料并运行对照实验。

**非目标**：不扩到 30–50 义项（等 M1 实验通过），不追求影视品质渲染（先用低成本验证语义设计）。

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
