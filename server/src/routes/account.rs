use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::post;
use axum::{Json, Router};
use serde::Deserialize;
use uuid::Uuid;

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;

pub const DELETE_ACCOUNT_CONFIRMATION: &str = "delete my account";

pub fn router() -> Router<AppState> {
    Router::new().route("/account/delete", post(delete_account))
}

#[derive(Debug, Deserialize)]
struct DeleteAccountRequest {
    #[serde(rename = "confirmationText")]
    confirmation_text: String,
}

/// Deletes the account: sole-member workspaces cascade-delete (content +
/// sync data), then the user row cascades user_settings/memberships/OTP
/// challenges; the subject is tombstoned so old tokens get
/// 410 ACCOUNT_DELETED and the email cannot re-register.
async fn delete_account(
    State(state): State<AppState>,
    Authenticated(user): Authenticated,
    Json(req): Json<DeleteAccountRequest>,
) -> Result<StatusCode, ApiError> {
    if req.confirmation_text != DELETE_ACCOUNT_CONFIRMATION {
        return Err(ApiError::BadRequest(
            "type \"delete my account\" exactly to confirm".into(),
        ));
    }

    let mut tx = state.pool.begin().await?;

    let email: String = sqlx::query_scalar("SELECT email FROM org.users WHERE user_id = $1")
        .bind(user.user_id)
        .fetch_one(&mut *tx)
        .await?;

    // Sole-member workspaces are deleted (cascade: learning states, review
    // events, lists, sync metadata). Multi-member workspaces keep their data.
    let workspace_ids: Vec<Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM org.workspace_memberships WHERE user_id = $1",
    )
    .bind(user.user_id)
    .fetch_all(&mut *tx)
    .await?;
    for workspace_id in workspace_ids {
        let member_count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM org.workspace_memberships WHERE workspace_id = $1",
        )
        .bind(workspace_id)
        .fetch_one(&mut *tx)
        .await?;
        if member_count == 1 {
            sqlx::query("DELETE FROM org.workspaces WHERE workspace_id = $1")
                .bind(workspace_id)
                .execute(&mut *tx)
                .await?;
        }
    }

    // User row cascades: user_settings, memberships, learning states,
    // OTP challenges (and their verify attempts).
    sqlx::query("DELETE FROM org.users WHERE user_id = $1")
        .bind(user.user_id)
        .execute(&mut *tx)
        .await?;

    // Send-event log is keyed by email (no FK).
    sqlx::query("DELETE FROM auth.otp_send_events WHERE email = $1")
        .bind(&email)
        .execute(&mut *tx)
        .await?;

    // Tombstone: reject stale tokens and block re-registration.
    sqlx::query(
        "INSERT INTO auth.deleted_subjects (subject_key, email) VALUES ($1, $2)
         ON CONFLICT (subject_key) DO NOTHING",
    )
    .bind(user.user_id)
    .bind(&email)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(StatusCode::OK)
}
