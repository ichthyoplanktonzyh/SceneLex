use axum::extract::State;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::post;
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::json;

use crate::auth::otp::{self, OtpError};
use crate::auth::token;
use crate::auth::AuthUser;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/auth/send-code", post(send_code))
        .route("/auth/verify-code", post(verify_code))
        .route("/auth/refresh-token", post(refresh_token))
        .route("/auth/revoke-token", post(revoke_token))
}

#[derive(Debug, Deserialize)]
struct SendCodeRequest {
    email: String,
}

#[derive(Debug, Deserialize)]
struct VerifyCodeRequest {
    email: String,
    code: String,
}

#[derive(Debug, Deserialize)]
struct RefreshTokenRequest {
    // Optional field: a missing/empty token must surface as
    // REFRESH_TOKEN_MISSING (401), not as a JSON parse failure (400).
    #[serde(rename = "refreshToken", default)]
    refresh_token: String,
}

#[derive(Debug, Deserialize)]
struct RevokeTokenRequest {
    #[serde(rename = "refreshToken")]
    refresh_token: String,
}

impl IntoResponse for OtpError {
    fn into_response(self) -> Response {
        let status = match self {
            OtpError::RateLimited => StatusCode::TOO_MANY_REQUESTS,
            OtpError::AccountDeleted => StatusCode::GONE,
            _ => StatusCode::BAD_REQUEST,
        };
        (status, Json(json!({ "error": self.to_string() }))).into_response()
    }
}

/// Structured auth error: {"code": "...", "message": "..."} (C 段 uses the
/// code for localized messages; mirrors the reference jsonAuthError shape).
#[derive(Debug)]
struct AuthTokenError {
    status: StatusCode,
    code: &'static str,
    message: &'static str,
}

impl IntoResponse for AuthTokenError {
    fn into_response(self) -> Response {
        (
            self.status,
            Json(json!({ "code": self.code, "message": self.message })),
        )
            .into_response()
    }
}

const INVALID_REQUEST: AuthTokenError = AuthTokenError {
    status: StatusCode::BAD_REQUEST,
    code: "INVALID_REQUEST",
    message: "Invalid request.",
};
const REFRESH_TOKEN_MISSING: AuthTokenError = AuthTokenError {
    status: StatusCode::UNAUTHORIZED,
    code: "REFRESH_TOKEN_MISSING",
    message: "Sign in again.",
};
const REFRESH_TOKEN_FAILED: AuthTokenError = AuthTokenError {
    status: StatusCode::UNAUTHORIZED,
    code: "REFRESH_TOKEN_FAILED",
    message: "Sign in again.",
};
const REVOKE_TOKEN_MISSING: AuthTokenError = AuthTokenError {
    status: StatusCode::BAD_REQUEST,
    code: "REVOKE_TOKEN_MISSING",
    message: "Sign in again.",
};
const ACCOUNT_DELETED: AuthTokenError = AuthTokenError {
    status: StatusCode::GONE,
    code: "ACCOUNT_DELETED",
    message: "Account deleted.",
};

async fn send_code(
    State(state): State<AppState>,
    Json(req): Json<SendCodeRequest>,
) -> Result<StatusCode, OtpError> {
    otp::send_code(&state.pool, state.email_sender.as_ref(), &req.email, None).await?;
    Ok(StatusCode::OK)
}

async fn verify_code(
    State(state): State<AppState>,
    Json(req): Json<VerifyCodeRequest>,
) -> Result<Json<serde_json::Value>, OtpError> {
    let user: AuthUser = otp::verify_code(&state.pool, &req.email, &req.code).await?;
    let id_token = token::issue(&user, &state.token_secret);
    let refresh_token = token::issue_refresh_token();

    sqlx::query(
        "INSERT INTO auth.refresh_tokens (token_hash, user_id, expires_at)
         VALUES ($1, $2, $3)",
    )
    .bind(token::hash_refresh_token(&refresh_token))
    .bind(user.user_id)
    .bind(
        chrono::Utc::now()
            + chrono::Duration::seconds(token::refresh_token_ttl_seconds()),
    )
    .execute(&state.pool)
    .await
    .map_err(OtpError::Db)?;

    Ok(Json(json!({
        "idToken": id_token,
        "refreshToken": refresh_token,
        "expiresIn": token::id_token_ttl_seconds(),
        "user": { "userId": user.user_id, "email": user.email }
    })))
}

async fn refresh_token(
    State(state): State<AppState>,
    req: Result<Json<RefreshTokenRequest>, axum::extract::rejection::JsonRejection>,
) -> Result<Json<serde_json::Value>, AuthTokenError> {
    let Json(req) = req.map_err(|_| INVALID_REQUEST)?;
    if req.refresh_token.is_empty() {
        return Err(REFRESH_TOKEN_MISSING);
    }

    let token_hash = token::hash_refresh_token(&req.refresh_token);
    let row: Option<(uuid::Uuid, chrono::DateTime<chrono::Utc>, Option<chrono::DateTime<chrono::Utc>>)> =
        sqlx::query_as(
            "SELECT user_id, expires_at, revoked_at FROM auth.refresh_tokens WHERE token_hash = $1",
        )
        .bind(&token_hash)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| REFRESH_TOKEN_FAILED)?;

    let Some((user_id, expires_at, revoked_at)) = row else {
        return Err(REFRESH_TOKEN_FAILED);
    };
    if revoked_at.is_some() || expires_at < chrono::Utc::now() {
        return Err(REFRESH_TOKEN_FAILED);
    }

    // Deleted accounts: stale refresh tokens are rejected with 410
    // ACCOUNT_DELETED, matching the bearer-token extractor semantics.
    let deleted: Option<uuid::Uuid> = sqlx::query_scalar(
        "SELECT subject_key FROM auth.deleted_subjects WHERE subject_key = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|_| REFRESH_TOKEN_FAILED)?;
    if deleted.is_some() {
        return Err(ACCOUNT_DELETED);
    }

    let email: String = sqlx::query_scalar("SELECT email FROM org.users WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(&state.pool)
        .await
        .map_err(|_| REFRESH_TOKEN_FAILED)?;

    let user = AuthUser { user_id, email };
    let id_token = token::issue(&user, &state.token_secret);
    Ok(Json(json!({
        "idToken": id_token,
        "expiresIn": token::id_token_ttl_seconds(),
    })))
}

async fn revoke_token(
    State(state): State<AppState>,
    req: Result<Json<RevokeTokenRequest>, axum::extract::rejection::JsonRejection>,
) -> Result<Json<serde_json::Value>, AuthTokenError> {
    let Json(req) = req.map_err(|_| INVALID_REQUEST)?;
    if req.refresh_token.is_empty() {
        return Err(REVOKE_TOKEN_MISSING);
    }

    // Idempotent: revoking an already-revoked (or unknown) token is a no-op
    // that still answers 200, mirroring the reference logout contract.
    sqlx::query(
        "UPDATE auth.refresh_tokens SET revoked_at = now()
         WHERE token_hash = $1 AND revoked_at IS NULL",
    )
    .bind(token::hash_refresh_token(&req.refresh_token))
    .execute(&state.pool)
    .await
    .map_err(|_| REFRESH_TOKEN_FAILED)?;

    Ok(Json(json!({ "ok": true })))
}
