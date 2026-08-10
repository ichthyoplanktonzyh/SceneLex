use axum::extract::{Path, State};
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};
use uuid::Uuid;

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/content/senses", get(list_senses))
        .route("/content/programs/{program_id}", get(get_program))
}

/// GET /v1/content/senses: published word senses with their current program version.
async fn list_senses(
    State(state): State<AppState>,
    Authenticated(_user): Authenticated,
) -> Result<Json<Value>, ApiError> {
    let rows = sqlx::query_as::<_, (Uuid, String, String, String, String, String, Option<i32>, Option<Uuid>)>(
        "SELECT s.word_sense_id, s.sense_key, s.lemma, s.pos, s.semantic_type, s.locale_l1,
                p.program_version, p.program_id
         FROM content.word_senses s
         LEFT JOIN LATERAL (
            SELECT program_id, program_version FROM content.experience_programs
            WHERE word_sense_id = s.word_sense_id AND quality_status = 'reviewed'
            ORDER BY program_version DESC LIMIT 1
         ) p ON true
         ORDER BY s.lemma ASC",
    )
    .fetch_all(&state.pool)
    .await?;

    let senses: Vec<Value> = rows
        .iter()
        .map(|(id, key, lemma, pos, semantic_type, l1, version, program_id)| {
            json!({
                "wordSenseId": id,
                "senseKey": key,
                "lemma": lemma,
                "pos": pos,
                "semanticType": semantic_type,
                "localeL1": l1,
                "programVersion": version,
                "programId": program_id,
            })
        })
        .collect();

    Ok(Json(json!({ "senses": senses })))
}

/// GET /v1/content/programs/{id}: full experience program (units included).
async fn get_program(
    State(state): State<AppState>,
    Authenticated(_user): Authenticated,
    Path(program_id): Path<Uuid>,
) -> Result<Json<Value>, ApiError> {
    let program = sqlx::query_as::<_, (Uuid, Uuid, i32, String, String, String, String)>(
        "SELECT program_id, word_sense_id, program_version, compiler_version,
                prompt_version, model_provider, quality_status
         FROM content.experience_programs WHERE program_id = $1",
    )
    .bind(program_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| ApiError::NotFound(format!("program {program_id} not found")))?;

    let units = sqlx::query_as::<_, (Uuid, String, String, Value)>(
        "SELECT experience_unit_id, stage, unit_type, content
         FROM content.experience_units WHERE program_id = $1 ORDER BY stage",
    )
    .bind(program_id)
    .fetch_all(&state.pool)
    .await?;

    let units: Vec<Value> = units
        .iter()
        .map(|(id, stage, unit_type, content)| {
            json!({
                "experienceUnitId": id,
                "stage": stage,
                "unitType": unit_type,
                "content": content,
            })
        })
        .collect();

    let (id, word_sense_id, version, compiler, prompt, provider, status) = program;
    Ok(Json(json!({
        "programId": id,
        "wordSenseId": word_sense_id,
        "programVersion": version,
        "compilerVersion": compiler,
        "promptVersion": prompt,
        "modelProvider": provider,
        "qualityStatus": status,
        "units": units,
    })))
}
