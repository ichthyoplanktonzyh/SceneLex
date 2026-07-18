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


# 进行中的后台任务 (重起草/批量/审核): job_key -> {proc, log, args, sense_id}.
# 进程内状态, 服务重启即失——产物在文件里, 状态本身不值得持久化。
JOBS: dict[str, dict[str, Any]] = {}


def _job_status(job_key: str) -> dict[str, Any] | None:
    job = JOBS.get(job_key)
    if not job:
        return None
    code = job["proc"].poll()
    try:
        tail = Path(job["log"]).read_text(encoding="utf-8")[-800:]
    except OSError:
        tail = ""
    return {
        "sense_id": job.get("sense_id", job_key),
        "args": job["args"],
        "status": "running" if code is None
        else ("done" if code == 0 else "failed"),
        "tail": tail,
    }


def _sense_busy(sense_id: str) -> bool:
    """同一义项的生成与审核任务互斥, 避免审核到一半的文件被改写。"""
    for key in (sense_id, f"review:{sense_id}"):
        status = _job_status(key)
        if status and status["status"] == "running":
            return True
    return False


def _draft_review_files(sense_id: str) -> list[Path]:
    """与 review.py 的审核对象一致: 词义草稿 + 场景草稿 (忽略 _unparsed)。"""
    files = []
    sense = ROOT / "data" / "drafts" / "senses" / f"{sense_id}.yaml"
    if sense.exists():
        files.append(sense)
    scene_dir = ROOT / "data" / "drafts" / "scenes" / sense_id
    if scene_dir.exists():
        files += [p for p in sorted(scene_dir.glob("*.yaml"))
                  if not p.name.startswith("_")]
    return files


def _load_review(sense_id: str) -> dict[str, Any] | None:
    """读取审核记录并标注时效性。审核是可选参考, 不参与门禁。"""
    import review
    path = review.record_path(sense_id)
    if not path.exists():
        return None
    try:
        record = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None
    if not isinstance(record, dict):
        return None
    files = _draft_review_files(sense_id)
    record["fresh"] = bool(files) and \
        record.get("content_digest") == review.content_digest(files)
    record["path"] = str(path.relative_to(ROOT))
    return record


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
    if _sense_busy(sense_id):
        raise HTTPException(409, f"{sense_id} 已有任务在运行")
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


def _load_batch_state() -> dict[str, Any]:
    """draft.py batch 的断点状态 (每阶段完成即落盘, 全部成功后自清理)。"""
    path = ROOT / "data" / "drafts" / "batch-state.json"
    if not path.exists():
        return {}
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
        return state if isinstance(state, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _teachable_total(word: str, entry: dict[str, Any]) -> int:
    """离线取该词义项总数: 词典缓存优先, 无缓存时用状态里已枚举的键。"""
    try:
        import dictionary
        if dictionary._cache_path(word).exists():
            n = len(dictionary.teachable_senses(word))
            if n:
                return n
    except Exception:
        pass
    keys = set(entry.get("senses", {})) | set(entry.get("scenes", {}))
    return max(len(keys), 1)


@app.get("/api/batch/progress")
def api_batch_progress() -> dict[str, Any]:
    """批量生成进度: 任务状态 + batch-state.json 的逐义项阶段结果。"""
    job = _job_status("_batch")
    state = _load_batch_state()
    running = bool(job and job["status"] == "running")
    senses_only = bool(job and "--senses-only" in job["args"])

    words: list[str] = []
    if job:
        words = [a for a in job["args"][1:] if not a.startswith("--")]
    for w in state:
        if w not in words:
            words.append(w)

    rows = []
    done_stages = total_stages = 0
    stages_per_sense = 1 if senses_only else 2
    for word in words:
        entry = state.get(word, {})
        senses = entry.get("senses", {})
        scenes = entry.get("scenes", {})
        nums = [f"{i:02d}" for i in range(1, _teachable_total(word, entry) + 1)]
        srow = []
        for num in nums:
            s, sc = senses.get(num), scenes.get(num)
            if s == "failed" or sc == "failed":
                status = "failed"
            elif s == "done" and (sc == "done" or senses_only):
                status = "done"
            elif s == "done":
                status = "scenes"
            else:
                status = "sense"
            srow.append({"num": num, "status": status})
            total_stages += stages_per_sense
            done_stages += (1 if s == "done" else 0) \
                + (0 if senses_only else (1 if sc == "done" else 0))
        rows.append({"word": word, "senses": srow})

    return {
        "job": job, "running": running, "senses_only": senses_only,
        "words": rows, "done_stages": done_stages,
        "total_stages": total_stages,
        "percent": round(100 * done_stages / total_stages)
        if total_stages else 0,
    }


@app.get("/api/review/{sense_id}")
def api_review_get(sense_id: str) -> dict[str, Any]:
    """已有审核记录 (含时效性标注); 无记录时 record 为 null。"""
    return {"sense_id": sense_id, "record": _load_review(sense_id)}


@app.post("/api/review/{sense_id}")
def api_review_run(sense_id: str) -> dict[str, Any]:
    """后台运行模型审核 (可选质量参考, 不阻塞 promote)。"""
    import re as _re
    if not _re.fullmatch(r"[a-z][a-z_]*-\d{2}", sense_id):
        raise HTTPException(400, f"非法义项 ID: {sense_id}")
    if _sense_busy(sense_id):
        raise HTTPException(409, f"{sense_id} 已有任务在运行")
    if not _draft_review_files(sense_id):
        raise HTTPException(400, f"{sense_id} 没有待审草稿")
    log = tempfile.NamedTemporaryFile(
        prefix=f"scenelex-review-{sense_id}-", suffix=".log", delete=False
    )
    env = {**os.environ, **_load_env_file()}
    proc = subprocess.Popen(
        [sys.executable, str(ROOT / "tools" / "review.py"), sense_id],
        stdout=log, stderr=subprocess.STDOUT, env=env, cwd=ROOT,
    )
    JOBS[f"review:{sense_id}"] = {
        "proc": proc, "log": log.name,
        "args": ["review", sense_id], "sense_id": sense_id,
    }
    return {"sense_id": sense_id, "status": "running"}


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


# ------------------------------------------------------------------ Dictionary API

def _build_dict_word(word: str, senses: dict, scenes: dict) -> dict[str, Any] | None:
    """构建一个词的词典摘要（来自 load_library 的数据）。"""
    word_senses = []
    for sense_id, entry in sorted(senses.items()):
        doc = entry.get("doc") or {}
        if doc.get("word") != word:
            continue
        scene_list = scenes.get(sense_id, [])
        stypes = {}
        for sc in scene_list:
            sc_doc = sc.get("doc") or {}
            t = sc_doc.get("scene_type", "")
            if t:
                stypes.setdefault(t, 0)
                stypes[t] += 1
        word_senses.append({
            "id": sense_id,
            "sense_label": doc.get("sense_label", ""),
            "definition": doc.get("definition", ""),
            "pos": doc.get("pos", ""),
            "status": doc.get("status", "draft"),
            "source": entry.get("source"),
            "scene_count": len(scene_list),
            "scene_types": stypes,
            "problems": len(entry.get("errors", []))
                       + sum(len(s.get("errors", [])) for s in scene_list),
        })
    # 可能有场景文件但无词义文档的义项
    for sense_id, scene_list in sorted(scenes.items()):
        if any(s["id"] == sense_id for s in word_senses):
            continue
        if not sense_id.startswith(f"{word}-"):
            continue
        stypes = {}
        for sc in scene_list:
            sc_doc = sc.get("doc") or {}
            t = sc_doc.get("scene_type", "")
            if t:
                stypes.setdefault(t, 0)
                stypes[t] += 1
        word_senses.append({
            "id": sense_id,
            "sense_label": "",
            "definition": "",
            "pos": "",
            "status": "draft",
            "source": max((s.get("source") for s in scene_list), default="draft"),
            "scene_count": len(scene_list),
            "scene_types": stypes,
            "problems": sum(len(s.get("errors", [])) for s in scene_list),
        })

    if not word_senses:
        return None

    # 聚合
    all_pos = sorted(set(s["pos"] for s in word_senses if s["pos"]))
    return {
        "word": word,
        "pos": all_pos,
        "sense_count": len(word_senses),
        "scene_count": sum(s["scene_count"] for s in word_senses),
        "senses": word_senses,
    }


@app.get("/api/dict")
def api_dict() -> dict[str, Any]:
    """按词聚合的词典摘要。"""
    lib = load_library()
    senses = lib["senses"]
    scenes = lib["scenes"]

    words_map: dict[str, dict[str, Any]] = {}
    for sense_id, entry in senses.items():
        doc = entry.get("doc") or {}
        word = doc.get("word", sense_id.rsplit("-", 1)[0])
        if word not in words_map:
            words_map[word] = _build_dict_word(word, senses, scenes)
    # 只有场景没有词义的词
    for sense_id in scenes:
        word = sense_id.rsplit("-", 1)[0]
        if word not in words_map:
            words_map[word] = _build_dict_word(word, senses, scenes)

    words = sorted(
        (w for w in words_map.values() if w),
        key=lambda w: w["word"],
    )
    # 附加可教学义项数
    for w in words:
        try:
            import dictionary
            w["teachable_sense_count"] = dictionary.sense_count(w["word"])
        except Exception:
            w["teachable_sense_count"] = w["sense_count"]
    return {"words": words, "total": len(words)}


@app.get("/api/dict/{word}")
def api_dict_word(word: str) -> dict[str, Any]:
    """单个词的完整词典条目。"""
    lib = load_library()
    entry = _build_dict_word(word.strip().lower(), lib["senses"], lib["scenes"])
    if not entry:
        raise HTTPException(404, f"'{word}' 尚无义项")
    # 可教学义项数
    try:
        import dictionary
        entry["teachable_sense_count"] = dictionary.sense_count(entry["word"])
    except Exception:
        entry["teachable_sense_count"] = entry["sense_count"]
    # 为 senses 附加场景详情
    for s in entry["senses"]:
        s["scenes"] = [
            {
                "id": (sc.get("doc") or {}).get("id", ""),
                "scene_type": (sc.get("doc") or {}).get("scene_type", ""),
                "title": (sc.get("doc") or {}).get("title", ""),
                "synopsis": (sc.get("doc") or {}).get("synopsis", ""),
                "status": (sc.get("doc") or {}).get("status", ""),
                "source": sc.get("source"),
                "errors": sc.get("errors", []),
                "path": sc.get("path", ""),
            }
            for sc in lib["scenes"].get(s["id"], [])
        ]
    return entry


# ------------------------------------------------------------------ Pages

@app.get("/", response_class=HTMLResponse)
def page_index(request: Request):
    lib = load_library()
    drafts = [row for row in lib["board"]
              if row["draft_scenes"] or (row["sense_source"] == "draft")]
    for row in drafts:
        record = _load_review(row["sense_id"])
        row["review"] = None if not record else {
            "verdict": record.get("verdict"),
            "fresh": record.get("fresh"),
        }
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
    jobs = [_job_status(sense_id), _job_status(f"review:{sense_id}")]
    job = next((j for j in jobs if j and j["status"] == "running"), None) \
        or next((j for j in jobs if j), None)
    return templates.TemplateResponse(request, "sense.html", {
        "sense_id": sense_id,
        "sense": sense_entry,
        "by_type": by_type,
        "has_draft": has_draft,
        "has_published_scenes": any(
            e["source"] == "published" for e in scenes
        ),
        "job": job,
        "review": _load_review(sense_id) if has_draft else None,
    })


@app.get("/dictionary", response_class=HTMLResponse)
def page_dictionary(request: Request):
    return templates.TemplateResponse(request, "dictionary.html", {})


@app.get("/words/{word}", response_class=HTMLResponse)
def page_word(request: Request, word: str):
    return templates.TemplateResponse(request, "word.html", {"word": word.strip().lower()})


@app.post("/api/dict/{word}/generate")
async def api_dict_generate(word: str):
    """触发该词的批量生成。"""
    import subprocess, sys
    cmd = [sys.executable, "-m", "tools.draft", "batch", word.strip().lower(),
           "--concurrency", "4", "--retries", "2", "--sleep", "1"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        return {
            "ok": proc.returncode == 0,
            "stdout": proc.stdout[-2000:],
            "stderr": proc.stderr[-2000:],
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "stdout": "", "stderr": "生成超时（> 10 分钟）"}


def main() -> None:
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8321)


if __name__ == "__main__":
    main()
