/// FSRS-6 scheduling, a Dart port of the Rust core
/// (`core/src/fsrs/algorithm.rs`), which itself mirrors ts-fsrs 5.2.3.
/// Verified against the golden vectors in `test/fsrs_vectors_test.dart`.
library;

import 'dart:math' as math;

class SchedulerSettings {
  const SchedulerSettings({
    this.desiredRetention = 0.90,
    this.learningStepsMinutes = const [1, 10],
    this.relearningStepsMinutes = const [10],
    this.maximumIntervalDays = 36500,
    this.enableFuzz = true,
  });

  final double desiredRetention;
  final List<int> learningStepsMinutes;
  final List<int> relearningStepsMinutes;
  final int maximumIntervalDays;
  final bool enableFuzz;
}

enum FsrsCardState { new_, learning, review, relearning }

enum ReviewRating { again, hard, good, easy }

/// Persisted scheduler state (input to a review).
class ScheduleState {
  const ScheduleState({
    this.reps = 0,
    this.lapses = 0,
    this.state = FsrsCardState.new_,
    this.stepIndex,
    this.stability,
    this.difficulty,
    this.lastReviewedAt,
    this.scheduledDays,
  });

  final int reps;
  final int lapses;
  final FsrsCardState state;
  final int? stepIndex;
  final double? stability;
  final double? difficulty;
  final DateTime? lastReviewedAt;
  final int? scheduledDays;
}

class ReviewSchedule {
  const ReviewSchedule({
    required this.dueAt,
    required this.reps,
    required this.lapses,
    required this.state,
    required this.stepIndex,
    required this.stability,
    required this.difficulty,
    required this.lastReviewedAt,
    required this.scheduledDays,
  });

  final DateTime dueAt;
  final int reps;
  final int lapses;
  final FsrsCardState state;
  final int? stepIndex;
  final double stability;
  final double difficulty;
  final DateTime lastReviewedAt;
  final int scheduledDays;
}

// ---------------------------------------------------------------------------
// Constants (mirror the Rust core).
// ---------------------------------------------------------------------------

const List<double> _defaultW = [
  0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722,
  0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
  0.0912, 0.0658, 0.1542,
];

const double _sMin = 0.001;
const double _w17w18Ceiling = 2.0;
final double _decay = -_defaultW[20];

double get _factor =>
    _roundTo8(math.exp(math.pow(_decay, -1).toDouble() * math.log(0.9)) - 1);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------


double _roundTo8(double value) => (value * 1e8).round() / 1e8;

double _clamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

DateTime _addMinutes(DateTime date, int minutes) =>
    date.add(Duration(minutes: minutes));

DateTime _addDays(DateTime date, int days) => date.add(Duration(days: days));

int _dateDiffInDays(DateTime lastReviewedAt, DateTime now) {
  if (now.isBefore(lastReviewedAt)) {
    throw StateError('Review timestamp moved backwards');
  }
  final last = DateTime.utc(lastReviewedAt.year, lastReviewedAt.month, lastReviewedAt.day);
  final nowDay = DateTime.utc(now.year, now.month, now.day);
  return nowDay.difference(last).inDays;
}

double _getIntervalModifier(double requestRetention) =>
    _roundTo8((math.pow(requestRetention, 1 / _decay).toDouble() - 1) / _factor);

String _formatSeedNumber(double value) {
  if (value == 0) return '0';
  return value.toString();
}

int _gradeOf(ReviewRating rating) => rating.index + 1;

List<int> _getStepsForState(SchedulerSettings settings, FsrsCardState state) =>
    (state == FsrsCardState.relearning || state == FsrsCardState.review)
        ? settings.relearningStepsMinutes
        : settings.learningStepsMinutes;

int _getCurrentStepIndex(ScheduleState state) => state.stepIndex ?? 0;

int _getLearningStrategyStepIndex(ScheduleState state, int grade) {
  final current = _getCurrentStepIndex(state);
  if (state.state == FsrsCardState.learning && grade != 1 && grade != 2) {
    return current + 1;
  }
  return current;
}

int _getHardStepMinutes(List<int> steps) {
  if (steps.length == 1) return (steps[0] * 1.5).round();
  return ((steps[0] + steps[1]) / 2).round();
}

({int? scheduledMinutes, int nextStepIndex}) _getLearningStepResult(
    SchedulerSettings settings, ScheduleState state, int grade) {
  final steps = _getStepsForState(settings, state.state);
  final strategyStepIndex = _getLearningStrategyStepIndex(state, grade);

  if (steps.isEmpty) {
    throw StateError('Workspace scheduler steps must not be empty');
  }
  if (state.state == FsrsCardState.review) {
    return (scheduledMinutes: steps[0], nextStepIndex: 0);
  }
  if (grade == 1) {
    return (scheduledMinutes: steps[0], nextStepIndex: 0);
  }
  if (grade == 2) {
    return (
      scheduledMinutes: _getHardStepMinutes(steps),
      nextStepIndex: strategyStepIndex,
    );
  }
  if (grade == 4) {
    return (scheduledMinutes: null, nextStepIndex: 0);
  }
  final nextStepIndex = strategyStepIndex + 1;
  if (nextStepIndex >= steps.length) {
    return (scheduledMinutes: null, nextStepIndex: 0);
  }
  return (scheduledMinutes: steps[nextStepIndex], nextStepIndex: nextStepIndex);
}

double _initStability(int grade) => math.max(_defaultW[grade - 1], 0.1);

double _initDifficulty(int grade) =>
    _roundTo8(_defaultW[4] - math.exp((grade - 1) * _defaultW[5]) + 1);

double _meanReversion(double initialDifficulty, double currentDifficulty) =>
    _roundTo8(_defaultW[7] * initialDifficulty +
        (1 - _defaultW[7]) * currentDifficulty);

double _linearDamping(double deltaDifficulty, double difficulty) =>
    _roundTo8(deltaDifficulty * (10 - difficulty) / 9);

double _nextDifficulty(double difficulty, int grade) {
  final delta = -_defaultW[6] * (grade - 3);
  final next = difficulty + _linearDamping(delta, difficulty);
  return _clamp(_meanReversion(_initDifficulty(4), next), 1, 10);
}

double _forgettingCurve(int elapsedDays, double stability) =>
    _roundTo8(math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble());

double _nextRecallStability(
    double difficulty, double stability, double retrievability, int grade) {
  final hardPenalty = grade == 2 ? _defaultW[15] : 1.0;
  final easyBound = grade == 4 ? _defaultW[16] : 1.0;
  return _roundTo8(_clamp(
    stability *
        (1 +
            math.exp(_defaultW[8]) *
                (11 - difficulty) *
                math.pow(stability, -_defaultW[9]).toDouble() *
                (math.exp((1 - retrievability) * _defaultW[10]) - 1) *
                hardPenalty *
                easyBound),
    _sMin,
    36500,
  ));
}

double _nextForgetStability(
    double difficulty, double stability, double retrievability) {
  return _roundTo8(_clamp(
    _defaultW[11] *
        math.pow(difficulty, -_defaultW[12]).toDouble() *
        (math.pow(stability + 1, _defaultW[13]).toDouble() - 1) *
        math.exp((1 - retrievability) * _defaultW[14]),
    _sMin,
    36500,
  ));
}

({double w17, double w18}) _getShortTermWeights(SchedulerSettings settings) {
  if (settings.relearningStepsMinutes.length <= 1) {
    return (w17: _defaultW[17], w18: _defaultW[18]);
  }
  final value = -(math.log(_defaultW[11]) +
          math.log(math.pow(2, _defaultW[13]).toDouble() - 1) +
          _defaultW[14] * 0.3) /
      settings.relearningStepsMinutes.length;
  final ceiling = _clamp(_roundTo8(value), 0.01, _w17w18Ceiling);
  return (
    w17: _clamp(_defaultW[17], 0, ceiling),
    w18: _clamp(_defaultW[18], 0, ceiling),
  );
}

double _nextShortTermStability(
    double stability, int grade, SchedulerSettings settings) {
  final weights = _getShortTermWeights(settings);
  final sinc = math.pow(stability, -_defaultW[19]).toDouble() *
      math.exp(weights.w17 * (grade - 3 + weights.w18));
  final masked = grade >= 3 ? math.max(sinc, 1) : sinc;
  return _roundTo8(_clamp(stability * masked, _sMin, 36500));
}

({double stability, double difficulty}) _createInitialMemoryState(int grade) =>
    (
      stability: _initStability(grade),
      difficulty: _clamp(_initDifficulty(grade), 1, 10),
    );

({double stability, double difficulty}) _computeNextShortTermMemoryState(
    ({double stability, double difficulty}) memory, int grade, SchedulerSettings settings) =>
    (
      stability: _nextShortTermStability(memory.stability, grade, settings),
      difficulty: _nextDifficulty(memory.difficulty, grade),
    );

({double stability, double difficulty}) _computeNextReviewMemoryState(
    ({double stability, double difficulty}) memory,
    int elapsedDays,
    int grade,
    SchedulerSettings settings) {
  final retrievability = _forgettingCurve(elapsedDays, memory.stability);
  final afterSuccess = _nextRecallStability(
      memory.difficulty, memory.stability, retrievability, grade);
  final afterFailure =
      _nextForgetStability(memory.difficulty, memory.stability, retrievability);

  var nextStability = afterSuccess;
  if (grade == 1) {
    final weights = _getShortTermWeights(settings);
    final min = memory.stability / math.exp(weights.w17 * weights.w18);
    nextStability = _clamp(_roundTo8(min), _sMin, afterFailure);
  }
  return (
    stability: nextStability,
    difficulty: _nextDifficulty(memory.difficulty, grade),
  );
}

({int min, int max}) _getFuzzRange(int interval, int elapsedDays, int maximumInterval) {
  var delta = 1.0;
  const ranges = [(2.5, 7.0, 0.15), (7.0, 20.0, 0.1), (20.0, double.infinity, 0.05)];
  for (final (start, end, factor) in ranges) {
    // Rust `f64 as i64` saturates at i64::MAX; emulate with a non-finite guard.
    final boundedEnd = end.isFinite ? end.truncate() : interval;
    delta += factor * math.max(math.min(interval, boundedEnd) - start, 0);
  }
  final clampedInterval = math.min(interval, maximumInterval);
  var minInterval = math.max((clampedInterval - delta).round(), 2);
  final maxInterval = math.min((clampedInterval + delta).round(), maximumInterval);
  if (clampedInterval > elapsedDays) {
    minInterval = math.max(minInterval, elapsedDays + 1);
  }
  minInterval = math.min(minInterval, maxInterval);
  return (min: minInterval, max: maxInterval);
}

String _getIntervalSeed(DateTime now, int reps, double? memoryProduct) =>
    '${now.millisecondsSinceEpoch}_${reps}_${_formatSeedNumber(memoryProduct ?? 0)}';

int _nextInterval(double stability, int elapsedDays, SchedulerSettings settings,
    String intervalSeed) {
  final modifier = _getIntervalModifier(settings.desiredRetention);
  final raw =
      _clamp((stability * modifier).roundToDouble(), 1, settings.maximumIntervalDays.toDouble())
          .round();

  if (!settings.enableFuzz || raw < 3) return raw;

  final prng = Alea(intervalSeed);
  final fuzzFactor = prng.next();
  final range = _getFuzzRange(raw, elapsedDays, settings.maximumIntervalDays);
  return (fuzzFactor * (range.max - range.min + 1) + range.min).floor();
}

({double stability, double difficulty})? _getMemoryState(ScheduleState state) {
  if (state.state == FsrsCardState.new_) {
    if (state.stability != null ||
        state.difficulty != null ||
        state.lastReviewedAt != null ||
        state.scheduledDays != null ||
        state.stepIndex != null) {
      throw StateError('New card must not have persisted FSRS state');
    }
    return null;
  }
  if (state.stability == null ||
      state.difficulty == null ||
      state.lastReviewedAt == null ||
      state.scheduledDays == null) {
    throw StateError('Persisted FSRS card state is incomplete');
  }
  if (state.state == FsrsCardState.review && state.stepIndex != null) {
    throw StateError('Review card must not persist fsrsStepIndex');
  }
  if ((state.state == FsrsCardState.learning ||
          state.state == FsrsCardState.relearning) &&
      state.stepIndex == null) {
    throw StateError('Learning or relearning card is missing fsrsStepIndex');
  }
  return (stability: state.stability!, difficulty: state.difficulty!);
}

ReviewSchedule _buildShortTermSchedule(
    ScheduleState state,
    ({double stability, double difficulty}) nextMemory,
    ReviewRating rating,
    DateTime now,
    int reps,
    int lapses,
    SchedulerSettings settings,
    FsrsCardState nextState,
    int elapsedDays,
    String intervalSeed) {
  final grade = _gradeOf(rating);
  final step = _getLearningStepResult(settings, state, grade);
  if (step.scheduledMinutes == null) {
    return _buildGraduatedReviewSchedule(nextMemory, now, reps, lapses, settings,
        elapsedDays, intervalSeed);
  }
  return ReviewSchedule(
    dueAt: _addMinutes(now, step.scheduledMinutes!),
    reps: reps,
    lapses: lapses,
    state: nextState,
    stepIndex: step.nextStepIndex,
    stability: nextMemory.stability,
    difficulty: nextMemory.difficulty,
    lastReviewedAt: now,
    scheduledDays: 0,
  );
}

ReviewSchedule _buildGraduatedReviewSchedule(
    ({double stability, double difficulty}) nextMemory,
    DateTime now,
    int reps,
    int lapses,
    SchedulerSettings settings,
    int elapsedDays,
    String intervalSeed) {
  final scheduledDays =
      _nextInterval(nextMemory.stability, elapsedDays, settings, intervalSeed);
  return ReviewSchedule(
    dueAt: _addDays(now, scheduledDays),
    reps: reps,
    lapses: lapses,
    state: FsrsCardState.review,
    stepIndex: null,
    stability: nextMemory.stability,
    difficulty: nextMemory.difficulty,
    lastReviewedAt: now,
    scheduledDays: scheduledDays,
  );
}

ReviewSchedule _buildReviewSuccessSchedule(
    DateTime now,
    int reps,
    int lapses,
    SchedulerSettings settings,
    int elapsedDays,
    ({double stability, double difficulty}) hardMemory,
    ({double stability, double difficulty}) goodMemory,
    ({double stability, double difficulty}) easyMemory,
    ReviewRating rating,
    String intervalSeed) {
  var hardInterval =
      _nextInterval(hardMemory.stability, elapsedDays, settings, intervalSeed);
  var goodInterval =
      _nextInterval(goodMemory.stability, elapsedDays, settings, intervalSeed);
  hardInterval = math.min(hardInterval, goodInterval);
  goodInterval = math.max(goodInterval, hardInterval + 1);
  final easyInterval = math.max(
      _nextInterval(easyMemory.stability, elapsedDays, settings, intervalSeed),
      goodInterval + 1);

  final (dueAt, memory, scheduledDays) = switch (rating) {
    ReviewRating.hard => (
        _addDays(now, hardInterval),
        hardMemory,
        hardInterval,
      ),
    ReviewRating.good => (
        _addDays(now, goodInterval),
        goodMemory,
        goodInterval,
      ),
    _ => (
        _addDays(now, easyInterval),
        easyMemory,
        easyInterval,
      ),
  };

  return ReviewSchedule(
    dueAt: dueAt,
    reps: reps,
    lapses: lapses,
    state: FsrsCardState.review,
    stepIndex: null,
    stability: memory.stability,
    difficulty: memory.difficulty,
    lastReviewedAt: now,
    scheduledDays: scheduledDays,
  );
}

/// Compute the next scheduler state for one review.
ReviewSchedule computeReviewSchedule(ScheduleState state,
    SchedulerSettings settings, ReviewRating rating, DateTime now) {
  final memory = _getMemoryState(state);
  final grade = _gradeOf(rating);
  final elapsedDays = state.lastReviewedAt == null
      ? 0
      : _dateDiffInDays(state.lastReviewedAt!, now);
  final reps = state.reps + 1;
  final lapses = rating == ReviewRating.again && state.state == FsrsCardState.review
      ? state.lapses + 1
      : state.lapses;
  final intervalSeed =
      _getIntervalSeed(now, reps, memory == null ? null : memory.stability * memory.difficulty);

  if (state.state == FsrsCardState.new_) {
    final nextMemory = _createInitialMemoryState(grade);
    return _buildShortTermSchedule(state, nextMemory, rating, now, reps, lapses,
        settings, FsrsCardState.learning, 0, intervalSeed);
  }

  final m = memory!;
  if (state.state == FsrsCardState.learning ||
      state.state == FsrsCardState.relearning) {
    final nextMemory = _computeNextShortTermMemoryState(m, grade, settings);
    return _buildShortTermSchedule(state, nextMemory, rating, now, reps, lapses,
        settings, state.state, elapsedDays, intervalSeed);
  }

  final againMemory = _computeNextReviewMemoryState(m, elapsedDays, 1, settings);
  final hardMemory = _computeNextReviewMemoryState(m, elapsedDays, 2, settings);
  final goodMemory = _computeNextReviewMemoryState(m, elapsedDays, 3, settings);
  final easyMemory = _computeNextReviewMemoryState(m, elapsedDays, 4, settings);

  if (rating == ReviewRating.again) {
    return _buildShortTermSchedule(state, againMemory, rating, now, reps, lapses,
        settings, FsrsCardState.relearning, elapsedDays, intervalSeed);
  }

  return _buildReviewSuccessSchedule(now, reps, lapses, settings, elapsedDays,
      hardMemory, goodMemory, easyMemory, rating, intervalSeed);
}

// ---------------------------------------------------------------------------
// Alea PRNG (JS semantics, mirrors the Rust core).
// ---------------------------------------------------------------------------

const double _two32 = 4294967296.0;
const double _scale = 2.3283064365386963e-10;

int _toUint32(double x) => (x % _two32).toInt();

int _toInt32(double x) => _toUint32(x).toSigned(32);

class _Mash {
  double n = 0xefc8249d;

  double next(String data) {
    var next = n;
    for (final c in data.codeUnits) {
      next += c.toDouble();
      var h = 0.02519603282416938 * next;
      next = _toUint32(h).toDouble();
      h -= next;
      h *= next;
      next = _toUint32(h).toDouble();
      h -= next;
      next += h * _two32;
    }
    n = next;
    return _toUint32(next).toDouble() * _scale;
  }
}

class Alea {
  Alea(String seed) {
    final mash = _Mash();
    s0 = mash.next(' ');
    s1 = mash.next(' ');
    s2 = mash.next(' ');
    s0 -= mash.next(seed);
    if (s0 < 0) s0 += 1;
    s1 -= mash.next(seed);
    if (s1 < 0) s1 += 1;
    s2 -= mash.next(seed);
    if (s2 < 0) s2 += 1;
    c = 1;
  }

  late double s0;
  late double s1;
  late double s2;
  late int c;

  double next() {
    final t = 2091639 * s0 + c * _scale;
    s0 = s1;
    s1 = s2;
    c = _toInt32(t);
    s2 = t - c.toDouble();
    return s2;
  }
}
