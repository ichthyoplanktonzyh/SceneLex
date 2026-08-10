//! Email OTP auth, replicating the reference behaviour:
//! - auto-registration on send-code
//! - 8-digit codes, 3-minute lifetime, single use
//! - 5 failed attempts lock a challenge
//! - rate limits per email and per IP
//! - random response delay to reduce email enumeration

use chrono::{Duration, Utc};
use rand::Rng;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use super::email::EmailSender;
use super::AuthUser;

const CODE_LENGTH: usize = 8;
const CHALLENGE_TTL: Duration = Duration::minutes(3);
const MAX_VERIFY_ATTEMPTS: i64 = 5;

#[derive(Debug, thiserror::Error)]
pub enum OtpError {
    #[error("rate limited")]
    RateLimited,
    #[error("code expired. Request a new one.")]
    Expired,
    #[error("code already used. Request a new one.")]
    AlreadyUsed,
    #[error("too many invalid attempts. Request a new code.")]
    TooManyAttempts,
    #[error("invalid code")]
    InvalidCode,
    #[error("database error: {0}")]
    Db(#[from] sqlx::Error),
}

fn hash_code(code: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(code.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn generate_code() -> String {
    let mut rng = rand::thread_rng();
    (0..CODE_LENGTH)
        .map(|_| rng.gen_range(0..10).to_string())
        .collect()
}

async fn rate_limit_email(pool: &PgPool, email: &str) -> Result<(), OtpError> {
    let now = Utc::now();
    for (window_minutes, max) in [(1i64, 3i64), (15, 5), (24 * 60, 10)] {
        let since = now - Duration::minutes(window_minutes);
        let count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM auth.otp_send_events WHERE email = $1 AND created_at >= $2",
        )
        .bind(email)
        .bind(since)
        .fetch_one(pool)
        .await?;
        if count >= max {
            return Err(OtpError::RateLimited);
        }
    }
    Ok(())
}

async fn rate_limit_ip(pool: &PgPool, ip: Option<&str>) -> Result<(), OtpError> {
    let Some(ip) = ip else {
        return Ok(());
    };
    let now = Utc::now();
    for (window_minutes, max) in [(15i64, 10i64), (60, 30), (24 * 60, 100)] {
        let since = now - Duration::minutes(window_minutes);
        let count: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM auth.otp_send_events WHERE ip_address = $1 AND created_at >= $2",
        )
        .bind(ip)
        .bind(since)
        .fetch_one(pool)
        .await?;
        if count >= max {
            return Err(OtpError::RateLimited);
        }
    }
    Ok(())
}

/// Send an OTP to `email`, auto-registering the user if needed.
pub async fn send_code(
    pool: &PgPool,
    sender: &dyn EmailSender,
    email: &str,
    ip: Option<&str>,
) -> Result<(), OtpError> {
    let email = email.trim().to_lowercase();

    rate_limit_email(pool, &email).await?;
    rate_limit_ip(pool, ip).await?;

    // Auto-register: find or create the user.
    let user_id: Uuid = match sqlx::query_scalar(
        "SELECT user_id FROM org.users WHERE email = $1",
    )
    .bind(&email)
    .fetch_optional(pool)
    .await?
    {
        Some(id) => id,
        None => {
            let id = Uuid::new_v4();
            sqlx::query("INSERT INTO org.users (user_id, email) VALUES ($1, $2)")
                .bind(id)
                .bind(&email)
                .execute(pool)
                .await?;
            id
        }
    };

    let code = generate_code();
    let challenge_id = Uuid::new_v4();
    let expires_at = Utc::now() + CHALLENGE_TTL;
    sqlx::query(
        "INSERT INTO auth.otp_challenges (challenge_id, user_id, email, code_hash, expires_at)
         VALUES ($1, $2, $3, $4, $5)",
    )
    .bind(challenge_id)
    .bind(user_id)
    .bind(&email)
    .bind(hash_code(&code))
    .bind(expires_at)
    .execute(pool)
    .await?;

    sqlx::query("INSERT INTO auth.otp_send_events (email, ip_address) VALUES ($1, $2)")
        .bind(&email)
        .bind(ip)
        .execute(pool)
        .await?;

    sender.send_otp(&email, &code).await;

    // Anti-enumeration: uniform-ish random delay 200-800ms.
    let delay_ms = rand::thread_rng().gen_range(200..=800u64);
    tokio::time::sleep(std::time::Duration::from_millis(delay_ms)).await;

    Ok(())
}

/// Verify an OTP and return the authenticated user.
pub async fn verify_code(
    pool: &PgPool,
    email: &str,
    code: &str,
) -> Result<AuthUser, OtpError> {
    let email = email.trim().to_lowercase();

    let challenge = sqlx::query_as::<_, (Uuid, Uuid, String, chrono::DateTime<Utc>, Option<chrono::DateTime<Utc>>)>(
        "SELECT challenge_id, user_id, code_hash, expires_at, consumed_at
         FROM auth.otp_challenges
         WHERE email = $1
         ORDER BY created_at DESC
         LIMIT 1",
    )
    .bind(&email)
    .fetch_optional(pool)
    .await?;

    let Some((challenge_id, user_id, code_hash, expires_at, consumed_at)) = challenge else {
        return Err(OtpError::Expired);
    };

    if consumed_at.is_some() {
        return Err(OtpError::AlreadyUsed);
    }
    if expires_at < Utc::now() {
        return Err(OtpError::Expired);
    }

    let attempts: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM auth.otp_verify_attempts WHERE challenge_id = $1",
    )
    .bind(challenge_id)
    .fetch_one(pool)
    .await?;
    if attempts >= MAX_VERIFY_ATTEMPTS {
        return Err(OtpError::TooManyAttempts);
    }

    if hash_code(code.trim()) != code_hash {
        sqlx::query("INSERT INTO auth.otp_verify_attempts (challenge_id) VALUES ($1)")
            .bind(challenge_id)
            .execute(pool)
            .await?;
        return Err(OtpError::InvalidCode);
    }

    sqlx::query("UPDATE auth.otp_challenges SET consumed_at = now() WHERE challenge_id = $1")
        .bind(challenge_id)
        .execute(pool)
        .await?;

    let email_row: String = sqlx::query_scalar("SELECT email FROM org.users WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(pool)
        .await?;

    Ok(AuthUser {
        user_id,
        email: email_row,
    })
}
