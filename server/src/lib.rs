//! SceneLex API server.
//!
//! Phase 1: minimal runnable shell (config, DB pool, health).
//! Phase 2 adds: auth (email OTP), workspaces, learning states, FSRS,
//! sync protocol, content (program) delivery, progress reports.

pub mod auth;
pub mod config;
pub mod db;
pub mod entities;
pub mod error;
pub mod extractors;
pub mod routes;
pub mod state;
pub mod sync;
pub mod workspaces;
