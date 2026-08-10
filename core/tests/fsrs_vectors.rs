//! FSRS-6 golden vector parity tests.
//!
//! Vectors are copied from the flashcards-open-source-app reference
//! (`tests/fsrs-full-vectors.json`), which mirrors ts-fsrs 5.2.3 behaviour.
//! If these fail, the port diverges from the reference scheduler.

use chrono::{DateTime, Utc};
use scenelex_core::fsrs::{
    compute_review_schedule, rebuild_schedule_state, FsrsCardState, ReviewRating, ScheduleState,
    SchedulerSettings,
};
use serde::Deserialize;

const VECTORS: &str = include_str!("fixtures/fsrs-full-vectors.json");

#[derive(Debug, Deserialize)]
struct Vector {
    name: String,
    #[serde(rename = "cardId")]
    card_id: String,
    settings: VectorSettings,
    reviews: Vec<VectorReview>,
    expected: VectorState,
    #[serde(rename = "rebuiltExpected")]
    rebuilt_expected: VectorState,
}

#[derive(Debug, Deserialize)]
struct VectorSettings {
    #[serde(rename = "desiredRetention")]
    desired_retention: f64,
    #[serde(rename = "learningStepsMinutes")]
    learning_steps_minutes: Vec<i64>,
    #[serde(rename = "relearningStepsMinutes")]
    relearning_steps_minutes: Vec<i64>,
    #[serde(rename = "maximumIntervalDays")]
    maximum_interval_days: i64,
    #[serde(rename = "enableFuzz")]
    enable_fuzz: bool,
}

#[derive(Debug, Deserialize)]
struct VectorReview {
    at: String,
    rating: i32,
}

#[derive(Debug, Deserialize)]
struct VectorState {
    #[serde(rename = "dueAt")]
    due_at: String,
    reps: i64,
    lapses: i64,
    #[serde(rename = "fsrsCardState")]
    fsrs_card_state: String,
    #[serde(rename = "fsrsStepIndex")]
    fsrs_step_index: Option<i64>,
    #[serde(rename = "fsrsStability")]
    fsrs_stability: Option<f64>,
    #[serde(rename = "fsrsDifficulty")]
    fsrs_difficulty: Option<f64>,
    #[serde(rename = "fsrsLastReviewedAt")]
    fsrs_last_reviewed_at: Option<String>,
    #[serde(rename = "fsrsScheduledDays")]
    fsrs_scheduled_days: Option<i64>,
}

fn parse_at(s: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(s)
        .unwrap_or_else(|e| panic!("bad timestamp {s}: {e}"))
        .with_timezone(&Utc)
}

fn parse_state_state(s: &str) -> FsrsCardState {
    match s {
        "new" => FsrsCardState::New,
        "learning" => FsrsCardState::Learning,
        "review" => FsrsCardState::Review,
        "relearning" => FsrsCardState::Relearning,
        other => panic!("unknown state {other}"),
    }
}

fn empty_state() -> ScheduleState {
    ScheduleState {
        reps: 0,
        lapses: 0,
        fsrs_state: FsrsCardState::New,
        fsrs_step_index: None,
        fsrs_stability: None,
        fsrs_difficulty: None,
        fsrs_last_reviewed_at: None,
        fsrs_scheduled_days: None,
    }
}

fn settings_of(v: &VectorSettings) -> SchedulerSettings {
    SchedulerSettings {
        desired_retention: v.desired_retention,
        learning_steps_minutes: v.learning_steps_minutes.clone(),
        relearning_steps_minutes: v.relearning_steps_minutes.clone(),
        maximum_interval_days: v.maximum_interval_days,
        enable_fuzz: v.enable_fuzz,
    }
}

fn assert_matches(
    expected: &VectorState,
    state: &ScheduleState,
    due_at: Option<DateTime<Utc>>,
    name: &str,
    what: &str,
) {
    assert_eq!(
        due_at,
        Some(parse_at(&expected.due_at)),
        "[{name}]{what} dueAt ({})",
        expected.due_at
    );
    assert_eq!(state.reps, expected.reps, "[{name}]{what} reps");
    assert_eq!(state.lapses, expected.lapses, "[{name}]{what} lapses");
    assert_eq!(
        state.fsrs_state,
        parse_state_state(&expected.fsrs_card_state),
        "[{name}]{what} fsrsCardState"
    );
    assert_eq!(
        state.fsrs_step_index,
        expected.fsrs_step_index,
        "[{name}]{what} fsrsStepIndex"
    );
    if let (Some(actual), Some(exp)) = (state.fsrs_stability, expected.fsrs_stability) {
        assert_eq!(actual, exp, "[{name}]{what} fsrsStability");
    } else {
        assert!(
            state.fsrs_stability.is_none() && expected.fsrs_stability.is_none(),
            "[{name}]{what} fsrsStability nullity mismatch"
        );
    }
    if let (Some(actual), Some(exp)) = (state.fsrs_difficulty, expected.fsrs_difficulty) {
        assert_eq!(actual, exp, "[{name}]{what} fsrsDifficulty");
    } else {
        assert!(
            state.fsrs_difficulty.is_none() && expected.fsrs_difficulty.is_none(),
            "[{name}]{what} fsrsDifficulty nullity mismatch"
        );
    }
    assert_eq!(
        state.fsrs_last_reviewed_at,
        expected.fsrs_last_reviewed_at.as_deref().map(parse_at),
        "[{name}]{what} fsrsLastReviewedAt"
    );
    assert_eq!(
        state.fsrs_scheduled_days,
        expected.fsrs_scheduled_days,
        "[{name}]{what} fsrsScheduledDays"
    );
}

#[test]
fn vectors_match_reference_scheduler() {
    let vectors: Vec<Vector> = serde_json::from_str(VECTORS).expect("parse vectors");
    assert_eq!(vectors.len(), 15, "vector set changed; update the fixture deliberately");

    for v in &vectors {
        let settings = settings_of(&v.settings);

        // Replay: expected is the state after the last review.
        let mut state = empty_state();
        let mut due_at = None;
        for review in &v.reviews {
            let rating = ReviewRating::from_i32(review.rating)
                .unwrap_or_else(|| panic!("[{}] bad rating {}", v.name, review.rating));
            let next =
                compute_review_schedule(&state, &settings, rating, parse_at(&review.at));
            state = ScheduleState {
                reps: next.reps,
                lapses: next.lapses,
                fsrs_state: next.fsrs_state,
                fsrs_step_index: next.fsrs_step_index,
                fsrs_stability: Some(next.fsrs_stability),
                fsrs_difficulty: Some(next.fsrs_difficulty),
                fsrs_last_reviewed_at: Some(next.fsrs_last_reviewed_at),
                fsrs_scheduled_days: Some(next.fsrs_scheduled_days),
            };
            due_at = Some(next.due_at);
        }
        assert_matches(&v.expected, &state, due_at, &v.name, " expected");

        // Rebuilt: replay from scratch through the public rebuild entry.
        let reviews: Vec<(DateTime<Utc>, ReviewRating)> = v
            .reviews
            .iter()
            .map(|r| {
                (
                    parse_at(&r.at),
                    ReviewRating::from_i32(r.rating).unwrap(),
                )
            })
            .collect();
        let rebuilt = rebuild_schedule_state(&settings, &reviews);
        assert_matches(
            &v.rebuilt_expected,
            &rebuilt.state,
            rebuilt.due_at,
            &v.name,
            " rebuilt",
        );
    }
}
