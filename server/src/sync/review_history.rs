//! Review history pull: append-only lane, keyset by review_sequence.

use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, Clone, serde::Deserialize)]
pub struct ReviewHistoryRequest {
    #[serde(rename = "afterReviewSequenceId")]
    pub after_review_sequence_id: i64,
    pub limit: i64,
}

pub async fn process_review_history_pull(
    pool: &PgPool,
    workspace_id: Uuid,
    req: &ReviewHistoryRequest,
) -> Result<Value, sqlx::Error> {
    let limit = req.limit.clamp(1, 500);

    let rows = sqlx::query_as::<_, (i64, Uuid, Uuid, i32, Uuid, i16, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>, Option<String>, Option<chrono::NaiveDate>)>(
        "SELECT review_sequence, review_event_id, word_sense_id, program_version,
                experience_unit_id, rating, reviewed_at_client, reviewed_at_server,
                reviewed_time_zone, reviewed_local_date
         FROM content.review_events
         WHERE workspace_id = $1 AND review_sequence > $2
         ORDER BY review_sequence ASC
         LIMIT $3",
    )
    .bind(workspace_id)
    .bind(req.after_review_sequence_id)
    .bind(limit + 1)
    .fetch_all(pool)
    .await?;

    let has_more = rows.len() as i64 > limit;
    let rows = rows.into_iter().take(limit as usize).collect::<Vec<_>>();

    let mut next_sequence = req.after_review_sequence_id;
    let mut events: Vec<Value> = Vec::with_capacity(rows.len());
    for (sequence, event_id, word_sense_id, program_version, unit_id, rating, at_client, at_server, tz, local_date) in rows {
        next_sequence = sequence;
        events.push(json!({
            "reviewEventId": event_id,
            "wordSenseId": word_sense_id,
            "programVersion": program_version,
            "experienceUnitId": unit_id,
            "rating": rating,
            "reviewedAtClient": at_client,
            "reviewedAtServer": at_server,
            "reviewedTimeZone": tz,
            "reviewedLocalDate": local_date,
        }));
    }

    Ok(json!({
        "reviewEvents": events,
        "nextReviewSequenceId": next_sequence,
        "hasMore": has_more,
    }))
}
