#!/usr/bin/env python3
"""离线导入 SceneLex 语义层资源(WordSense + canonical ExperienceProgram)到 server 数据库。

数据源:
- WordSense 元数据: data/senses/*.yaml(status=reviewed)
- canonical ExperienceProgram: tests/fixtures/experience-programs/*.yaml
  (status=reviewed/published; draft 一律拒绝)

幂等:身份使用 Contract v1 稳定字符串 ID(sense_key / program_id),重复运行只 upsert。
canonical 程序以整份 JSONB 写入 content.experience_program_documents(单一权威载体,
不再手工拆分一份易漂移的 stage/content 形状)。

用法:
    SCENELEX_DATABASE_URL=postgres://scenelex:scenelex@localhost:5432/scenelex \
        .venv/bin/python scripts/import_content.py
"""

import json
import os
import pathlib
import sys

import psycopg
import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tools"))
import experience_compiler as compiler  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parent.parent
SENSES_DIR = REPO / "data" / "senses"
PROGRAM_FIXTURES_DIR = REPO / "tests" / "fixtures" / "experience-programs"

DEFAULT_L1 = "zh"
REVIEWABLE_STATUSES = ("reviewed", "published")


def load_yaml(path: pathlib.Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def main() -> int:
    database_url = os.environ.get(
        "SCENELEX_DATABASE_URL",
        "postgres://scenelex:scenelex@localhost:5432/scenelex",
    )

    sense_files = sorted(SENSES_DIR.glob("*.yaml"))
    program_files = sorted(PROGRAM_FIXTURES_DIR.glob("*.yaml"))
    if not sense_files:
        print(f"no senses found in {SENSES_DIR}", file=sys.stderr)
        return 1

    with psycopg.connect(database_url) as conn:
        conn.autocommit = True
        imported_senses = 0
        imported_programs = 0
        imported_documents = 0

        for sense_file in sense_files:
            sense = load_yaml(sense_file)
            if sense.get("status") != "reviewed":
                print(f"skip {sense_file.name}: status={sense.get('status')}")
                continue

            sense_key = sense["id"]
            conn.execute(
                """
                INSERT INTO content.word_senses
                    (word_sense_id, sense_key, lemma, pos, semantic_type, locale_l1)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (sense_key) DO UPDATE SET
                    word_sense_id = EXCLUDED.word_sense_id,
                    lemma = EXCLUDED.lemma,
                    pos = EXCLUDED.pos,
                    semantic_type = EXCLUDED.semantic_type
                """,
                (
                    sense_key,
                    sense_key,
                    sense["word"],
                    sense.get("pos", ""),
                    sense.get("semantic_type", "unspecified"),
                    DEFAULT_L1,
                ),
            )
            imported_senses += 1

        for program_file in program_files:
            program = load_yaml(program_file)
            status = program.get("status")
            if status not in REVIEWABLE_STATUSES:
                print(
                    f"skip {program_file.name}: status={status} "
                    "(draft 内容禁止进入 server 内容通道)"
                )
                continue

            diagnostics = compiler.validate_program_file(program_file)
            if diagnostics:
                rendered = "\n".join(
                    f"  [{d.stage}] {d.path}: {d.message}" for d in diagnostics
                )
                print(
                    f"skip {program_file.name}: 未通过 Compiler 校验:\n{rendered}",
                    file=sys.stderr,
                )
                return 1

            target = program["target"]
            sense_key = target["sense_id"]
            program_id = program["program_id"]
            program_version = int(program["program_version"])
            metadata = program.get("metadata") or {}
            compiler_version = metadata.get("compiler_version", "1.0.0")

            conn.execute(
                """
                INSERT INTO content.experience_programs
                    (program_id, word_sense_id, program_version, compiler_version,
                     prompt_version, model_provider, quality_status)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (word_sense_id, program_version) DO UPDATE SET
                    program_id = EXCLUDED.program_id,
                    compiler_version = EXCLUDED.compiler_version,
                    quality_status = EXCLUDED.quality_status
                """,
                (
                    program_id,
                    sense_key,
                    program_version,
                    compiler_version,
                    str(metadata.get("prompt_versions", "import-script")),
                    metadata.get("model_provider", "none"),
                    status,
                ),
            )
            imported_programs += 1

            canonical_json = json.dumps(program, ensure_ascii=False)
            conn.execute(
                """
                INSERT INTO content.experience_program_documents
                    (program_id, canonical_json, status)
                VALUES (%s, %s, %s)
                ON CONFLICT (program_id) DO UPDATE SET
                    canonical_json = EXCLUDED.canonical_json,
                    status = EXCLUDED.status,
                    updated_at = now()
                """,
                (program_id, psycopg.types.json.Jsonb(program), status),
            )
            imported_documents += 1

        print(
            f"imported: {imported_senses} senses, {imported_programs} programs, "
            f"{imported_documents} canonical documents"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
