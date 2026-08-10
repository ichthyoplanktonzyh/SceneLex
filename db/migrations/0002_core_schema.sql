-- SceneLex core schema: org / content / sync / auth.
-- Modeled on docs/v1/data-model-mapping.md (flashcards behavior reference).

-- ============================================================
-- org: users, workspaces, memberships
-- ============================================================

CREATE SCHEMA IF NOT EXISTS org;

CREATE TABLE org.users (
    user_id         UUID PRIMARY KEY,
    email           TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (email)
);

CREATE TABLE org.workspaces (
    workspace_id    UUID PRIMARY KEY,
    name            TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- FSRS scheduler settings (workspace level, mirrors flashcards org.workspaces).
    fsrs_algorithm                TEXT NOT NULL DEFAULT 'fsrs-6',
    fsrs_desired_retention        DOUBLE PRECISION NOT NULL DEFAULT 0.90,
    fsrs_learning_steps_minutes   JSONB NOT NULL DEFAULT '[1,10]',
    fsrs_relearning_steps_minutes JSONB NOT NULL DEFAULT '[10]',
    fsrs_maximum_interval_days    INTEGER NOT NULL DEFAULT 36500,
    fsrs_enable_fuzz              BOOLEAN NOT NULL DEFAULT true,
    -- LWW metadata for scheduler settings sync.
    fsrs_client_updated_at        TIMESTAMPTZ NOT NULL DEFAULT '1970-01-01T00:00:00Z',
    fsrs_last_modified_by_replica_id UUID,
    fsrs_last_operation_id        UUID,
    fsrs_updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (fsrs_algorithm = 'fsrs-6'),
    CHECK (fsrs_desired_retention > 0 AND fsrs_desired_retention < 1),
    CHECK (fsrs_maximum_interval_days >= 1)
);

CREATE TABLE org.user_settings (
    user_id            UUID PRIMARY KEY REFERENCES org.users(user_id) ON DELETE CASCADE,
    selected_workspace_id UUID REFERENCES org.workspaces(workspace_id) ON DELETE SET NULL,
    locale             TEXT,
    progress_time_zone TEXT NOT NULL DEFAULT 'UTC',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE org.workspace_memberships (
    workspace_id UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES org.users(user_id) ON DELETE CASCADE,
    role         TEXT NOT NULL DEFAULT 'owner',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, user_id),
    CHECK (role IN ('owner', 'member'))
);

-- ============================================================
-- content: word senses, programs, units, lists, learning states, review events
-- ============================================================

CREATE SCHEMA IF NOT EXISTS content;

CREATE TABLE content.word_senses (
    word_sense_id UUID PRIMARY KEY,
    sense_key     TEXT NOT NULL,
    lemma         TEXT NOT NULL,
    pos           TEXT NOT NULL,
    semantic_type TEXT NOT NULL,
    locale_l1     TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (sense_key)
);

CREATE TABLE content.experience_programs (
    program_id        UUID PRIMARY KEY,
    word_sense_id     UUID NOT NULL REFERENCES content.word_senses(word_sense_id) ON DELETE CASCADE,
    program_version   INTEGER NOT NULL,
    compiler_version  TEXT NOT NULL,
    prompt_version    TEXT NOT NULL,
    model_provider    TEXT NOT NULL,
    quality_status    TEXT NOT NULL DEFAULT 'draft',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (word_sense_id, program_version),
    CHECK (quality_status IN ('draft', 'reviewed', 'published'))
);

CREATE TABLE content.experience_units (
    experience_unit_id UUID PRIMARY KEY,
    program_id         UUID NOT NULL REFERENCES content.experience_programs(program_id) ON DELETE CASCADE,
    stage              TEXT NOT NULL,
    unit_type          TEXT NOT NULL,
    content            JSONB NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (stage IN ('anchor', 'variation', 'perturbation', 'discrimination', 'symbol_binding', 'l2_grounding', 'transfer')),
    CHECK (unit_type IN ('narrative', 'judgment', 'recall'))
);

-- Decks equivalent: smart filter lists (SceneLex word lists).
CREATE TABLE content.lists (
    list_id           UUID PRIMARY KEY,
    workspace_id      UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    name              TEXT NOT NULL,
    filter_definition JSONB NOT NULL DEFAULT '{}',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- LWW metadata.
    client_updated_at        TIMESTAMPTZ NOT NULL,
    last_modified_by_replica_id UUID,
    last_operation_id        UUID,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ
);

-- Per (workspace x word_sense) learning progress + FSRS state.
CREATE TABLE content.learning_states (
    learning_state_id UUID PRIMARY KEY,
    workspace_id      UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES org.users(user_id) ON DELETE CASCADE,
    word_sense_id     UUID NOT NULL REFERENCES content.word_senses(word_sense_id),
    status            TEXT NOT NULL DEFAULT 'active',

    due_at            TIMESTAMPTZ,
    reps              INTEGER NOT NULL DEFAULT 0,
    lapses            INTEGER NOT NULL DEFAULT 0,

    fsrs_stability       DOUBLE PRECISION,
    fsrs_difficulty      DOUBLE PRECISION,
    fsrs_last_reviewed_at TIMESTAMPTZ,
    fsrs_scheduled_days  INTEGER,
    fsrs_card_state      TEXT NOT NULL DEFAULT 'new',
    fsrs_step_index      INTEGER,

    client_updated_at        TIMESTAMPTZ NOT NULL,
    last_modified_by_replica_id UUID,
    last_operation_id        UUID,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (workspace_id, user_id, word_sense_id),
    CHECK (status IN ('active', 'suspended', 'retired')),
    CHECK (fsrs_card_state IN ('new', 'learning', 'review', 'relearning')),
    -- Invariants mirroring the reference: new must have no FSRS state.
    CHECK (
        (fsrs_card_state = 'new'
         AND due_at IS NULL
         AND fsrs_stability IS NULL
         AND fsrs_difficulty IS NULL
         AND fsrs_last_reviewed_at IS NULL
         AND fsrs_scheduled_days IS NULL
         AND fsrs_step_index IS NULL)
        OR fsrs_card_state <> 'new'
    )
);

CREATE INDEX learning_states_queue_idx ON content.learning_states (workspace_id, due_at)
    WHERE deleted_at IS NULL;

-- Append-only review history; dedup by (workspace, replica, client_event_id).
CREATE TABLE content.review_events (
    review_event_id    UUID PRIMARY KEY,
    workspace_id       UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    word_sense_id      UUID NOT NULL,
    program_version    INTEGER NOT NULL,
    experience_unit_id UUID NOT NULL,
    replica_id         UUID NOT NULL,
    client_event_id    UUID NOT NULL,
    rating             SMALLINT NOT NULL,
    reviewed_at_client TIMESTAMPTZ NOT NULL,
    reviewed_at_server TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_time_zone TEXT,
    reviewed_local_date DATE,
    review_sequence    BIGINT GENERATED BY DEFAULT AS IDENTITY,
    UNIQUE (workspace_id, replica_id, client_event_id),
    CHECK (rating IN (0, 1, 2, 3))
);
CREATE INDEX review_events_seq_idx ON content.review_events (workspace_id, review_sequence);

-- ============================================================
-- sync: installations, replicas, hot changes, idempotency ledger
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sync;

CREATE TABLE sync.installations (
    installation_id UUID PRIMARY KEY,
    user_id         UUID NOT NULL,
    platform        TEXT NOT NULL,
    app_version     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (platform IN ('ios', 'android', 'web', 'macos', 'windows', 'linux'))
);

CREATE TABLE sync.workspace_replicas (
    replica_id    UUID PRIMARY KEY,
    workspace_id  UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    user_id       UUID NOT NULL,
    actor_kind    TEXT NOT NULL,
    installation_id UUID,
    actor_key     TEXT,
    platform      TEXT NOT NULL,
    app_version   TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (workspace_id, installation_id),
    CHECK (actor_kind IN ('client_installation', 'workspace_seed', 'workspace_reset')),
    CHECK (
        (actor_kind = 'client_installation' AND installation_id IS NOT NULL AND actor_key IS NULL)
        OR (actor_kind <> 'client_installation' AND installation_id IS NULL AND actor_key IS NOT NULL)
    )
);

-- Compact hot-change log: identity + LWW metadata only; snapshots are read
-- from canonical tables at pull time.
CREATE TABLE sync.hot_changes (
    change_id        BIGINT GENERATED ALWAYS AS IDENTITY,
    workspace_id     UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    entity_type      TEXT NOT NULL,
    entity_id        UUID NOT NULL,
    action           TEXT NOT NULL DEFAULT 'upsert',
    replica_id       UUID,
    operation_id     UUID,
    client_updated_at TIMESTAMPTZ NOT NULL,
    recorded_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (change_id, workspace_id),
    CHECK (action = 'upsert')
);
CREATE INDEX hot_changes_entity_idx ON sync.hot_changes (workspace_id, entity_type, entity_id, change_id);
CREATE INDEX hot_changes_cursor_idx ON sync.hot_changes (workspace_id, change_id);

-- Push idempotency ledger (bounded by retention policy, none yet).
CREATE TABLE sync.applied_operations_current (
    workspace_id   UUID NOT NULL REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    replica_id     UUID NOT NULL,
    operation_id   UUID NOT NULL,
    operation_type TEXT NOT NULL,
    entity_type    TEXT NOT NULL,
    entity_id      UUID NOT NULL,
    client_updated_at TIMESTAMPTZ NOT NULL,
    resulting_hot_change_id BIGINT,
    applied_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (workspace_id, replica_id, operation_id, applied_at)
);

CREATE TABLE sync.workspace_sync_metadata (
    workspace_id UUID PRIMARY KEY REFERENCES org.workspaces(workspace_id) ON DELETE CASCADE,
    min_available_hot_change_id BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- auth: OTP challenges and rate limits
-- ============================================================

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE auth.otp_challenges (
    challenge_id  UUID PRIMARY KEY,
    user_id       UUID NOT NULL REFERENCES org.users(user_id) ON DELETE CASCADE,
    email         TEXT NOT NULL,
    code_hash     TEXT NOT NULL,
    expires_at    TIMESTAMPTZ NOT NULL,
    consumed_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX otp_challenges_user_idx ON auth.otp_challenges (user_id, created_at DESC);

CREATE TABLE auth.otp_send_events (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email        TEXT NOT NULL,
    ip_address   TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX otp_send_events_email_time_idx ON auth.otp_send_events (email, created_at);
CREATE INDEX otp_send_events_ip_time_idx ON auth.otp_send_events (ip_address, created_at);

CREATE TABLE auth.otp_verify_attempts (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    challenge_id UUID NOT NULL REFERENCES auth.otp_challenges(challenge_id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX otp_verify_attempts_challenge_idx ON auth.otp_verify_attempts (challenge_id, created_at);
