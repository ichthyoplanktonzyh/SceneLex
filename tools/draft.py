#!/usr/bin/env python3
"""SceneLex 内容起草工具 — 管线的第 2、3 阶段。

把 LLM 从"作者"降为"打字员", 把人从"作者"升为"编辑"。
调用哪个模型由 tools/llm.py 决定 (模型无关)。

用法:
    python3 tools/draft.py sense <word>        # 起草词义 → data/drafts/senses/
    python3 tools/draft.py scenes <sense_id>   # 起草五场景组 → data/drafts/scenes/
    python3 tools/draft.py list                # 列出待审草稿
    python3 tools/draft.py promote <id>        # 草稿定稿 → data/ 并跑全量校验
    python3 tools/draft.py backlog             # 转发 validate.py --backlog 选词

草稿一律落在 data/drafts/, 与正式库隔离; 人工审阅后再 promote。
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

import llm

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "tools" / ".." / "prompts"
DRAFTS = ROOT / "data" / "drafts"
SENSE_ID = re.compile(r"^[a-z][a-z_]*-\d{2}$")

# 用作 few-shot 的现有范例
SENSE_EXAMPLES = ["messy-01", "reluctant-01"]
SCENE_EXAMPLE_SENSE = "reluctant-01"

SCENE_ORDER = ["prototype", "contrast", "counterexample", "boundary", "transfer"]
SCENE_ABBR = {"prototype": "proto", "contrast": "contrast",
              "counterexample": "counter", "boundary": "boundary",
              "transfer": "transfer"}


def read(path):
    return path.read_text(encoding="utf-8")


def load_schema(name):
    return Draft202012Validator(json.loads(read(ROOT / "schema" / name)))


def extract_yaml_blocks(text):
    """抽取 ```yaml ... ``` 代码块; 无围栏时把整段当作单块。"""
    blocks = re.findall(r"```ya?ml\s*\n(.*?)```", text, re.DOTALL)
    if not blocks:
        stripped = text.strip()
        if stripped:
            blocks = [stripped]
    return [b.strip() for b in blocks]


def schema_check(doc, validator, label):
    errs = []
    for err in validator.iter_errors(doc):
        loc = "/".join(str(p) for p in err.absolute_path) or "(root)"
        errs.append(f"  ✗ {label} [{loc}] {err.message}")
    return errs


def resolve_sense_path(sense_id):
    """先找正式库, 再找草稿库。"""
    for base in (ROOT / "data" / "senses", DRAFTS / "senses"):
        p = base / f"{sense_id}.yaml"
        if p.exists():
            return p
    return None


def existing_scenes(sense_id, scene_type=None):
    """收集正式库与草稿库中该义项的场景文件, 可按类型过滤。"""
    abbr = SCENE_ABBR.get(scene_type) if scene_type else None
    pattern = re.compile(
        rf"^{re.escape(sense_id)}-({abbr or '[a-z]+'})-(\d{{2}})$"
    )
    found = []
    for base in (ROOT / "data" / "scenes" / sense_id,
                 DRAFTS / "scenes" / sense_id):
        if not base.exists():
            continue
        for p in sorted(base.glob("*.yaml")):
            if pattern.fullmatch(p.stem):
                found.append(p)
    return found


def next_scene_id(sense_id, scene_type):
    """按正式库+草稿库中已占用的序号, 生成该类型的下一个场景 ID。"""
    abbr = SCENE_ABBR[scene_type]
    taken = [int(p.stem.rsplit("-", 1)[1])
             for p in existing_scenes(sense_id, scene_type)]
    return f"{sense_id}-{abbr}-{max(taken, default=0) + 1:02d}"


# ---------------------------------------------------------------- sense

def cmd_sense(args):
    word = args.word.strip().lower()
    if not re.match(r"^[a-z][a-z_]*$", word):
        sys.exit(f"单词 '{word}' 含非法字符 (只允许小写字母和下划线)")
    sense_num = getattr(args, "num", "01")

    template = read(PROMPTS / "sense-draft.md")
    schema = read(ROOT / "schema" / "word-sense.schema.json")
    ex1 = read(ROOT / "data" / "senses" / f"{SENSE_EXAMPLES[0]}.yaml")
    ex2 = read(ROOT / "data" / "senses" / f"{SENSE_EXAMPLES[1]}.yaml")
    import dictionary
    print(f"→ 获取 '{word}' 的词典事实 ...", file=sys.stderr)
    dict_block = dictionary.prompt_block(word, sense_num)
    total = dictionary.sense_count(word)
    prompt = (template
              .replace("{{SCHEMA}}", schema)
              .replace("{{EXAMPLE_1}}", ex1)
              .replace("{{EXAMPLE_2}}", ex2)
              .replace("{{DICTIONARY}}", dict_block)
              .replace("{{WORD}}", word)
              .replace("{{SENSE_NUM}}", sense_num)
              .replace("{{TOTAL_SENSES}}", str(total)))

    print(f"→ 起草词义 '{word}-{sense_num}' ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")

    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as e:
        out = DRAFTS / "senses" / f"{word}-{sense_num}.yaml"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(blocks[0], encoding="utf-8")
        sys.exit(f"YAML 解析失败, 原文已存 {out.relative_to(ROOT)} 供修复:\n{e}")
    if not isinstance(doc, dict):
        sys.exit("词义草稿的 YAML 根节点必须是对象")

    # The requested ID determines the path. Model output is untrusted content
    # and must never be able to choose a filesystem path.
    expected_id = f"{word}-{sense_num}"
    out = DRAFTS / "senses" / f"{expected_id}.yaml"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(blocks[0].rstrip() + "\n", encoding="utf-8")
    print(f"✓ 草稿已写入 {out.relative_to(ROOT)}")

    errs = schema_check(doc, load_schema("word-sense.schema.json"), out.name)
    if doc.get("id") != expected_id:
        errs.append(f"  ✗ {out.name} id 必须是 '{expected_id}'")
    _report(errs, out)


# ---------------------------------------------------------------- scenes

def cmd_scenes(args):
    sense_id = args.sense_id.strip()
    if not SENSE_ID.match(sense_id):
        sys.exit(f"义项 ID '{sense_id}' 不符合 {{word}}-{{nn}} 约定")
    sense_path = resolve_sense_path(sense_id)
    if not sense_path:
        sys.exit(f"找不到义项 '{sense_id}' (data/senses/ 和 data/drafts/senses/ 均无)")

    if args.add:
        return _scenes_add(sense_id, sense_path, args.add)

    template = read(PROMPTS / "scene-draft.md")
    schema = read(ROOT / "schema" / "scene-spec.schema.json")
    sense_yaml = read(sense_path)

    ex_dir = ROOT / "data" / "scenes" / SCENE_EXAMPLE_SENSE
    examples = "\n\n".join(
        f"```yaml\n{read(p)}```"
        for p in sorted(ex_dir.glob("*.yaml"))) if ex_dir.exists() else ""

    prompt = (template
              .replace("{{SCHEMA}}", schema)
              .replace("{{SENSE}}", sense_yaml)
              .replace("{{EXAMPLES}}", examples)
              .replace("{{SENSE_ID}}", sense_id))

    print(f"→ 起草 '{sense_id}' 五场景组 ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")

    out_dir = DRAFTS / "scenes" / sense_id
    out_dir.mkdir(parents=True, exist_ok=True)
    validator = load_schema("scene-spec.schema.json")
    all_errs = []
    written = []
    for i, block in enumerate(blocks):
        try:
            doc = yaml.safe_load(block)
        except yaml.YAMLError as e:
            fname = out_dir / f"_unparsed-{i + 1}.yaml"
            fname.write_text(block, encoding="utf-8")
            all_errs.append(f"  ✗ 第 {i + 1} 块 YAML 解析失败: {e} (原文存 {fname.name})")
            continue
        if not isinstance(doc, dict):
            all_errs.append(f"  ✗ 第 {i + 1} 块 YAML 根节点必须是对象")
            continue
        scene_type = doc.get("scene_type", "")
        abbr = SCENE_ABBR.get(scene_type, f"blk{i + 1}")
        expected_id = f"{sense_id}-{abbr}-01"
        raw_id = doc.get("id")
        sid = raw_id if isinstance(raw_id, str) and re.fullmatch(
            r"[a-z][a-z_]*-\d{2}-(?:proto|contrast|counter|boundary|transfer)-\d{2}",
            raw_id,
        ) else expected_id
        fname = out_dir / f"{sid}.yaml"
        if fname in written:
            all_errs.append(f"  ✗ 第 {i + 1} 块与前一场景使用了重复 id '{sid}'")
            continue
        fname.write_text(block.rstrip() + "\n", encoding="utf-8")
        written.append(fname)
        all_errs += schema_check(doc, validator, fname.name)
        if raw_id != expected_id:
            all_errs.append(
                f"  ✗ {fname.name} id 必须是 '{expected_id}'"
            )

    print(f"✓ 写入 {len(written)} 个场景草稿 → {out_dir.relative_to(ROOT)}")
    got = {yaml.safe_load(read(p)).get("scene_type") for p in written}
    missing = [t for t in SCENE_ORDER if t not in got]
    if missing:
        print(f"⚠ 缺少场景类型: {', '.join(missing)}")
    _report(all_errs, out_dir)


def _scenes_add(sense_id, sense_path, scene_type):
    """为已有义项增补一个指定类型的场景 (泛化扩证据)。"""
    peers = existing_scenes(sense_id, scene_type)
    if not peers:
        print(f"⚠ '{sense_id}' 尚无 {scene_type} 场景, 建议先起草完整五场景组",
              file=sys.stderr)
    new_id = next_scene_id(sense_id, scene_type)
    existing = "\n\n".join(f"```yaml\n{read(p)}```" for p in peers) \
        or "(该类型暂无已有场景)"

    prompt = (read(PROMPTS / "scene-add.md")
              .replace("{{SCHEMA}}", read(ROOT / "schema" / "scene-spec.schema.json"))
              .replace("{{SENSE}}", read(sense_path))
              .replace("{{EXISTING}}", existing)
              .replace("{{SENSE_ID}}", sense_id)
              .replace("{{SCENE_TYPE}}", scene_type)
              .replace("{{NEW_ID}}", new_id))

    print(f"→ 增补 '{sense_id}' 的 {scene_type} 场景 ({new_id}) ...",
          file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")

    out_dir = DRAFTS / "scenes" / sense_id
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{new_id}.yaml"
    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as e:
        unparsed = out_dir / f"_unparsed-{new_id}.yaml"
        unparsed.write_text(blocks[0], encoding="utf-8")
        sys.exit(f"YAML 解析失败, 原文已存 {unparsed.relative_to(ROOT)} 供修复:\n{e}")
    if not isinstance(doc, dict):
        sys.exit("场景草稿的 YAML 根节点必须是对象")

    out.write_text(blocks[0].rstrip() + "\n", encoding="utf-8")
    print(f"✓ 草稿已写入 {out.relative_to(ROOT)}")

    errs = schema_check(doc, load_schema("scene-spec.schema.json"), out.name)
    if doc.get("id") != new_id:
        errs.append(f"  ✗ {out.name} id 必须是 '{new_id}'")
    if doc.get("scene_type") != scene_type:
        errs.append(f"  ✗ {out.name} scene_type 必须是 '{scene_type}'")
    if not doc.get("surface"):
        errs.append(f"  ✗ {out.name} 增补场景必须填写 surface")
    _report(errs, out)


# ---------------------------------------------------------------- list

def cmd_list(args):
    if not DRAFTS.exists():
        print("草稿库为空。")
        return
    senses = sorted((DRAFTS / "senses").glob("*.yaml")) \
        if (DRAFTS / "senses").exists() else []
    print(f"待审词义草稿 ({len(senses)}):")
    for p in senses:
        print(f"  {p.relative_to(ROOT)}")
    scene_root = DRAFTS / "scenes"
    if scene_root.exists():
        for d in sorted(scene_root.iterdir()):
            if d.is_dir():
                n = len(list(d.glob("*.yaml")))
                print(f"待审场景组 {d.name}: {n} 个场景 → {d.relative_to(ROOT)}")


# ---------------------------------------------------------------- promote

def cmd_promote(args):
    ident = args.id.strip()
    if not SENSE_ID.fullmatch(ident):
        sys.exit(f"义项 ID '{ident}' 不符合 {{word}}-{{nn}} 约定")
    sense_draft = DRAFTS / "senses" / f"{ident}.yaml"
    scene_draft_dir = DRAFTS / "scenes" / ident
    has_sense = sense_draft.exists()
    has_scenes = scene_draft_dir.exists()
    if not has_sense and not has_scenes:
        sys.exit(f"未找到 '{ident}' 的草稿 (词义或场景组均无)")

    sense_dest = ROOT / "data" / "senses" / f"{ident}.yaml"
    scene_dest_dir = ROOT / "data" / "scenes" / ident
    if has_sense and sense_dest.exists():
        sys.exit(f"正式义项已存在: {sense_dest.relative_to(ROOT)}；拒绝静默覆盖")
    scene_files = sorted(scene_draft_dir.glob("*.yaml")) if has_scenes else []
    for path in scene_files:
        if (scene_dest_dir / path.name).exists():
            sys.exit(
                f"正式场景已存在: {(scene_dest_dir / path.name).relative_to(ROOT)}"
                "；拒绝静默覆盖"
            )

    # Build a complete candidate repository and validate it before touching
    # published paths. Temporary files live on the same filesystem so the
    # final os.replace operations are atomic.
    with tempfile.TemporaryDirectory(prefix=".promotion-", dir=ROOT / "data") as tmp:
        staged = Path(tmp)
        shutil.copytree(ROOT / "data" / "senses", staged / "senses")
        shutil.copytree(ROOT / "data" / "scenes", staged / "scenes")

        if has_sense:
            prepared = _mark_reviewed(read(sense_draft))
            (staged / "senses" / sense_draft.name).write_text(
                prepared, encoding="utf-8"
            )
        if has_scenes:
            # The staged tree already contains any published scenes for this
            # sense; additions merge in beside them.
            staged_scene_dir = staged / "scenes" / ident
            staged_scene_dir.mkdir(exist_ok=True)
            for path in scene_files:
                (staged_scene_dir / path.name).write_text(
                    _mark_reviewed(read(path)), encoding="utf-8"
                )

        print("→ 在隔离目录运行发布前全量校验 ...\n")
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "tools" / "validate.py"),
                "--data-root",
                str(staged),
            ],
            check=False,
        )
        if result.returncode:
            sys.exit("发布前校验失败；草稿与正式库均未改动")

        promoted = []
        if has_sense:
            os.replace(staged / "senses" / sense_draft.name, sense_dest)
            promoted.append(sense_dest)
        if has_scenes:
            scene_dest_dir.mkdir(parents=True, exist_ok=True)
            for path in scene_files:
                dest = scene_dest_dir / path.name
                os.replace(staged / "scenes" / ident / path.name, dest)
                promoted.append(dest)

    if has_sense:
        sense_draft.unlink()
    if has_scenes:
        shutil.rmtree(scene_draft_dir)
    for path in promoted:
        print(f"✓ 定稿 {path.relative_to(ROOT)}")

    # 同步更新词目条目
    word = ident.rsplit("-", 1)[0]
    try:
        from dict import build_word_entry, write_word_entry

        ranks_path = ROOT / "data" / "wordlists" / "en-top-20000.tsv"
        ranks: dict[str, int] = {}
        if ranks_path.exists():
            for line in ranks_path.read_text(encoding="utf-8").splitlines():
                if line and not line.startswith("#"):
                    parts = line.split("\t")
                    if len(parts) >= 2 and parts[0].isdigit():
                        ranks[parts[1]] = int(parts[0])
        entry = build_word_entry(word, ranks)
        if entry and entry.get("senses"):
            # 保留词目文件已有的 schema_version, 自增 version
            existing_path = ROOT / "data" / "words" / f"{word}.yaml"
            if existing_path.exists():
                existing = yaml.safe_load(
                    existing_path.read_text(encoding="utf-8")
                )
                if isinstance(existing, dict):
                    entry["version"] = (existing.get("version") or 1) + 1
                    if existing.get("schema_version"):
                        entry["schema_version"] = existing["schema_version"]
            else:
                entry["version"] = 1
            entry.setdefault("schema_version", "1.0")
            write_word_entry(word, entry)
            print(f"✓ 词目条目已更新 → data/words/{word}.yaml")
    except Exception as exc:
        print(f"  ⚠ 词目条目更新失败: {exc}", file=sys.stderr)

    print("\n→ 复核正式库 ...\n")
    result = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "validate.py")], check=False
    )
    sys.exit(result.returncode)


# ---------------------------------------------------------------- batch

BATCH_STATE = DRAFTS / "batch-state.json"


def _load_batch_state():
    if BATCH_STATE.exists():
        return json.loads(BATCH_STATE.read_text(encoding="utf-8"))
    return {}


def _save_batch_state(state):
    BATCH_STATE.parent.mkdir(parents=True, exist_ok=True)
    BATCH_STATE.write_text(
        json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8"
    )


def _run_stage(stage_args, retries, sleep_seconds):
    """在子进程中跑一个起草阶段, 失败时重试。返回 (ok, message)。"""
    import time
    last = ""
    for attempt in range(1, retries + 2):
        result = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), *stage_args],
            capture_output=True, text=True, timeout=1800,
        )
        if result.returncode == 0:
            return True, (result.stdout.strip().splitlines() or ["ok"])[-1]
        last = (result.stderr or result.stdout).strip()[-400:]
        print(f"    ✗ 第 {attempt} 次失败: {last.splitlines()[-1] if last else '?'}",
              file=sys.stderr)
        if attempt <= retries:
            time.sleep(sleep_seconds)
    return False, last


def cmd_batch(args):
    import time
    import threading
    from concurrent.futures import ThreadPoolExecutor, as_completed

    if args.words:
        words = [w.strip().lower() for w in args.words]
    else:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import candidates
        words = [item["word"] for item in candidates.build_queue(args.count)]
    if not words:
        sys.exit("候选队列为空")

    state = _load_batch_state()
    state_lock = threading.Lock()
    print_lock = threading.Lock()

    print(f"=== 批量起草 {len(words)} 个词 (并发 {args.concurrency}) ===\n")

    # 枚举所有 (word, sense_num) 任务
    tasks: list[tuple[str, str]] = []
    for word in words:
        import dictionary as _dict
        try:
            total_senses = _dict.sense_count(word)
        except Exception:
            total_senses = 1
        with print_lock:
            print(f"→ {word}: {total_senses} 个义项")
        for i in range(1, total_senses + 1):
            tasks.append((word, f"{i:02d}"))

    def process_one(word: str, sense_num: str) -> None:
        """处理单个 (word, sense_num) 的义项 + 场景。"""
        sense_id = f"{word}-{sense_num}"
        entry = state.setdefault(word, {})
        sense_entry = entry.setdefault("senses", {})

        # --- sense ---
        sense_state = sense_entry.get(sense_num)
        if sense_state == "done" or resolve_sense_path(sense_id):
            with state_lock:
                sense_entry[sense_num] = "done"
                _save_batch_state(state)
            with print_lock:
                print(f"  ✓ {word}: 义项 {sense_num} 已存在")
        else:
            ok, msg = _run_stage(["sense", word, "--num", sense_num],
                                 args.retries, args.sleep)
            with state_lock:
                sense_entry[sense_num] = "done" if ok else "failed"
                _save_batch_state(state)
            if not ok:
                with print_lock:
                    print(f"  ✗ {word}: 义项 {sense_num} 起草失败")
                # 场景会被跳过, 但给 scene_entry 留个记录便于批处理汇总
                entry.setdefault("scenes", {})[sense_num] = "failed"
                return
            with print_lock:
                print(f"  ✓ {word}: 义项 {sense_num} 草稿完成")

        # --- scenes ---
        if args.senses_only:
            return
        scene_entry = entry.setdefault("scenes", {})
        if scene_entry.get(sense_num) == "done":
            with print_lock:
                print(f"  ✓ {word}: {sense_num} 场景组已完成")
            return
        ok, msg = _run_stage(["scenes", sense_id], args.retries, args.sleep)
        with state_lock:
            scene_entry[sense_num] = "done" if ok else "failed"
            _save_batch_state(state)
        with print_lock:
            print(f"  {'✓' if ok else '✗'} {word}: {sense_num} 场景组{'完成' if ok else '失败'}")

    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        futures = {pool.submit(process_one, w, sn): (w, sn) for w, sn in tasks}
        from tqdm import tqdm
        for f in tqdm(as_completed(futures), total=len(futures),
                      desc="生成中", unit="义项", ncols=80):
            pass

    print("\n=== 批量汇总 ===")
    for word in words:
        entry = state.get(word, {})
        s = entry.get("senses", {})
        sc = entry.get("scenes", {})
        sense_summary = " ".join(
            f"{k}:{'✓' if v == 'done' else '✗'}" for k, v in sorted(s.items())
        ) if s else "(无)"
        scene_summary = " ".join(
            f"{k}:{'✓' if v == 'done' else '✗'}" for k, v in sorted(sc.items())
        ) if sc else "(无)"
        print(f"  {word:16}  义项: {sense_summary} | 场景: {scene_summary}")

    total_senses = sum(
        sum(1 for v in state.get(w, {}).get("senses", {}).values() if v == "done")
        for w in words
    )
    total_senses_all = sum(
        len(state.get(w, {}).get("senses", {}))
        for w in words
    )
    total_scenes = sum(
        sum(1 for v in state.get(w, {}).get("scenes", {}).values() if v == "done")
        for w in words
    )
    total_scenes_all = sum(
        len(state.get(w, {}).get("scenes", {}))
        for w in words
    ) if not args.senses_only else 0
    all_ok = total_senses == total_senses_all and total_scenes == total_scenes_all
    if all_ok:
        BATCH_STATE.unlink(missing_ok=True)
        print(f"\n✓ 全部 {total_senses} 个义项、{total_scenes} 个场景完成, "
              f"状态文件已清理。运行 draft.py list 查看待审草稿。")
    else:
        print(f"\n⚠ 有失败项 (义项 {total_senses}/{total_senses_all}, "
              f"场景 {total_scenes}/{total_scenes_all}); "
              f"重跑同一命令将从断点续作 (状态: "
              f"{BATCH_STATE.relative_to(ROOT)})")


# ---------------------------------------------------------------- backlog

def cmd_backlog(args):
    subprocess.run([sys.executable, str(ROOT / "tools" / "validate.py"),
                    "--backlog"])


# ---------------------------------------------------------------- helpers

def _report(errs, out):
    if errs:
        print(f"\n⚠ {len(errs)} 处 schema 问题, 需人工修复后再 promote:",
              file=sys.stderr)
        for e in errs:
            print(e, file=sys.stderr)
    else:
        print("✓ schema 校验通过。审阅后运行: "
              f"python3 tools/draft.py promote <id>")


def _mark_reviewed(text):
    """Change exactly one top-level draft status without reformatting YAML."""
    updated, count = re.subn(
        r"(?m)^status:\s*draft\s*$", "status: reviewed", text, count=1
    )
    if count != 1:
        raise ValueError("草稿必须包含顶层 'status: draft'")
    return updated


def main():
    parser = argparse.ArgumentParser(description="SceneLex 内容起草工具")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("sense", help="起草词义")
    p.add_argument("word")
    p.add_argument("--num", "-n", default="01",
                   help="义项序号 (默认 01)")
    p.set_defaults(func=cmd_sense)

    p = sub.add_parser("scenes", help="起草五场景组, 或用 --add 增补单个场景")
    p.add_argument("sense_id")
    p.add_argument("--add", choices=SCENE_ORDER, metavar="TYPE",
                   help="为已有义项增补一个指定类型的场景 (泛化扩证据)")
    p.set_defaults(func=cmd_scenes)

    sub.add_parser("list", help="列出待审草稿").set_defaults(func=cmd_list)

    p = sub.add_parser("promote", help="草稿定稿并校验")
    p.add_argument("id")
    p.set_defaults(func=cmd_promote)

    sub.add_parser("backlog", help="输出选词 backlog").set_defaults(
        func=cmd_backlog)

    p = sub.add_parser("batch", help="按候选队列批量起草 (断点可续)")
    p.add_argument("words", nargs="*",
                   help="显式词列表; 缺省时取 candidates.py 队列前 N 个")
    p.add_argument("--count", type=int, default=4, help="从队列取的词数 (默认 4)")
    p.add_argument("--retries", type=int, default=1, help="每阶段失败重试次数")
    p.add_argument("--sleep", type=int, default=15, help="阶段间隔秒数 (限速)")
    p.add_argument("--concurrency", "-C", type=int, default=1000,
                   help="并行处理词数 (默认 1000)")
    p.add_argument("--senses-only", action="store_true", help="只起草词义, 不起草场景")
    p.set_defaults(func=cmd_batch)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
