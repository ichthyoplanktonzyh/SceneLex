use axum::extract::{Path, State};
use axum::routing::get;
use axum::{Json, Router};
use serde_json::{json, Value};

use crate::error::ApiError;
use crate::extractors::Authenticated;
use crate::state::AppState;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/content/senses", get(list_senses))
        .route("/content/programs/{program_id}", get(get_program))
}

/// GET /v1/content/senses: canonical consumer catalog (snake_case Contract
/// identity). Each sense carries its currently released program link plus the
/// renderable WordSense summary (invariant + l1 confusables) extracted from
/// the canonical program document. Only reviewed/published programs qualify.
async fn list_senses(
    State(state): State<AppState>,
    Authenticated(_user): Authenticated,
) -> Result<Json<Value>, ApiError> {
    let rows = sqlx::query_as::<
        _,
        (
            String,
            String,
            String,
            String,
            String,
            String,
            Option<i32>,
            Option<String>,
        ),
    >(
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

    let mut senses: Vec<Value> = Vec::with_capacity(rows.len());
    for (id, key, lemma, pos, semantic_type, l1, version, program_id) in rows {
        let (invariant, confusables) = match &program_id {
            Some(pid) => extract_catalog_fields(&state, pid).await,
            None => (String::new(), Vec::new()),
        };
        senses.push(json!({
            "word_sense_id": id,
            "sense_key": key,
            "lemma": lemma,
            "pos": pos,
            "semantic_type": semantic_type,
            "locale_l1": l1,
            "invariant": invariant,
            "l1_confusables": confusables,
            "boundaries": [],
            "boundaries_status": "not_collected",
            "program_id": program_id,
            "program_version": version,
        }));
    }

    Ok(Json(json!({ "senses": senses })))
}

/// Extract renderable catalog fields from the canonical program document.
/// Compiler internals are never exposed; only the explicit consumer fields.
async fn extract_catalog_fields(state: &AppState, program_id: &str) -> (String, Vec<String>) {
    let row: Option<(Value,)> = sqlx::query_as(
        "SELECT canonical_json FROM content.experience_program_documents
         WHERE program_id = $1 AND status IN ('reviewed', 'published')",
    )
    .bind(program_id)
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten();

    match row {
        None => (String::new(), Vec::new()),
        Some((canonical,)) => {
            let semantic = canonical
                .get("semantic_model")
                .cloned()
                .unwrap_or_else(|| json!({}));
            let invariant = semantic
                .get("invariant")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            let confusables: Vec<String> = semantic
                .get("l1_interference")
                .and_then(|v| v.as_array())
                .map(|items| {
                    items
                        .iter()
                        .filter_map(|i| i.as_str().map(str::to_string))
                        .collect()
                })
                .unwrap_or_default();
            (invariant, confusables)
        }
    }
}

/// GET /v1/content/programs/{id}: the complete canonical ExperienceProgram
/// (Contract v1, snake_case) from the program document carrier. Only
/// reviewed/published documents are served; drafts never reach the App.
async fn get_program(
    State(state): State<AppState>,
    Authenticated(_user): Authenticated,
    Path(program_id): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let row = sqlx::query_as::<_, (Value,)>(
        "SELECT canonical_json FROM content.experience_program_documents
         WHERE program_id = $1 AND status IN ('reviewed', 'published')",
    )
    .bind(&program_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| ApiError::NotFound(format!("program {program_id} not found")))?;

    let (canonical,) = row;
    let status = canonical
        .get("status")
        .and_then(|v| v.as_str())
        .unwrap_or("draft");
    if status != "reviewed" && status != "published" {
        return Err(ApiError::NotFound(format!(
            "program {program_id} not found"
        )));
    }
    Ok(Json(canonical))
}
