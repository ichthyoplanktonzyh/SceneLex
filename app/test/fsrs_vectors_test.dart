import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/fsrs.dart';

/// FSRS-6 golden vector parity: the Dart port must match the reference
/// (ts-fsrs 5.2.3 via the flashcards vectors) exactly.
void main() {
  final raw = File('test/fixtures/fsrs-full-vectors.json').readAsStringSync();
  final vectors = jsonDecode(raw) as List<dynamic>;

  test('vector set is the canonical 15', () {
    expect(vectors.length, 15);
  });

  for (final v in vectors) {
    final name = v['name'] as String;
    final settingsJson = v['settings'] as Map<String, dynamic>;
    final settings = SchedulerSettings(
      desiredRetention: (settingsJson['desiredRetention'] as num).toDouble(),
      learningStepsMinutes:
          (settingsJson['learningStepsMinutes'] as List).cast<int>(),
      relearningStepsMinutes:
          (settingsJson['relearningStepsMinutes'] as List).cast<int>(),
      maximumIntervalDays: settingsJson['maximumIntervalDays'] as int,
      enableFuzz: settingsJson['enableFuzz'] as bool,
    );

    test('$name matches reference', () {
      var state = ScheduleState();
      for (final review in v['reviews'] as List<dynamic>) {
        final at = DateTime.parse(review['at'] as String).toUtc();
        final rating = _rating(review['rating'] as int);
        final next = computeReviewSchedule(state, settings, rating, at);
        state = ScheduleState(
          reps: next.reps,
          lapses: next.lapses,
          state: next.state,
          stepIndex: next.stepIndex,
          stability: next.stability,
          difficulty: next.difficulty,
          lastReviewedAt: next.lastReviewedAt,
          scheduledDays: next.scheduledDays,
        );
      }
      _assertMatches(v['expected'] as Map<String, dynamic>, state, name);
    });
  }
}

ReviewRating _rating(int r) => switch (r) {
      0 => ReviewRating.again,
      1 => ReviewRating.hard,
      2 => ReviewRating.good,
      _ => ReviewRating.easy,
    };

void _assertMatches(Map<String, dynamic> expected, ScheduleState state, String name) {
  expect(state.reps, expected['reps'], reason: '[$name] reps');
  expect(state.lapses, expected['lapses'], reason: '[$name] lapses');
  expect(state.state.name.replaceFirst('_', ''), expected['fsrsCardState'],
      reason: '[$name] fsrsCardState');
  expect(state.stepIndex, expected['fsrsStepIndex'], reason: '[$name] stepIndex');
  expect(state.stability, expected['fsrsStability'], reason: '[$name] stability');
  expect(state.difficulty, expected['fsrsDifficulty'], reason: '[$name] difficulty');
  expect(state.scheduledDays, expected['fsrsScheduledDays'],
      reason: '[$name] scheduledDays');
  final expectedLast = expected['fsrsLastReviewedAt'] as String?;
  expect(state.lastReviewedAt, expectedLast == null ? null : DateTime.parse(expectedLast),
      reason: '[$name] lastReviewedAt');
}
