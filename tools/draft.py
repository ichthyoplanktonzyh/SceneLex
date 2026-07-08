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
import re
import subprocess
import sys
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


# ---------------------------------------------------------------- sense

def cmd_sense(args):
    word = args.word.strip().lower()
    if not re.match(r"^[a-z][a-z_]*$", word):
        sys.exit(f"单词 '{word}' 含非法字符 (只允许小写字母和下划线)")

    template = read(PROMPTS / "sense-draft.md")
    schema = read(ROOT / "schema" / "word-sense.schema.json")
    ex1 = read(ROOT / "data" / "senses" / f"{SENSE_EXAMPLES[0]}.yaml")
    ex2 = read(ROOT / "data" / "senses" / f"{SENSE_EXAMPLES[1]}.yaml")
    prompt = (template
              .replace("{{SCHEMA}}", schema)
              .replace("{{EXAMPLE_1}}", ex1)
              .replace("{{EXAMPLE_2}}", ex2)
              .replace("{{WORD}}", word))

    print(f"→ 起草词义 '{word}' ...", file=sys.stderr)
    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")

    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as e:
        out = DRAFTS / "senses" / f"{word}-01.yaml"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(blocks[0], encoding="utf-8")
        sys.exit(f"YAML 解析失败, 原文已存 {out.relative_to(ROOT)} 供修复:\n{e}")

    out = DRAFTS / "senses" / f"{doc.get('id', word + '-01')}.yaml"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(blocks[0].rstrip() + "\n", encoding="utf-8")
    print(f"✓ 草稿已写入 {out.relative_to(ROOT)}")

    errs = schema_check(doc, load_schema("word-sense.schema.json"), out.name)
    _report(errs, out)


# ---------------------------------------------------------------- scenes

def cmd_scenes(args):
    sense_id = args.sense_id.strip()
    if not SENSE_ID.match(sense_id):
        sys.exit(f"义项 ID '{sense_id}' 不符合 {{word}}-{{nn}} 约定")
    sense_path = resolve_sense_path(sense_id)
    if not sense_path:
        sys.exit(f"找不到义项 '{sense_id}' (data/senses/ 和 data/drafts/senses/ 均无)")

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
        scene_type = doc.get("scene_type", "")
        abbr = SCENE_ABBR.get(scene_type, scene_type or f"blk{i + 1}")
        sid = doc.get("id") or f"{sense_id}-{abbr}-01"
        fname = out_dir / f"{sid}.yaml"
        fname.write_text(block.rstrip() + "\n", encoding="utf-8")
        written.append(fname)
        all_errs += schema_check(doc, validator, fname.name)

    print(f"✓ 写入 {len(written)} 个场景草稿 → {out_dir.relative_to(ROOT)}")
    got = {yaml.safe_load(read(p)).get("scene_type") for p in written}
    missing = [t for t in SCENE_ORDER if t not in got]
    if missing:
        print(f"⚠ 缺少场景类型: {', '.join(missing)}")
    _report(all_errs, out_dir)


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
    moved = []
    # 词义草稿?
    sense_draft = DRAFTS / "senses" / f"{ident}.yaml"
    if sense_draft.exists():
        dest = ROOT / "data" / "senses" / f"{ident}.yaml"
        dest.write_text(read(sense_draft), encoding="utf-8")
        sense_draft.unlink()
        moved.append(dest)
    # 场景组草稿?
    scene_draft_dir = DRAFTS / "scenes" / ident
    if scene_draft_dir.exists():
        dest_dir = ROOT / "data" / "scenes" / ident
        dest_dir.mkdir(parents=True, exist_ok=True)
        for p in sorted(scene_draft_dir.glob("*.yaml")):
            (dest_dir / p.name).write_text(read(p), encoding="utf-8")
            p.unlink()
            moved.append(dest_dir / p.name)
        try:
            scene_draft_dir.rmdir()
        except OSError:
            pass
    if not moved:
        sys.exit(f"未找到 '{ident}' 的草稿 (词义或场景组均无)")
    for m in moved:
        print(f"✓ 定稿 {m.relative_to(ROOT)}")
    print("\n→ 运行全量校验 ...\n")
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "validate.py")])
    sys.exit(r.returncode)


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


def main():
    parser = argparse.ArgumentParser(description="SceneLex 内容起草工具")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("sense", help="起草词义")
    p.add_argument("word")
    p.set_defaults(func=cmd_sense)

    p = sub.add_parser("scenes", help="起草五场景组")
    p.add_argument("sense_id")
    p.set_defaults(func=cmd_scenes)

    sub.add_parser("list", help="列出待审草稿").set_defaults(func=cmd_list)

    p = sub.add_parser("promote", help="草稿定稿并校验")
    p.add_argument("id")
    p.set_defaults(func=cmd_promote)

    sub.add_parser("backlog", help="输出选词 backlog").set_defaults(
        func=cmd_backlog)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
