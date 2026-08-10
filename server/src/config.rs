use std::env;

/// Server configuration loaded from the environment.
#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub listen_addr: String,
    pub token_secret: String,
}

impl Config {
    pub fn from_env() -> Self {
        let database_url = env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://scenelex:scenelex@localhost:5432/scenelex".to_string());
        let host = env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
        let port = env::var("PORT").unwrap_or_else(|_| "8081".to_string());
        let token_secret = env::var("TOKEN_SECRET")
            .unwrap_or_else(|_| "scenelex-dev-secret-do-not-use-in-production".to_string());
        Self {
            database_url,
            listen_addr: format!("{host}:{port}"),
            token_secret,
        }
    }
}
