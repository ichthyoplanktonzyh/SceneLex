/// Review session: new-experience reverse retrieval.
///
/// Queue: due senses → each sense's least-used review_pool item (rotation,
/// unused items first). Transfer mode uses the sense's concept transfer
/// experience instead. First-learning units are never replayed as review
/// cards, and the target word never appears before the reveal. Grading runs
/// the real FSRS schedule and writes the review event locally (offline-safe).
library;

import 'package:flutter/foundation.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../domain/learning/learning_progress.dart';

/// One review card (content loaded; nothing L2-exposing until reveal).
@immutable
class ReviewCard {
  const ReviewCard({
    required this.senseId,
    required this.experienceUnitId,
    required this.programVersion,
    required this.isTransfer,
    required this.isNewItem,
    required this.episode,
    required this.lemma,
    required this.ipa,
    required this.minimalHint,
    this.question,
    this.choices,
  });

  final String senseId;
  final String experienceUnitId;
  final int programVersion;
  final bool isTransfer;

  /// True when this review_pool item has never been used locally.
  final bool isNewItem;

  /// Learner-facing experience episode (no target word guaranteed by content
  /// contract; the UI never renders [lemma] before the reveal).
  final String episode;

  // Reveal-only fields.
  final String lemma;
  final String? ipa;
  final String? minimalHint;

  /// Transfer judgment question (only for transfer mode cards).
  final String? question;

  /// Transfer judgment choices (transfer mode only).
  final List<Answer>? choices;
}

enum ReviewPhase { loading, loadError, recalling, revealed, grading, done }

typedef ReviewSubmitFn =
    Future<void> Function({
      required String wordSenseId,
      required String learningStateId,
      required String experienceUnitId,
      required int programVersion,
      required int rating,
      required DateTime reviewedAtClient,
    });

class ReviewSessionViewModel extends ChangeNotifier {
  ReviewSessionViewModel({
    required this.transferMode,
    this.cap,
    required this.submitReview,
  });

  final bool transferMode;
  final int? cap;
  final ReviewSubmitFn submitReview;

  ReviewPhase _phase = ReviewPhase.loading;
  ReviewPhase get phase => _phase;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<ReviewCard> _cards = const [];
  List<ReviewCard> get cards => _cards;

  int _index = 0;
  int get index => _index;

  ReviewCard? get currentCard => _index < _cards.length ? _cards[_index] : null;

  bool _revealed = false;
  bool get revealed => _revealed;

  int _gradedCount = 0;
  int get gradedCount => _gradedCount;

  /// Builds the queue and loads the first card.
  Future<void> load({
    required WordSenseCatalog catalog,
    required Map<String, LearningStateView> states,
    required Map<String, ExperienceProgram> programs,
    required Map<String, int> usedItemCounts,
  }) async {
    _phase = ReviewPhase.loading;
    notifyListeners();
    final tasks = buildReviewQueue(
      catalog: catalog,
      states: states,
      programs: programs,
      usedItemCounts: usedItemCounts,
      transferMode: transferMode,
      cap: cap,
    );
    if (tasks.isEmpty) {
      _phase = ReviewPhase.done;
      notifyListeners();
      return;
    }
    final cards = <ReviewCard>[];
    for (final task in tasks) {
      final program = programs[task.senseId];
      final entry = catalog.entryFor(task.senseId);
      if (program == null) continue;
      if (task.isTransfer) {
        final unit = program.units
            .where((u) => u.id == task.experienceUnitId)
            .firstOrNull;
        if (unit == null) continue;
        cards.add(
          ReviewCard(
            senseId: task.senseId,
            experienceUnitId: task.experienceUnitId,
            programVersion: task.programVersion,
            isTransfer: true,
            isNewItem: task.isNewItem,
            episode: unit.experience.episode,
            lemma: entry.lemma,
            ipa: entry.ipa,
            minimalHint: program.symbolBinding.minimalL1Gloss,
            question: unit.interaction.question,
            choices: unit.interaction.answers,
          ),
        );
      } else {
        final item = program.reviewPool
            .where((i) => i.id == task.experienceUnitId)
            .firstOrNull;
        if (item == null) continue;
        final experience = item.experience;
        if (experience == null) continue;
        cards.add(
          ReviewCard(
            senseId: task.senseId,
            experienceUnitId: task.experienceUnitId,
            programVersion: task.programVersion,
            isTransfer: false,
            isNewItem: task.isNewItem,
            episode: Experience.fromJson(experience).episode,
            lemma: entry.lemma,
            ipa: entry.ipa,
            minimalHint: program.symbolBinding.minimalL1Gloss,
          ),
        );
      }
    }
    if (cards.isEmpty) {
      _phase = ReviewPhase.done;
      notifyListeners();
      return;
    }
    _cards = cards;
    _index = 0;
    _revealed = false;
    _phase = ReviewPhase.recalling;
    notifyListeners();
  }

  /// Reveals the answer (word, IPA, minimal hint). The target word is only
  /// introduced here.
  void reveal() {
    if (_revealed) return;
    _revealed = true;
    _phase = ReviewPhase.revealed;
    notifyListeners();
  }

  Future<bool> grade(
    int rating, {
    required String learningStateId,
    required DateTime reviewedAtClient,
  }) async {
    final card = currentCard;
    if (card == null || !_revealed) return false;
    _phase = ReviewPhase.grading;
    notifyListeners();
    try {
      await submitReview(
        wordSenseId: card.senseId,
        learningStateId: learningStateId,
        experienceUnitId: card.experienceUnitId,
        programVersion: card.programVersion,
        rating: rating,
        reviewedAtClient: reviewedAtClient,
      );
    } catch (_) {
      // Offline submission failure is surfaced as a state, not a crash; the
      // card is not consumed.
      _phase = ReviewPhase.revealed;
      notifyListeners();
      return false;
    }
    _gradedCount += 1;
    if (_index + 1 < _cards.length) {
      _index += 1;
      _revealed = false;
      _phase = ReviewPhase.recalling;
    } else {
      _phase = ReviewPhase.done;
    }
    notifyListeners();
    return true;
  }

  /// Skip the remaining cards (queue empty states only); unused.
  void close() {
    _phase = ReviewPhase.done;
    notifyListeners();
  }
}
