use std::sync::Arc;

use sqlx::PgPool;

use crate::auth::email::EmailSender;

/// Shared application state for all handlers.
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub token_secret: Arc<String>,
    pub email_sender: Arc<dyn EmailSender>,
}
