#!/usr/bin/env python3
"""离线导入 SceneLex 语义层资源(WordSense + ExperienceProgram)到 server 数据库。

幂等:所有 id 由 sense_key 确定性派生(UUIDv5),重复运行只 upsert 不产生新行。
用法:
    SCENELEX_DATABASE_URL=postgres://scenelex:scenelex@localhost:5432/scenelex \
        .venv/bin/python scripts/import_content.py

注意:
- sense_key 与 id 的派生规则与 server 端(内容通道)约定一致,不可随意更改。
- 只导入 data/senses 中 status=reviewed 的义项及其 data/scenes 场景。
- 场景到前台 stage 的映射是 v1 占位语义(compiler 之后负责正式映射)。
"""

import hashlib
import os
import pathlib
import sys
import uuid

import psycopg
import yaml

REPO = pathlib.Path(__file__).resolve().parent.parent
SENSES_DIR = REPO / "data" / "senses"
SCENES_DIR = REPO / "data" / "scenes"

SENSE_NAMESPACE = uuid.UUID("6ba7b811-9dad-11d1-80b4-00c0-4fd4-30c8")
PROGRAM_NAMESPACE = uuid.UUID("6ba7b812-9dad-11d1-80b4-00c0-4fd4-30c8")
UNIT_NAMESPACE = uuid.UUID("6ba7b813-9dad-11d1-80b4-00c0-4fd4-30c8")

DEFAULT_L1 = "zh-Hans"

# 五类教学证据 -> 前台经验阶段(v1 占位映射)
STAGE_BY_SCENE_TYPE = {
    "proto": "anchor",
    "variation": "variation",
    "contrast": "discrimination",
    "counter": "perturbation",
    "boundary": "perturbation",
    "transfer": "transfer",
}


def v5(namespace: uuid.UUID, key: str) -> uuid.UUID:
    digest = hashlib.sha256(namespace.bytes + key.encode("utf-8")).digest()
    raw = bytearray(digest[:16])
    raw[6] = (raw[6] & 0x0F) | 0x50
    raw[8] = (raw[8] & 0x3F) | 0x80
    return uuid.UUID(bytes=bytes(raw))


def load_sense(path: pathlib.Path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def scene_unit_content(scene: dict) -> dict:
    """把已审核场景压缩为 ExperienceUnit 的 v1 内容载荷(JSONB)。"""
    return {
        "scene_id": scene.get("id"),
        "scene_type": scene.get("scene_type"),
        "title": scene.get("title"),
        "synopsis": scene.get("synopsis"),
        "storyboard": scene.get("storyboard"),
        "learning_tasks": scene.get("learning_tasks"),
        "contrast_target": scene.get("contrast_target"),
    }


def main() -> int:
    database_url = os.environ.get(
        "SCENELEX_DATABASE_URL",
        "postgres://scenelex:scenelex@localhost:5432/scenelex",
    )

    sense_files = sorted(SENSES_DIR.glob("*.yaml"))
    if not sense_files:
        print(f"no senses found in {SENSES_DIR}", file=sys.stderr)
        return 1

    with psycopg.connect(database_url) as conn:
        conn.autocommit = True
        imported_senses = 0
        imported_programs = 0
        imported_units = 0

        for sense_file in sense_files:
            sense = load_sense(sense_file)
            if sense.get("status") != "reviewed":
                print(f"skip {sense_file.name}: status={sense.get('status')}")
                continue

            sense_key = sense["id"]
            word_sense_id = v5(SENSE_NAMESPACE, sense_key)
            lemma = sense["word"]
            pos = sense.get("pos", "")
            semantic_type = sense.get("semantic_type", "unspecified")

            conn.execute(
                """
                INSERT INTO content.word_senses
                    (word_sense_id, sense_key, lemma, pos, semantic_type, locale_l1)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (sense_key) DO UPDATE SET
                    lemma = EXCLUDED.lemma,
                    pos = EXCLUDED.pos,
                    semantic_type = EXCLUDED.semantic_type
                """,
                (word_sense_id, sense_key, lemma, pos, semantic_type, DEFAULT_L1),
            )
            imported_senses += 1

            # 每个已审核义项生成 program v1(当前场景集作为 units)。
            program_id = v5(PROGRAM_NAMESPACE, f"{sense_key}:v1")
            conn.execute(
                """
                INSERT INTO content.experience_programs
                    (program_id, word_sense_id, program_version, compiler_version,
                     prompt_version, model_provider, quality_status)
                VALUES (%s, %s, 1, 'offline-import-v1', 'import-script', 'none', 'reviewed')
                ON CONFLICT (word_sense_id, program_version) DO UPDATE SET
                    quality_status = EXCLUDED.quality_status
                """,
                (program_id, word_sense_id),
            )
            imported_programs += 1

            scene_dir = SCENES_DIR / sense_key
            if not scene_dir.is_dir():
                print(f"  warn: no scenes dir for {sense_key}")
                continue

            for scene_file in sorted(scene_dir.glob("*.yaml")):
                scene = load_sense(scene_file)
                if scene.get("status") != "reviewed":
                    continue
                scene_id = scene["id"]
                unit_id = v5(UNIT_NAMESPACE, scene_id)
                stage = STAGE_BY_SCENE_TYPE.get(scene.get("scene_type"), "variation")
                content = scene_unit_content(scene)

                conn.execute(
                    """
                    INSERT INTO content.experience_units
                        (experience_unit_id, program_id, stage, unit_type, content)
                    VALUES (%s, %s, %s, 'narrative', %s)
                    ON CONFLICT (experience_unit_id) DO UPDATE SET
                        stage = EXCLUDED.stage,
                        content = EXCLUDED.content
                    """,
                    (unit_id, program_id, stage, psycopg.types.json.Jsonb(content)),
                )
                imported_units += 1

        print(
            f"imported: {imported_senses} senses, "
            f"{imported_programs} programs, {imported_units} units"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
