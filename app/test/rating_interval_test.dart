import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';
import 'package:scenelex/features/review/rating_interval.dart';

import 'package:scenelex/data/fsrs.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final base = DateTime.utc(2026, 1, 1, 12, 0, 0);

  String interval(Duration offset) =>
      formatReviewInterval(base, base.add(offset), en);

  group('formatReviewInterval (parity with reviewRatingOptions.ts)', () {
    const cases = <(Duration, String)>[
      (Duration(seconds: -10), 'in less than a minute'),
      (Duration.zero, 'in less than a minute'),
      (Duration(seconds: 59), 'in less than a minute'),
      (Duration(seconds: 60), 'in 1 minute'),
      (Duration(seconds: 90), 'in 1 minute'),
      (Duration(minutes: 59, seconds: 59), 'in 59 minutes'),
      (Duration(minutes: 60), 'in 1 hour'),
      (Duration(hours: 23, minutes: 59), 'in 23 hours'),
      (Duration(days: 1), 'in 1 day'),
      (Duration(days: 1, hours: 1), 'in 1 day'),
      (Duration(days: 10), 'in 10 days'),
    ];

    for (final (offset, expected) in cases) {
      test('dueAt - now = ${offset.inSeconds}s -> "$expected"', () {
        expect(interval(offset), expected);
      });
    }
  });

  group('buildRatingOptions', () {
    test('returns four options in presentation order with titles', () {
      final options = buildRatingOptions(
        state: const ScheduleState(),
        settings: const SchedulerSettings(),
        now: base,
        l10n: en,
      );
      expect(options.map((o) => o.rating), [0, 1, 2, 3]);
      expect(options.map((o) => o.title), ['Again', 'Hard', 'Good', 'Easy']);
    });

    test('new card: Again minutes-scale, Easy days-scale', () {
      final options = buildRatingOptions(
        state: const ScheduleState(),
        settings: const SchedulerSettings(),
        now: base,
        l10n: en,
      );
      expect(options[0].interval, startsWith('in '));
      expect(options[0].interval, contains('minute'));
      expect(options[3].interval, contains('day'));
    });

    test('throwing schedule computation propagates to the caller', () {
      final state = ScheduleState(
        lastReviewedAt: base.add(const Duration(days: 1)),
        state: FsrsCardState.review,
      );
      expect(
        () => buildRatingOptions(
          state: state,
          settings: const SchedulerSettings(),
          now: base,
          l10n: en,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
