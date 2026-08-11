use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;

use crate::auth::token;
use crate::auth::AuthUser;
use crate::state::AppState;

/// Bearer-token auth extractor.
pub struct Authenticated(pub AuthUser);

impl FromRequestParts<AppState> for Authenticated {
    type Rejection = Response;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let header = parts
            .headers
            .get(axum::http::header::AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .ok_or_else(|| StatusCode::UNAUTHORIZED.into_response())?;

        let token_str = header
            .strip_prefix("Bearer ")
            .ok_or_else(|| StatusCode::UNAUTHORIZED.into_response())?;

        let user = token::verify(token_str, &state.token_secret)
            .map_err(|_| StatusCode::UNAUTHORIZED.into_response())?;

        // Deleted accounts: stale tokens are rejected with 410 ACCOUNT_DELETED
        // (reference behavior; the tombstone also blocks re-registration).
        let deleted: Option<uuid::Uuid> = sqlx::query_scalar(
            "SELECT subject_key FROM auth.deleted_subjects WHERE subject_key = $1",
        )
        .bind(user.user_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR.into_response())?;
        if deleted.is_some() {
            return Err((
                StatusCode::GONE,
                Json(json!({ "error": "ACCOUNT_DELETED" })),
            )
                .into_response());
        }

        Ok(Self(user))
    }
}
