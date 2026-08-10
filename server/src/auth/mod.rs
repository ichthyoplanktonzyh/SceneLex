pub mod email;
pub mod otp;
pub mod token;

use serde::{Deserialize, Serialize};

/// Authenticated request identity.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthUser {
    pub user_id: uuid::Uuid,
    pub email: String,
}
