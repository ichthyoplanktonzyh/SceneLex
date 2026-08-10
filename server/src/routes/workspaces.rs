use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;
use crate::workspaces;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/workspaces", get(list).post(create))
        .route("/workspaces/{workspace_id}/select", post(select))
}

async fn list(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
) -> Result<Json<Value>, ApiError> {
    let selected: Option<Option<uuid::Uuid>> = sqlx::query_scalar(
        "SELECT selected_workspace_id FROM org.user_settings WHERE user_id = $1",
    )
    .bind(user.user_id)
    .fetch_optional(&state.pool)
    .await?;
    let selected = selected.flatten();

    let rows = workspaces::list_workspaces(&state.pool, user.user_id).await?;
    let items: Vec<Value> = rows
        .iter()
        .map(|w| {
            json!({
                "workspaceId": w.workspace_id,
                "name": w.name,
                "createdAt": w.created_at,
                "isSelected": Some(w.workspace_id) == selected,
            })
        })
        .collect();
    Ok(Json(json!({ "workspaces": items, "selectedWorkspaceId": selected })))
}

#[derive(Debug, Deserialize)]
struct CreateWorkspaceRequest {
    name: String,
}

async fn create(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Json(req): Json<CreateWorkspaceRequest>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    let name = req.name.trim();
    if name.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(json!({ "error": "workspace name must not be empty" })),
        ));
    }
    match workspaces::create_workspace(&state.pool, user.user_id, name).await {
        Ok(w) => Ok((
            StatusCode::CREATED,
            Json(json!({
                "workspaceId": w.workspace_id,
                "name": w.name,
                "createdAt": w.created_at,
                "isSelected": true,
            })),
        )),
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": e.to_string() })),
        )),
    }
}

async fn select(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    match workspaces::select_workspace(&state.pool, user.user_id, workspace_id).await {
        Ok(true) => Ok(Json(json!({ "workspaceId": workspace_id }))),
        Ok(false) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({ "error": "workspace not found" })),
        )),
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": e.to_string() })),
        )),
    }
}
