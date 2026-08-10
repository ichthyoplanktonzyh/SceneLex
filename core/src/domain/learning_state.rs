use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Per (workspace × word_sense) learning progress plus FSRS scheduler state.
/// Field set mirrors the flashcards card row, with content stripped out.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LearningState {
    pub learning_state_id: Uuid,
    pub workspace_id: Uuid,
    pub user_id: Uuid,
    pub word_sense_id: Uuid,

    // Product-visible schedule fields.
    /// NULL = never reviewed (new).
    pub due_at: Option<DateTime<Utc>>,
    pub reps: i64,
    pub lapses: i64,

    // Hidden FSRS memory fields.
    pub fsrs_stability: Option<f64>,
    pub fsrs_difficulty: Option<f64>,
    pub fsrs_last_reviewed_at: Option<DateTime<Utc>>,
    pub fsrs_scheduled_days: Option<i64>,
    pub fsrs_state: FsrsCardState,
    pub fsrs_step_index: Option<i64>,

    // LWW metadata.
    pub client_updated_at: DateTime<Utc>,
    pub last_modified_by_replica_id: Uuid,
    pub last_operation_id: Uuid,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

/// FSRS card state machine.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FsrsCardState {
    New,
    Learning,
    Review,
    Relearning,
}

/// Review ratings, shared by UI and API (wire: 0..3).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReviewRating {
    Again = 0,
    Hard = 1,
    Good = 2,
    Easy = 3,
}
