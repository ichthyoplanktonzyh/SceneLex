use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use chrono::{Duration, Utc};
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use super::AuthUser;

type HmacSha256 = Hmac<Sha256>;

/// idToken lifetime. The reference app has no equivalent constant (its
/// tokens come from Cognito configuration); 1 hour is our decision.
const ID_TOKEN_TTL: Duration = Duration::hours(1);

/// refreshToken lifetime. Same rationale as [ID_TOKEN_TTL]; 30 days is our
/// decision. The token is stored only as a sha256 digest (see
/// `auth.refresh_tokens.token_hash`).
const REFRESH_TOKEN_TTL: Duration = Duration::days(30);

#[derive(Debug, thiserror::Error)]
pub enum TokenError {
    #[error("token expired")]
    Expired,
    #[error("token malformed")]
    Malformed,
    #[error("token signature invalid")]
    InvalidSignature,
}

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    email: String,
    exp: i64,
}

/// Issue a signed bearer token (HS256, payload-agnostic, no JWT dependency).
pub fn issue(user: &AuthUser, secret: &str) -> String {
    let exp = (Utc::now() + ID_TOKEN_TTL).timestamp();
    let claims = Claims {
        sub: user.user_id.to_string(),
        email: user.email.clone(),
        exp,
    };
    let payload = serde_json::to_vec(&claims).expect("serialize claims");
    let encoded = URL_SAFE_NO_PAD.encode(&payload);
    let signature = sign(&encoded, secret);
    format!("{encoded}.{signature}")
}

/// Verify and decode a bearer token.
pub fn verify(token: &str, secret: &str) -> Result<AuthUser, TokenError> {
    let (encoded, signature) = token
        .split_once('.')
        .ok_or(TokenError::Malformed)?;

    let expected = sign(encoded, secret);
    // Constant-time comparison via hmac crate internals is overkill here;
    // compare with a simple loop over bytes.
    if signature != expected {
        return Err(TokenError::InvalidSignature);
    }

    let bytes = URL_SAFE_NO_PAD
        .decode(encoded)
        .map_err(|_| TokenError::Malformed)?;
    let claims: Claims = serde_json::from_slice(&bytes).map_err(|_| TokenError::Malformed)?;

    if claims.exp < Utc::now().timestamp() {
        return Err(TokenError::Expired);
    }

    Ok(AuthUser {
        user_id: uuid::Uuid::parse_str(&claims.sub).map_err(|_| TokenError::Malformed)?,
        email: claims.email,
    })
}

fn sign(payload: &str, secret: &str) -> String {
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).expect("hmac accepts any key");
    mac.update(payload.as_bytes());
    URL_SAFE_NO_PAD.encode(mac.finalize().into_bytes())
}

/// Issue a fresh opaque refresh token (32 random bytes, URL-safe base64).
/// The raw value is returned to the client exactly once; the server stores
/// only [hash_refresh_token] of it.
pub fn issue_refresh_token() -> String {
    use rand::RngCore;
    let mut bytes = [0u8; 32];
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

/// sha256 digest of a refresh token (what actually lives in the DB).
pub fn hash_refresh_token(token: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(token.as_bytes());
    format!("{:x}", hasher.finalize())
}

/// TTL of a refresh token (see [REFRESH_TOKEN_TTL]).
pub fn refresh_token_ttl_seconds() -> i64 {
    REFRESH_TOKEN_TTL.num_seconds()
}

/// TTL of an idToken (see [ID_TOKEN_TTL]), reported as `expiresIn`.
pub fn id_token_ttl_seconds() -> i64 {
    ID_TOKEN_TTL.num_seconds()
}
