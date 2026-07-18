#!/usr/bin/env python3
"""SceneLex 模型审核 — 语言/场景/教学三层审核的执行器 (可选质量参考)。

审核不是管线的强制门: promote 不要求审核记录, 记录只作为人工判断的参考。
人工三层审核由模型审核替代 (AGENT.md 核心原则 6), 人工只做可选抽查。
审核模型通过 SCENELEX_REVIEW_LLM_* 环境变量单独配置 (逐项覆盖同名
SCENELEX_LLM_* 配置); 未配置时回退到起草模型, 并给出自我确认风险警告。

用法:
    python3 tools/review.py <sense_id>          # 审核草稿 (词义+场景组)
    python3 tools/review.py --all               # 审核草稿区全部义项
    python3 tools/review.py <sense_id> --show   # 查看已有审核记录

审核记录写入 data/drafts/reviews/{sense_id}.yaml, 含八维度结论、逐条问题
与草稿内容指纹 (content_digest)。promote 时若记录与当前内容匹配, 随资源
归档到 data/reviews/; 缺失或过期只提示, 不阻塞。verdict 在记录中表达,
退出码只表示审核流程本身是否出错。
"""

import argparse
import hashlib
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml

import draft
import llm

DIMENSIONS = [
    "language_accuracy",
    "semantic_conditions",
    "observability",
    "neighbor_discrimination",
    "audio_visual_timing",
    "l1_insight",
    "transferability",
    "licensing",
]

REVIEW_ENV_PREFIX = "SCENELEX_REVIEW_LLM_"


def apply_review_env():
    """把 SCENELEX_REVIEW_LLM_* 映射为 SCENELEX_LLM_*, 返回是否有覆盖。"""
    applied = False
    for key, val in list(os.environ.items()):
        if key.startswith(REVIEW_ENV_PREFIX):
            os.environ["SCENELEX_LLM_" + key[len(REVIEW_ENV_PREFIX):]] = val
            applied = True
    if not applied:
        print("⚠ 未配置 SCENELEX_REVIEW_LLM_*，审核将使用与起草相同的模型"
              "（自我确认风险，建议换用不同模型）", file=sys.stderr)
    return applied


def reviews_dir():
    return draft.DRAFTS / "reviews"


def record_path(sense_id):
    return reviews_dir() / f"{sense_id}.yaml"


def content_digest(paths):
    """对参与审核的草稿文件集计算稳定指纹, 供 promote 校验时效性。"""
    h = hashlib.sha256()
    for p in sorted(paths, key=lambda x: x.name):
        h.update(p.name.encode("utf-8"))
        h.update(b"\0")
        h.update(p.read_bytes())
        h.update(b"\0")
    return h.hexdigest()


def collect_targets(sense_id):
    """收集审核对象: (词义路径, 词义是否为草稿, 场景草稿列表)。"""
    sense_draft = draft.DRAFTS / "senses" / f"{sense_id}.yaml"
    sense_is_draft = sense_draft.exists()
    sense_path = sense_draft if sense_is_draft \
        else draft.ROOT / "data" / "senses" / f"{sense_id}.yaml"
    if not sense_path.exists():
        sys.exit(f"找不到义项 '{sense_id}' (草稿库与正式库均无)")

    scene_dir = draft.DRAFTS / "scenes" / sense_id
    scene_drafts = sorted(scene_dir.glob("*.yaml")) if scene_dir.exists() else []
    leftovers = [p for p in scene_drafts if p.name.startswith("_")]
    if leftovers:
        names = ", ".join(p.name for p in leftovers)
        print(f"⚠ 忽略未解析残骸: {names} (不参与审核, promote 前需处理)",
              file=sys.stderr)
    scene_drafts = [p for p in scene_drafts if not p.name.startswith("_")]

    if not sense_is_draft and not scene_drafts:
        sys.exit(f"'{sense_id}' 没有待审草稿 (词义与场景组均已定稿或不存在)")
    return sense_path, sense_is_draft, scene_drafts


def build_prompt(sense_id, sense_path, sense_is_draft, scene_drafts):
    template = draft.read(draft.PROMPTS / "review.md")
    sense_note = "（本身是待审草稿）" if sense_is_draft \
        else "（已定稿正式版，仅作审核上下文；本次只审场景草稿）"
    scenes = "\n\n".join(
        f"## {p.name}\n\n```yaml\n{draft.read(p)}```" for p in scene_drafts
    ) or "（本次无场景草稿，只审词义规格；场景相关维度按 scene_requirements 的可实现性评估。）"
    return (template
            .replace("{{TYPE_STRATEGY}}", draft.type_strategy(sense_path))
            .replace("{{SENSE_NOTE}}", sense_note)
            .replace("{{SENSE}}", draft.read(sense_path))
            .replace("{{SCENES}}", scenes))


def parse_verdict(raw, sense_id):
    """解析模型输出为 (dimensions, issues, summary); 失败时保存原文并退出。"""

    def bail(msg):
        reviews_dir().mkdir(parents=True, exist_ok=True)
        dump = reviews_dir() / f"_unparsed-{sense_id}.txt"
        dump.write_text(raw, encoding="utf-8")
        sys.exit(f"审核输出不合规: {msg}; 原文已存 {dump.relative_to(draft.ROOT)}")

    blocks = draft.extract_yaml_blocks(raw)
    if not blocks:
        bail("模型未返回 YAML 内容")
    try:
        doc = yaml.safe_load(blocks[0])
    except yaml.YAMLError as e:
        bail(f"YAML 解析失败: {e}")
    if not isinstance(doc, dict):
        bail("根节点必须是对象")

    dims = doc.get("dimensions")
    if not isinstance(dims, dict) or set(dims) != set(DIMENSIONS):
        bail(f"dimensions 必须恰好包含八个维度键 {DIMENSIONS}")
    for key, val in dims.items():
        if val not in ("pass", "fail"):
            bail(f"维度 {key} 的值必须是 pass 或 fail, 得到 {val!r}")

    issues = doc.get("issues")
    if issues is None:
        issues = []
    if not isinstance(issues, list):
        bail("issues 必须是数组")
    for i, item in enumerate(issues):
        if not isinstance(item, dict):
            bail(f"issues[{i}] 必须是对象")
        missing = {"file", "dimension", "severity", "note"} - set(item)
        if missing:
            bail(f"issues[{i}] 缺少字段 {sorted(missing)}")
        if item["dimension"] not in DIMENSIONS:
            bail(f"issues[{i}].dimension 非法: {item['dimension']!r}")
        if item["severity"] not in ("major", "minor"):
            bail(f"issues[{i}].severity 必须是 major 或 minor")

    # 一致性归一: 有 major 问题的维度强制 fail (不信任模型的自我汇总)
    for item in issues:
        if item["severity"] == "major":
            dims[item["dimension"]] = "fail"

    summary = doc.get("summary")
    if not isinstance(summary, str) or not summary.strip():
        bail("summary 必须是非空字符串")
    return dims, issues, summary.strip()


def run_review(sense_id):
    """执行一次审核并写记录, 返回 (verdict, 记录路径)。"""
    if not draft.SENSE_ID.fullmatch(sense_id):
        sys.exit(f"义项 ID '{sense_id}' 不符合 {{word}}-{{nn}} 约定")
    sense_path, sense_is_draft, scene_drafts = collect_targets(sense_id)
    reviewed = ([sense_path] if sense_is_draft else []) + scene_drafts

    prompt = build_prompt(sense_id, sense_path, sense_is_draft, scene_drafts)
    n = len(scene_drafts)
    print(f"→ 审核 '{sense_id}' (词义{'草稿' if sense_is_draft else '正式版'}"
          f" + {n} 个场景草稿) ...", file=sys.stderr)
    raw = llm.generate(prompt)
    dims, issues, summary = parse_verdict(raw, sense_id)

    verdict = "pass" if all(v == "pass" for v in dims.values()) else "fail"
    record = {
        "sense_id": sense_id,
        "reviewed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "review_model": os.environ.get("SCENELEX_LLM_MODEL", "unknown"),
        "files": [p.name for p in reviewed],
        "content_digest": content_digest(reviewed),
        "verdict": verdict,
        "dimensions": dims,
        "issues": issues,
        "summary": summary,
    }
    reviews_dir().mkdir(parents=True, exist_ok=True)
    out = record_path(sense_id)
    out.write_text(
        yaml.safe_dump(record, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )
    _print_record(record, out)
    return verdict, out


def _print_record(record, path):
    mark = "✓" if record["verdict"] == "pass" else "✗"
    print(f"{mark} {record['sense_id']}: {record['verdict']}"
          f" ({len(record['issues'])} 个问题)")
    for key, val in record["dimensions"].items():
        if val != "pass":
            print(f"  ✗ {key}")
    for item in record["issues"]:
        print(f"  [{item['severity']}] {item['file']} ({item['dimension']})"
              f" {item['note']}")
        if item.get("suggestion"):
            print(f"      → {item['suggestion']}")
    print(f"  {record['summary']}")
    print(f"  记录: {path.relative_to(draft.ROOT)}")


def draft_sense_ids():
    """草稿区全部义项 ID (词义草稿 ∪ 场景草稿目录)。"""
    ids = set()
    sense_dir = draft.DRAFTS / "senses"
    if sense_dir.exists():
        ids.update(p.stem for p in sense_dir.glob("*.yaml")
                   if not p.name.startswith("_"))
    scene_root = draft.DRAFTS / "scenes"
    if scene_root.exists():
        ids.update(d.name for d in scene_root.iterdir() if d.is_dir())
    return sorted(ids)


def cmd_show(sense_id):
    path = record_path(sense_id)
    if not path.exists():
        sys.exit(f"没有审核记录: {path.relative_to(draft.ROOT)}")
    _print_record(yaml.safe_load(draft.read(path)), path)


def main():
    parser = argparse.ArgumentParser(description="SceneLex 模型审核门")
    parser.add_argument("sense_id", nargs="?", help="要审核的义项 ID")
    parser.add_argument("--all", action="store_true", help="审核草稿区全部义项")
    parser.add_argument("--show", action="store_true", help="只查看已有审核记录")
    args = parser.parse_args()

    if args.show:
        if not args.sense_id:
            sys.exit("--show 需要指定义项 ID")
        cmd_show(args.sense_id)
        return

    if args.all:
        ids = draft_sense_ids()
        if not ids:
            print("草稿区为空, 无可审核对象。")
            return
        apply_review_env()
        failed = []
        for sense_id in ids:
            verdict, _ = run_review(sense_id)
            if verdict != "pass":
                failed.append(sense_id)
        print(f"\n共审核 {len(ids)} 个义项, 未通过 {len(failed)} 个"
              + (f": {', '.join(failed)}" if failed else ""))
        return

    if not args.sense_id:
        parser.error("需要义项 ID 或 --all")
    apply_review_env()
    run_review(args.sense_id)


if __name__ == "__main__":
    main()
