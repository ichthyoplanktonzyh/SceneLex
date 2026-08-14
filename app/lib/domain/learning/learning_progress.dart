/// Learning progress derivation: due queue, learnable senses, statistics.
/// Pure functions over catalog + local learning state (no Flutter, no DB).
library;

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/experience_program/experience_unit.dart';

/// Minimal learning state projection needed by the derivations below.
class LearningStateView {
  const LearningStateView({
    required this.wordSenseId,
    this.dueAt,
    this.fsrsCardState,
    this.reps = 0,
    this.lapses = 0,
    this.stability,
    this.difficulty,
    this.scheduledDays,
    this.lastReviewedAt,
    this.fsrsStepIndex,
  });

  final String wordSenseId;
  final DateTime? dueAt;
  final String? fsrsCardState;
  final int reps;
  final int lapses;
  final double? stability;
  final double? difficulty;
  final int? scheduledDays;
  final DateTime? lastReviewedAt;
  final int? fsrsStepIndex;

  bool get isNew => fsrsCardState == null || fsrsCardState == 'new';

  /// A card is due once it has a learning state whose due time has arrived;
  /// freshly learned cards are created already-due so the learner can
  /// consolidate them the same day.
  bool get isDue => dueAt != null && !dueAt!.isAfter(DateTime.now());

  bool get isDeleted =>
      fsrsCardState == null && dueAt == null && reps == 0 && false;

  /// FSRS stability bucket index (0..7) for the mastery overview.
  int get stabilityBucket {
    if (stability == null) return 0;
    final days = stability! / const Duration(days: 1).inSeconds;
    if (days >= 90) return 7;
    if (days >= 30) return 6;
    if (days >= 14) return 5;
    if (days >= 7) return 4;
    if (days >= 3) return 3;
    if (days >= 1) return 2;
    return 1;
  }
}

/// Derived home/study numbers for the product pages.
class LearningProgress {
  const LearningProgress({
    required this.catalogSize,
    required this.learnCount,
    required this.reviewCount,
    required this.learnedCount,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.relearningCount,
  });

  /// Senses not yet in study (Learn 待理解).
  final int learnCount;

  /// Due reviews (Review 待复习).
  final int reviewCount;

  /// Senses with an active learning state (已理解/在学).
  final int learnedCount;

  final int catalogSize;

  /// FSRS mastery distribution.
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int relearningCount;
}

/// Derive home numbers from catalog + states.
LearningProgress deriveLearningProgress({
  required WordSenseCatalog catalog,
  required Iterable<LearningStateView> states,
}) {
  final bySense = {for (final s in states) s.wordSenseId: s};
  final learned = bySense.keys.toSet();
  var reviewCount = 0;
  var newCount = 0;
  var learningCount = 0;
  var reviewingCount = 0;
  var relearningCount = 0;
  for (final sense in catalog.senses.keys) {
    final state = bySense[sense];
    if (state == null) continue;
    if (state.isDue) reviewCount++;
    switch (state.fsrsCardState) {
      case 'learning':
        learningCount++;
      case 'review':
        reviewingCount++;
      case 'relearning':
        relearningCount++;
      default:
        newCount++;
    }
  }
  return LearningProgress(
    catalogSize: catalog.senses.length,
    learnCount: catalog.senses.length - learned.length,
    reviewCount: reviewCount,
    learnedCount: learned.length,
    newCount: newCount,
    learningCount: learningCount,
    reviewingCount: reviewingCount,
    relearningCount: relearningCount,
  );
}

/// Ordered due queue: due first (asc dueAt), then nothing else — the product
/// only offers reviews for learned senses.
List<String> orderedDueSenses({
  required WordSenseCatalog catalog,
  required Map<String, LearningStateView> states,
  DateTime? now,
}) {
  final due = <String>[];
  for (final senseId in catalog.senses.keys) {
    final state = states[senseId];
    if (state == null) continue;
    if (state.dueAt == null) continue;
    if (now != null
        ? !state.dueAt!.isAfter(now)
        : state.dueAt!.isBefore(DateTime.now())) {
      due.add(senseId);
    }
  }
  due.sort((a, b) {
    final da = states[a]!.dueAt;
    final db = states[b]!.dueAt;
    final cmp = da!.compareTo(db!);
    if (cmp != 0) return cmp;
    return a.compareTo(b);
  });
  return due;
}

/// Senses available for a new learn group: not in study yet, ordered by
/// catalog (stable Contract order), capped by [maxGroupSize].
List<String> nextLearnGroup({
  required WordSenseCatalog catalog,
  required Set<String> learnedSenseIds,
  required int maxGroupSize,
}) {
  final available = catalog.senses.keys
      .where((id) => !learnedSenseIds.contains(id))
      .toList();
  return available.take(maxGroupSize).toList();
}

/// A review task from the review_pool (recall) or a transfer unit.
class ReviewTask {
  const ReviewTask({
    required this.senseId,
    required this.experienceUnitId,
    required this.programVersion,
    required this.isTransfer,
    required this.isNewItem,
    required this.usedCount,
  });

  final String senseId;
  final String experienceUnitId;
  final int programVersion;
  final bool isTransfer;
  final bool isNewItem;
  final int usedCount;
}

/// Build the review queue: for each due sense pick its least-used
/// review_pool item (rotation), preferring unused items; transfer mode uses
/// the sense's transfer unit instead. Never replays first-learning units.
List<ReviewTask> buildReviewQueue({
  required WordSenseCatalog catalog,
  required Map<String, LearningStateView> states,
  required Map<String, ExperienceProgram> programs,
  required Map<String, int> usedItemCounts,
  required bool transferMode,
  int? cap,
}) {
  final due = transferMode
      ? catalog.senses.keys.where((id) => states[id] != null).toList()
      : orderedDueSenses(catalog: catalog, states: states);

  final tasks = <ReviewTask>[];
  for (final senseId in due) {
    final program = programs[senseId];
    if (program == null) continue;
    final entry = catalog.entryFor(senseId);
    if (transferMode) {
      final transferUnit = program.units
          .where((u) => u.role == UnitRole.transfer)
          .firstOrNull;
      if (transferUnit != null) {
        tasks.add(
          ReviewTask(
            senseId: senseId,
            experienceUnitId: transferUnit.id,
            programVersion: entry.programVersion,
            isTransfer: true,
            isNewItem: (usedItemCounts[transferUnit.id] ?? 0) == 0,
            usedCount: usedItemCounts[transferUnit.id] ?? 0,
          ),
        );
      }
      continue;
    }
    if (program.reviewPool.isEmpty) continue;
    final usableItems = program.reviewPool.where((i) => i.id != null).toList();
    if (usableItems.isEmpty) continue;
    usableItems.sort((a, b) {
      final ua = usedItemCounts[a.id] ?? 0;
      final ub = usedItemCounts[b.id] ?? 0;
      if (ua != ub) return ua.compareTo(ub);
      return a.id!.compareTo(b.id!);
    });
    final item = usableItems.first;
    tasks.add(
      ReviewTask(
        senseId: senseId,
        experienceUnitId: item.id!,
        programVersion: entry.programVersion,
        isTransfer: false,
        isNewItem: (usedItemCounts[item.id] ?? 0) == 0,
        usedCount: usedItemCounts[item.id] ?? 0,
      ),
    );
  }

  // Stable order: due first (already sorted), then transfer-mode senses in
  // catalog order. Cap for a single group.
  final capped = cap == null ? tasks : tasks.take(cap).toList();
  return List.unmodifiable(capped);
}
