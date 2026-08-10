-- SceneLex database migrations (single source of truth, applied by the server at boot).
-- Phase 1: placeholder migration. Real schema lands in Phase 2 (auth, workspaces,
-- learning states, sync, content delivery) following docs/v1/data-model-mapping.md.
CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO schema_meta (key, value)
VALUES ('scenelex_phase', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
