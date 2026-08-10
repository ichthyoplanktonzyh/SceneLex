use axum::extract::{Path, State};
use axum::routing::post;
use axum::{Json, Router};
use serde_json::Value;

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::reviews;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new().route("/workspaces/{workspace_id}/review", post(submit_review))
}

async fn submit_review(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<reviews::ReviewRequest>,
) -> Result<Json<Value>, ApiError> {
    let member: Option<uuid::Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM org.workspace_memberships
         WHERE user_id = $1 AND workspace_id = $2",
    )
    .bind(user.user_id)
    .bind(workspace_id)
    .fetch_optional(&state.pool)
    .await?;
    if member.is_none() {
        return Err(ApiError::NotFound(format!(
            "workspace {workspace_id} not found for user {}",
            user.user_id
        )));
    }

    let result = reviews::submit_review(&state.pool, workspace_id, &user, &req).await?;
    Ok(Json(result))
}
