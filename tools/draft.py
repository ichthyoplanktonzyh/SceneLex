#!/usr/bin/env python3
"""SceneLex 内容起草工具 — 管线的第 2、3 阶段。

把 LLM 从"作者"降为"打字员", 把人从"作者"升为"编辑"。
调用哪个模型由 tools/llm.py 决定 (模型无关)。

词义起草由 approved Sense Inventory 驱动: sense ID、lemma、pos、语义身份和
dictionary source mapping 都取自 data/inventories/{word}.yaml, 模型只负责把
已经冻结的那一个 sense 详细化。词典条目不是 SceneLex sense, 因此按词典条目
序号起草的旧 --num 路径已弃用。

用法:
    python3 tools/draft.py sense <sense_id>    # 起草单个词义 → data/drafts/senses/
    python3 tools/draft.py senses <word>       # 按 Inventory 起草整词全部词义
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
import time
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

import llm

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "tools" / ".." / "prompts"
DRAFTS = ROOT / "data" / "drafts"
SENSE_ID = re.compile(r"^[a-z][a-z_]*-\d{2}$")

SCENE_ORDER = ["prototype", "contrast", "counterexample", "boundary", "transfer"]
SCENE_ABBR = {"prototype": "proto", "contrast": "contrast",
              "counterexample": "counter", "boundary": "boundary",
              "transfer": "transfer"}


def read(path):
    return path.read_text(encoding="utf-8")


def _rel(path):
    """尽量输出相对 ROOT 的路径; 测试把草稿目录重定向到 ROOT 之外时仍可读。"""
    try:
        return str(Path(path).relative_to(ROOT))
    except ValueError:
        return str(path)


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


def type_strategy(sense_path):
    """按义项的 semantic_type 读取对应的场景表达策略片段。

    起草不使用具体范例 few-shot (避免锚定表面选择);
    类型策略是"语义—场景设计手册"在提示词中的落地。
    """
    try:
        semantic_type = yaml.safe_load(read(sense_path)).get("semantic_type")
    except yaml.YAMLError:
        semantic_type = None
    if not semantic_type:
        print("⚠ 词义规格缺少 semantic_type, 无类型策略可注入", file=sys.stderr)
        return "（该义项未声明 semantic_type，按五类职责的通用要求构造场景。）"
    strategy = PROMPTS / "scene-strategies" / f"{semantic_type}.md"
    if not strategy.exists():
        print(f"⚠ 缺少策略片段 prompts/scene-strategies/{semantic_type}.md",
              file=sys.stderr)
        return (f"（semantic_type 为 {semantic_type}，策略片段尚未编写，"
                "按五类职责的通用要求构造场景。）")
    return read(strategy).strip()


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

WORD_PATTERN = re.compile(r"^[a-z][a-z_]*$")
LEGACY_SENSES = DRAFTS / "legacy-senses"

DEPRECATED_NUM_MESSAGE = """\
The dictionary-indexed --num workflow is deprecated because dictionary
entries are not SceneLex senses.

Use:
  python3 tools/inventory.py draft {word}
  python3 tools/inventory.py mark-reviewed {word}
  python3 tools/inventory.py approve {word}
  python3 tools/draft.py sense {word}-{num}"""


class SenseDraftError(RuntimeError):
    """单个 WordSense 起草失败; 消息已包含 sense ID 与失败阶段。"""


def _atomic_write(path, text):
    """临时文件 + os.replace: 起草失败时绝不留下半份文件, 也不破坏已有草稿。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.",
                                    suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(text)
        os.replace(tmp_name, path)
    except Exception:
        Path(tmp_name).unlink(missing_ok=True)
        raise


def _dump_failure(prefix, sense_id, text):
    """把失败的模型输出留在旁路文件里, 永不占用正常草稿路径。"""
    path = DRAFTS / "senses" / f"_{prefix}-{sense_id}.yaml"
    _atomic_write(path, text if text.endswith("\n") else text + "\n")
    return path


def _yaml_block(data):
    return yaml.safe_dump(data, allow_unicode=True, sort_keys=False).rstrip()


def _current_sense_block(inventory_sense):
    """CURRENT_SENSE: inventory sense 的完整锁定内容, 原样呈现。"""
    return _yaml_block(inventory_sense)


def _all_senses_block(inventory_doc):
    """ALL_SENSES: 每个 sense 的稳定摘要, 让模型能描述边界但无法重新定义它们。"""
    summaries = [
        {
            "id": sense.get("id"),
            "pos": sense.get("pos"),
            "label_zh": sense.get("label_zh"),
            "definition": sense.get("definition"),
            "semantic_signature": sense.get("semantic_signature"),
        }
        for sense in inventory_doc.get("senses") or []
        if isinstance(sense, dict)
    ]
    return _yaml_block(summaries)


def _locked_relations_block(inventory, inventory_doc, sense_id):
    """LOCKED_RELATIONS: 显式标注方向, 反向关系不做隐式改写。"""
    lines = []
    for relation in inventory.relations_for_sense(inventory_doc, sense_id):
        source, target = relation.get("source"), relation.get("target")
        direction = ("outgoing (当前 sense 是 source)" if source == sense_id
                     else "incoming (当前 sense 是 target)")
        lines.append(_yaml_block({
            "direction": direction,
            "source": source,
            "target": target,
            "relation": relation.get("relation"),
            "distinction": relation.get("distinction"),
        }))
    return "\n---\n".join(lines) or "(该 sense 在 Inventory 中没有已记录的跨义项关系)"


def _dictionary_entries_block(entries, inventory_sense, word):
    """CURRENT_SENSE 的证据给全文; 同词其他条目只给摘要供边界判断。"""
    owned = set(inventory_sense.get("source_entries") or [])
    primary = [e for e in entries if e.get("entry_id") in owned]
    others = [e for e in entries if e.get("entry_id") not in owned]

    parts = ["## CURRENT_SENSE 的来源条目 (完整证据)", _yaml_block(primary)]
    if others:
        parts += [
            "\n## 同词其他条目 (仅供边界判断, 不属于本 sense)",
            _yaml_block([
                {"entry_id": e.get("entry_id"), "pos": e.get("pos"),
                 "gloss": e.get("gloss")}
                for e in others
            ]),
        ]
    import dictionary
    parts.append(f"\n来源: {dictionary.source_url(word)} "
                 f"({dictionary.LICENSE_NOTE})")
    return "\n".join(parts)


def build_sense_prompt(inventory_doc, inventory_sense, entries):
    """构造 inventory-driven 的 sense 起草提示词。

    每次起草都注入完整 ALL_SENSES: 模型必须在整词已冻结的义项格局中描述边界,
    而不是只看着一条词典释义自由发挥。
    """
    import inventory as inventory_module

    sense_id = inventory_sense.get("id")
    word = inventory_doc.get("word")
    meta = _yaml_block({
        "word": word,
        "language": inventory_doc.get("language"),
        "status": inventory_doc.get("status"),
        "inventory_version": inventory_doc.get("inventory_version"),
        "evidence_digest": (inventory_doc.get("source") or {}).get(
            "evidence_digest"),
        "sense_count": len(inventory_doc.get("senses") or []),
    })
    return (read(PROMPTS / "sense-draft.md")
            .replace("{{SCHEMA}}", read(ROOT / "schema" / "word-sense.schema.json"))
            .replace("{{INVENTORY_META}}", meta)
            .replace("{{CURRENT_SENSE}}", _current_sense_block(inventory_sense))
            .replace("{{ALL_SENSES}}", _all_senses_block(inventory_doc))
            .replace("{{LOCKED_RELATIONS}}",
                     _locked_relations_block(inventory_module, inventory_doc,
                                             sense_id))
            .replace("{{SOURCE_DICTIONARY_ENTRIES}}",
                     _dictionary_entries_block(entries, inventory_sense, word))
            .replace("{{SENSE_ID}}", sense_id))


def apply_inventory_fields(doc, inventory_doc, inventory_sense):
    """程序覆盖机器权威字段。

    模型可以写这些字段, 但它写的值一律作废: 义项身份属于 approved Inventory,
    不属于本次生成。人工事后改动仍会被 validate_sense_against_inventory 抓到。
    """
    import inventory as inventory_module

    signature = inventory_sense.get("semantic_signature") or {}
    doc["schema_version"] = "1.1"
    doc["language"] = inventory_doc.get("language")
    doc["id"] = inventory_sense.get("id")
    doc["word"] = inventory_sense.get("lemma")
    doc["pos"] = inventory_sense.get("pos")
    doc["semantic_identity"] = {
        field: signature.get(field)
        for field in inventory_module.IDENTITY_SIGNATURE_FIELDS
    }
    doc["inventory_source_entries"] = list(inventory_sense.get("source_entries") or [])
    doc["inventory"] = {
        "word": inventory_doc.get("word"),
        "version": inventory_doc.get("inventory_version"),
        "evidence_digest": (inventory_doc.get("source") or {}).get("evidence_digest"),
        "sense_id": inventory_sense.get("id"),
        "identity_digest": inventory_module.compute_identity_digest(inventory_sense),
    }
    return doc


def draft_one_sense(sense_id, inventory_doc, entries, force=False):
    """起草一个 inventory sense 的 WordSense 草稿, 成功时返回输出路径。

    失败一律抛 SenseDraftError 且不触碰已有的合法草稿: 非法 YAML、schema 错误、
    身份漂移和 inventory 冲突分别落到 _unparsed- / _invalid- / _conflict- 旁路
    文件, 正常路径只承载通过全部校验的内容。
    """
    import inventory as inventory_module

    inventory_sense = inventory_module.find_inventory_sense(inventory_doc, sense_id)
    if inventory_sense is None:
        available = ", ".join(inventory_module.inventory_sense_ids(inventory_doc))
        raise SenseDraftError(
            f"[{sense_id}] lookup 阶段失败: approved Sense Inventory 中没有这个 "
            f"sense。可用的 sense ID: {available or '(空)'}"
        )

    out = DRAFTS / "senses" / f"{sense_id}.yaml"
    if out.exists() and not force:
        raise SenseDraftError(
            f"[{sense_id}] 起草阶段失败: 草稿已存在于 {_rel(out)}; "
            "使用 --force 覆盖"
        )

    prompt = build_sense_prompt(inventory_doc, inventory_sense, entries)
    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        raise SenseDraftError(f"[{sense_id}] 生成阶段失败: 模型未返回任何 YAML 内容")

    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as exc:
        path = _dump_failure("unparsed", sense_id, blocks[0])
        raise SenseDraftError(
            f"[{sense_id}] 解析阶段 YAML 失败: {exc}; "
            f"原始输出已存 {_rel(path)}"
        ) from exc
    if not isinstance(doc, dict):
        path = _dump_failure("unparsed", sense_id, blocks[0])
        raise SenseDraftError(
            f"[{sense_id}] 解析阶段失败: WordSense 的 YAML 根节点必须是对象; "
            f"原始输出已存 {_rel(path)}"
        )

    if doc.get("generation_status") == "inventory_conflict":
        path = _dump_failure("conflict", sense_id, blocks[0])
        issues = "; ".join(
            f"{item.get('field')}: {item.get('message')}"
            for item in doc.get("issues") or [] if isinstance(item, dict)
        ) or "(模型未给出结构化 issues)"
        raise SenseDraftError(
            f"[{sense_id}] 冲突阶段: 模型报告 approved Inventory 无法支撑生成 — "
            f"{issues}\n冲突报告已存 {_rel(path)}; "
            "请回到 inventory 层修正, 不要在 sense 草稿中自行修复。"
        )

    apply_inventory_fields(doc, inventory_doc, inventory_sense)

    errors = schema_check(doc, load_schema("word-sense.schema.json"),
                          f"{sense_id}.yaml")
    errors += [
        f"  ✗ {sense_id}.yaml: {message}"
        for message in inventory_module.validate_sense_against_inventory(
            doc, inventory_doc, inventory_sense
        )
    ]
    if errors:
        path = _dump_failure("invalid", sense_id, blocks[0])
        detail = "\n".join(errors)
        raise SenseDraftError(
            f"[{sense_id}] 校验阶段失败 ({len(errors)} 处), 原始输出已存 "
            f"{_rel(path)}:\n{detail}"
        )

    _atomic_write(out, _yaml_block(doc) + "\n")
    return out


def cmd_sense(args):
    target = args.target.strip().lower()
    if args.num is not None or not SENSE_ID.fullmatch(target):
        return _legacy_sense(args, target)

    import inventory as inventory_module

    word = target.rsplit("-", 1)[0]
    try:
        inventory_doc = inventory_module.load_approved_inventory(word)
        entries = inventory_module.load_approved_evidence_entries(word)
    except inventory_module.InventoryError as exc:
        sys.exit(str(exc))

    print(f"→ 依据 approved Inventory 起草 '{target}' ...", file=sys.stderr)
    try:
        out = draft_one_sense(target, inventory_doc, entries, force=args.force)
    except SenseDraftError as exc:
        sys.exit(str(exc))
    print(f"✓ 草稿已写入 {_rel(out)}")
    _report([], out)


def cmd_senses(args):
    """按 approved Inventory 枚举整词的全部 sense 并逐一起草。"""
    import inventory as inventory_module
    from concurrent.futures import ThreadPoolExecutor

    word = args.word.strip().lower()
    if not WORD_PATTERN.match(word):
        sys.exit(f"单词 '{word}' 含非法字符 (只允许小写字母和下划线)")
    try:
        inventory_doc = inventory_module.load_approved_inventory(word)
        entries = inventory_module.load_approved_evidence_entries(word)
    except inventory_module.InventoryError as exc:
        sys.exit(str(exc))

    sense_ids = inventory_module.inventory_sense_ids(inventory_doc)
    if not sense_ids:
        sys.exit(f"[{word}] senses 阶段失败: approved Inventory 中没有任何 sense")
    print(f"→ '{word}' 的 approved Inventory 有 {len(sense_ids)} 个 sense: "
          f"{', '.join(sense_ids)}", file=sys.stderr)

    def run(sense_id):
        # 模型侧的传输/配置错误也只拖垮它自己那一条: 其余 sense 的草稿已经各自
        # 原子落盘, 汇总仍要如实报出哪几条失败。
        try:
            draft_one_sense(sense_id, inventory_doc, entries, force=args.force)
        except (SenseDraftError, llm.LLMConfigurationError,
                llm.LLMResponseError) as exc:
            return sense_id, False, str(exc)
        return sense_id, True, ""

    workers = max(1, min(args.workers, len(sense_ids)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(run, sense_ids))

    print(f"\n=== {word} 起草汇总 ===")
    for sense_id, ok, message in results:
        if ok:
            print(f"{sense_id} PASS")
        else:
            print(f"{sense_id} FAILED {message.splitlines()[0]}")
    failed = [sense_id for sense_id, ok, _ in results if not ok]
    if failed:
        print(f"\n⚠ {len(failed)}/{len(results)} 个 sense 起草失败 "
              f"({', '.join(failed)}); 成功的草稿已保留, 修复后可单独重跑:",
              file=sys.stderr)
        for sense_id, ok, message in results:
            if not ok:
                print(f"\n{message}", file=sys.stderr)
        sys.exit(1)
    print(f"\n✓ 全部 {len(results)} 个 sense 草稿完成。审阅后运行: "
          f"python3 tools/draft.py promote <id>")


def _legacy_sense(args, target):
    """旧的 dictionary-indexed 路径: 默认禁用, 显式开关下也不占用正常草稿路径。"""
    word = target
    num = args.num or "01"
    if not WORD_PATTERN.match(word):
        sys.exit(
            f"'{target}' 既不是合法的 sense ID ({{word}}-{{nn}}), 也不是合法单词。\n"
            "新用法: python3 tools/draft.py sense slow-02"
        )
    if not args.legacy_dictionary_index:
        sys.exit(DEPRECATED_NUM_MESSAGE.format(word=word, num=num))

    print(
        "⚠⚠ 正在使用已弃用的 dictionary-indexed 起草路径。词典条目不是 SceneLex "
        "sense, 本次生成的编号没有 Inventory 权威支持, 结果只能用于临时实验, "
        f"不得 promote。产物写入 {_rel(LEGACY_SENSES)}/, "
        "不会进入正常草稿区。",
        file=sys.stderr,
    )

    import dictionary
    template = read(PROMPTS / "sense-draft-legacy.md")
    prompt = (template
              .replace("{{SCHEMA}}", read(ROOT / "schema" / "word-sense.schema.json"))
              .replace("{{DICTIONARY}}", dictionary.prompt_block(word, num))
              .replace("{{WORD}}", word)
              .replace("{{SENSE_NUM}}", num)
              .replace("{{TOTAL_SENSES}}", str(dictionary.sense_count(word))))

    raw = llm.generate(prompt)
    blocks = extract_yaml_blocks(raw)
    if not blocks:
        sys.exit("模型未返回任何 YAML 内容")
    out = LEGACY_SENSES / f"{word}-{num}.yaml"
    _atomic_write(out, blocks[0].rstrip() + "\n")
    print(f"✓ 实验性草稿已写入 {_rel(out)} (不可 promote)")


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

    prompt = (template
              .replace("{{SCHEMA}}", schema)
              .replace("{{SENSE}}", sense_yaml)
              .replace("{{TYPE_STRATEGY}}", type_strategy(sense_path))
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
              .replace("{{TYPE_STRATEGY}}", type_strategy(sense_path))
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

def _review_advisory(ident, reviewed_files):
    """模型审核是可选参考, 不阻塞 promote。

    返回可归档的记录路径: 记录存在且内容指纹与当前草稿匹配时 (无论 verdict),
    promote 后随资源归档以便追溯; 缺失、过期或损坏只提示。
    """
    import review
    record_file = review.record_path(ident)
    if not record_file.exists():
        print(f"⚠ 未经模型审核 (可选): python3 tools/review.py {ident}",
              file=sys.stderr)
        return None
    try:
        record = yaml.safe_load(read(record_file))
    except yaml.YAMLError as e:
        print(f"⚠ 审核记录无法解析, 忽略: {e}", file=sys.stderr)
        return None
    if not isinstance(record, dict):
        print("⚠ 审核记录格式异常, 忽略", file=sys.stderr)
        return None
    if record.get("content_digest") != review.content_digest(reviewed_files):
        print("⚠ 审核记录已过期 (草稿在审核后被修改), 不随资源归档",
              file=sys.stderr)
        return None
    verdict = record.get("verdict")
    if verdict == "pass":
        print("✓ 模型审核通过")
    else:
        print(f"⚠ 模型审核 verdict={verdict}; 审核不阻塞 promote, 请自行判断",
              file=sys.stderr)
    return record_file


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
    leftovers = [p for p in scene_files if p.name.startswith("_")]
    if leftovers:
        names = ", ".join(p.name for p in leftovers)
        sys.exit(f"场景草稿目录存在未解析残骸: {names}；修复或删除后重试")
    for path in scene_files:
        if (scene_dest_dir / path.name).exists():
            sys.exit(
                f"正式场景已存在: {(scene_dest_dir / path.name).relative_to(ROOT)}"
                "；拒绝静默覆盖"
            )

    # 模型审核是可选参考, 只提示不阻塞
    reviewed_files = ([sense_draft] if has_sense else []) + scene_files
    record_file = _review_advisory(ident, reviewed_files)

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

    if record_file is not None:
        archive_dir = ROOT / "data" / "reviews"
        archive_dir.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime("%Y%m%d%H%M%S", time.gmtime())
        archived = archive_dir / f"{ident}-{stamp}.yaml"
        os.replace(record_file, archived)
        print(f"✓ 审核记录归档 → {archived.relative_to(ROOT)}")

    # 同步更新词目条目
    word = ident.rsplit("-", 1)[0]
    try:
        from wordbook import build_word_entry, write_word_entry

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

    # 按 approved Sense Inventory 枚举任务。绝不按 Wiktionary 条目数生成
    # SceneLex sense ID: 词典条目不是 sense, 条目序号也不是 sense 编号。
    import inventory as inventory_module

    tasks: list[tuple[str, str]] = []
    skipped: list[str] = []
    for word in words:
        try:
            inventory_doc = inventory_module.load_approved_inventory(word)
        except inventory_module.InventoryError as exc:
            skipped.append(word)
            with print_lock:
                print(f"  ✗ {word}: 跳过 (没有可用的 approved Sense Inventory)\n"
                      f"    {str(exc).splitlines()[0]}", file=sys.stderr)
            continue
        sense_ids = inventory_module.inventory_sense_ids(inventory_doc)
        with print_lock:
            print(f"→ {word}: {len(sense_ids)} 个 approved sense "
                  f"({', '.join(sense_ids)})")
        for sense_id in sense_ids:
            tasks.append((word, sense_id.rsplit("-", 1)[1]))
    if not tasks:
        sys.exit("没有任何词具备 approved Sense Inventory; "
                 "先运行 tools/inventory.py draft/mark-reviewed/approve")

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
            ok, msg = _run_stage(["sense", sense_id], args.retries, args.sleep)
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
    all_ok = (not skipped and total_senses == total_senses_all
              and total_scenes == total_scenes_all)
    if skipped:
        print(f"\n⚠ {len(skipped)} 个词没有 approved Sense Inventory, 已跳过: "
              f"{', '.join(skipped)}", file=sys.stderr)
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

    p = sub.add_parser(
        "sense", help="按 approved Sense Inventory 起草单个词义 (参数是 sense ID)")
    p.add_argument("target", metavar="sense_id",
                   help="SceneLex sense ID, 如 slow-02 (必须已在 approved Inventory 中)")
    p.add_argument("--force", action="store_true", help="覆盖已存在的草稿")
    p.add_argument("--num", "-n", default=None,
                   help="[已弃用] 词典条目序号; 词典条目不是 SceneLex sense")
    p.add_argument("--legacy-dictionary-index", action="store_true",
                   help="[危险] 启用已弃用的 --num 路径, 产物写入 data/drafts/legacy-senses/")
    p.set_defaults(func=cmd_sense)

    p = sub.add_parser(
        "senses", help="按 approved Sense Inventory 起草整词的全部词义")
    p.add_argument("word")
    p.add_argument("--force", action="store_true", help="覆盖已存在的草稿")
    p.add_argument("--workers", type=int, default=1, help="并发起草的 sense 数 (默认 1)")
    p.set_defaults(func=cmd_senses)

    p = sub.add_parser("scenes", help="起草五场景组, 或用 --add 增补单个场景")
    p.add_argument("sense_id")
    p.add_argument("--add", choices=SCENE_ORDER, metavar="TYPE",
                   help="为已有义项增补一个指定类型的场景 (泛化扩证据)")
    p.set_defaults(func=cmd_scenes)

    sub.add_parser("list", help="列出待审草稿").set_defaults(func=cmd_list)

    p = sub.add_parser("promote", help="草稿定稿并校验 (模型审核可选, 不阻塞)")
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
