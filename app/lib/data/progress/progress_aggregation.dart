import 'dart:math' as math;

import '../local/database.dart';

/// Canonical palette values (ARGB ints, mirroring the flashcards
/// docs/progress-pie-palette.md) so the data layer stays Flutter-free.
const int chartRatingColorAgain = 0xFFD7263D;
const int chartRatingColorHard = 0xFFE69F00;
const int chartRatingColorGood = 0xFF2BB673;
const int chartRatingColorEasy = 0xFF3F7CC8;

const int scheduleBucketColorNew = 0xFFF4C430;
const int scheduleBucketColorToday = 0xFFD7263D;
const int scheduleBucketColor1To7 = 0xFF1FB5C1;
const int scheduleBucketColor8To30 = 0xFF8E5BD9;
const int scheduleBucketColor31To90 = 0xFF2BB673;
const int scheduleBucketColor91To360 = 0xFFE69F00;
const int scheduleBucketColor1To2y = 0xFF3F7CC8;
const int scheduleBucketColorLater = 0xFF7A8088;

/// Progress statistics aggregated from the local database.
/// Behavior mirrors flashcards (apps/web/src/progress/streakFreeze.ts and the
/// progress report models): local-date bucketing, freeze credits with capacity
/// 2 (10 units = 1 credit), weekly chart pages, and 8-bucket schedule rings.

// ---------------------------------------------------------------------------
// Date helpers (device-local timezone, YYYY-MM-DD keys)
// ---------------------------------------------------------------------------

String formatLocalDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseLocalDate(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String shiftLocalDate(String value, int days) {
  final d = parseLocalDate(value);
  return formatLocalDate(d.add(Duration(days: days)));
}

String todayLocalDate() => formatLocalDate(DateTime.now());

// ---------------------------------------------------------------------------
// Streak + freeze (port of flashcards evaluateProgressStreakFreeze)
// ---------------------------------------------------------------------------

const streakFreezeStartCapacity = 2;
const streakFreezeMaxCapacity = 2;
const streakFreezeUnitsPerCredit = 10;
const streakFreezeEarnedUnitsPerStreakDay = 1;

enum StreakDayState { reviewed, frozen, missed, pending }

class StreakFreeze {
  const StreakFreeze({
    required this.availableCredits,
    required this.capacity,
    required this.balanceUnits,
    required this.unitsPerCredit,
    required this.earnedUnitsPerStreakDay,
    required this.nextCreditProgressUnits,
    required this.nextCreditRequiredUnits,
  });

  final int availableCredits;
  final int capacity;
  final int balanceUnits;
  final int unitsPerCredit;
  final int earnedUnitsPerStreakDay;
  final int nextCreditProgressUnits;
  final int nextCreditRequiredUnits;

  int get unitsUntilNextCredit =>
      availableCredits >= capacity ? 0 : unitsPerCredit - balanceUnits % unitsPerCredit;
}

class StreakEvaluation {
  const StreakEvaluation({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.streakFreeze,
    required this.statesByDate,
  });

  final int currentStreakDays;
  final int longestStreakDays;
  final StreakFreeze streakFreeze;
  final Map<String, StreakDayState> statesByDate;
}

int get _initialBalanceUnits =>
    math.min(streakFreezeStartCapacity, streakFreezeMaxCapacity) *
    streakFreezeUnitsPerCredit;

int get _maximumBalanceUnits =>
    streakFreezeMaxCapacity * streakFreezeUnitsPerCredit;

int _availableCredits(int balanceUnits) =>
    math.min(streakFreezeMaxCapacity, balanceUnits ~/ streakFreezeUnitsPerCredit);

class _StreakComputationState {
  _StreakComputationState()
      : balanceUnits = _initialBalanceUnits,
        currentStreakDays = 0,
        longestStreakDays = 0,
        hasActiveSegment = false,
        lastEvaluatedDate = null;

  _StreakComputationState._raw({
    required this.balanceUnits,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.hasActiveSegment,
    required this.lastEvaluatedDate,
  });

  int balanceUnits;
  int currentStreakDays;
  int longestStreakDays;
  bool hasActiveSegment;
  String? lastEvaluatedDate;
}

StreakFreeze _createStreakFreeze(int balanceUnits) {
  final clamped = math.min(balanceUnits, _maximumBalanceUnits);
  final credits = _availableCredits(clamped);
  return StreakFreeze(
    availableCredits: credits,
    capacity: streakFreezeMaxCapacity,
    balanceUnits: clamped,
    unitsPerCredit: streakFreezeUnitsPerCredit,
    earnedUnitsPerStreakDay: streakFreezeEarnedUnitsPerStreakDay,
    nextCreditProgressUnits: credits >= streakFreezeMaxCapacity
        ? 0
        : clamped % streakFreezeUnitsPerCredit,
    nextCreditRequiredUnits: streakFreezeUnitsPerCredit,
  );
}

_StreakComputationState _addReviewedDay(
  _StreakComputationState state,
  String date,
  Map<String, StreakDayState> statesByDate,
) {
  final balanceUnits = math.min(
    (state.hasActiveSegment ? state.balanceUnits : _initialBalanceUnits) +
        streakFreezeEarnedUnitsPerStreakDay,
    _maximumBalanceUnits,
  );
  final currentStreakDays = state.hasActiveSegment ? state.currentStreakDays + 1 : 1;
  statesByDate[date] = StreakDayState.reviewed;

  return _StreakComputationState._raw(
    balanceUnits: balanceUnits,
    currentStreakDays: currentStreakDays,
    longestStreakDays: math.max(state.longestStreakDays, currentStreakDays),
    hasActiveSegment: true,
    lastEvaluatedDate: date,
  );
}

_StreakComputationState _addFrozenDay(
  _StreakComputationState state,
  String date,
  Map<String, StreakDayState> statesByDate,
) {
  final afterSpend = state.balanceUnits - streakFreezeUnitsPerCredit;
  final balanceUnits = math.min(
    afterSpend + streakFreezeEarnedUnitsPerStreakDay,
    _maximumBalanceUnits,
  );
  final currentStreakDays = state.currentStreakDays + 1;
  statesByDate[date] = StreakDayState.frozen;

  return _StreakComputationState._raw(
    balanceUnits: balanceUnits,
    currentStreakDays: currentStreakDays,
    longestStreakDays: math.max(state.longestStreakDays, currentStreakDays),
    hasActiveSegment: true,
    lastEvaluatedDate: date,
  );
}

_StreakComputationState _addMissedDay(
  _StreakComputationState state,
  String date,
  Map<String, StreakDayState> statesByDate,
) {
  statesByDate[date] = StreakDayState.missed;
  return _StreakComputationState._raw(
    balanceUnits: _initialBalanceUnits,
    currentStreakDays: 0,
    longestStreakDays: state.longestStreakDays,
    hasActiveSegment: false,
    lastEvaluatedDate: date,
  );
}

_StreakComputationState _addNonReviewedCompletedDay(
  _StreakComputationState state,
  String date,
  Map<String, StreakDayState> statesByDate,
) {
  if (state.hasActiveSegment && _availableCredits(state.balanceUnits) > 0) {
    return _addFrozenDay(state, date, statesByDate);
  }
  return _addMissedDay(state, date, statesByDate);
}

_StreakComputationState _addNonReviewedDaysBeforeReview(
  _StreakComputationState state,
  String nextReviewDate,
  Map<String, StreakDayState> statesByDate,
) {
  var currentState = state;
  var currentDate = state.lastEvaluatedDate == null
      ? nextReviewDate
      : shiftLocalDate(state.lastEvaluatedDate!, 1);

  while (state.lastEvaluatedDate != null && currentDate.compareTo(nextReviewDate) < 0) {
    currentState = _addNonReviewedCompletedDay(currentState, currentDate, statesByDate);
    currentDate = shiftLocalDate(currentDate, 1);
  }

  return currentState;
}

_StreakComputationState _addTrailingDaysThroughToday(
  _StreakComputationState state,
  String today,
  Map<String, StreakDayState> statesByDate,
) {
  var currentState = state;
  var currentDate = state.lastEvaluatedDate == null
      ? today
      : shiftLocalDate(state.lastEvaluatedDate!, 1);

  while (currentDate.compareTo(today) <= 0) {
    if (currentDate == today) {
      statesByDate[today] = StreakDayState.pending;
      currentState = _StreakComputationState._raw(
        balanceUnits: currentState.balanceUnits,
        currentStreakDays: currentState.currentStreakDays,
        longestStreakDays: currentState.longestStreakDays,
        hasActiveSegment: currentState.hasActiveSegment,
        lastEvaluatedDate: today,
      );
    } else {
      currentState = _addNonReviewedCompletedDay(currentState, currentDate, statesByDate);
    }
    currentDate = shiftLocalDate(currentDate, 1);
  }

  return currentState;
}

/// Evaluate the streak from sorted distinct local review dates (inclusive of
/// today). Port of flashcards `evaluateProgressStreakFreeze`.
StreakEvaluation evaluateStreak(
  List<String> sortedActiveReviewLocalDates,
  String today,
) {
  final statesByDate = <String, StreakDayState>{};
  final throughToday = sortedActiveReviewLocalDates
      .where((date) => date.compareTo(today) <= 0)
      .toList();

  var state = _StreakComputationState();
  for (final reviewDate in throughToday) {
    state = _addNonReviewedDaysBeforeReview(state, reviewDate, statesByDate);
    state = _addReviewedDay(state, reviewDate, statesByDate);
  }
  state = _addTrailingDaysThroughToday(state, today, statesByDate);

  return StreakEvaluation(
    currentStreakDays: state.currentStreakDays,
    longestStreakDays: state.longestStreakDays,
    streakFreeze: _createStreakFreeze(state.balanceUnits),
    statesByDate: statesByDate,
  );
}

// ---------------------------------------------------------------------------
// Streak week grid (5 weeks ending with the current week, Monday start)
// ---------------------------------------------------------------------------

class StreakWeekDay {
  const StreakWeekDay({
    required this.date,
    required this.state,
    required this.isFuture,
    required this.isToday,
    required this.dayLabel,
  });

  final String date;
  final StreakDayState state;
  final bool isFuture;
  final bool isToday;
  final String dayLabel;
}

const streakWeekCount = 5;

List<List<StreakWeekDay>> buildStreakWeeks(
  Map<String, StreakDayState> statesByDate,
  String today,
) {
  final todayDate = parseLocalDate(today);
  final dayOfWeek = todayDate.weekday % 7; // 0 = Sunday ... keep Monday start
  final offsetFromMonday = (dayOfWeek - 1 + 7) % 7;
  final currentWeekStart =
      formatLocalDate(todayDate.subtract(Duration(days: offsetFromMonday)));

  final weeks = <List<StreakWeekDay>>[];
  for (var w = streakWeekCount - 1; w >= 0; w--) {
    final weekStart = parseLocalDate(shiftLocalDate(currentWeekStart, -w * 7));
    final days = <StreakWeekDay>[];
    for (var d = 0; d < 7; d++) {
      final date = formatLocalDate(weekStart.add(Duration(days: d)));
      days.add(StreakWeekDay(
        date: date,
        state: date.compareTo(today) > 0
            ? StreakDayState.pending
            : statesByDate[date] ?? StreakDayState.missed,
        isFuture: date.compareTo(today) > 0,
        isToday: date == today,
        dayLabel: '${parseLocalDate(date).day}',
      ));
    }
    weeks.add(days);
  }
  return weeks;
}

// ---------------------------------------------------------------------------
// Daily review points + weekly chart pages
// ---------------------------------------------------------------------------

class DailyReviewPoint {
  const DailyReviewPoint({
    required this.date,
    required this.againCount,
    required this.hardCount,
    required this.goodCount,
    required this.easyCount,
  });

  final String date;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;

  int get reviewCount => againCount + hardCount + goodCount + easyCount;

  int countFor(ChartRatingKey rating) => switch (rating) {
        ChartRatingKey.again => againCount,
        ChartRatingKey.hard => hardCount,
        ChartRatingKey.good => goodCount,
        ChartRatingKey.easy => easyCount,
      };
}

/// Group local review events into per-day points (YYYY-MM-DD keys, device
/// timezone; falls back to reviewedAtClient for rows without a local date).
List<DailyReviewPoint> aggregateDailyReviews(List<LocalReviewEvent> events) {
  final byDate = <String, List<int>>{};
  for (final e in events) {
    final date = e.reviewedLocalDate ??
        formatLocalDate(e.reviewedAtClient.toLocal());
    byDate.putIfAbsent(date, () => [0, 0, 0, 0]);
    final counts = byDate[date]!;
    final rating = e.rating.clamp(0, 3);
    counts[rating] = counts[rating] + 1;
  }
  final dates = byDate.keys.toList()..sort();
  return [
    for (final date in dates)
      DailyReviewPoint(
        date: date,
        againCount: byDate[date]![0],
        hardCount: byDate[date]![1],
        goodCount: byDate[date]![2],
        easyCount: byDate[date]![3],
      ),
  ];
}

enum ChartRatingKey { again, hard, good, easy }

class ChartRatingSegment {
  const ChartRatingSegment({
    required this.rating,
    required this.count,
    required this.heightPercentage,
  });

  final ChartRatingKey rating;
  final int count;
  final double heightPercentage;
}

class ChartDay {
  const ChartDay({
    required this.date,
    required this.reviewCount,
    required this.displayReviewCount,
    required this.barHeightPercentage,
    required this.segments,
    required this.isToday,
    required this.weekdayLabel,
    required this.dayLabel,
    required this.monthLabel,
    required this.showMonthLabel,
  });

  final String date;
  final int reviewCount;
  final int displayReviewCount;
  final double barHeightPercentage;
  final List<ChartRatingSegment> segments;
  final bool isToday;
  final String weekdayLabel;
  final String dayLabel;
  final String monthLabel;
  final bool showMonthLabel;

  int countFor(ChartRatingKey rating) => segments
      .where((s) => s.rating == rating)
      .fold<int>(0, (sum, s) => sum + s.count);
}

class ChartPage {
  const ChartPage({required this.days, required this.upperBound});

  final List<ChartDay> days;
  final double upperBound;
}

const chartRatingColors = {
  ChartRatingKey.again: chartRatingColorAgain,
  ChartRatingKey.hard: chartRatingColorHard,
  ChartRatingKey.good: chartRatingColorGood,
  ChartRatingKey.easy: chartRatingColorEasy,
};

class ChartSelection {
  const ChartSelection.none() : day = null, rating = null;
  const ChartSelection.day(this.day) : rating = null;
  const ChartSelection.rating(this.rating) : day = null;

  final String? day;
  final ChartRatingKey? rating;
}

int _weekIndex(DateTime d) {
  final monday = d.subtract(Duration(days: ((d.weekday - 1 + 7) % 7)));
  // Use UTC calendar days to avoid timezone-offset drift when rebuilding.
  return DateTime.utc(monday.year, monday.month, monday.day)
      .millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

double _chartUpperBound(List<DailyReviewPoint> points, ChartRatingKey? rating) {
  var max = 0;
  for (final p in points) {
    final display = rating == null ? p.reviewCount : p.countFor(rating);
    if (display > max) max = display;
  }
  if (max <= 0) return 1;
  return math.max(1, (max * 1.1).ceilToDouble());
}

/// Weekly chart pages (Mon-Sun), one page per week that has review data.
List<ChartPage> buildChartPages(
  List<DailyReviewPoint> dailyReviews,
  String today,
  ChartRatingKey? selectedRating,
) {
  if (dailyReviews.isEmpty) return const [];
  final upperBound = _chartUpperBound(dailyReviews, selectedRating);

  final byWeek = <int, List<DailyReviewPoint>>{};
  for (final p in dailyReviews) {
    byWeek.putIfAbsent(_weekIndex(parseLocalDate(p.date)), () => []).add(p);
  }
  final weekIndexes = byWeek.keys.toList()..sort();

  final pages = <ChartPage>[];
  for (final week in weekIndexes) {
    final monday = DateTime.fromMillisecondsSinceEpoch(
        week * Duration.millisecondsPerDay,
        isUtc: true).toLocal();
    final byDate = {for (final p in byWeek[week]!) p.date: p};
    final days = <ChartDay>[];
    for (var d = 0; d < 7; d++) {
      final date = formatLocalDate(monday.add(Duration(days: d)));
      final point = byDate[date];
      final display = selectedRating == null
          ? (point?.reviewCount ?? 0)
          : (point?.countFor(selectedRating) ?? 0);
      final segments = <ChartRatingSegment>[];
      if (point != null) {
        for (final rating in ChartRatingKey.values) {
          final count = point.countFor(rating);
          if (count > 0 && (selectedRating == null || selectedRating == rating)) {
            segments.add(ChartRatingSegment(
              rating: rating,
              count: count,
              heightPercentage: display <= 0 ? 0 : count / display * 100,
            ));
          }
        }
      }
      days.add(ChartDay(
        date: date,
        reviewCount: point?.reviewCount ?? 0,
        displayReviewCount: display,
        barHeightPercentage: display <= 0 ? 0 : display / upperBound * 100,
        segments: segments,
        isToday: date == today,
        weekdayLabel: _weekdayNarrow(parseLocalDate(date)),
        dayLabel: '${parseLocalDate(date).day}',
        monthLabel: _monthShort(parseLocalDate(date)),
        showMonthLabel: d == 0,
      ));
    }
    pages.add(ChartPage(days: days, upperBound: upperBound));
  }
  return pages;
}

class ChartLegendItem {
  const ChartLegendItem({
    required this.rating,
    required this.count,
    required this.percentageLabel,
    required this.isSelected,
    required this.isDimmed,
    required this.isDisabled,
  });

  final ChartRatingKey rating;
  final int count;
  final String percentageLabel;
  final bool isSelected;
  final bool isDimmed;
  final bool isDisabled;
}

List<ChartLegendItem> buildChartLegendItems(
  ChartPage? visiblePage,
  ChartSelection selection,
) {
  if (visiblePage == null) return const [];
  final sourceDays = selection.day == null
      ? visiblePage.days
      : visiblePage.days.where((d) => d.date == selection.day).toList();
  final total = sourceDays.fold<int>(0, (sum, d) => sum + d.reviewCount);

  return [
    for (final rating in ChartRatingKey.values)
      ChartLegendItem(
        rating: rating,
        count: sourceDays.fold<int>(0, (sum, d) => sum + d.countFor(rating)),
        percentageLabel: total <= 0
            ? '0%'
            : '${((sourceDays.fold<int>(0, (sum, d) => sum + d.countFor(rating)) / total) * 100).round()}%',
        isSelected: selection.rating == rating,
        isDimmed: selection.rating != null && selection.rating != rating,
        isDisabled:
            sourceDays.fold<int>(0, (sum, d) => sum + d.countFor(rating)) == 0,
      ),
  ];
}

String _weekdayNarrow(DateTime d) => switch (d.weekday) {
      1 => 'M',
      2 => 'T',
      3 => 'W',
      4 => 'T',
      5 => 'F',
      6 => 'S',
      _ => 'S',
    };

String _monthShort(DateTime d) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][d.month - 1];

// ---------------------------------------------------------------------------
// Review schedule buckets
// ---------------------------------------------------------------------------

enum ScheduleBucket {
  new_, today, days1To7, days8To30, days31To90, days91To360, years1To2, later
}

class ScheduleBucketView {
  const ScheduleBucketView({
    required this.bucket,
    required this.count,
  });

  final ScheduleBucket bucket;
  final int count;
}

const scheduleBucketColors = {
  ScheduleBucket.new_: scheduleBucketColorNew,
  ScheduleBucket.today: scheduleBucketColorToday,
  ScheduleBucket.days1To7: scheduleBucketColor1To7,
  ScheduleBucket.days8To30: scheduleBucketColor8To30,
  ScheduleBucket.days31To90: scheduleBucketColor31To90,
  ScheduleBucket.days91To360: scheduleBucketColor91To360,
  ScheduleBucket.years1To2: scheduleBucketColor1To2y,
  ScheduleBucket.later: scheduleBucketColorLater,
};

DateTime _localDayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Bucket boundaries in UTC, derived from the device-local today (mirrors the
/// backend SQL: today_start..later boundaries offset from the local date).
ScheduleBucket bucketForDue(
  DateTime? dueAtUtc,
  DateTime localNow,
) {
  if (dueAtUtc == null) return ScheduleBucket.new_;
  final tomorrowStart = _localDayStart(localNow.add(const Duration(days: 1))).toUtc();
  final days8 = _localDayStart(localNow.add(const Duration(days: 8))).toUtc();
  final days31 = _localDayStart(localNow.add(const Duration(days: 31))).toUtc();
  final days91 = _localDayStart(localNow.add(const Duration(days: 91))).toUtc();
  final days361 = _localDayStart(localNow.add(const Duration(days: 361))).toUtc();
  final days721 = _localDayStart(localNow.add(const Duration(days: 721))).toUtc();

  final due = dueAtUtc.toUtc();
  if (due.isBefore(tomorrowStart)) return ScheduleBucket.today;
  if (due.isBefore(days8)) return ScheduleBucket.days1To7;
  if (due.isBefore(days31)) return ScheduleBucket.days8To30;
  if (due.isBefore(days91)) return ScheduleBucket.days31To90;
  if (due.isBefore(days361)) return ScheduleBucket.days91To360;
  if (due.isBefore(days721)) return ScheduleBucket.years1To2;
  return ScheduleBucket.later;
}

List<ScheduleBucketView> aggregateSchedule(
  List<LocalLearningState> states,
  DateTime localNow,
) {
  final counts = {for (final b in ScheduleBucket.values) b: 0};
  for (final s in states) {
    counts[bucketForDue(s.dueAt, localNow)] = counts[bucketForDue(s.dueAt, localNow)]! + 1;
  }
  return [
    for (final b in ScheduleBucket.values)
      ScheduleBucketView(bucket: b, count: counts[b]!),
  ];
}
