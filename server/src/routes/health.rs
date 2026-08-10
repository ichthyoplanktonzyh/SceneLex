use axum::Json;
use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct Health {
    pub status: &'static str,
    pub service: &'static str,
}

pub async fn get() -> Json<Health> {
    Json(Health {
        status: "ok",
        service: "scenelex-server",
    })
}
