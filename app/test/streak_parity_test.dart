import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/progress/progress_aggregation.dart';

/// Parity checks for the streak/freeze algorithm ported from flashcards
/// (apps/web/src/progress/streakFreeze.ts). Kept as a golden-vector-style
/// exception to the no-unit-tests rule, like the FSRS vectors.

void main() {
  group('streak parity with flashcards', () {
    test('empty history: 0 days, start with 2 credits', () {
      final e = evaluateStreak([], '2026-08-11');
      expect(e.currentStreakDays, 0);
      expect(e.longestStreakDays, 0);
      expect(e.streakFreeze.availableCredits, 2);
      expect(e.streakFreeze.balanceUnits, 20);
      expect(e.statesByDate['2026-08-11'], StreakDayState.pending);
    });

    test('three consecutive days incl. today: streak 3', () {
      final e = evaluateStreak(['2026-08-09', '2026-08-10', '2026-08-11'], '2026-08-11');
      expect(e.currentStreakDays, 3);
      expect(e.longestStreakDays, 3);
      expect(e.statesByDate['2026-08-09'], StreakDayState.reviewed);
      expect(e.statesByDate['2026-08-10'], StreakDayState.reviewed);
      expect(e.statesByDate['2026-08-11'], StreakDayState.reviewed);
    });

    test('gap of one day consumes a freeze credit and keeps streak', () {
      final e = evaluateStreak(['2026-08-09', '2026-08-10', '2026-08-12'], '2026-08-12');
      expect(e.statesByDate['2026-08-11'], StreakDayState.frozen);
      expect(e.currentStreakDays, 4);
      expect(e.streakFreeze.availableCredits, 1);
      expect(e.streakFreeze.balanceUnits, 12);
    });

    test('gap of three days breaks the streak after credits run out', () {
      final e = evaluateStreak(['2026-08-09', '2026-08-10', '2026-08-14'], '2026-08-14');
      expect(e.statesByDate['2026-08-11'], StreakDayState.frozen);
      expect(e.statesByDate['2026-08-12'], StreakDayState.frozen);
      expect(e.statesByDate['2026-08-13'], StreakDayState.missed);
      expect(e.currentStreakDays, 1);
      // Two freeze days kept the segment alive through day 12.
      expect(e.longestStreakDays, 4);
      expect(e.streakFreeze.availableCredits, 2);
      expect(e.streakFreeze.balanceUnits, 20);
    });

    test('longest streak preserved across a break', () {
      final e = evaluateStreak(['2026-07-20', '2026-07-21', '2026-07-22', '2026-08-10'], '2026-08-10');
      // 7/23 and 7/24 froze, 7/25 broke the segment.
      expect(e.longestStreakDays, 5);
      expect(e.currentStreakDays, 1);
    });

    test('today pending does not add to the streak', () {
      final e = evaluateStreak(['2026-08-09', '2026-08-10'], '2026-08-11');
      expect(e.currentStreakDays, 2);
      expect(e.statesByDate['2026-08-11'], StreakDayState.pending);
      expect(e.longestStreakDays, 2);
    });
  });

  group('schedule buckets', () {
    test('boundaries mirror the backend SQL (Asia/Shanghai host)', () {
      final now = DateTime(2026, 8, 11, 12, 0);
      final offset = now.timeZoneOffset.inHours;
      DateTime local(int day, int hour) =>
          DateTime.utc(2026, 8, day, hour - offset);
      expect(bucketForDue(null, now), ScheduleBucket.new_);
      expect(bucketForDue(local(11, 23), now), ScheduleBucket.today);
      expect(bucketForDue(local(12, 1), now), ScheduleBucket.days1To7);
      expect(bucketForDue(local(19, 1), now), ScheduleBucket.days8To30);
      expect(bucketForDue(local(42, 1), now), ScheduleBucket.days31To90);
      expect(bucketForDue(local(102, 1), now), ScheduleBucket.days91To360);
      expect(bucketForDue(local(372, 1), now), ScheduleBucket.years1To2);
      expect(bucketForDue(local(800, 1), now), ScheduleBucket.later);
    });
  });

  group('weekly chart pages', () {
    test('pages group by Monday-start weeks, newest last', () {
      final points = [
        const DailyReviewPoint(date: '2026-08-10', againCount: 1, hardCount: 0, goodCount: 2, easyCount: 0),
        const DailyReviewPoint(date: '2026-08-11', againCount: 0, hardCount: 1, goodCount: 0, easyCount: 1),
      ];
      final pages = buildChartPages(points, '2026-08-11', null);
      expect(pages.length, 1);
      expect(pages.first.days.length, 7);
      expect(pages.first.days.first.date, '2026-08-10');
      final monday = pages.first.days.firstWhere((d) => d.date == '2026-08-10');
      expect(monday.segments.map((s) => s.rating).toList(),
          [ChartRatingKey.again, ChartRatingKey.good]);
    });

    test('rating filter restricts segments', () {
      final points = [
        const DailyReviewPoint(date: '2026-08-10', againCount: 1, hardCount: 0, goodCount: 2, easyCount: 0),
      ];
      final pages = buildChartPages(points, '2026-08-11', ChartRatingKey.good);
      expect(pages.first.days.first.segments.map((s) => s.rating).toList(),
          [ChartRatingKey.good]);
      expect(pages.first.days.first.displayReviewCount, 2);
    });
  });
}
