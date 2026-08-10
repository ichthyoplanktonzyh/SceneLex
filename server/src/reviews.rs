//! Online review submission: server computes FSRS, appends the review event,
//! and updates the learning state (single transaction, hot change emitted).
//! Phase 4 moves the computation client-side and uses the push protocol instead.

use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use scenelex_core::fsrs::{
    compute_review_schedule, FsrsCardState, ReviewRating, ScheduleState, SchedulerSettings,
};

use crate::auth::AuthUser;
use crate::entities;
use crate::sync::replica;

#[derive(Debug, Clone, serde::Deserialize)]
pub struct ReviewRequest {
    #[serde(rename = "installationId")]
    pub installation_id: Uuid,
    #[serde(default)]
    pub platform: String,
    #[serde(rename = "wordSenseId")]
    pub word_sense_id: Uuid,
    #[serde(rename = "experienceUnitId")]
    pub experience_unit_id: Uuid,
    #[serde(rename = "programVersion", default)]
    pub program_version: i32,
    pub rating: i32,
    #[serde(rename = "reviewedAtClient")]
    pub reviewed_at_client: DateTime<Utc>,
    #[serde(rename = "reviewedTimeZone", default)]
    pub reviewed_time_zone: Option<String>,
}

/// Current persisted FSRS state for a (workspace, user, word_sense).
async fn current_state(
    pool: &PgPool,
    workspace_id: Uuid,
    user_id: Uuid,
    word_sense_id: Uuid,
) -> Result<ScheduleState, sqlx::Error> {
    let row = sqlx::query_as::<_, (
        Option<DateTime<Utc>>,
        i32,
        i32,
        Option<f64>,
        Option<f64>,
        Option<DateTime<Utc>>,
        Option<i32>,
        String,
        Option<i32>,
    )>(
        "SELECT due_at, reps, lapses, fsrs_stability, fsrs_difficulty,
                fsrs_last_reviewed_at, fsrs_scheduled_days, fsrs_card_state, fsrs_step_index
         FROM content.learning_states
         WHERE workspace_id = $1 AND user_id = $2 AND word_sense_id = $3",
    )
    .bind(workspace_id)
    .bind(user_id)
    .bind(word_sense_id)
    .fetch_optional(pool)
    .await?;

    Ok(match row {
        None => ScheduleState {
            reps: 0,
            lapses: 0,
            fsrs_state: FsrsCardState::New,
            fsrs_step_index: None,
            fsrs_stability: None,
            fsrs_difficulty: None,
            fsrs_last_reviewed_at: None,
            fsrs_scheduled_days: None,
        },
        Some((
            _due,
            reps,
            lapses,
            stability,
            difficulty,
            last_reviewed,
            scheduled_days,
            state,
            step_index,
        )) => ScheduleState {
            reps: reps as i64,
            lapses: lapses as i64,
            fsrs_state: match state.as_str() {
                "learning" => FsrsCardState::Learning,
                "review" => FsrsCardState::Review,
                "relearning" => FsrsCardState::Relearning,
                _ => FsrsCardState::New,
            },
            fsrs_step_index: step_index.map(i64::from),
            fsrs_stability: stability,
            fsrs_difficulty: difficulty,
            fsrs_last_reviewed_at: last_reviewed,
            fsrs_scheduled_days: scheduled_days.map(i64::from),
        },
    })
}

async fn workspace_settings(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<SchedulerSettings, sqlx::Error> {
    let row = sqlx::query_as::<_, (f64, Value, Value, i32, bool)>(
        "SELECT fsrs_desired_retention, fsrs_learning_steps_minutes,
                fsrs_relearning_steps_minutes, fsrs_maximum_interval_days, fsrs_enable_fuzz
         FROM org.workspaces WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await?;
    let (retention, learning, relearning, max_interval, fuzz) = row;
    Ok(SchedulerSettings {
        desired_retention: retention,
        learning_steps_minutes: serde_json::from_value(learning).unwrap_or_default(),
        relearning_steps_minutes: serde_json::from_value(relearning).unwrap_or_default(),
        maximum_interval_days: max_interval as i64,
        enable_fuzz: fuzz,
    })
}

/// Submit a review: compute FSRS, append review event, update learning state.
pub async fn submit_review(
    pool: &PgPool,
    workspace_id: Uuid,
    user: &AuthUser,
    req: &ReviewRequest,
) -> Result<Value, sqlx::Error> {
    let rating = ReviewRating::from_i32(req.rating)
        .ok_or_else(|| sqlx::Error::Protocol("rating out of range".into()))?;

    let state = current_state(pool, workspace_id, user.user_id, req.word_sense_id).await?;
    let settings = workspace_settings(pool, workspace_id).await?;
    let next = compute_review_schedule(&state, &settings, rating, req.reviewed_at_client);

    let mut tx = pool.begin().await?;
    let replica_id = replica::ensure_workspace_replica_tx(
        &mut tx,
        workspace_id,
        user.user_id,
        req.installation_id,
        if req.platform.is_empty() { "web" } else { &req.platform },
        None,
    )
    .await?;

    let client_event_id = Uuid::new_v4();
    let review_payload = json!({
        "reviewEventId": client_event_id,
        "wordSenseId": req.word_sense_id,
        "programVersion": req.program_version,
        "experienceUnitId": req.experience_unit_id,
        "clientEventId": client_event_id,
        "rating": req.rating,
        "reviewedAtClient": req.reviewed_at_client,
        "reviewedTimeZone": req.reviewed_time_zone,
    });
    entities::append_review_event(&mut tx, workspace_id, &review_payload, replica_id).await?;

    let operation_id = Uuid::new_v4();
    let state_payload = json!({
        "learningStateId": Uuid::new_v4(),
        "wordSenseId": req.word_sense_id,
        "dueAt": next.due_at,
        "reps": next.reps,
        "lapses": next.lapses,
        "fsrsStability": next.fsrs_stability,
        "fsrsDifficulty": next.fsrs_difficulty,
        "fsrsLastReviewedAt": next.fsrs_last_reviewed_at,
        "fsrsScheduledDays": next.fsrs_scheduled_days,
        "fsrsCardState": match next.fsrs_state {
            FsrsCardState::New => "new",
            FsrsCardState::Learning => "learning",
            FsrsCardState::Review => "review",
            FsrsCardState::Relearning => "relearning",
        },
        "fsrsStepIndex": next.fsrs_step_index,
        "clientUpdatedAt": req.reviewed_at_client,
        "lastModifiedByReplicaId": replica_id,
        "lastOperationId": operation_id,
        "deletedAt": None::<DateTime<Utc>>,
    });
    entities::upsert_learning_state(
        &mut tx,
        workspace_id,
        user.user_id,
        req.word_sense_id,
        &state_payload,
        replica_id,
        operation_id,
    )
    .await?;

    tx.commit().await?;

    Ok(json!({
        "rating": req.rating,
        "reps": next.reps,
        "lapses": next.lapses,
        "fsrsCardState": match next.fsrs_state {
            FsrsCardState::New => "new",
            FsrsCardState::Learning => "learning",
            FsrsCardState::Review => "review",
            FsrsCardState::Relearning => "relearning",
        },
        "fsrsStepIndex": next.fsrs_step_index,
        "dueAt": next.due_at,
        "fsrsStability": next.fsrs_stability,
        "fsrsDifficulty": next.fsrs_difficulty,
        "fsrsScheduledDays": next.fsrs_scheduled_days,
    }))
}
