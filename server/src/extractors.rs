use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};

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

        Ok(Self(user))
    }
}
