//! SceneLex API server.
//!
//! Phase 1: minimal runnable shell (config, DB pool, health).
//! Phase 2 adds: auth (email OTP), workspaces, learning states, FSRS,
//! sync protocol, content (program) delivery, progress reports.

pub mod config;
pub mod db;
pub mod routes;
