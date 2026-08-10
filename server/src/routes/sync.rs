use axum::extract::{Path, State};
use axum::routing::post;
use axum::{Json, Router};
use serde_json::{json, Value};

use crate::auth::AuthUser;
use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;
use crate::sync::{bootstrap, pull, push, review_history};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/workspaces/{workspace_id}/sync/push", post(sync_push))
        .route("/workspaces/{workspace_id}/sync/pull", post(sync_pull))
        .route("/workspaces/{workspace_id}/sync/bootstrap", post(sync_bootstrap))
        .route(
            "/workspaces/{workspace_id}/sync/review-history/pull",
            post(sync_review_history_pull),
        )
}

/// Verify workspace membership, returning an error for non-members.
async fn check_workspace_access(
    state: &AppState,
    user_id: uuid::Uuid,
    workspace_id: uuid::Uuid,
) -> Result<(), ApiError> {
    let member: Option<uuid::Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM org.workspace_memberships
         WHERE user_id = $1 AND workspace_id = $2",
    )
    .bind(user_id)
    .bind(workspace_id)
    .fetch_optional(&state.pool)
    .await?;
    match member {
        Some(_) => Ok(()),
        None => Err(ApiError::NotFound(format!(
            "workspace {workspace_id} not found for user {user_id}"
        ))),
    }
}

async fn sync_push(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<push::PushRequest>,
) -> Result<Json<Value>, ApiError> {
    check_workspace_access(&state, user.user_id, workspace_id).await?;
    let outcomes = push::process_push(&state.pool, workspace_id, &user, &req).await?;
    let operations: Vec<Value> = outcomes.iter().map(push::outcome_json).collect();
    Ok(Json(json!({ "operations": operations })))
}

async fn sync_pull(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<pull::PullRequest>,
) -> Result<Json<Value>, ApiError> {
    check_workspace_access(&state, user.user_id, workspace_id).await?;
    let result = pull::process_pull(&state.pool, workspace_id, &user, &req).await?;
    Ok(Json(result))
}

async fn sync_bootstrap(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<bootstrap::BootstrapRequest>,
) -> Result<Json<Value>, ApiError> {
    check_workspace_access(&state, user.user_id, workspace_id).await?;
    let result = bootstrap::process_bootstrap(&state.pool, workspace_id, &user, &req).await?;
    Ok(Json(result))
}

async fn sync_review_history_pull(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<review_history::ReviewHistoryRequest>,
) -> Result<Json<Value>, ApiError> {
    check_workspace_access(&state, user.user_id, workspace_id).await?;
    let result = review_history::process_review_history_pull(&state.pool, workspace_id, &req).await?;
    Ok(Json(result))
}

// Keep AuthUser import used (check_workspace_access takes user_id).
#[allow(unused_imports)]
use AuthUser as _AuthUserAlias;
