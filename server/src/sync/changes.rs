//! Hot-change log recording. Mirrors the reference: a compact log holding
//! identity + LWW metadata only; snapshots are materialized at pull time.

use chrono::{DateTime, Utc};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

/// Record a hot change inside the caller's transaction. Returns the change id.
pub async fn record_hot_change(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    entity_type: &str,
    entity_id: Uuid,
    replica_id: Uuid,
    operation_id: Uuid,
    client_updated_at: DateTime<Utc>,
) -> Result<i64, sqlx::Error> {
    // Serialize change_id allocation per workspace.
    sqlx::query(
        "INSERT INTO sync.workspace_sync_metadata (workspace_id)
         VALUES ($1)
         ON CONFLICT (workspace_id) DO UPDATE SET updated_at = now()",
    )
    .bind(workspace_id)
    .execute(&mut **tx)
    .await?;

    let change_id: i64 = sqlx::query_scalar(
        "INSERT INTO sync.hot_changes
            (workspace_id, entity_type, entity_id, action, replica_id, operation_id, client_updated_at)
         VALUES ($1, $2, $3, 'upsert', $4, $5, $6)
         RETURNING change_id",
    )
    .bind(workspace_id)
    .bind(entity_type)
    .bind(entity_id)
    .bind(replica_id)
    .bind(operation_id)
    .bind(client_updated_at)
    .fetch_one(&mut **tx)
    .await?;

    Ok(change_id)
}

/// Latest hot change id for a workspace (used as ack anchor).
pub async fn latest_change_id(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
) -> Result<Option<i64>, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT MAX(change_id) FROM sync.hot_changes WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
}
