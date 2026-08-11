//! FSRS-6 scheduling, a 1:1 port of the flashcards backend implementation
//! (`apps/backend/src/scheduling/index.ts`, mirroring ts-fsrs 5.2.3).
//!
//! Golden vectors in `core/tests/fsrs_vectors.rs` verify parity.

use chrono::{DateTime, Datelike, TimeZone, Utc};
use serde::{Deserialize, Serialize};

use super::alea::Alea;

pub const S_MIN: f64 = 0.001;
pub const W17_W18_CEILING: f64 = 2.0;

/// FSRS-6 default weights (w0..w20), fixed and not user-configurable.
pub const DEFAULT_W: [f64; 21] = [
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796,
    1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
];

pub const DECAY: f64 = -DEFAULT_W[20];

/// FACTOR = roundTo8(exp(pow(DECAY, -1) * ln(0.9)) - 1), matching the
/// reference `Number.parseFloat(...toFixed(8))`.
pub fn factor() -> f64 {
    round_to_8((DECAY.powf(-1.0) * 0.9f64.ln()).exp() - 1.0)
}

/// Fuzz ranges applied to intervals by size.
pub const FUZZ_RANGES: [(f64, f64, f64); 3] = [
    (2.5, 7.0, 0.15),
    (7.0, 20.0, 0.1),
    (20.0, f64::INFINITY, 0.05),
];

/// Workspace-level scheduler configuration (mirrors `WorkspaceSchedulerSettings`).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SchedulerSettings {
    pub desired_retention: f64,
    pub learning_steps_minutes: Vec<i64>,
    pub relearning_steps_minutes: Vec<i64>,
    pub maximum_interval_days: i64,
    pub enable_fuzz: bool,
}

impl Default for SchedulerSettings {
    fn default() -> Self {
        Self {
            desired_retention: 0.90,
            learning_steps_minutes: vec![1, 10],
            relearning_steps_minutes: vec![10],
            maximum_interval_days: 36_500,
            enable_fuzz: true,
        }
    }
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

/// Review rating: Again=0 .. Easy=3 (wire value). FSRS grade = rating + 1.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReviewRating {
    Again = 0,
    Hard = 1,
    Good = 2,
    Easy = 3,
}

impl ReviewRating {
    pub fn from_i32(v: i32) -> Option<Self> {
        match v {
            0 => Some(Self::Again),
            1 => Some(Self::Hard),
            2 => Some(Self::Good),
            3 => Some(Self::Easy),
            _ => None,
        }
    }
}

/// Hidden FSRS memory fields.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MemoryState {
    pub stability: f64,
    pub difficulty: f64,
}

/// The persisted per-card scheduler state (input to a review).
#[derive(Debug, Clone, PartialEq)]
pub struct ScheduleState {
    pub reps: i64,
    pub lapses: i64,
    pub fsrs_state: FsrsCardState,
    pub fsrs_step_index: Option<i64>,
    pub fsrs_stability: Option<f64>,
    pub fsrs_difficulty: Option<f64>,
    pub fsrs_last_reviewed_at: Option<DateTime<Utc>>,
    pub fsrs_scheduled_days: Option<i64>,
}

/// The resulting scheduler state after one review.
#[derive(Debug, Clone, PartialEq)]
pub struct ReviewSchedule {
    pub due_at: DateTime<Utc>,
    pub reps: i64,
    pub lapses: i64,
    pub fsrs_state: FsrsCardState,
    pub fsrs_step_index: Option<i64>,
    pub fsrs_stability: f64,
    pub fsrs_difficulty: f64,
    pub fsrs_last_reviewed_at: DateTime<Utc>,
    pub fsrs_scheduled_days: i64,
}

fn round_to_8(value: f64) -> f64 {
    (value * 1e8).round() / 1e8
}

fn clamp(value: f64, min: f64, max: f64) -> f64 {
    value.max(min).min(max)
}

fn add_minutes(date: DateTime<Utc>, minutes: i64) -> DateTime<Utc> {
    date + chrono::Duration::minutes(minutes)
}

fn add_days(date: DateTime<Utc>, days: i64) -> DateTime<Utc> {
    date + chrono::Duration::days(days)
}

/// Whole UTC calendar days between two instants.
fn date_diff_in_days(last_reviewed_at: DateTime<Utc>, now: DateTime<Utc>) -> i64 {
    if now < last_reviewed_at {
        panic!(
            "Review timestamp moved backwards: lastReviewedAt={}, now={}",
            last_reviewed_at.to_rfc3339(),
            now.to_rfc3339()
        );
    }
    let last = Utc
        .with_ymd_and_hms(
            last_reviewed_at.year(),
            last_reviewed_at.month(),
            last_reviewed_at.day(),
            0,
            0,
            0,
        )
        .unwrap();
    let now_day = Utc
        .with_ymd_and_hms(now.year(), now.month(), now.day(), 0, 0, 0)
        .unwrap();
    (now_day - last).num_days()
}

fn get_interval_modifier(request_retention: f64) -> f64 {
    round_to_8((request_retention.powf(1.0 / DECAY) - 1.0) / factor())
}

fn format_seed_number(value: f64) -> String {
    if value == 0.0 {
        return "0".to_string();
    }
    format!("{value}")
}

fn grade_of(rating: ReviewRating) -> i32 {
    rating as i32 + 1
}

fn get_steps_for_state(settings: &SchedulerSettings, state: FsrsCardState) -> &[i64] {
    if state == FsrsCardState::Relearning || state == FsrsCardState::Review {
        &settings.relearning_steps_minutes
    } else {
        &settings.learning_steps_minutes
    }
}

fn get_current_step_index(state: &ScheduleState) -> i64 {
    state.fsrs_step_index.unwrap_or(0)
}

fn get_learning_strategy_step_index(state: &ScheduleState, grade: i32) -> i64 {
    let current = get_current_step_index(state);
    if state.fsrs_state == FsrsCardState::Learning && grade != 1 && grade != 2 {
        return current + 1;
    }
    current
}

fn get_hard_step_minutes(steps: &[i64]) -> i64 {
    if steps.len() == 1 {
        return (steps[0] as f64 * 1.5).round() as i64;
    }
    ((steps[0] + steps[1]) as f64 / 2.0).round() as i64
}

struct LearningStepResult {
    scheduled_minutes: Option<i64>,
    next_step_index: i64,
}

fn get_learning_step_result(
    settings: &SchedulerSettings,
    state: &ScheduleState,
    grade: i32,
) -> LearningStepResult {
    let steps = get_steps_for_state(settings, state.fsrs_state);
    let strategy_step_index = get_learning_strategy_step_index(state, grade);

    if steps.is_empty() {
        panic!("Workspace scheduler steps must not be empty");
    }

    if state.fsrs_state == FsrsCardState::Review {
        return LearningStepResult {
            scheduled_minutes: Some(steps[0]),
            next_step_index: 0,
        };
    }

    if grade == 1 {
        return LearningStepResult {
            scheduled_minutes: Some(steps[0]),
            next_step_index: 0,
        };
    }

    if grade == 2 {
        return LearningStepResult {
            scheduled_minutes: Some(get_hard_step_minutes(steps)),
            next_step_index: strategy_step_index,
        };
    }

    if grade == 4 {
        return LearningStepResult {
            scheduled_minutes: None,
            next_step_index: 0,
        };
    }

    let next_step_index = strategy_step_index + 1;
    let next_step_minutes = steps.get(next_step_index as usize).copied();
    match next_step_minutes {
        None => LearningStepResult {
            scheduled_minutes: None,
            next_step_index: 0,
        },
        Some(minutes) => LearningStepResult {
            scheduled_minutes: Some(minutes),
            next_step_index,
        },
    }
}

fn init_stability(grade: i32) -> f64 {
    DEFAULT_W[grade as usize - 1].max(0.1)
}

fn init_difficulty(grade: i32) -> f64 {
    round_to_8(DEFAULT_W[4] - ((grade - 1) as f64 * DEFAULT_W[5]).exp() + 1.0)
}

fn mean_reversion(initial_difficulty: f64, current_difficulty: f64) -> f64 {
    round_to_8(DEFAULT_W[7] * initial_difficulty + (1.0 - DEFAULT_W[7]) * current_difficulty)
}

fn linear_damping(delta_difficulty: f64, difficulty: f64) -> f64 {
    round_to_8(delta_difficulty * (10.0 - difficulty) / 9.0)
}

fn next_difficulty(difficulty: f64, grade: i32) -> f64 {
    let delta_difficulty = -DEFAULT_W[6] * (grade as f64 - 3.0);
    let next = difficulty + linear_damping(delta_difficulty, difficulty);
    clamp(
        mean_reversion(init_difficulty(4), next),
        1.0,
        10.0,
    )
}

fn forgetting_curve(elapsed_days: i64, stability: f64) -> f64 {
    round_to_8(
        (1.0 + factor() * elapsed_days as f64 / stability).powf(DECAY),
    )
}

fn next_recall_stability(
    difficulty: f64,
    stability: f64,
    retrievability: f64,
    grade: i32,
) -> f64 {
    let hard_penalty = if grade == 2 { DEFAULT_W[15] } else { 1.0 };
    let easy_bound = if grade == 4 { DEFAULT_W[16] } else { 1.0 };
    round_to_8(clamp(
        stability
            * (1.0
                + DEFAULT_W[8].exp()
                    * (11.0 - difficulty)
                    * stability.powf(-DEFAULT_W[9])
                    * ((1.0 - retrievability) * DEFAULT_W[10]).exp_m1()
                    * hard_penalty
                    * easy_bound),
        S_MIN,
        36_500.0,
    ))
}

fn next_forget_stability(difficulty: f64, stability: f64, retrievability: f64) -> f64 {
    round_to_8(clamp(
        DEFAULT_W[11]
            * difficulty.powf(-DEFAULT_W[12])
            * ((stability + 1.0).powf(DEFAULT_W[13]) - 1.0)
            * ((1.0 - retrievability) * DEFAULT_W[14]).exp(),
        S_MIN,
        36_500.0,
    ))
}

struct ShortTermWeights {
    w17: f64,
    w18: f64,
}

fn get_short_term_weights(settings: &SchedulerSettings) -> ShortTermWeights {
    if settings.relearning_steps_minutes.len() <= 1 {
        return ShortTermWeights {
            w17: DEFAULT_W[17],
            w18: DEFAULT_W[18],
        };
    }
    let value = -(DEFAULT_W[11].ln()
        + (2f64.powf(DEFAULT_W[13]) - 1.0).ln()
        + DEFAULT_W[14] * 0.3)
        / settings.relearning_steps_minutes.len() as f64;
    let ceiling = clamp(round_to_8(value), 0.01, W17_W18_CEILING);
    ShortTermWeights {
        w17: clamp(DEFAULT_W[17], 0.0, ceiling),
        w18: clamp(DEFAULT_W[18], 0.0, ceiling),
    }
}

fn next_short_term_stability(stability: f64, grade: i32, settings: &SchedulerSettings) -> f64 {
    let weights = get_short_term_weights(settings);
    let sinc = stability.powf(-DEFAULT_W[19])
        * (weights.w17 * (grade as f64 - 3.0 + weights.w18)).exp();
    let masked_sinc = if grade >= 3 { sinc.max(1.0) } else { sinc };
    round_to_8(clamp(stability * masked_sinc, S_MIN, 36_500.0))
}

fn create_initial_memory_state(grade: i32) -> MemoryState {
    MemoryState {
        stability: init_stability(grade),
        difficulty: clamp(init_difficulty(grade), 1.0, 10.0),
    }
}

fn compute_next_short_term_memory_state(
    memory: MemoryState,
    grade: i32,
    settings: &SchedulerSettings,
) -> MemoryState {
    MemoryState {
        stability: next_short_term_stability(memory.stability, grade, settings),
        difficulty: next_difficulty(memory.difficulty, grade),
    }
}

fn compute_next_review_memory_state(
    memory: MemoryState,
    elapsed_days: i64,
    grade: i32,
    settings: &SchedulerSettings,
) -> MemoryState {
    let retrievability = forgetting_curve(elapsed_days, memory.stability);
    let stability_after_success = next_recall_stability(
        memory.difficulty,
        memory.stability,
        retrievability,
        grade,
    );
    let stability_after_failure =
        next_forget_stability(memory.difficulty, memory.stability, retrievability);

    let next_stability = if grade == 1 {
        let weights = get_short_term_weights(settings);
        let min = memory.stability / (weights.w17 * weights.w18).exp();
        clamp(round_to_8(min), S_MIN, stability_after_failure)
    } else {
        stability_after_success
    };

    MemoryState {
        stability: next_stability,
        difficulty: next_difficulty(memory.difficulty, grade),
    }
}

fn get_fuzz_range(interval: i64, elapsed_days: i64, maximum_interval: i64) -> (i64, i64) {
    let mut delta = 1.0;
    for (start, end, factor) in FUZZ_RANGES {
        delta += factor * (interval.min(end as i64) as f64 - start).max(0.0);
    }

    let clamped_interval = interval.min(maximum_interval);
    let mut min_interval = (clamped_interval as f64 - delta).round().max(2.0) as i64;
    let max_interval = ((clamped_interval as f64 + delta).round() as i64).min(maximum_interval);
    if clamped_interval > elapsed_days {
        min_interval = min_interval.max(elapsed_days + 1);
    }
    min_interval = min_interval.min(max_interval);
    (min_interval, max_interval)
}

fn get_interval_seed(now: DateTime<Utc>, reps: i64, memory: Option<MemoryState>) -> String {
    let memory_product = match memory {
        None => 0.0,
        Some(m) => m.difficulty * m.stability,
    };
    format!(
        "{}_{}_{}",
        now.timestamp_millis(),
        reps,
        format_seed_number(memory_product)
    )
}

fn next_interval(
    stability: f64,
    elapsed_days: i64,
    settings: &SchedulerSettings,
    interval_seed: &str,
) -> i64 {
    let interval_modifier = get_interval_modifier(settings.desired_retention);
    let next_raw_interval = clamp(
        (stability * interval_modifier).round(),
        1.0,
        settings.maximum_interval_days as f64,
    ) as i64;

    if !settings.enable_fuzz || next_raw_interval < 3 {
        return next_raw_interval;
    }

    let mut prng = Alea::new(interval_seed);
    let fuzz_factor = prng.next();
    let (min_interval, max_interval) =
        get_fuzz_range(next_raw_interval, elapsed_days, settings.maximum_interval_days);
    (fuzz_factor * (max_interval - min_interval + 1) as f64 + min_interval as f64).floor() as i64
}

fn get_memory_state(state: &ScheduleState) -> Option<MemoryState> {
    if state.fsrs_state == FsrsCardState::New {
        if state.fsrs_stability.is_some()
            || state.fsrs_difficulty.is_some()
            || state.fsrs_last_reviewed_at.is_some()
            || state.fsrs_scheduled_days.is_some()
            || state.fsrs_step_index.is_some()
        {
            panic!("New card must not have persisted FSRS state");
        }
        return None;
    }

    if state.fsrs_stability.is_none()
        || state.fsrs_difficulty.is_none()
        || state.fsrs_last_reviewed_at.is_none()
        || state.fsrs_scheduled_days.is_none()
    {
        panic!("Persisted FSRS card state is incomplete");
    }

    if state.fsrs_state == FsrsCardState::Review && state.fsrs_step_index.is_some() {
        panic!("Review card must not persist fsrsStepIndex");
    }

    if (state.fsrs_state == FsrsCardState::Learning
        || state.fsrs_state == FsrsCardState::Relearning)
        && state.fsrs_step_index.is_none()
    {
        panic!("Learning or relearning card is missing fsrsStepIndex");
    }

    Some(MemoryState {
        stability: state.fsrs_stability.unwrap(),
        difficulty: state.fsrs_difficulty.unwrap(),
    })
}

// Kept as a flat function mirroring the reference algorithm's shape; the
// argument list is intentionally unchanged for structural parity.
#[allow(clippy::too_many_arguments)]
fn build_short_term_schedule(
    state: &ScheduleState,
    next_memory: MemoryState,
    rating: ReviewRating,
    now: DateTime<Utc>,
    reps: i64,
    lapses: i64,
    settings: &SchedulerSettings,
    next_state: FsrsCardState,
    elapsed_days: i64,
    interval_seed: &str,
) -> ReviewSchedule {
    let grade = grade_of(rating);
    let learning_step = get_learning_step_result(settings, state, grade);
    if learning_step.scheduled_minutes.is_none() {
        return build_graduated_review_schedule(
            next_memory,
            now,
            reps,
            lapses,
            settings,
            elapsed_days,
            interval_seed,
        );
    }

    ReviewSchedule {
        due_at: add_minutes(now, learning_step.scheduled_minutes.unwrap()),
        reps,
        lapses,
        fsrs_state: next_state,
        fsrs_step_index: Some(learning_step.next_step_index),
        fsrs_stability: next_memory.stability,
        fsrs_difficulty: next_memory.difficulty,
        fsrs_last_reviewed_at: now,
        fsrs_scheduled_days: 0,
    }
}

fn build_graduated_review_schedule(
    next_memory: MemoryState,
    now: DateTime<Utc>,
    reps: i64,
    lapses: i64,
    settings: &SchedulerSettings,
    elapsed_days: i64,
    interval_seed: &str,
) -> ReviewSchedule {
    let scheduled_days =
        next_interval(next_memory.stability, elapsed_days, settings, interval_seed);

    ReviewSchedule {
        due_at: add_days(now, scheduled_days),
        reps,
        lapses,
        fsrs_state: FsrsCardState::Review,
        fsrs_step_index: None,
        fsrs_stability: next_memory.stability,
        fsrs_difficulty: next_memory.difficulty,
        fsrs_last_reviewed_at: now,
        fsrs_scheduled_days: scheduled_days,
    }
}

#[allow(clippy::too_many_arguments)]
fn build_review_success_schedule(
    now: DateTime<Utc>,
    reps: i64,
    lapses: i64,
    settings: &SchedulerSettings,
    elapsed_days: i64,
    hard_memory: MemoryState,
    good_memory: MemoryState,
    easy_memory: MemoryState,
    rating: ReviewRating,
    interval_seed: &str,
) -> ReviewSchedule {
    let mut hard_interval =
        next_interval(hard_memory.stability, elapsed_days, settings, interval_seed);
    let mut good_interval =
        next_interval(good_memory.stability, elapsed_days, settings, interval_seed);
    hard_interval = hard_interval.min(good_interval);
    good_interval = good_interval.max(hard_interval + 1);
    let easy_interval = next_interval(easy_memory.stability, elapsed_days, settings, interval_seed)
        .max(good_interval + 1);

    let (due_at, memory) = match rating {
        ReviewRating::Hard => (add_days(now, hard_interval), hard_memory),
        ReviewRating::Good => (add_days(now, good_interval), good_memory),
        _ => (add_days(now, easy_interval), easy_memory),
    };

    let scheduled_days = match rating {
        ReviewRating::Hard => hard_interval,
        ReviewRating::Good => good_interval,
        _ => easy_interval,
    };

    ReviewSchedule {
        due_at,
        reps,
        lapses,
        fsrs_state: FsrsCardState::Review,
        fsrs_step_index: None,
        fsrs_stability: memory.stability,
        fsrs_difficulty: memory.difficulty,
        fsrs_last_reviewed_at: now,
        fsrs_scheduled_days: scheduled_days,
    }
}

/// Compute the next scheduler state for one review.
pub fn compute_review_schedule(
    state: &ScheduleState,
    settings: &SchedulerSettings,
    rating: ReviewRating,
    now: DateTime<Utc>,
) -> ReviewSchedule {
    let memory = get_memory_state(state);
    let grade = grade_of(rating);
    let elapsed_days = match state.fsrs_last_reviewed_at {
        None => 0,
        Some(last) => date_diff_in_days(last, now),
    };
    let reps = state.reps + 1;
    let lapses = if rating == ReviewRating::Again && state.fsrs_state == FsrsCardState::Review {
        state.lapses + 1
    } else {
        state.lapses
    };
    let interval_seed = get_interval_seed(now, reps, memory);

    if state.fsrs_state == FsrsCardState::New {
        let next_memory = create_initial_memory_state(grade);
        return build_short_term_schedule(
            state,
            next_memory,
            rating,
            now,
            reps,
            lapses,
            settings,
            FsrsCardState::Learning,
            0,
            &interval_seed,
        );
    }

    let memory = match memory {
        None => panic!("Persisted FSRS card state is incomplete"),
        Some(m) => m,
    };

    if state.fsrs_state == FsrsCardState::Learning
        || state.fsrs_state == FsrsCardState::Relearning
    {
        let next_memory = compute_next_short_term_memory_state(memory, grade, settings);
        return build_short_term_schedule(
            state,
            next_memory,
            rating,
            now,
            reps,
            lapses,
            settings,
            state.fsrs_state,
            elapsed_days,
            &interval_seed,
        );
    }

    // Review state.
    let again_memory = compute_next_review_memory_state(memory, elapsed_days, 1, settings);
    let hard_memory = compute_next_review_memory_state(memory, elapsed_days, 2, settings);
    let good_memory = compute_next_review_memory_state(memory, elapsed_days, 3, settings);
    let easy_memory = compute_next_review_memory_state(memory, elapsed_days, 4, settings);

    if rating == ReviewRating::Again {
        return build_short_term_schedule(
            state,
            again_memory,
            rating,
            now,
            reps,
            lapses,
            settings,
            FsrsCardState::Relearning,
            elapsed_days,
            &interval_seed,
        );
    }

    build_review_success_schedule(
        now,
        reps,
        lapses,
        settings,
        elapsed_days,
        hard_memory,
        good_memory,
        easy_memory,
        rating,
        &interval_seed,
    )
}

/// Rebuilt state plus the resulting due time (None for a fresh card).
#[derive(Debug, Clone, PartialEq)]
pub struct RebuiltScheduleState {
    pub due_at: Option<DateTime<Utc>>,
    pub state: ScheduleState,
}

/// Rebuild the scheduler state from an empty state by replaying review events.
pub fn rebuild_schedule_state(
    settings: &SchedulerSettings,
    reviews: &[(DateTime<Utc>, ReviewRating)],
) -> RebuiltScheduleState {
    let mut state = ScheduleState {
        reps: 0,
        lapses: 0,
        fsrs_state: FsrsCardState::New,
        fsrs_step_index: None,
        fsrs_stability: None,
        fsrs_difficulty: None,
        fsrs_last_reviewed_at: None,
        fsrs_scheduled_days: None,
    };
    let mut due_at: Option<DateTime<Utc>> = None;

    for (at, rating) in reviews {
        let next = compute_review_schedule(&state, settings, *rating, *at);
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

    RebuiltScheduleState { due_at, state }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn factor_matches_reference() {
        // roundTo8(exp(pow(DECAY, -1) * ln(0.9)) - 1) with DECAY = -0.1542
        let raw = (DECAY.powf(-1.0) * 0.9f64.ln()).exp() - 1.0;
        assert_eq!(round_to_8(raw), factor());
    }

    #[test]
    fn first_again_enters_learning() {
        let settings = SchedulerSettings::default();
        let state = ScheduleState {
            reps: 0,
            lapses: 0,
            fsrs_state: FsrsCardState::New,
            fsrs_step_index: None,
            fsrs_stability: None,
            fsrs_difficulty: None,
            fsrs_last_reviewed_at: None,
            fsrs_scheduled_days: None,
        };
        let now = DateTime::parse_from_rfc3339("2026-03-08T09:00:00.000Z")
            .unwrap()
            .with_timezone(&Utc);
        let next = compute_review_schedule(&state, &settings, ReviewRating::Again, now);
        assert_eq!(next.fsrs_state, FsrsCardState::Learning);
        assert_eq!(next.fsrs_step_index, Some(0));
        assert_eq!(next.fsrs_stability, 0.212);
        assert_eq!(next.fsrs_difficulty, 6.4133);
        assert_eq!(
            next.due_at,
            DateTime::parse_from_rfc3339("2026-03-08T09:01:00.000Z")
                .unwrap()
                .with_timezone(&Utc)
        );
    }
}
