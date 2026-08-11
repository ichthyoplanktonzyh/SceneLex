-- Refresh-token store for session renewal (P0-2 B段).
-- Only the sha256 digest of the refresh token is stored, never the plaintext.
CREATE TABLE auth.refresh_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES org.users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX refresh_tokens_user_id_idx ON auth.refresh_tokens (user_id);
