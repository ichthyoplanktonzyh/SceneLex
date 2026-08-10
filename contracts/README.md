# SceneLex Contracts

Machine-readable contracts shared across the monorepo.

- **Rust types (source of truth for server/core):** `../core/src/domain/`
- **Flutter side:** Dart mirrors of the wire types live in `../app/` (Phase 2+, after
  the sync protocol is fixed)
- **OpenAPI:** generated from Rust types in Phase 2 (sync protocol, auth, content
  delivery), stored under `contracts/openapi/`
- **SceneLex semantic layer (unchanged, authoritative):** `../schema/` (word-sense,
  scene-spec, resource-bundle, sense-inventory)

Rule: change the contract first (core types), then implementations. Do not let a
client or server drift from these definitions.
