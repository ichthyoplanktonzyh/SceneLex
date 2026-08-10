use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::domain::learning_state::ReviewRating;

/// Append-only review event. Extends the flashcards shape with the SceneLex
/// content identity: which program version and which experience unit was shown,
/// enabling compiler-version effectiveness analysis.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReviewEvent {
    pub review_event_id: Uuid,
    pub workspace_id: Uuid,
    pub word_sense_id: Uuid,
    /// Program version used for this review (new first learning: initial version).
    pub program_version: u32,
    /// The experience unit actually shown for this review.
    pub experience_unit_id: Uuid,
    pub replica_id: Uuid,
    pub client_event_id: Uuid,
    pub rating: ReviewRating,
    /// Client answer time: the single FSRS time basis.
    pub reviewed_at_client: DateTime<Utc>,
    pub reviewed_at_server: Option<DateTime<Utc>>,
    pub reviewed_time_zone: Option<String>,
    pub review_sequence: Option<i64>,
}
