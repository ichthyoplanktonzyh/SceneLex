/// Daily Learning Session domain — the product-level model of the
/// "unified entry + dynamic task orchestration" prototype.
///
/// This deliberately does NOT reuse the Journey vocabulary: a session is a
/// composable, mode-driven plan of product-neutral task kinds (recall /
/// discover / boundary / transfer), not a fixed narrative script. The Journey
/// prototype stays untouched; nothing here imports it.
///
/// Everything in this file is prototype logic — content (catalog, programs,
/// review pool, transfer units) is real; only planning and grading are mock.
library;

import 'package:flutter/foundation.dart';

/// The three mutually exclusive session shapes offered by the prototype.
/// The mode is an input to the planner — never a UI-only filter.
enum DailySessionMode {
  /// Review + one new sense + boundary when needed.
  standard,

  /// Only the senses that are due today.
  reviewOnly,

  /// One new sense (+ boundary when available); never recall.
  learnOnly,
}

/// Product-neutral task kinds a session can compose. The Journey names
/// (recall / discover / boundary / transfer) happen to match, but the model
/// here is the product concept, not the Journey script.
enum DailySessionTaskType { recall, discover, boundary, transfer }

/// The session block a task belongs to. Blocks are the visible "chapters"
/// of a session (warm-up → core → boundary → transfer → wrap-up); they are a
/// derived view of the plan, not a script.
enum DailySessionBlock { warmup, core, boundary, transfer, completion }

/// Prototype-only duration weights (minutes) per task type.
///
/// Centralized here so the estimate is a single testable source of truth.
///  - Recall:    1 min  (wake-up, self-graded)
///  - Discover:  5 min  (real ExperienceProgram first-run flow)
///  - Boundary:  2 min  (one scene, one judgment, contrast explanation)
///  - Transfer:  2 min  (new-situation drill)
const Map<DailySessionTaskType, int> kDailySessionTaskMinutes = {
  DailySessionTaskType.recall: 1,
  DailySessionTaskType.discover: 5,
  DailySessionTaskType.boundary: 2,
  DailySessionTaskType.transfer: 2,
};

/// Estimated minutes for a list of tasks — the only estimate computation.
int dailySessionEstimatedMinutes(List<DailySessionTask> tasks) =>
    tasks.fold(0, (sum, task) => sum + kDailySessionTaskMinutes[task.type]!);

/// The block a task belongs to.
DailySessionBlock blockFor(DailySessionTaskType type) => switch (type) {
  DailySessionTaskType.recall => DailySessionBlock.warmup,
  DailySessionTaskType.discover => DailySessionBlock.core,
  DailySessionTaskType.boundary => DailySessionBlock.boundary,
  DailySessionTaskType.transfer => DailySessionBlock.transfer,
};

/// One step of a session plan.
@immutable
class DailySessionTask {
  const DailySessionTask({
    required this.id,
    required this.type,
    required this.primarySenseId,
    this.secondarySenseId,
  });

  final String id;
  final DailySessionTaskType type;

  /// The sense this task centers on.
  final String primarySenseId;

  /// The other side of a boundary task.
  final String? secondarySenseId;

  DailySessionBlock get block => blockFor(type);
}

/// A complete session plan for one mode. Immutable; dynamic insertions
/// (remedial transfer after a Forgot) produce a new plan instance.
@immutable
class DailySessionPlan {
  const DailySessionPlan._(this.tasks, this.estimatedMinutes);

  factory DailySessionPlan(List<DailySessionTask> tasks) => DailySessionPlan._(
    List.unmodifiable(tasks),
    dailySessionEstimatedMinutes(tasks),
  );

  final List<DailySessionTask> tasks;
  final int estimatedMinutes;

  bool get isEmpty => tasks.isEmpty;

  int countOf(DailySessionTaskType type) =>
      tasks.where((t) => t.type == type).length;

  /// A plan with [task] inserted after [index] (used for the remedial
  /// transfer inserted after a Forgot recall).
  DailySessionPlan insertingAfter(int index, DailySessionTask task) {
    final next = [...tasks]..insert(index + 1, task);
    return DailySessionPlan(next);
  }
}

/// Self-grading options for a recall task (prototype-only; no FSRS write).
enum DailySessionRecallGrade { forgot, hard, gotIt }

/// Per-task outcome, recorded while the session runs.
@immutable
class DailySessionResult {
  const DailySessionResult({
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
  final DailySessionTaskType type;
  final String primarySenseId;
  final String? secondarySenseId;
  final DailySessionRecallGrade? recallGrade;
  final bool? boundaryCorrect;
  final bool? transferCorrect;
  final int? discoverFirstAttemptCorrect;
  final int? discoverTotalQuestions;
}

/// Everything a completed session produced, plus which senses got a
/// remedial transfer drill.
@immutable
class DailySessionCompletion {
  const DailySessionCompletion({
    required this.results,
    required this.completedAt,
    required this.insertedTransferSenseIds,
  });

  final List<DailySessionResult> results;
  final DateTime completedAt;

  /// Senses for which a remedial transfer was inserted during this session
  /// (recall answered Forgot). Used by the completion page and the graph.
  final Set<String> insertedTransferSenseIds;
}
