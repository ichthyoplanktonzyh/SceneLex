/// Prototype journey planner — turns the prototype learner state into a
/// deterministic daily journey.
///
/// This is NOT a learning-path algorithm: it hard-codes a canonical task
/// sequence (recall → discover → boundary → transfer → discover) that
/// demonstrates the product idea with the real bundled content. Given the
/// same catalog and the same learner state, it always produces the same plan.
///
/// Every sense id in the plan is a real catalog id; missing content degrades
/// gracefully (tasks are dropped, never crashes).
library;

import '../../domain/content_catalog/word_sense_catalog.dart';
import 'prototype_journey_plan.dart';
import 'prototype_learner_state.dart';
import 'prototype_semantic_graph.dart';

class PrototypeJourneyPlanner {
  const PrototypeJourneyPlanner({
    this.boundaryRelations = kPrototypeBoundaryRelations,
  });

  /// Prototype boundary relations (dirty ↔ messy by default).
  final List<PrototypeBoundaryRelation> boundaryRelations;

  /// Builds today's journey. Deterministic for a fixed catalog + state.
  JourneyPlan plan({
    required WordSenseCatalog catalog,
    required PrototypeLearnerState learnerState,
  }) {
    final tasks = <JourneyTask>[];
    final unseen = learnerState.unseenSenseIds(catalog);

    // 1. Recall: the learned sense that is due today.
    final recallSense = learnerState.dueSenseIds(catalog).firstOrNull;
    if (recallSense != null) {
      tasks.add(
        JourneyTask(
          id: 'recall-$recallSense',
          type: JourneyTaskType.recall,
          primarySenseId: recallSense,
        ),
      );
    }

    // 2. Discover: prefer the "new side" of the prototype boundary relation
    //    (so the boundary can be taught today), otherwise the first unseen
    //    sense in catalog order.
    final boundaryPrimary = _boundaryPrimary(catalog, unseen);
    final discoverSense1 = boundaryPrimary ?? (unseen.isEmpty ? null : unseen.first);
    if (discoverSense1 != null) {
      tasks.add(
        JourneyTask(
          id: 'discover-$discoverSense1',
          type: JourneyTaskType.newConcept,
          primarySenseId: discoverSense1,
        ),
      );
    }

    // 3. Boundary: a prototype relation whose "new" side was just
    //    discovered and whose other side is already learned.
    final boundary = _boundaryTask(catalog, learnerState, discoverSense1);
    if (boundary != null) tasks.add(boundary);

    // 4. Transfer: take the recalled sense to a brand-new situation.
    if (recallSense != null) {
      tasks.add(
        JourneyTask(
          id: 'transfer-$recallSense',
          type: JourneyTaskType.transfer,
          primarySenseId: recallSense,
        ),
      );
    }

    // 5. Discover: the next unseen sense (after the one used above).
    final discoverSense2 = unseen
        .where((id) => id != discoverSense1)
        .firstOrNull;
    if (discoverSense2 != null) {
      tasks.add(
        JourneyTask(
          id: 'discover-$discoverSense2',
          type: JourneyTaskType.newConcept,
          primarySenseId: discoverSense2,
        ),
      );
    }

    return JourneyPlan(
      tasks: List.unmodifiable(tasks),
      estimatedMinutes: tasks.length * 2,
    );
  }

  /// The "new side" of the first boundary relation, when it is still unseen.
  String? _boundaryPrimary(WordSenseCatalog catalog, List<String> unseen) {
    for (final relation in boundaryRelations) {
      final primary = _senseForLemma(catalog, relation.primaryLemma);
      if (primary != null && unseen.contains(primary)) return primary;
    }
    return null;
  }

  JourneyTask? _boundaryTask(
    WordSenseCatalog catalog,
    PrototypeLearnerState learnerState,
    String? newlyDiscoveredSenseId,
  ) {
    for (final relation in boundaryRelations) {
      final primary = _senseForLemma(catalog, relation.primaryLemma);
      final secondary = _senseForLemma(catalog, relation.secondaryLemma);
      if (primary == null || secondary == null) continue;
      // The "new" side must be the sense just discovered in this plan;
      // the other side must already be learned.
      if (primary != newlyDiscoveredSenseId) continue;
      if (!learnerState.isLearned(secondary)) continue;
      return JourneyTask(
        id: 'boundary-$primary-vs-$secondary',
        type: JourneyTaskType.discrimination,
        primarySenseId: primary,
        secondarySenseId: secondary,
      );
    }
    return null;
  }

  static String? _senseForLemma(WordSenseCatalog catalog, String lemma) {
    for (final entry in catalog.senses.values) {
      if (entry.lemma == lemma) return entry.senseId;
    }
    return null;
  }
}
