#!/usr/bin/env python3
"""SceneLex 本地审核工作台 — 文件库之上的无状态 Web 壳。

架构约束:
- 仓库文件是唯一权威; 本服务不落任何自己的数据。
- promote 一律 shell 到 tools/draft.py, 质量门只有一个。
- ``/api/*`` 是干净的 JSON 层, HTML 页面只是它的第一个消费者;
  将来的词典视图、渲染画廊或 SPA 岛都应复用同一层。

用法: python3 tools/workbench.py  (默认 http://127.0.0.1:8321)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any

import yaml
from fastapi import Body, FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
WEBUI = Path(__file__).resolve().parent / "webui"
SCENE_TYPES = ["prototype", "contrast", "counterexample", "boundary", "transfer"]
SCENE_TYPE_LABELS = {
    "prototype": "原型",
    "contrast": "对比",
    "counterexample": "反例",
    "boundary": "边界",
    "transfer": "迁移",
}

app = FastAPI(title="SceneLex Workbench")
app.mount("/static", StaticFiles(directory=WEBUI / "static"), name="static")
templates = Jinja2Templates(directory=WEBUI / "templates")
templates.env.globals.update(
    SCENE_TYPES=SCENE_TYPES, SCENE_TYPE_LABELS=SCENE_TYPE_LABELS
)


def _validator(name: str) -> Draft202012Validator:
    with open(ROOT / "schema" / name, encoding="utf-8") as file:
        return Draft202012Validator(json.load(file))


def _load_file(path: Path, validator: Draft202012Validator) -> dict[str, Any]:
    """读一个 YAML 资源文件, 返回文档 + 原文 + schema 问题。"""
    raw = path.read_text(encoding="utf-8")
    entry: dict[str, Any] = {
        "path": str(path.relative_to(ROOT)),
        "raw": raw,
        "doc": None,
        "errors": [],
    }
    try:
        doc = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        entry["errors"].append(f"YAML 解析失败: {exc}")
        return entry
    if not isinstance(doc, dict):
        entry["errors"].append("YAML 根节点必须是对象")
        return entry
    entry["doc"] = doc
    entry["errors"] = [
        "[" + ("/".join(str(p) for p in err.absolute_path) or "root") + "] "
        + err.message
        for err in validator.iter_errors(doc)
    ]
    return entry


def load_library() -> dict[str, Any]:
    """每次请求都重扫仓库——文件是权威, 工作台无状态。"""
    sense_validator = _validator("word-sense.schema.json")
    scene_validator = _validator("scene-spec.schema.json")

    senses: dict[str, dict[str, Any]] = {}
    scenes: dict[str, list[dict[str, Any]]] = defaultdict(list)

    for source, base in (("published", ROOT / "data"),
                         ("draft", ROOT / "data" / "drafts")):
        sense_dir = base / "senses"
        if sense_dir.exists():
            for path in sorted(sense_dir.glob("*.yaml")):
                entry = _load_file(path, sense_validator)
                entry["source"] = source
                senses[path.stem] = entry
        scene_root = base / "scenes"
        if scene_root.exists():
            for path in sorted(scene_root.glob("*/*.yaml")):
                entry = _load_file(path, scene_validator)
                entry["source"] = source
                scenes[path.parent.name].append(entry)

    board = []
    for sense_id in sorted(set(senses) | set(scenes)):
        counts: dict[str, dict[str, int]] = {
            t: {"published": 0, "draft": 0} for t in SCENE_TYPES
        }
        problems = 0
        for entry in scenes.get(sense_id, []):
            doc = entry["doc"] or {}
            stype = doc.get("scene_type")
            if stype in counts:
                counts[stype][entry["source"]] += 1
            problems += len(entry["errors"])
        sense_entry = senses.get(sense_id)
        sense_doc = (sense_entry or {}).get("doc") or {}
        board.append({
            "sense_id": sense_id,
            "word": sense_doc.get("word", sense_id.rsplit("-", 1)[0]),
            "definition": sense_doc.get("definition", ""),
            "sense_source": (sense_entry or {}).get("source"),
            "counts": counts,
            "total": sum(c["published"] + c["draft"] for c in counts.values()),
            "draft_scenes": sum(c["draft"] for c in counts.values()),
            "problems": problems + len((sense_entry or {}).get("errors", [])),
        })
    return {"senses": senses, "scenes": scenes, "board": board}


def _resolve_draft_path(rel_path: str) -> Path:
    """把请求路径解析到草稿区内, 拒绝一切越界。

    行内编辑只对 data/drafts/ 开放——正式库的修改必须走 git,
    工作台不为已发布资源提供写口。
    """
    drafts_root = (ROOT / "data" / "drafts").resolve()
    p = (ROOT / rel_path).resolve()
    if not p.is_relative_to(drafts_root):
        raise HTTPException(403, "只允许编辑 data/drafts/ 下的草稿")
    if p.suffix != ".yaml" or not p.is_file():
        raise HTTPException(404, f"草稿不存在: {rel_path}")
    return p


def _load_env_file() -> dict[str, str]:
    """解析仓库 .env (export KEY=VALUE), 供重起草子进程继承 LLM 配置。"""
    env: dict[str, str] = {}
    path = ROOT / ".env"
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        key, sep, value = line.partition("=")
        if sep:
            env[key.strip()] = value.strip().strip("'\"")
    return env


# 进行中的重起草任务: sense_id -> {proc, log, args}. 进程内状态,
# 服务重启即失——产物在文件里, 状态本身不值得持久化。
JOBS: dict[str, dict[str, Any]] = {}


def _job_status(sense_id: str) -> dict[str, Any] | None:
    job = JOBS.get(sense_id)
    if not job:
        return None
    code = job["proc"].poll()
    try:
        tail = Path(job["log"]).read_text(encoding="utf-8")[-800:]
    except OSError:
        tail = ""
    return {
        "sense_id": sense_id,
        "args": job["args"],
        "status": "running" if code is None
        else ("done" if code == 0 else "failed"),
        "tail": tail,
    }


# ------------------------------------------------------------------ JSON API

@app.get("/api/library")
def api_library() -> dict[str, Any]:
    lib = load_library()
    return {"board": lib["board"]}


@app.get("/api/senses/{sense_id}")
def api_sense(sense_id: str) -> dict[str, Any]:
    lib = load_library()
    if sense_id not in lib["senses"] and sense_id not in lib["scenes"]:
        raise HTTPException(404, f"未知义项 {sense_id}")
    return {
        "sense": lib["senses"].get(sense_id),
        "scenes": lib["scenes"].get(sense_id, []),
    }


@app.get("/api/file")
def api_file_read(path: str) -> dict[str, Any]:
    return {"path": path, "content": _resolve_draft_path(path).read_text(encoding="utf-8")}


@app.post("/api/file")
def api_file_save(payload: dict = Body(...)) -> dict[str, Any]:
    """保存草稿并即时反馈校验结果; schema 问题不阻止保存 (promote 才是门)。"""
    p = _resolve_draft_path(str(payload.get("path", "")))
    content = payload.get("content")
    if not isinstance(content, str) or not content.strip():
        raise HTTPException(400, "内容不能为空")
    p.write_text(content if content.endswith("\n") else content + "\n",
                 encoding="utf-8")
    issues: list[str] = []
    try:
        doc = yaml.safe_load(content)
    except yaml.YAMLError as exc:
        return {"ok": True, "issues": [f"YAML 解析失败: {exc}"]}
    if isinstance(doc, dict):
        schema = ("word-sense.schema.json" if "senses" in p.parts
                  else "scene-spec.schema.json")
        issues = [
            "[" + ("/".join(str(x) for x in e.absolute_path) or "root") + "] "
            + e.message
            for e in _validator(schema).iter_errors(doc)
        ]
    else:
        issues = ["YAML 根节点必须是对象"]
    return {"ok": True, "issues": issues}


@app.post("/api/redraft/{sense_id}")
def api_redraft(sense_id: str, payload: dict = Body(default={})) -> dict[str, Any]:
    """后台重起草整组或增补单场景 (LLM 调用可达十几分钟, 不能同步等)。"""
    status = _job_status(sense_id)
    if status and status["status"] == "running":
        raise HTTPException(409, f"{sense_id} 已有生成任务在运行")
    args = ["scenes", sense_id]
    add_type = payload.get("add")
    if add_type:
        if add_type not in SCENE_TYPES:
            raise HTTPException(400, f"未知场景类型 {add_type}")
        args += ["--add", add_type]
    log = tempfile.NamedTemporaryFile(
        prefix=f"scenelex-{sense_id}-", suffix=".log", delete=False
    )
    env = {**os.environ, **_load_env_file()}
    proc = subprocess.Popen(
        [sys.executable, str(ROOT / "tools" / "draft.py"), *args],
        stdout=log, stderr=subprocess.STDOUT, env=env, cwd=ROOT,
    )
    JOBS[sense_id] = {"proc": proc, "log": log.name, "args": args}
    return {"sense_id": sense_id, "status": "running", "args": args}


@app.get("/api/jobs")
def api_jobs() -> dict[str, Any]:
    return {
        "jobs": [s for s in (_job_status(sid) for sid in list(JOBS)) if s]
    }


# 单次生成上限。词典事实锚定已上线, 但"批量全部"仍需人工分批放行——
# 一个词全场景 ≈ 14 分钟, 50 词 ≈ 12 小时, 误触全选不该烧掉几天的 API 配额。
GENERATE_MAX = 50


@app.post("/api/generate")
def api_generate(payload: dict = Body(...)) -> dict[str, Any]:
    """从候选队列选词批量生成 (后台 draft.py batch)。"""
    words = payload.get("words")
    if not isinstance(words, list) or not words:
        raise HTTPException(400, "words 必须是非空列表")
    if len(words) > GENERATE_MAX:
        raise HTTPException(
            400, f"单次最多 {GENERATE_MAX} 个词 (收到 {len(words)})"
        )
    import re as _re
    for w in words:
        if not isinstance(w, str) or not _re.fullmatch(r"[a-z][a-z_]*", w):
            raise HTTPException(400, f"非法单词: {w!r}")
    status = _job_status("_batch")
    if status and status["status"] == "running":
        raise HTTPException(409, "已有批量生成任务在运行")
    args = ["batch", *words]
    if payload.get("senses_only"):
        args.append("--senses-only")
    log = tempfile.NamedTemporaryFile(
        prefix="scenelex-batch-", suffix=".log", delete=False
    )
    env = {**os.environ, **_load_env_file()}
    proc = subprocess.Popen(
        [sys.executable, str(ROOT / "tools" / "draft.py"), *args],
        stdout=log, stderr=subprocess.STDOUT, env=env, cwd=ROOT,
    )
    JOBS["_batch"] = {"proc": proc, "log": log.name, "args": args}
    return {"status": "running", "words": words}


@app.post("/api/promote/{sense_id}")
def api_promote(sense_id: str) -> dict[str, Any]:
    """质量门唯一入口: shell 到 draft.py promote。"""
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "draft.py"), "promote", sense_id],
        capture_output=True, text=True, timeout=300,
    )
    return {
        "sense_id": sense_id,
        "ok": result.returncode == 0,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


# ------------------------------------------------------------------ Pages

@app.get("/", response_class=HTMLResponse)
def page_index(request: Request):
    lib = load_library()
    drafts = [row for row in lib["board"]
              if row["draft_scenes"] or (row["sense_source"] == "draft")]
    return templates.TemplateResponse(request, "index.html", {
        "board": lib["board"], "drafts": drafts,
    })


CANDIDATES_PER_PAGE = 1000


@app.get("/candidates", response_class=HTMLResponse)
def page_candidates(request: Request, page: int = 1, q: str = ""):
    import candidates
    queue = candidates.build_queue(None)
    query = q.strip().lower()
    if query:
        queue = [item for item in queue if query in item["word"]]
    total = len(queue)
    pages = max(1, -(-total // CANDIDATES_PER_PAGE))
    page = min(max(1, page), pages)
    start = (page - 1) * CANDIDATES_PER_PAGE
    return templates.TemplateResponse(request, "candidates.html", {
        "queue": queue[start:start + CANDIDATES_PER_PAGE],
        "batch_job": _job_status("_batch"),
        "page": page, "pages": pages, "total": total,
        "start": start, "q": q,
        "generate_max": GENERATE_MAX,
    })


@app.get("/senses/{sense_id}", response_class=HTMLResponse)
def page_sense(request: Request, sense_id: str,
               promoted: str | None = None):
    lib = load_library()
    if sense_id not in lib["senses"] and sense_id not in lib["scenes"]:
        raise HTTPException(404, f"未知义项 {sense_id}")
    scenes = lib["scenes"].get(sense_id, [])
    by_type: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entry in scenes:
        by_type[(entry["doc"] or {}).get("scene_type", "?")].append(entry)
    has_draft = any(e["source"] == "draft" for e in scenes)
    sense_entry = lib["senses"].get(sense_id)
    if sense_entry and sense_entry["source"] == "draft":
        has_draft = True
    return templates.TemplateResponse(request, "sense.html", {
        "sense_id": sense_id,
        "sense": sense_entry,
        "by_type": by_type,
        "has_draft": has_draft,
        "has_published_scenes": any(
            e["source"] == "published" for e in scenes
        ),
        "job": _job_status(sense_id),
    })


def main() -> None:
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8321)


if __name__ == "__main__":
    main()
