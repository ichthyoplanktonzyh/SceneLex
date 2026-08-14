//! Push: apply client outbox operations with idempotency + LWW.

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::AuthUser;
use crate::entities::{self, EntityType};
use crate::sync::replica;

#[derive(Debug, Clone, serde::Deserialize)]
pub struct PushRequest {
    #[serde(rename = "installationId")]
    pub installation_id: Uuid,
    #[serde(default)]
    pub platform: String,
    #[serde(rename = "appVersion", default)]
    pub app_version: Option<String>,
    pub operations: Vec<PushOperation>,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct PushOperation {
    #[serde(rename = "operationId")]
    pub operation_id: Uuid,
    #[serde(rename = "entityType")]
    pub entity_type: String,
    #[serde(rename = "entityId")]
    pub entity_id: String,
    #[serde(default)]
    pub action: String,
    #[serde(rename = "clientUpdatedAt")]
    pub client_updated_at: chrono::DateTime<chrono::Utc>,
    pub payload: Value,
}

pub struct PushOutcome {
    pub operation_id: Uuid,
    pub entity_type: String,
    pub entity_id: String,
    pub status: &'static str,
    pub resulting_hot_change_id: Option<i64>,
    pub error: Option<String>,
}

pub async fn process_push(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &PushRequest,
) -> Result<Vec<PushOutcome>, sqlx::Error> {
    let mut tx = pool.begin().await?;

    let replica_id = replica::ensure_workspace_replica_tx(
        &mut tx,
        workspace_id,
        user.user_id,
        req.installation_id,
        if req.platform.is_empty() {
            "web"
        } else {
            &req.platform
        },
        req.app_version.as_deref(),
    )
    .await?;

    let mut outcomes = Vec::with_capacity(req.operations.len());

    for op in &req.operations {
        let previous: Option<Option<i64>> = sqlx::query_scalar(
            "SELECT resulting_hot_change_id
             FROM sync.applied_operations_current
             WHERE workspace_id = $1 AND replica_id = $2 AND operation_id = $3
             ORDER BY applied_at DESC
             LIMIT 1",
        )
        .bind(workspace_id)
        .bind(replica_id)
        .bind(op.operation_id)
        .fetch_optional(&mut *tx)
        .await?;

        if let Some(Some(change_id)) = previous {
            outcomes.push(PushOutcome {
                operation_id: op.operation_id,
                entity_type: op.entity_type.clone(),
                entity_id: op.entity_id.clone(),
                status: "duplicate",
                resulting_hot_change_id: Some(change_id),
                error: None,
            });
            continue;
        }

        let (status, change_id, error) =
            match apply_operation(&mut tx, workspace_id, user, replica_id, op).await {
                Ok((applied, change_id)) => {
                    if applied {
                        ("applied", change_id, None)
                    } else {
                        // LWW loser: acknowledged so the client can advance its cursor.
                        ("ignored", None, None)
                    }
                }
                Err(e) => {
                    tracing::warn!(
                        "push operation rejected: entity={} entity_id={} err={}",
                        op.entity_type,
                        op.entity_id,
                        e
                    );
                    ("rejected", None, Some(e.to_string()))
                }
            };
        // Record the operation in the idempotency ledger (applied or not).
        if status == "applied" {
            sqlx::query(
                "INSERT INTO sync.applied_operations_current
                    (workspace_id, replica_id, operation_id, operation_type,
                     entity_type, entity_id, client_updated_at, resulting_hot_change_id)
                 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)",
            )
            .bind(workspace_id)
            .bind(replica_id)
            .bind(op.operation_id)
            .bind(&op.action)
            .bind(&op.entity_type)
            .bind(&op.entity_id)
            .bind(op.client_updated_at)
            .bind(change_id)
            .execute(&mut *tx)
            .await?;
        }

        outcomes.push(PushOutcome {
            operation_id: op.operation_id,
            entity_type: op.entity_type.clone(),
            entity_id: op.entity_id.clone(),
            status,
            resulting_hot_change_id: change_id,
            error,
        });
    }

    tx.commit().await?;
    Ok(outcomes)
}

/// Returns (applied, change_id).
async fn apply_operation(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    workspace_id: Uuid,
    user: &AuthUser,
    replica_id: Uuid,
    op: &PushOperation,
) -> Result<(bool, Option<i64>), sqlx::Error> {
    match op.entity_type.as_str() {
        "learning_state" => {
            entities::upsert_learning_state(
                tx,
                workspace_id,
                user.user_id,
                &op.entity_id,
                &op.payload,
                replica_id,
                op.operation_id,
            )
            .await
        }
        "list" => {
            let list_id = Uuid::parse_str(&op.entity_id)
                .map_err(|_| sqlx::Error::Protocol("list entityId must be a UUID".into()))?;
            entities::upsert_list(
                tx,
                workspace_id,
                list_id,
                &op.payload,
                replica_id,
                op.operation_id,
            )
            .await
        }
        "workspace_scheduler_settings" => {
            entities::upsert_workspace_settings(
                tx,
                workspace_id,
                &op.payload,
                replica_id,
                op.operation_id,
            )
            .await
        }
        "review_event" => {
            let (applied, _seq) =
                entities::append_review_event(tx, workspace_id, &op.payload, replica_id).await?;
            Ok((applied, None))
        }
        other => Err(sqlx::Error::Protocol(format!(
            "unknown entity type {other}"
        ))),
    }
}

pub fn operation_entity_type(s: &str) -> Option<EntityType> {
    match s {
        "learning_state" => Some(EntityType::LearningState),
        "list" => Some(EntityType::List),
        "workspace_scheduler_settings" => Some(EntityType::WorkspaceSchedulerSettings),
        _ => None,
    }
}

pub fn outcome_json(o: &PushOutcome) -> Value {
    json!({
        "operationId": o.operation_id,
        "entityType": o.entity_type,
        "entityId": o.entity_id,
        "status": o.status,
        "resultingHotChangeId": o.resulting_hot_change_id,
        "error": o.error,
    })
}
