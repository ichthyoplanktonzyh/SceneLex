/// Journey task / plan domain for the Journey preview.
///
/// A journey is one daily session that mixes different cognitive tasks
/// instead of separating "learn" and "review". The plan is deterministic
/// and content-driven (sense ids are real catalog ids); only the *choice of
/// tasks* is prototype logic.
library;

import 'package:flutter/foundation.dart';

/// The kind of cognitive work one journey task asks for.
enum JourneyTaskType { recall, newConcept, discrimination, transfer }

/// One step of a journey plan.
@immutable
class JourneyTask {
  const JourneyTask({
    required this.id,
    required this.type,
    required this.primarySenseId,
    this.secondarySenseId,
  });

  final String id;
  final JourneyTaskType type;

  /// The sense this task centers on (recall / discover / transfer target,
  /// or the "new" side of a discrimination).
  final String primarySenseId;

  /// The other side of a discrimination (boundary) task.
  final String? secondarySenseId;

  bool get isDiscrimination => type == JourneyTaskType.discrimination;
}

/// A complete deterministic journey plan for one day.
@immutable
class JourneyPlan {
  const JourneyPlan({required this.tasks, required this.estimatedMinutes});

  final List<JourneyTask> tasks;
  final int estimatedMinutes;

  bool get isEmpty => tasks.isEmpty;

  int countOf(JourneyTaskType type) => tasks.where((t) => t.type == type).length;
}

/// Grade options for a recall task (prototype-only; no FSRS write).
enum JourneyRecallGrade { forgot, hard, gotIt }

/// Per-task outcome, recorded while the journey runs.
@immutable
class JourneyTaskResult {
  const JourneyTaskResult({
    required this.taskId,
    required this.type,
    required this.primarySenseId,
    this.secondarySenseId,
    this.recallGrade,
    this.boundaryCorrect,
    this.transferCorrect,
    this.discoverFirstAttemptCorrect,
    this.discoverTotalQuestions,
  });

  final String taskId;
  final JourneyTaskType type;
  final String primarySenseId;
  final String? secondarySenseId;
  final JourneyRecallGrade? recallGrade;
  final bool? boundaryCorrect;
  final bool? transferCorrect;
  final int? discoverFirstAttemptCorrect;
  final int? discoverTotalQuestions;
}

/// Everything a completed journey produced.
@immutable
class JourneyCompletion {
  const JourneyCompletion({
    required this.results,
    required this.completedAt,
  });

  final List<JourneyTaskResult> results;
  final DateTime completedAt;
}
