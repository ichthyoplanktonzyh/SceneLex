/// Prototype learner state — the "where is this learner" mock for the
/// Journey preview.
///
/// The Journey prototype must be stable and reproducible, so the learner
/// state is explicit instead of read from a real DB. This is the ONLY place
/// that decides how far the learner has come; everything else (content,
/// programs, semantics) comes from the real catalog.
///
/// Production never imports this file; it lives under `features/journey_prototype`
/// so the whole prototype can be deleted cleanly.
library;

import '../../domain/content_catalog/word_sense_catalog.dart';

/// How well a sense is established for the prototype learner.
enum PrototypeSenseStatus {
  /// Learned and stable (no recall needed today).
  mastered,

  /// Learned but due today (needs recall).
  learning,

  /// Not learned yet.
  unseen,
}

/// Immutable prototype learner state, keyed by real sense id.
class PrototypeLearnerState {
  const PrototypeLearnerState._(this._bySenseId);

  /// Prototype-only: defines the learner's starting point by *lemma*.
  /// Sense ids are resolved through the catalog (a lemma may map to several
  /// senses; we take the first matching entry). Unknown lemmas are dropped.
  static PrototypeLearnerState resolve({
    required WordSenseCatalog catalog,
    required Map<String, PrototypeSenseStatus> byLemma,
  }) {
    final bySenseId = <String, PrototypeSenseStatus>{};
    for (final entry in catalog.senses.values) {
      final status = byLemma[entry.lemma];
      if (status != null) {
        bySenseId.putIfAbsent(entry.senseId, () => status);
      }
    }
    return PrototypeLearnerState._(Map.unmodifiable(bySenseId));
  }

  /// The standard demo learner used by the preview entry.
  ///
  ///   reluctant → learning (learned, due today)
  ///   dirty     → mastered (learned, stable)
  ///   messy     → unseen
  ///   almost    → unseen
  static const Map<String, PrototypeSenseStatus> defaultByLemma = {
    'reluctant': PrototypeSenseStatus.learning,
    'dirty': PrototypeSenseStatus.mastered,
    'messy': PrototypeSenseStatus.unseen,
    'almost': PrototypeSenseStatus.unseen,
  };

  final Map<String, PrototypeSenseStatus> _bySenseId;

  PrototypeSenseStatus statusFor(String senseId) =>
      _bySenseId[senseId] ?? PrototypeSenseStatus.unseen;

  bool isLearned(String senseId) =>
      statusFor(senseId) != PrototypeSenseStatus.unseen;

  /// Senses whose status is [PrototypeSenseStatus.learning] (due today).
  List<String> dueSenseIds(WordSenseCatalog catalog) =>
      _ordered(catalog, PrototypeSenseStatus.learning);

  /// Senses not yet learned, in catalog order.
  List<String> unseenSenseIds(WordSenseCatalog catalog) =>
      _ordered(catalog, PrototypeSenseStatus.unseen);

  List<String> _ordered(WordSenseCatalog catalog, PrototypeSenseStatus want) =>
      catalog.senses.values
          .where((e) => statusFor(e.senseId) == want)
          .map((e) => e.senseId)
          .toList(growable: false);
}
