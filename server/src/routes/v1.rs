use axum::routing::get;
use axum::Router;

use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/health", get(super::health::get))
        .merge(super::auth::router())
        .merge(super::me::router())
        .merge(super::workspaces::router())
        .merge(super::sync::router())
        .merge(super::content::router())
        .merge(super::review::router())
}
