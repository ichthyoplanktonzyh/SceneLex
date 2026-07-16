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
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

import yaml
from fastapi import FastAPI, HTTPException, Request
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
    })


def main() -> None:
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8321)


if __name__ == "__main__":
    main()
