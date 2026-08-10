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

impl IntoResponse for OtpError {
    fn into_response(self) -> Response {
        let status = match self {
            OtpError::RateLimited => StatusCode::TOO_MANY_REQUESTS,
            _ => StatusCode::BAD_REQUEST,
        };
        (status, Json(json!({ "error": self.to_string() }))).into_response()
    }
}

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
    let token = token::issue(&user, &state.token_secret);
    Ok(Json(json!({
        "token": token,
        "user": { "userId": user.user_id, "email": user.email }
    })))
}
