//! SceneLex shared core.
//!
//! Phase 1: domain type skeleton only.
//! Phase 2 adds: FSRS-6 scheduling, LWW conflict resolution, sync protocol validation.

pub mod domain;
pub mod fsrs;

pub mod error {
    use thiserror::Error;

    #[derive(Debug, Error)]
    pub enum CoreError {
        #[error("invalid value for {field}: {message}")]
        InvalidValue { field: String, message: String },
    }
}
