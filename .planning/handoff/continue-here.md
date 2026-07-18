# Continue Here — 会话交接

> 最后更新：2026-07-18

## 启动顺序

1. `AGENT.md`
2. `.planning/STATE.md`
3. `docs/production-workflow.md`
4. `.planning/phases/1.3-render-pipeline/PLAN.md`
5. `.planning/codebase/ARCHITECTURE.md`

## 当前主线

```text
WordSense + SceneSpec
→ Director Agent
→ model-adapted video prompt
→ video model
→ Director查看并修正
```

Director是核心中间层。它默认直接T2V；参考图、关键图、首尾帧、拆片和animatic都按实际失败使用，不是固定流程。

现有WordSense与SceneSpec已经能正确表达词义，Director不得改写内容。渲染层全局视觉方向是Pixar-style 3D动画，由`prompts/render-style.yaml`注入。

## 已完成

- Director Schema、prompt模板、两个capability profiles。
- `tools/director.py generate/show/list`。
- Director独立测试6项通过。
- 本地ComfyUI已具备SDXL、IPAdapter和Wan 2.2 TI2V 5B。

## 下一步

```bash
python3 tools/director.py generate reluctant-01-proto-01 --profile wan2.2-ti2v-5b
python3 tools/director.py show reluctant-01-proto-01
```

需要先配置`SCENELEX_LLM_*`。取得真实Director Prompt后，尽早提交视频模型，不先增加复杂流程。随后让Director根据视频输出`pass/retry + problem + revision`。

## 注意

- 旧`render-plan`/`render.py`是逐beat文生图原型，暂未迁移。
- `render-style.yaml`已改为Pixar-style 3D，并同时供Director和旧render流程使用。
- 用户未追踪的`data/drafts/renders/reluctant-01-proto-01/v05/`测试产物保持不动。

## 校验

```bash
python3 tools/validate.py --backlog
python3 -m pytest -q
git status --short
```
