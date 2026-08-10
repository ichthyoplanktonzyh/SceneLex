//! Bootstrap: first hydration of a workspace, dual mode.
//! pull mode: server -> client full snapshot with an opaque cursor.
//! push mode: client -> server initial seed when the remote workspace is empty.

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::AuthUser;
use crate::entities;

#[derive(Debug, Clone, serde::Deserialize)]
pub struct BootstrapRequest {
    pub mode: String,
    #[serde(default)]
    pub cursor: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub entries: Vec<Value>,
}

pub async fn process_bootstrap(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &BootstrapRequest,
) -> Result<Value, sqlx::Error> {
    let bootstrap_hot_change_id: i64 = sqlx::query_scalar(
        "SELECT COALESCE(MAX(change_id), 0) FROM sync.hot_changes WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await?;

    let (learning_count, list_count, review_count): (i64, i64, i64) = sqlx::query_as(
        "SELECT
            (SELECT count(*) FROM content.learning_states WHERE workspace_id = $1 AND deleted_at IS NULL),
            (SELECT count(*) FROM content.lists WHERE workspace_id = $1 AND deleted_at IS NULL),
            (SELECT count(*) FROM content.review_events WHERE workspace_id = $1)",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await?;
    let remote_is_empty = learning_count == 0 && list_count == 0 && review_count == 0;

    if req.mode == "push" {
        if !remote_is_empty {
            return Ok(json!({
                "error": "bootstrap push rejected: remote workspace is not empty",
                "mode": "push",
            }));
        }
        return bootstrap_push(pool, workspace_id, user, req, bootstrap_hot_change_id).await;
    }

    bootstrap_pull(pool, workspace_id, user, req, bootstrap_hot_change_id, remote_is_empty).await
}

/// pull mode: paged full snapshot ordered by (rank, entity_id).
/// rank 0 = scheduler settings (single row), 1 = learning states, 2 = lists.
async fn bootstrap_pull(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &BootstrapRequest,
    bootstrap_hot_change_id: i64,
    remote_is_empty: bool,
) -> Result<Value, sqlx::Error> {
    let limit = req.limit.unwrap_or(1000).clamp(1, 1000);
    let (rank, after_id) = match &req.cursor {
        None => (0i32, Uuid::nil()),
        Some(c) => {
            let parts: Vec<&str> = c.split(':').collect();
            if parts.len() == 2 {
                (
                    parts[0].parse().unwrap_or(0),
                    Uuid::parse_str(parts[1]).unwrap_or(Uuid::nil()),
                )
            } else {
                (0i32, Uuid::nil())
            }
        }
    };

    let mut entries: Vec<Value> = Vec::new();
    let mut next_cursor: Option<String> = None;
    let mut has_more = false;
    let mut current_rank = rank;
    let mut current_after = after_id;

    // Rank 0: workspace scheduler settings (emitted once per bootstrap).
    if current_rank == 0 && current_after == Uuid::nil() {
        let settings = entities::workspace_settings_snapshot(pool, workspace_id).await?;
        entries.push(json!({
            "entityType": "workspace_scheduler_settings",
            "entityId": workspace_id,
            "action": "upsert",
            "payload": settings,
        }));
        current_rank = 1;
        current_after = Uuid::nil();
    }

    // Rank 1: learning states (keyset by word_sense_id).
    if entries.len() < limit as usize && current_rank <= 1 {
        let want = (limit as usize - entries.len()) as i64 + 1;
        let rows = sqlx::query_as::<_, (Uuid,)>(
            "SELECT word_sense_id
             FROM content.learning_states
             WHERE workspace_id = $1 AND user_id = $2 AND deleted_at IS NULL
               AND word_sense_id > $3
             ORDER BY word_sense_id ASC
             LIMIT $4",
        )
        .bind(workspace_id)
        .bind(user.user_id)
        .bind(current_after)
        .bind(want)
        .fetch_all(pool)
        .await?;

        has_more = rows.len() as i64 > want - 1;
        let rows = rows.into_iter().take((want - 1) as usize).collect::<Vec<_>>();
        for (word_sense_id,) in &rows {
            if let Some(payload) =
                entities::learning_state_snapshot(pool, workspace_id, user.user_id, *word_sense_id).await?
            {
                entries.push(json!({
                    "entityType": "learning_state",
                    "entityId": word_sense_id,
                    "action": "upsert",
                    "payload": payload,
                }));
            }
        }
        if has_more {
            if let Some((last,)) = rows.last() {
                next_cursor = Some(format!("1:{last}"));
            }
        } else {
            current_rank = 2;
            current_after = Uuid::nil();
        }
    }

    // Rank 2: lists (keyset by list_id).
    if entries.len() < limit as usize && current_rank <= 2 {
        let want = (limit as usize - entries.len()) as i64 + 1;
        let rows = sqlx::query_as::<_, (Uuid,)>(
            "SELECT list_id
             FROM content.lists
             WHERE workspace_id = $1 AND deleted_at IS NULL
               AND list_id > $2
             ORDER BY list_id ASC
             LIMIT $3",
        )
        .bind(workspace_id)
        .bind(current_after)
        .bind(want)
        .fetch_all(pool)
        .await?;

        has_more = rows.len() as i64 > want - 1;
        let rows = rows.into_iter().take((want - 1) as usize).collect::<Vec<_>>();
        for (list_id,) in &rows {
            if let Some(payload) = entities::list_snapshot(pool, workspace_id, *list_id).await? {
                entries.push(json!({
                    "entityType": "list",
                    "entityId": list_id,
                    "action": "upsert",
                    "payload": payload,
                }));
            }
        }
        if has_more {
            if let Some((last,)) = rows.last() {
                next_cursor = Some(format!("2:{last}"));
            }
        }
    }

    Ok(json!({
        "mode": "pull",
        "entries": entries,
        "nextCursor": next_cursor,
        "hasMore": has_more,
        "bootstrapHotChangeId": bootstrap_hot_change_id,
        "remoteIsEmpty": remote_is_empty,
    }))
}

/// push mode: seed an empty remote workspace from the client's local state.
async fn bootstrap_push(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &BootstrapRequest,
    bootstrap_hot_change_id: i64,
) -> Result<Value, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let mut applied_count = 0i64;

    for entry in &req.entries {
        let entity_type = entry.get("entityType").and_then(|v| v.as_str()).unwrap_or("");
        let payload = entry.get("payload").cloned().unwrap_or_else(|| json!({}));
        let entity_id = entry
            .get("entityId")
            .and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok())
            .unwrap_or_else(Uuid::new_v4);
        let operation_id = payload
            .get("lastOperationId")
            .and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok())
            .unwrap_or_else(Uuid::new_v4);
        let replica_id = payload
            .get("lastModifiedByReplicaId")
            .and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok())
            .unwrap_or_else(Uuid::new_v4);

        let applied = match entity_type {
            "learning_state" => {
                entities::upsert_learning_state(
                    &mut tx,
                    workspace_id,
                    user.user_id,
                    entity_id,
                    &payload,
                    replica_id,
                    operation_id,
                )
                .await
            }
            "list" => {
                entities::upsert_list(
                    &mut tx,
                    workspace_id,
                    entity_id,
                    &payload,
                    replica_id,
                    operation_id,
                )
                .await
            }
            "workspace_scheduler_settings" => {
                entities::upsert_workspace_settings(
                    &mut tx,
                    workspace_id,
                    &payload,
                    replica_id,
                    operation_id,
                )
                .await
            }
            _ => Ok((false, None)),
        };
        if let Ok((true, _)) = applied {
            applied_count += 1;
        }
    }

    tx.commit().await?;
    Ok(json!({
        "mode": "push",
        "appliedEntriesCount": applied_count,
        "bootstrapHotChangeId": bootstrap_hot_change_id,
    }))
}
