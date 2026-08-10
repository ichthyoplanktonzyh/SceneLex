use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Workspace-level FSRS scheduler settings (stored on the workspace row,
/// mirrors flashcards `org.workspaces` fsrs_* columns).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct WorkspaceSchedulerSettings {
    pub workspace_id: Uuid,
    /// FSRS-6 is the only algorithm; kept as a field for forward compatibility.
    pub fsrs_algorithm: String,
    pub fsrs_desired_retention: f64,
    pub fsrs_learning_steps_minutes: Vec<i64>,
    pub fsrs_relearning_steps_minutes: Vec<i64>,
    pub fsrs_maximum_interval_days: i64,
    pub fsrs_enable_fuzz: bool,

    // LWW metadata.
    pub fsrs_client_updated_at: DateTime<Utc>,
    pub fsrs_last_modified_by_replica_id: Uuid,
    pub fsrs_last_operation_id: Uuid,
}

impl Default for WorkspaceSchedulerSettings {
    fn default() -> Self {
        Self {
            workspace_id: Uuid::new_v4(),
            fsrs_algorithm: "fsrs-6".to_string(),
            fsrs_desired_retention: 0.90,
            fsrs_learning_steps_minutes: vec![1, 10],
            fsrs_relearning_steps_minutes: vec![10],
            fsrs_maximum_interval_days: 36500,
            fsrs_enable_fuzz: true,
            fsrs_client_updated_at: DateTime::<Utc>::from_timestamp(0, 0).unwrap_or_default(),
            fsrs_last_modified_by_replica_id: Uuid::nil(),
            fsrs_last_operation_id: Uuid::nil(),
        }
    }
}
