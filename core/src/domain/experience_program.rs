use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// A versioned Experience Program compiled for one WordSense and one L1.
/// Content is distributed one-way (content channel); this type is the wire shape.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExperienceProgram {
    pub program_id: Uuid,
    pub word_sense_id: Uuid,
    pub program_version: u32,
    pub compiler_version: String,
    pub prompt_version: String,
    pub model_provider: String,
    pub quality_status: QualityStatus,
    pub units: Vec<ExperienceUnit>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum QualityStatus {
    Draft,
    Reviewed,
    Published,
}

/// Stage of the concept-formation arc inside a program.
/// Internal vocabulary of the compiler; the player never shows these terms verbatim.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExperienceStage {
    Anchor,
    Variation,
    Perturbation,
    Discrimination,
    SymbolBinding,
    L2Grounding,
    Transfer,
}

/// One experience unit: a narrative, a judgment, or a recall task.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExperienceUnit {
    pub experience_unit_id: Uuid,
    pub stage: ExperienceStage,
    pub unit_type: UnitType,
    pub content: serde_json::Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UnitType {
    Narrative,
    Judgment,
    Recall,
}
