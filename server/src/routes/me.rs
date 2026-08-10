use axum::extract::State;
use axum::routing::get;
use axum::{Json, Router};
use serde_json::json;

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;
use crate::workspaces;

pub fn router() -> Router<AppState> {
    Router::new().route("/me", get(get_me))
}

/// GET /v1/me: user profile + selected workspace (bootstrap on first request).
async fn get_me(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
) -> Result<Json<serde_json::Value>, ApiError> {
    let workspace_id = workspaces::ensure_user_bootstrap(&state.pool, &user).await?;
    let profile: (String, Option<String>, chrono::DateTime<chrono::Utc>) = sqlx::query_as(
        "SELECT u.email, s.locale, u.created_at
         FROM org.users u
         LEFT JOIN org.user_settings s ON s.user_id = u.user_id
         WHERE u.user_id = $1",
    )
    .bind(user.user_id)
    .fetch_one(&state.pool)
    .await?;

    Ok(Json(json!({
        "userId": user.user_id,
        "email": profile.0,
        "selectedWorkspaceId": workspace_id,
        "profile": {
            "email": profile.0,
            "locale": profile.1,
            "createdAt": profile.2,
        },
    })))
}
