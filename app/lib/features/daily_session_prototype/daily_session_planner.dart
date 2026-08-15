/// Daily Session planner — turns catalog + prototype learner state + mode
/// into a session plan.
///
/// This is NOT a hard-coded script: the plan is recomputed from the mode,
/// the due senses and the unseen senses at plan time, and the session may
/// later be extended dynamically (remedial transfer after a Forgot recall).
/// Given the same catalog, learner state and mode it is deterministic.
///
/// Every sense id in the plan is a real catalog id; missing content degrades
/// gracefully (tasks are dropped or skipped, never crashes). The estimate
/// comes from the centralized per-task duration weights
/// (`kDailySessionTaskMinutes`).
///
/// Mode rules (also documented in docs/prototypes/daily-session/README.md):
///  - standard: due recall(s) → one discover (prefer the "new side" of a
///    prototype boundary) → boundary when the discovered sense has a learned
///    partner. No transfer by default.
///  - reviewOnly: only due recalls. Empty plan when nothing is due.
///  - learnOnly: one discover (+ boundary when available). Empty plan when
///    nothing is unseen.
library;

import '../../domain/content_catalog/word_sense_catalog.dart';
import 'daily_session_models.dart';
import 'session_learner_state.dart';
import 'session_semantic_graph.dart';

class DailySessionPlanner {
  const DailySessionPlanner({
    this.boundaryRelations = kSessionBoundaryRelations,
  });

  /// Prototype boundary relations (dirty ↔ messy by default).
  final List<SessionBoundaryRelation> boundaryRelations;

  DailySessionPlan plan({
    required WordSenseCatalog catalog,
    required SessionLearnerState learnerState,
    required DailySessionMode mode,
  }) {
    final tasks = <DailySessionTask>[];
    final unseen = learnerState.unseenSenseIds(catalog);
    final due = learnerState.dueSenseIds(catalog);

    // Warm-up: recall every sense that is due today (never in learn-only —
    // that mode contains no recall at all).
    if (mode != DailySessionMode.learnOnly) {
      for (final senseId in due) {
        tasks.add(
          DailySessionTask(
            id: 'recall-$senseId',
            type: DailySessionTaskType.recall,
            primarySenseId: senseId,
          ),
        );
      }
    }

    if (mode != DailySessionMode.reviewOnly) {
      // Core: discover one unseen sense — prefer the "new side" of a
      // prototype boundary so the boundary can be taught in the same
      // session; otherwise the first unseen sense in catalog order.
      final discoverSense =
          _boundaryPrimary(catalog, unseen) ?? unseen.firstOrNull;
      if (discoverSense != null) {
        tasks.add(
          DailySessionTask(
            id: 'discover-$discoverSense',
            type: DailySessionTaskType.discover,
            primarySenseId: discoverSense,
          ),
        );
        // Boundary: only when the discovered sense has a usable boundary
        // whose other side is already learned. No usable boundary → the
        // discover still stands alone.
        final boundary = _boundaryTask(catalog, learnerState, discoverSense);
        if (boundary != null) tasks.add(boundary);
      }
    }

    return DailySessionPlan(tasks);
  }

  /// The "new side" of the first boundary relation, when still unseen.
  String? _boundaryPrimary(WordSenseCatalog catalog, List<String> unseen) {
    for (final relation in boundaryRelations) {
      final primary = _senseForLemma(catalog, relation.primaryLemma);
      if (primary != null && unseen.contains(primary)) return primary;
    }
    return null;
  }

  DailySessionTask? _boundaryTask(
    WordSenseCatalog catalog,
    SessionLearnerState learnerState,
    String? newlyDiscoveredSenseId,
  ) {
    for (final relation in boundaryRelations) {
      final primary = _senseForLemma(catalog, relation.primaryLemma);
      final secondary = _senseForLemma(catalog, relation.secondaryLemma);
      if (primary == null || secondary == null) continue;
      if (primary != newlyDiscoveredSenseId) continue;
      if (!learnerState.isLearned(secondary)) continue;
      return DailySessionTask(
        id: 'boundary-$primary-vs-$secondary',
        type: DailySessionTaskType.boundary,
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
