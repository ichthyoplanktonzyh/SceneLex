/// Session learner state — the "where is this learner" mock for the Daily
/// Session prototype.
///
/// Content stays real (catalog + programs); only the learner's mastery
/// status is prototype state. This model lives here so the session domain
/// never depends on the Journey prototype; the only bridge to the shared
/// prototype learner state is the thin adapter below.
library;

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../journey_prototype/prototype_learner_state.dart'
    show PrototypeLearnerState, PrototypeSenseStatus;

/// How well a sense is established for the prototype learner.
enum SessionSenseStatus {
  /// Learned and stable (no recall needed today).
  mastered,

  /// Learned but due today (needs recall).
  learning,

  /// Not learned yet.
  unseen,
}

/// Immutable session learner state, keyed by real sense id.
class SessionLearnerState {
  const SessionLearnerState._(this._bySenseId);

  /// Thin adapter: maps the Journey prototype's learner state (lemma-based
  /// resolution) into the session domain. One point of contact — the
  /// session planner never sees Journey types.
  factory SessionLearnerState.fromPrototype(
    PrototypeLearnerState prototype, {
    required WordSenseCatalog catalog,
  }) {
    final bySenseId = <String, SessionSenseStatus>{};
    for (final entry in catalog.senses.values) {
      if (!prototype.isLearned(entry.senseId)) continue;
      final status =
          prototype.statusFor(entry.senseId) == PrototypeSenseStatus.learning
          ? SessionSenseStatus.learning
          : SessionSenseStatus.mastered;
      bySenseId[entry.senseId] = status;
    }
    return SessionLearnerState._(Map.unmodifiable(bySenseId));
  }

  /// The standard demo learner used by the preview entry (same demo state
  /// as the Journey prototype, resolved through the catalog):
  ///
  ///   reluctant → learning (learned, due today)
  ///   dirty     → mastered (learned, stable)
  ///   messy     → unseen
  ///   almost    → unseen
  static SessionLearnerState standard(WordSenseCatalog catalog) {
    final prototype = PrototypeLearnerState.resolve(
      catalog: catalog,
      byLemma: PrototypeLearnerState.defaultByLemma,
    );
    return SessionLearnerState.fromPrototype(prototype, catalog: catalog);
  }

  /// A learner whose statuses are given explicitly (tests / empty states).
  static SessionLearnerState fromByLemma({
    required WordSenseCatalog catalog,
    required Map<String, SessionSenseStatus> byLemma,
  }) {
    final bySenseId = <String, SessionSenseStatus>{};
    for (final entry in catalog.senses.values) {
      final status = byLemma[entry.lemma];
      if (status != null) bySenseId.putIfAbsent(entry.senseId, () => status);
    }
    return SessionLearnerState._(Map.unmodifiable(bySenseId));
  }

  final Map<String, SessionSenseStatus> _bySenseId;

  SessionSenseStatus statusFor(String senseId) =>
      _bySenseId[senseId] ?? SessionSenseStatus.unseen;

  bool isLearned(String senseId) =>
      statusFor(senseId) != SessionSenseStatus.unseen;

  /// Senses whose status is [SessionSenseStatus.learning] (due today).
  List<String> dueSenseIds(WordSenseCatalog catalog) =>
      _ordered(catalog, SessionSenseStatus.learning);

  /// Senses not yet learned, in catalog order.
  List<String> unseenSenseIds(WordSenseCatalog catalog) =>
      _ordered(catalog, SessionSenseStatus.unseen);

  List<String> _ordered(WordSenseCatalog catalog, SessionSenseStatus want) =>
      catalog.senses.values
          .where((e) => statusFor(e.senseId) == want)
          .map((e) => e.senseId)
          .toList(growable: false);

  /// The learner state after a completed session: senses established today
  /// become "learning" (just learned, will be due later).
  SessionLearnerState applyingCompletion({
    required Set<String> newlyEstablishedSenseIds,
  }) {
    if (newlyEstablishedSenseIds.isEmpty) return this;
    final next = Map<String, SessionSenseStatus>.of(_bySenseId);
    for (final senseId in newlyEstablishedSenseIds) {
      next[senseId] = SessionSenseStatus.learning;
    }
    return SessionLearnerState._(Map.unmodifiable(next));
  }
}
