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
        .route("/workspaces/{workspace_id}/rename", post(rename))
        .route(
            "/workspaces/{workspace_id}/delete-preview",
            get(delete_preview),
        )
        .route("/workspaces/{workspace_id}/delete", post(delete_workspace))
        .route(
            "/workspaces/{workspace_id}/reset-progress-preview",
            get(reset_progress_preview),
        )
        .route(
            "/workspaces/{workspace_id}/reset-progress",
            post(reset_progress),
        )
}

fn bad_request(message: &str) -> (StatusCode, Json<Value>) {
    (StatusCode::BAD_REQUEST, Json(json!({ "error": message })))
}

fn internal_error(error: impl std::fmt::Display) -> (StatusCode, Json<Value>) {
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({ "error": error.to_string() })),
    )
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
    Ok(Json(
        json!({ "workspaces": items, "selectedWorkspaceId": selected }),
    ))
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
        Err(e) => Err(internal_error(e)),
    }
}

#[derive(Debug, Deserialize)]
struct RenameWorkspaceRequest {
    name: String,
}

async fn rename(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<RenameWorkspaceRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let name = req.name.trim();
    if name.is_empty() {
        return Err(bad_request("workspace name must not be empty"));
    }
    match workspaces::rename_workspace(&state.pool, user.user_id, workspace_id, name).await {
        Ok(Some(w)) => Ok(Json(json!({
            "workspaceId": w.workspace_id,
            "name": w.name,
            "createdAt": w.created_at,
        }))),
        Ok(None) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({ "error": "workspace not found" })),
        )),
        Err(e) => Err(internal_error(e)),
    }
}

#[derive(Debug, Deserialize)]
struct WorkspaceConfirmationRequest {
    #[serde(rename = "confirmationText")]
    confirmation_text: String,
}

/// Owner + membership gate shared by the delete/reset actions and their
/// preview endpoints: the caller must be a member, and only the owner may
/// proceed. Returns `(is_sole_member)` for previews, and is a hard gate for
/// the mutating actions (owner AND sole member, mirroring the reference).
async fn gate_workspace_owner(
    state: &AppState,
    user_id: uuid::Uuid,
    workspace_id: uuid::Uuid,
) -> Result<bool, (StatusCode, Json<Value>)> {
    let role = workspaces::member_role(&state.pool, user_id, workspace_id)
        .await
        .map_err(internal_error)?;
    let Some((role_name, member_count)) = role else {
        return Err((
            StatusCode::NOT_FOUND,
            Json(json!({ "error": "workspace not found" })),
        ));
    };
    if role_name != "owner" {
        return Err((
            StatusCode::FORBIDDEN,
            Json(json!({ "error": "only the workspace owner can do this" })),
        ));
    }
    Ok(member_count == 1)
}

async fn require_owner_and_sole_member(
    state: &AppState,
    user_id: uuid::Uuid,
    workspace_id: uuid::Uuid,
) -> Result<(), (StatusCode, Json<Value>)> {
    let is_sole = gate_workspace_owner(state, user_id, workspace_id).await?;
    if !is_sole {
        return Err((
            StatusCode::FORBIDDEN,
            Json(json!({ "error": "workspace with other members cannot be modified" })),
        ));
    }
    Ok(())
}

async fn delete_preview(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let is_sole_member = gate_workspace_owner(&state, user.user_id, workspace_id).await?;
    match workspaces::delete_preview(&state.pool, workspace_id).await {
        Ok((learning_states, review_events, lists)) => Ok(Json(json!({
            "learningStates": learning_states,
            "reviewEvents": review_events,
            "lists": lists,
            "isSoleMember": is_sole_member,
        }))),
        Err(e) => Err(internal_error(e)),
    }
}

async fn reset_progress_preview(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let is_sole_member = gate_workspace_owner(&state, user.user_id, workspace_id).await?;
    match workspaces::reset_progress_preview(&state.pool, workspace_id).await {
        Ok((learning_states, review_events)) => Ok(Json(json!({
            "learningStatesToReset": learning_states,
            "reviewEventsToDelete": review_events,
            "isSoleMember": is_sole_member,
        }))),
        Err(e) => Err(internal_error(e)),
    }
}

async fn delete_workspace(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<WorkspaceConfirmationRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    if req.confirmation_text != workspaces::DELETE_WORKSPACE_CONFIRMATION {
        return Err(bad_request("type \"delete workspace\" exactly to confirm"));
    }
    require_owner_and_sole_member(&state, user.user_id, workspace_id).await?;
    match workspaces::delete_workspace(
        &state.pool,
        user.user_id,
        workspace_id,
        &req.confirmation_text,
    )
    .await
    {
        Ok(Some((workspace_id, next_selected, deleted_cards))) => Ok(Json(json!({
            "workspaceId": workspace_id,
            "deletedCardsCount": deleted_cards,
            "selectedWorkspaceId": next_selected,
        }))),
        Ok(None) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({ "error": "workspace not found" })),
        )),
        Err(e) => Err(internal_error(e)),
    }
}

async fn reset_progress(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Path(workspace_id): Path<uuid::Uuid>,
    Json(req): Json<WorkspaceConfirmationRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    if req.confirmation_text != workspaces::RESET_PROGRESS_CONFIRMATION {
        return Err(bad_request(
            "type \"reset all progress for all cards in this workspace\" exactly to confirm",
        ));
    }
    require_owner_and_sole_member(&state, user.user_id, workspace_id).await?;
    match workspaces::reset_workspace_progress(
        &state.pool,
        user.user_id,
        workspace_id,
        &req.confirmation_text,
    )
    .await
    {
        Ok(Some(cards_reset)) => Ok(Json(json!({
            "workspaceId": workspace_id,
            "cardsResetCount": cards_reset,
        }))),
        Ok(None) => Err((
            StatusCode::NOT_FOUND,
            Json(json!({ "error": "workspace not found" })),
        )),
        Err(e) => Err(internal_error(e)),
    }
}
