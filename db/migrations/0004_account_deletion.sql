-- Account deletion: tombstone for removed identities so stale tokens and
-- re-registration attempts are rejected. Mirrors the reference
-- deleted_subjects behavior: tokens for a deleted subject return
-- 410 ACCOUNT_DELETED, and the deleted email cannot re-register.

CREATE TABLE IF NOT EXISTS auth.deleted_subjects (
    subject_key UUID PRIMARY KEY,
    email       TEXT NOT NULL,
    deleted_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS deleted_subjects_email_idx
    ON auth.deleted_subjects (email);
