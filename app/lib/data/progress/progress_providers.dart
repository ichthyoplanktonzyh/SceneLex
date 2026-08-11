import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_providers.dart';
import 'progress_aggregation.dart';

class ProgressData {
  const ProgressData({
    required this.dailyReviews,
    required this.streak,
    required this.weeks,
    required this.schedule,
    required this.reviewCount,
  });

  final List<DailyReviewPoint> dailyReviews;
  final StreakEvaluation streak;
  final List<List<StreakWeekDay>> weeks;
  final List<ScheduleBucketView> schedule;
  final int reviewCount;
}

/// Aggregates progress statistics from the local database (offline-safe).
/// Refresh = run a best-effort sync first, then re-read local rows.
final progressDataProvider = FutureProvider.autoDispose<ProgressData>((ref) async {
  final local = ref.watch(localRepositoryProvider);

  final engine = await ref.watch(syncEngineProvider.future);
  try {
    await engine.runSync();
  } catch (_) {
    // Offline: aggregate from local rows as-is.
  }

  final events = await local.allReviewEvents();
  final states = await local.allStates(''); // single-workspace client

  final now = DateTime.now();
  final today = todayLocalDate();
  final dailyReviews = aggregateDailyReviews(events);
  final activeDates = [
    for (final p in dailyReviews) p.date,
  ];
  final streak = evaluateStreak(activeDates, today);
  final weeks = buildStreakWeeks(streak.statesByDate, today);
  final schedule = aggregateSchedule(states, now);

  return ProgressData(
    dailyReviews: dailyReviews,
    streak: streak,
    weeks: weeks,
    schedule: schedule,
    reviewCount: events.length,
  );
});
