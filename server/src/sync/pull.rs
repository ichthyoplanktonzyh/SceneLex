//! Pull: incremental hot-state deltas since the client's cursor.

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::AuthUser;
use crate::entities;

#[derive(Debug, Clone, serde::Deserialize)]
pub struct PullRequest {
    #[serde(rename = "afterHotChangeId")]
    pub after_hot_change_id: i64,
    pub limit: i64,
}

pub async fn process_pull(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &PullRequest,
) -> Result<Value, sqlx::Error> {
    let limit = req.limit.clamp(1, 500);
    let after = req.after_hot_change_id;

    // Latest change per entity, then ascending by change_id.
    let rows = sqlx::query_as::<_, (i64, String, Uuid, chrono::DateTime<chrono::Utc>)>(
        "SELECT DISTINCT ON (entity_type, entity_id) change_id, entity_type, entity_id, client_updated_at
         FROM sync.hot_changes
         WHERE workspace_id = $1 AND change_id > $2
         ORDER BY entity_type, entity_id, change_id DESC",
    )
    .bind(workspace_id)
    .bind(after)
    .fetch_all(pool)
    .await?;

    let mut rows = rows;
    rows.sort_by_key(|(change_id, _, _, _)| *change_id);

    let has_more = rows.len() as i64 > limit;
    rows.truncate(limit as usize);

    let mut changes: Vec<Value> = Vec::with_capacity(rows.len());
    let mut next_hot_change_id = after;
    for (change_id, entity_type, entity_id, _ts) in rows {
        next_hot_change_id = change_id;
        let payload = match entity_type.as_str() {
            "learning_state" => entities::learning_state_snapshot(pool, workspace_id, user.user_id, entity_id).await?,
            "list" => entities::list_snapshot(pool, workspace_id, entity_id).await?,
            "workspace_scheduler_settings" => Some(entities::workspace_settings_snapshot(pool, workspace_id).await?),
            _ => None,
        };
        if let Some(payload) = payload {
            changes.push(json!({
                "changeId": change_id,
                "entityType": entity_type,
                "entityId": entity_id,
                "action": "upsert",
                "payload": payload,
            }));
        }
    }

    Ok(json!({
        "changes": changes,
        "nextHotChangeId": next_hot_change_id,
        "hasMore": has_more,
    }))
}
