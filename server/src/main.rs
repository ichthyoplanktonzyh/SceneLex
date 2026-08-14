use std::sync::Arc;

use scenelex_server::auth::email::LogEmailSender;
use scenelex_server::config::Config;
use scenelex_server::db;
use scenelex_server::routes;
use scenelex_server::state::AppState;
use sqlx::migrate::Migrator;
use sqlx::PgPool;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "scenelex_server=info,sqlx=warn".into()),
        )
        .init();

    dotenvy::dotenv().ok();

    let config = Config::from_env();
    let pool: PgPool = db::connect(&config.database_url).await.map_err(|e| {
        anyhow::anyhow!(
            "cannot connect to database at {}: {e}\n\
             Did you start local infrastructure? See docker/README.md",
            config.database_url
        )
    })?;

    let migrations_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../db/migrations");
    let migrator = Migrator::new(migrations_dir.as_path()).await?;
    tracing::info!("found {} migrations", migrator.migrations.len());
    migrator.run(&pool).await?;

    let state = AppState {
        pool,
        token_secret: Arc::new(config.token_secret),
        email_sender: Arc::new(LogEmailSender),
    };

    let app = axum::Router::new()
        .nest("/v1", routes::v1::router())
        .layer(
            // Local development CORS: any origin/method/header. Tighten this
            // to the web origin when deploying to the cloud (P6 follow-up).
            tower_http::cors::CorsLayer::permissive(),
        )
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&config.listen_addr).await?;
    tracing::info!("scenelex-server listening on http://{}", config.listen_addr);
    axum::serve(listener, app).await?;
    Ok(())
}
