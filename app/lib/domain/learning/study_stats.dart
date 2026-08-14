/// Study statistics derivation (我的学习): all numbers come from local
/// data — check-ins, review events and recorded sessions.
library;

/// Weekly check-in row for the calendar.
class WeekDay {
  const WeekDay({
    required this.date,
    required this.checkedIn,
    required this.isToday,
  });

  final DateTime date;
  final bool checkedIn;
  final bool isToday;
}

class StudyStats {
  const StudyStats({
    required this.todayLearnedCount,
    required this.totalLearnedCount,
    required this.todayDurationSeconds,
    required this.totalDurationSeconds,
    required this.streakDays,
    required this.week,
  });

  /// 今日理解&复习 (today's review events count).
  final int todayLearnedCount;

  /// 累计理解 (senses with an active learning state).
  final int totalLearnedCount;

  final int todayDurationSeconds;
  final int totalDurationSeconds;
  final int streakDays;
  final List<WeekDay> week;
}

/// Derive study stats from local rows. [checkinDayKeys] are YYYY-MM-DD keys
/// of days with a check-in; [reviewEventTimes] are local reviewed timestamps;
/// [sessions] are recorded session durations; [learnedCount] comes from
/// learning states.
StudyStats deriveStudyStats({
  required Set<String> checkinDayKeys,
  required Iterable<DateTime> reviewEventTimes,
  required Iterable<
    ({DateTime startedAt, DateTime endedAt, int durationSeconds})
  >
  sessions,
  required int learnedCount,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final todayKey = _dayKey(current);

  final todayEvents = reviewEventTimes
      .where((t) => _dayKey(t) == todayKey)
      .length;

  final dayStart = DateTime(current.year, current.month, current.day);
  Duration todayDuration = Duration.zero;
  Duration totalDuration = Duration.zero;
  for (final s in sessions) {
    totalDuration += Duration(seconds: s.durationSeconds);
    if (!s.endedAt.isBefore(dayStart) &&
        s.endedAt.isBefore(dayStart.add(const Duration(days: 1)))) {
      todayDuration += Duration(seconds: s.durationSeconds);
    }
  }

  // Streak: consecutive check-ins ending today (or yesterday, grace).
  var streak = 0;
  var cursor = current;
  if (!checkinDayKeys.contains(_dayKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (checkinDayKeys.contains(_dayKey(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  // This week's calendar (Monday first).
  final monday = dayStart.subtract(Duration(days: dayStart.weekday - 1));
  final week = <WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    week.add(
      WeekDay(
        date: date,
        checkedIn: checkinDayKeys.contains(_dayKey(date)),
        isToday: _dayKey(date) == todayKey,
      ),
    );
  }

  return StudyStats(
    todayLearnedCount: todayEvents,
    totalLearnedCount: learnedCount,
    todayDurationSeconds: todayDuration.inSeconds,
    totalDurationSeconds: totalDuration.inSeconds,
    streakDays: streak,
    week: week,
  );
}

String _dayKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';
