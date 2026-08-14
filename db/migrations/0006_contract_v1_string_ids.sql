-- Contract v1 stable string IDs + canonical program documents.
--
-- Pre-release migration: there is no production data. Content identity
-- (word_sense_id / program_id / experience_unit_id) moves from UUIDs to the
-- Contract v1 stable string IDs (e.g. 'reluctant-01', 'reluctant-01-program',
-- 'unit-1'). Sync metadata (replica_id / operation_id / hot change ids) stays
-- UUID/bigint — only content identity is textual.
--
-- Also adds content.experience_program_documents: a single canonical JSONB
-- carrier per program so the server can serve complete Contract v1 programs
-- without hand-reassembling a drifting old stage/content shape.

-- word_senses: identity becomes the stable sense_key string. FKs must be
-- dropped first: Postgres cannot alter a referenced column's type.
ALTER TABLE content.experience_programs
    DROP CONSTRAINT experience_programs_word_sense_id_fkey;
ALTER TABLE content.experience_units
    DROP CONSTRAINT experience_units_program_id_fkey;
ALTER TABLE content.word_senses ALTER COLUMN word_sense_id TYPE TEXT;

-- experience_programs: widen both columns, recreate FK.
ALTER TABLE content.experience_programs ALTER COLUMN program_id TYPE TEXT;
ALTER TABLE content.experience_programs ALTER COLUMN word_sense_id TYPE TEXT;
ALTER TABLE content.experience_programs
    ADD CONSTRAINT experience_programs_word_sense_id_fkey
    FOREIGN KEY (word_sense_id) REFERENCES content.word_senses(word_sense_id)
    ON DELETE CASCADE;

-- experience_units: same widening (table retained for compatibility; the
-- canonical program document is the content authority going forward).
ALTER TABLE content.experience_units ALTER COLUMN experience_unit_id TYPE TEXT;
ALTER TABLE content.experience_units ALTER COLUMN program_id TYPE TEXT;
ALTER TABLE content.experience_units
    ADD CONSTRAINT experience_units_program_id_fkey
    FOREIGN KEY (program_id) REFERENCES content.experience_programs(program_id)
    ON DELETE CASCADE;

-- learning_states: word_sense_id is Contract identity (FK to word_senses was
-- dropped in 0003).
ALTER TABLE content.learning_states ALTER COLUMN word_sense_id TYPE TEXT;

-- review_events: word_sense_id + experience_unit_id are Contract identity.
ALTER TABLE content.review_events ALTER COLUMN word_sense_id TYPE TEXT;
ALTER TABLE content.review_events ALTER COLUMN experience_unit_id TYPE TEXT;

-- sync identity lanes: entity_id carries both content ids (text) and list
-- ids (uuid-as-text).
ALTER TABLE sync.hot_changes ALTER COLUMN entity_id TYPE TEXT;
ALTER TABLE sync.applied_operations_current ALTER COLUMN entity_id TYPE TEXT;

-- Canonical program documents: the server content authority for Contract v1.
CREATE TABLE content.experience_program_documents (
    program_id     TEXT PRIMARY KEY
                   REFERENCES content.experience_programs(program_id)
                   ON DELETE CASCADE,
    canonical_json JSONB NOT NULL,
    status         TEXT NOT NULL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (status IN ('draft', 'reviewed', 'published'))
);
