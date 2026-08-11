/// Review rating-button intervals: pure formatting + option construction,
/// ported from the reference web `reviewRatingOptions.ts` and the iOS
/// `ReviewAnswerSupport.swift` (`formatReviewIntervalText`). No Flutter
/// BuildContext dependencies; [AppLocalizations] is passed in for testing.
library;

import '../../data/fsrs.dart';
import '../../l10n/gen/app_localizations.dart';

/// Formatted next-review interval for a rating button subtitle, aligned with
/// the reference: single unit, all floor (never rounded), capped at days.
String formatReviewInterval(
  DateTime now,
  DateTime dueAt,
  AppLocalizations l10n,
) {
  final durationMilliseconds = dueAt.difference(now).inMilliseconds;
  final durationSeconds = (durationMilliseconds < 0 ? 0 : durationMilliseconds) ~/ 1000;

  if (durationSeconds < 60) {
    return l10n.reviewIntervalLessThanMinute;
  }

  final durationMinutes = durationSeconds ~/ 60;
  if (durationMinutes < 60) {
    return l10n.reviewIntervalMinutes(durationMinutes);
  }

  final durationHours = durationMinutes ~/ 60;
  if (durationHours < 24) {
    return l10n.reviewIntervalHours(durationHours);
  }

  return l10n.reviewIntervalDays(durationHours ~/ 24);
}

/// A single rating button: title (existing label) + interval subtitle.
class RatingOption {
  const RatingOption({
    required this.rating,
    required this.title,
    required this.interval,
  });

  final int rating;
  final String title;
  final String interval;
}

/// Builds the four rating options in presentation order
/// [again, hard, good, easy], each with its own computed schedule.
/// May throw when the schedule computation fails; the caller replaces the
/// button grid with an error banner in that case (reference ReviewPane).
List<RatingOption> buildRatingOptions({
  required ScheduleState state,
  required SchedulerSettings settings,
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final titles = [
    l10n.ratingAgain,
    l10n.ratingHard,
    l10n.ratingGood,
    l10n.ratingEasy,
  ];
  return [
    for (var rating = 0; rating < 4; rating++)
      RatingOption(
        rating: rating,
        title: titles[rating],
        interval: formatReviewInterval(
          now,
          computeReviewSchedule(
            state,
            settings,
            _ratingOf(rating),
            now,
          ).dueAt,
          l10n,
        ),
      ),
  ];
}

ReviewRating _ratingOf(int rating) => switch (rating) {
      0 => ReviewRating.again,
      1 => ReviewRating.hard,
      2 => ReviewRating.good,
      _ => ReviewRating.easy,
    };
