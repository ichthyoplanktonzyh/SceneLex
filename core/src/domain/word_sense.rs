use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// A word sense identity: the minimal teachable unit.
/// Mirrors the SceneLex semantic layer (`data/senses`, approved Sense Inventories).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WordSense {
    pub word_sense_id: Uuid,
    /// Stable key from the SceneLex semantic layer, e.g. `reluctant-01`.
    pub sense_key: String,
    pub lemma: String,
    pub pos: String,
    pub semantic_type: SemanticType,
    /// Learner L1 this sense is grounded in, e.g. `zh-Hans`.
    pub locale_l1: String,
}

/// The 10 core experience categories from the SceneLex semantic model.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SemanticType {
    Entity,
    Attribute,
    Spatial,
    Action,
    StateChange,
    MentalState,
    IntentionBehavior,
    EventLogic,
    Cognitive,
    TemporalStructure,
}
