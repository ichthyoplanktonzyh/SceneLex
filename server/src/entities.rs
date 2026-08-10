//! Canonical entity writes and snapshot materialization for the sync layer.
//! Entity types: learning_state, list, workspace_scheduler_settings, review_event.

use chrono::{DateTime, Utc};
use serde_json::{json, Value};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::sync::changes::record_hot_change;
use crate::sync::lww::{incoming_lww_wins, LwwMetadata};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntityType {
    LearningState,
    List,
    WorkspaceSchedulerSettings,
}

impl EntityType {
    pub fn as_str(&self) -> &'static str {
        match self {
            EntityType::LearningState => "learning_state",
            EntityType::List => "list",
            EntityType::WorkspaceSchedulerSettings => "workspace_scheduler_settings",
        }
    }
}

fn get_str<'a>(payload: &'a Value, key: &str) -> Option<&'a str> {
    payload.get(key).and_then(|v| v.as_str())
}

fn get_uuid(payload: &Value, key: &str) -> Option<Uuid> {
    get_str(payload, key).and_then(|s| Uuid::parse_str(s).ok())
}

fn get_i64(payload: &Value, key: &str) -> Option<i64> {
    payload.get(key).and_then(|v| v.as_i64())
}

fn get_f64(payload: &Value, key: &str) -> Option<f64> {
    payload.get(key).and_then(|v| v.as_f64())
}

fn get_dt(payload: &Value, key: &str) -> Option<DateTime<Utc>> {
    get_str(payload, key).and_then(|s| DateTime::parse_from_rfc3339(s).ok().map(|d| d.with_timezone(&Utc)))
}

fn get_bool(payload: &Value, key: &str) -> Option<bool> {
    payload.get(key).and_then(|v| v.as_bool())
}

fn lww_from(payload: &Value) -> Option<LwwMetadata> {
    Some(LwwMetadata {
        client_updated_at: get_dt(payload, "clientUpdatedAt")?,
        last_modified_by_replica_id: get_uuid(payload, "lastModifiedByReplicaId")?,
        last_operation_id: get_uuid(payload, "lastOperationId")?,
    })
}

async fn current_lww(
    tx: &mut Transaction<'_, Postgres>,
    table: &str,
    id_column: &str,
    workspace_id: Uuid,
    entity_id: Uuid,
) -> Result<Option<LwwMetadata>, sqlx::Error> {
    let sql = format!(
        "SELECT client_updated_at, last_modified_by_replica_id, last_operation_id
         FROM {table} WHERE workspace_id = $1 AND {id_column} = $2"
    );
    Ok(sqlx::query_as::<_, (DateTime<Utc>, Uuid, Uuid)>(&sql)
        .bind(workspace_id)
        .bind(entity_id)
        .fetch_optional(&mut **tx)
        .await?
        .map(|(client_updated_at, replica, op)| LwwMetadata {
            client_updated_at,
            last_modified_by_replica_id: replica,
            last_operation_id: op,
        }))
}

/// Upsert a learning_state snapshot under LWW. Returns (applied, change_id).
pub async fn upsert_learning_state(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    user_id: Uuid,
    entity_id: Uuid,
    payload: &Value,
    replica_id: Uuid,
    operation_id: Uuid,
) -> Result<(bool, Option<i64>), sqlx::Error> {
    let word_sense_id = get_uuid(payload, "wordSenseId").ok_or(sqlx::Error::Protocol("learning_state payload missing wordSenseId".into()))?;
    let incoming = lww_from(payload).ok_or(sqlx::Error::Protocol("learning_state payload missing LWW metadata".into()))?;

    let existing = sqlx::query_as::<_, (Option<DateTime<Utc>>, Option<Uuid>, Option<Uuid>, Uuid)>(
        "SELECT client_updated_at, last_modified_by_replica_id, last_operation_id, learning_state_id
         FROM content.learning_states
         WHERE workspace_id = $1 AND user_id = $2 AND word_sense_id = $3",
    )
    .bind(workspace_id)
    .bind(user_id)
    .bind(word_sense_id)
    .fetch_optional(&mut **tx)
    .await?;

    let current = existing.as_ref().map(|(t, r, o, _)| LwwMetadata {
        client_updated_at: t.unwrap_or(incoming.client_updated_at),
        last_modified_by_replica_id: r.unwrap_or(incoming.last_modified_by_replica_id),
        last_operation_id: o.unwrap_or(incoming.last_operation_id),
    });

    if !incoming_lww_wins(&incoming, current.as_ref()) {
        return Ok((false, None));
    }

    let payload_state_id = get_uuid(payload, "learningStateId").unwrap_or(entity_id);
    let row_id = existing
        .as_ref()
        .map(|(_, _, _, id)| *id)
        .unwrap_or(payload_state_id);
    let due_at = get_dt(payload, "dueAt");
    let deleted_at = get_dt(payload, "deletedAt");

    sqlx::query(
        "INSERT INTO content.learning_states
            (learning_state_id, workspace_id, user_id, word_sense_id,
             due_at, reps, lapses,
             fsrs_stability, fsrs_difficulty, fsrs_last_reviewed_at, fsrs_scheduled_days,
             fsrs_card_state, fsrs_step_index,
             client_updated_at, last_modified_by_replica_id, last_operation_id, deleted_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
         ON CONFLICT (workspace_id, user_id, word_sense_id) DO UPDATE SET
            learning_state_id = EXCLUDED.learning_state_id,
            due_at = EXCLUDED.due_at,
            reps = EXCLUDED.reps,
            lapses = EXCLUDED.lapses,
            fsrs_stability = EXCLUDED.fsrs_stability,
            fsrs_difficulty = EXCLUDED.fsrs_difficulty,
            fsrs_last_reviewed_at = EXCLUDED.fsrs_last_reviewed_at,
            fsrs_scheduled_days = EXCLUDED.fsrs_scheduled_days,
            fsrs_card_state = EXCLUDED.fsrs_card_state,
            fsrs_step_index = EXCLUDED.fsrs_step_index,
            client_updated_at = EXCLUDED.client_updated_at,
            last_modified_by_replica_id = EXCLUDED.last_modified_by_replica_id,
            last_operation_id = EXCLUDED.last_operation_id,
            deleted_at = EXCLUDED.deleted_at",
    )
    .bind(row_id)
    .bind(workspace_id)
    .bind(user_id)
    .bind(word_sense_id)
    .bind(due_at)
    .bind(get_i64(payload, "reps").unwrap_or(0))
    .bind(get_i64(payload, "lapses").unwrap_or(0))
    .bind(get_f64(payload, "fsrsStability"))
    .bind(get_f64(payload, "fsrsDifficulty"))
    .bind(get_dt(payload, "fsrsLastReviewedAt"))
    .bind(get_i64(payload, "fsrsScheduledDays"))
    .bind(get_str(payload, "fsrsCardState").unwrap_or("new"))
    .bind(get_i64(payload, "fsrsStepIndex"))
    .bind(incoming.client_updated_at)
    .bind(incoming.last_modified_by_replica_id)
    .bind(incoming.last_operation_id)
    .bind(deleted_at)
    .execute(&mut **tx)
    .await?;

    let change_id = record_hot_change(
        tx,
        workspace_id,
        EntityType::LearningState.as_str(),
        word_sense_id,
        replica_id,
        operation_id,
        incoming.client_updated_at,
    )
    .await?;
    Ok((true, Some(change_id)))
}

/// Upsert a list (word list / smart filter). Returns (applied, change_id).
pub async fn upsert_list(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    entity_id: Uuid,
    payload: &Value,
    replica_id: Uuid,
    operation_id: Uuid,
) -> Result<(bool, Option<i64>), sqlx::Error> {
    let incoming = lww_from(payload).ok_or(sqlx::Error::Protocol("list payload missing LWW metadata".into()))?;

    // Fork protection: an entity id must not silently migrate workspaces.
    let existing_ws: Option<Uuid> = sqlx::query_scalar(
        "SELECT workspace_id FROM content.lists WHERE list_id = $1",
    )
    .bind(entity_id)
    .fetch_optional(&mut **tx)
    .await?;
    if let Some(ws) = existing_ws {
        if ws != workspace_id {
            return Err(sqlx::Error::Protocol(format!(
                "list {entity_id} belongs to workspace {ws}, not {workspace_id}"
            )
            .into()));
        }
    }

    let current = current_lww(tx, "content.lists", "list_id", workspace_id, entity_id).await?;

    if !incoming_lww_wins(&incoming, current.as_ref()) {
        return Ok((false, None));
    }

    let name = get_str(payload, "name").unwrap_or("Untitled");
    let filter = payload.get("filterDefinition").cloned().unwrap_or_else(|| json!({}));
    let deleted_at = get_dt(payload, "deletedAt");

    sqlx::query(
        "INSERT INTO content.lists
            (list_id, workspace_id, name, filter_definition,
             client_updated_at, last_modified_by_replica_id, last_operation_id, deleted_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (list_id) DO UPDATE SET
            name = EXCLUDED.name,
            filter_definition = EXCLUDED.filter_definition,
            client_updated_at = EXCLUDED.client_updated_at,
            last_modified_by_replica_id = EXCLUDED.last_modified_by_replica_id,
            last_operation_id = EXCLUDED.last_operation_id,
            deleted_at = EXCLUDED.deleted_at",
    )
    .bind(entity_id)
    .bind(workspace_id)
    .bind(name)
    .bind(filter)
    .bind(incoming.client_updated_at)
    .bind(incoming.last_modified_by_replica_id)
    .bind(incoming.last_operation_id)
    .bind(deleted_at)
    .execute(&mut **tx)
    .await?;

    let change_id = record_hot_change(
        tx,
        workspace_id,
        EntityType::List.as_str(),
        entity_id,
        replica_id,
        operation_id,
        incoming.client_updated_at,
    )
    .await?;
    Ok((true, Some(change_id)))
}

/// Upsert workspace scheduler settings under LWW. Returns (applied, change_id).
pub async fn upsert_workspace_settings(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    payload: &Value,
    replica_id: Uuid,
    operation_id: Uuid,
) -> Result<(bool, Option<i64>), sqlx::Error> {
    let incoming = lww_from(payload).ok_or(sqlx::Error::Protocol("settings payload missing LWW metadata".into()))?;

    let current = sqlx::query_as::<_, (DateTime<Utc>, Option<Uuid>, Option<Uuid>)>(
        "SELECT fsrs_client_updated_at, fsrs_last_modified_by_replica_id, fsrs_last_operation_id
         FROM org.workspaces WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_optional(&mut **tx)
    .await?;
    let current = current.map(|(t, r, o)| LwwMetadata {
        client_updated_at: t,
        last_modified_by_replica_id: r.unwrap_or(incoming.last_modified_by_replica_id),
        last_operation_id: o.unwrap_or(incoming.last_operation_id),
    });

    if !incoming_lww_wins(&incoming, current.as_ref()) {
        return Ok((false, None));
    }

    let steps = |key: &str| -> Vec<Value> {
        payload
            .get(key)
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_else(|| json!([1, 10]).as_array().unwrap().clone())
    };

    sqlx::query(
        "UPDATE org.workspaces SET
            fsrs_desired_retention = $2,
            fsrs_learning_steps_minutes = $3,
            fsrs_relearning_steps_minutes = $4,
            fsrs_maximum_interval_days = $5,
            fsrs_enable_fuzz = $6,
            fsrs_client_updated_at = $7,
            fsrs_last_modified_by_replica_id = $8,
            fsrs_last_operation_id = $9,
            fsrs_updated_at = now()
         WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .bind(get_f64(payload, "desiredRetention").unwrap_or(0.90))
    .bind(steps("learningStepsMinutes"))
    .bind(steps("relearningStepsMinutes"))
    .bind(get_i64(payload, "maximumIntervalDays").unwrap_or(36500))
    .bind(get_bool(payload, "enableFuzz").unwrap_or(true))
    .bind(incoming.client_updated_at)
    .bind(incoming.last_modified_by_replica_id)
    .bind(incoming.last_operation_id)
    .execute(&mut **tx)
    .await?;

    let change_id = record_hot_change(
        tx,
        workspace_id,
        EntityType::WorkspaceSchedulerSettings.as_str(),
        workspace_id,
        replica_id,
        operation_id,
        incoming.client_updated_at,
    )
    .await?;
    Ok((true, Some(change_id)))
}

/// Append a review event with dedup by (workspace, replica, client_event_id).
/// Returns (applied, review_sequence).
pub async fn append_review_event(
    tx: &mut Transaction<'_, Postgres>,
    workspace_id: Uuid,
    payload: &Value,
    replica_id: Uuid,
) -> Result<(bool, Option<i64>), sqlx::Error> {
    let client_event_id = get_uuid(payload, "clientEventId")
        .or_else(|| get_uuid(payload, "reviewEventId"))
        .ok_or(sqlx::Error::Protocol("review_event payload missing clientEventId".into()))?;
    let word_sense_id = get_uuid(payload, "wordSenseId")
        .ok_or(sqlx::Error::Protocol("review_event payload missing wordSenseId".into()))?;
    let rating = get_i64(payload, "rating").ok_or(sqlx::Error::Protocol("review_event payload missing rating".into()))?;
    if !(0..=3).contains(&rating) {
        return Err(sqlx::Error::Protocol("rating out of range".into()));
    }
    let reviewed_at_client = get_dt(payload, "reviewedAtClient")
        .ok_or(sqlx::Error::Protocol("review_event payload missing reviewedAtClient".into()))?;
    let program_version = get_i64(payload, "programVersion").unwrap_or(1) as i32;
    let experience_unit_id = get_uuid(payload, "experienceUnitId")
        .ok_or(sqlx::Error::Protocol("review_event payload missing experienceUnitId".into()))?;

    let duplicate: Option<Uuid> = sqlx::query_scalar(
        "SELECT review_event_id FROM content.review_events
         WHERE workspace_id = $1 AND replica_id = $2 AND client_event_id = $3",
    )
    .bind(workspace_id)
    .bind(replica_id)
    .bind(client_event_id)
    .fetch_optional(&mut **tx)
    .await?;
    if duplicate.is_some() {
        return Ok((false, None));
    }

    let review_event_id = get_uuid(payload, "reviewEventId").unwrap_or_else(Uuid::new_v4);
    let time_zone = get_str(payload, "reviewedTimeZone").map(str::to_string);
    let local_date = get_str(payload, "reviewedLocalDate").and_then(|s| chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d").ok());

    let sequence: i64 = sqlx::query_scalar(
        "INSERT INTO content.review_events
            (review_event_id, workspace_id, word_sense_id, program_version, experience_unit_id,
             replica_id, client_event_id, rating, reviewed_at_client,
             reviewed_time_zone, reviewed_local_date)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         RETURNING review_sequence",
    )
    .bind(review_event_id)
    .bind(workspace_id)
    .bind(word_sense_id)
    .bind(program_version)
    .bind(experience_unit_id)
    .bind(replica_id)
    .bind(client_event_id)
    .bind(rating)
    .bind(reviewed_at_client)
    .bind(time_zone)
    .bind(local_date)
    .fetch_one(&mut **tx)
    .await?;

    Ok((true, Some(sequence)))
}

// ---------------------------------------------------------------
// Snapshots (pull/bootstrap materialization)
// ---------------------------------------------------------------

fn learning_state_payload(
    row: (Uuid, Option<DateTime<Utc>>, i32, i32, Option<f64>, Option<f64>, Option<DateTime<Utc>>, Option<i32>, String, Option<i32>, DateTime<Utc>, Uuid, Uuid, Option<DateTime<Utc>>),
) -> Value {
    let (id, due_at, reps, lapses, stability, difficulty, last_reviewed, scheduled_days, card_state, step_index, client_updated_at, replica, op, deleted_at) = row;
    json!({
        "learningStateId": id,
        "dueAt": due_at,
        "reps": reps,
        "lapses": lapses,
        "fsrsStability": stability,
        "fsrsDifficulty": difficulty,
        "fsrsLastReviewedAt": last_reviewed,
        "fsrsScheduledDays": scheduled_days,
        "fsrsCardState": card_state,
        "fsrsStepIndex": step_index,
        "clientUpdatedAt": client_updated_at,
        "lastModifiedByReplicaId": replica,
        "lastOperationId": op,
        "deletedAt": deleted_at,
    })
}

pub async fn learning_state_snapshot(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
    user_id: Uuid,
    word_sense_id: Uuid,
) -> Result<Option<Value>, sqlx::Error> {
    let row = sqlx::query_as::<_, (Uuid, Option<DateTime<Utc>>, i32, i32, Option<f64>, Option<f64>, Option<DateTime<Utc>>, Option<i32>, String, Option<i32>, DateTime<Utc>, Uuid, Uuid, Option<DateTime<Utc>>)>(
        "SELECT learning_state_id, due_at, reps, lapses,
                fsrs_stability, fsrs_difficulty, fsrs_last_reviewed_at, fsrs_scheduled_days,
                fsrs_card_state, fsrs_step_index,
                client_updated_at, last_modified_by_replica_id, last_operation_id, deleted_at
         FROM content.learning_states
         WHERE workspace_id = $1 AND user_id = $2 AND word_sense_id = $3",
    )
    .bind(workspace_id)
    .bind(user_id)
    .bind(word_sense_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(learning_state_payload))
}

pub async fn list_snapshot(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
    entity_id: Uuid,
) -> Result<Option<Value>, sqlx::Error> {
    let row = sqlx::query_as::<_, (Uuid, String, Value, DateTime<Utc>, Uuid, Uuid, Option<DateTime<Utc>>)>(
        "SELECT list_id, name, filter_definition, client_updated_at,
                last_modified_by_replica_id, last_operation_id, deleted_at
         FROM content.lists WHERE workspace_id = $1 AND list_id = $2",
    )
    .bind(workspace_id)
    .bind(entity_id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(|(id, name, filter, t, replica, op, deleted_at)| {
        json!({
            "listId": id,
            "name": name,
            "filterDefinition": filter,
            "clientUpdatedAt": t,
            "lastModifiedByReplicaId": replica,
            "lastOperationId": op,
            "deletedAt": deleted_at,
        })
    }))
}

pub async fn workspace_settings_snapshot(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
) -> Result<Value, sqlx::Error> {
    let row = sqlx::query_as::<_, (f64, Value, Value, i32, bool, DateTime<Utc>, Option<Uuid>, Option<Uuid>)>(
        "SELECT fsrs_desired_retention, fsrs_learning_steps_minutes,
                fsrs_relearning_steps_minutes, fsrs_maximum_interval_days, fsrs_enable_fuzz,
                fsrs_client_updated_at, fsrs_last_modified_by_replica_id, fsrs_last_operation_id
         FROM org.workspaces WHERE workspace_id = $1",
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await?;
    let (retention, learning, relearning, max_interval, fuzz, t, replica, op) = row;
    Ok(json!({
        "workspaceId": workspace_id,
        "desiredRetention": retention,
        "learningStepsMinutes": learning,
        "relearningStepsMinutes": relearning,
        "maximumIntervalDays": max_interval,
        "enableFuzz": fuzz,
        "clientUpdatedAt": t,
        "lastModifiedByReplicaId": replica.unwrap_or(Uuid::nil()),
        "lastOperationId": op.unwrap_or(Uuid::nil()),
    }))
}
