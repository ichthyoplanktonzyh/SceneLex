//! Device identity: installations and workspace replicas.
//! replica_id is deterministically derived from (workspace, installation),
//! so the same installation always maps to the same replica in a workspace.

use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

pub const REPLICA_NAMESPACE: Uuid = Uuid::from_u128(0x6ba7_b810_9dad_11d1_80b4_00c0_4fd4_30c8);

pub fn replica_id_for(workspace_id: Uuid, installation_id: Uuid) -> Uuid {
    let key = format!("{workspace_id}:{installation_id}");
    Uuid::new_v5(&REPLICA_NAMESPACE, key.as_bytes())
}

/// Claim the installation and ensure a workspace replica row exists.
/// Returns the replica id.
pub async fn ensure_workspace_replica(
    pool: &PgPool,
    workspace_id: Uuid,
    user_id: Uuid,
    installation_id: Uuid,
    platform: &str,
    app_version: Option<&str>,
) -> Result<Uuid, sqlx::Error> {
    // Claim installation (upsert, keep user ownership).
    sqlx::query(
        "INSERT INTO sync.installations (installation_id, user_id, platform, app_version)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (installation_id) DO UPDATE SET
            platform = EXCLUDED.platform,
            app_version = EXCLUDED.app_version,
            last_seen_at = now()",
    )
    .bind(installation_id)
    .bind(user_id)
    .bind(platform)
    .bind(app_version)
    .execute(pool)
    .await?;

    let replica_id = replica_id_for(workspace_id, installation_id);
    sqlx::query(
        "INSERT INTO sync.workspace_replicas
            (replica_id, workspace_id, user_id, actor_kind, installation_id, platform, app_version)
         VALUES ($1, $2, $3, 'client_installation', $4, $5, $6)
         ON CONFLICT (replica_id) DO UPDATE SET
            user_id = EXCLUDED.user_id,
            platform = EXCLUDED.platform,
            app_version = EXCLUDED.app_version,
            last_seen_at = now()",
    )
    .bind(replica_id)
    .bind(workspace_id)
    .bind(user_id)
    .bind(installation_id)
    .bind(platform)
    .bind(app_version)
    .execute(pool)
    .await?;

    Ok(replica_id)
}

/// Same as `ensure_workspace_replica` but inside a transaction.
pub async fn ensure_workspace_replica_tx(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    user_id: Uuid,
    installation_id: Uuid,
    platform: &str,
    app_version: Option<&str>,
) -> Result<Uuid, sqlx::Error> {
    sqlx::query(
        "INSERT INTO sync.installations (installation_id, user_id, platform, app_version)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (installation_id) DO UPDATE SET
            platform = EXCLUDED.platform,
            app_version = EXCLUDED.app_version,
            last_seen_at = now()",
    )
    .bind(installation_id)
    .bind(user_id)
    .bind(platform)
    .bind(app_version)
    .execute(&mut **tx)
    .await?;

    let replica_id = replica_id_for(workspace_id, installation_id);
    sqlx::query(
        "INSERT INTO sync.workspace_replicas
            (replica_id, workspace_id, user_id, actor_kind, installation_id, platform, app_version)
         VALUES ($1, $2, $3, 'client_installation', $4, $5, $6)
         ON CONFLICT (replica_id) DO UPDATE SET
            user_id = EXCLUDED.user_id,
            platform = EXCLUDED.platform,
            app_version = EXCLUDED.app_version,
            last_seen_at = now()",
    )
    .bind(replica_id)
    .bind(workspace_id)
    .bind(user_id)
    .bind(installation_id)
    .bind(platform)
    .bind(app_version)
    .execute(&mut **tx)
    .await?;

    Ok(replica_id)
}
