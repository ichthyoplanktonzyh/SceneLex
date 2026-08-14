/// ReviewSessionViewModel: reverse-retrieval queue, reveal gating and
/// grading state machine (pure VM with an injected submit function).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';
import 'package:scenelex/domain/learning/learning_progress.dart';
import 'package:scenelex/features/review_runtime/review_session_view_model.dart';

import 'fixtures/program_factory.dart';

WordSenseCatalog catalogFor(String senseId) => WordSenseCatalog.fromJson({
  'bundle_version': 1,
  'schema_version': '1.0',
  'catalog': {
    senseId: {
      'sense_id': senseId,
      'sense_key': 'k-$senseId',
      'lemma': senseId,
      'pos': 'noun',
      'ipa': '/x/',
      'semantic_type': 'entity',
      'locale_l1': 'zh',
      'invariant': 'i',
      'l1_confusables': <String>[],
      'boundaries': <Map<String, dynamic>>[],
      'boundaries_status': 'empty',
      'program_id': 'p-$senseId',
      'program_version': 1,
    },
  },
});

/// One due sense with a review pool of two items.
({ExperienceProgram program, String senseId}) poolProgram() {
  final json = programJsonWithUnitCount(2);
  json['review_pool'] = [
    {
      'id': 'pool-1',
      'episode': 'recall one',
      'lemma': 'pool',
      'experience': {
        'episode': 'recall one episode',
        'observable_evidence': ['e1'],
        'surface_dimensions': [
          {'name': 'd', 'baseline': 'b', 'deviation': 'v'},
        ],
      },
    },
    {
      'id': 'pool-2',
      'episode': 'recall two',
      'lemma': 'pool',
      'experience': {
        'episode': 'recall two episode',
        'observable_evidence': ['e2'],
        'surface_dimensions': [
          {'name': 'd', 'baseline': 'b', 'deviation': 'v'},
        ],
      },
    },
  ];
  return (program: ExperienceProgram.fromJson(json), senseId: 'synthetic-01');
}

Future<ReviewSessionViewModel> loadedReview({
  List<String> dueSenses = const ['synthetic-01'],
  Map<String, ExperienceProgram>? programs,
  Map<String, int> usedCounts = const {},
  bool transferMode = false,
  List<String>? submitLog,
}) async {
  final bundle = poolProgram();
  final log = submitLog ??= <String>[];
  final vm = ReviewSessionViewModel(
    transferMode: transferMode,
    submitReview: ({
      required String wordSenseId,
      required String learningStateId,
      required String experienceUnitId,
      required int programVersion,
      required int rating,
      required DateTime reviewedAtClient,
    }) async {
      log.add('$wordSenseId/$experienceUnitId/$rating');
    },
  );
  await vm.load(
    catalog: catalogFor('synthetic-01'),
    states: {for (final s in dueSenses) s: _state(s)},
    programs: programs ?? {bundle.senseId: bundle.program},
    usedItemCounts: usedCounts,
  );
  return vm;
}

LearningStateView _state(String senseId) => LearningStateView(
  wordSenseId: senseId,
  fsrsCardState: 'review',
  dueAt: DateTime(2020),
  reps: 1,
  stability: 1.0,
  difficulty: 5.0,
  scheduledDays: 1,
  lastReviewedAt: DateTime(2019),
);

void main() {
  test('reveal gating: no target word before the reveal', () async {
    final vm = await loadedReview();
    expect(vm.phase, ReviewPhase.recalling);
    final card = vm.currentCard!;
    expect(card.lemma, isNotEmpty, reason: 'card carries the reveal data');
    expect(vm.revealed, isFalse);
    vm.reveal();
    expect(vm.revealed, isTrue);
    expect(vm.phase, ReviewPhase.revealed);
  });

  test('grading advances through the queue to done', () async {
    final vm = await loadedReview();
    vm.reveal();
    final ok = await vm.grade(
      2,
      learningStateId: 'ls-1',
      reviewedAtClient: DateTime(2026, 8, 14),
    );
    expect(ok, isTrue);
    expect(vm.gradedCount, 1);
    expect(vm.phase, ReviewPhase.done);
  });

  test('failed submission is not consumed and stays on the card', () async {
    var fail = false;
    final vm = ReviewSessionViewModel(
      transferMode: false,
      submitReview: ({
        required String wordSenseId,
        required String learningStateId,
        required String experienceUnitId,
        required int programVersion,
        required int rating,
        required DateTime reviewedAtClient,
      }) async {
        fail = true;
        throw Exception('offline');
      },
    );
    final bundle = poolProgram();
    await vm.load(
      catalog: catalogFor('synthetic-01'),
      states: {'synthetic-01': _state('synthetic-01')},
      programs: {'synthetic-01': bundle.program},
      usedItemCounts: const {},
    );
    vm.reveal();
    final ok = await vm.grade(
      2,
      learningStateId: 'ls-1',
      reviewedAtClient: DateTime(2026, 8, 14),
    );
    expect(fail, isTrue);
    expect(ok, isFalse);
    expect(vm.phase, ReviewPhase.revealed,
        reason: 'a failed submission returns to the revealed state');
    expect(vm.gradedCount, 0);
  });

  test('queue is empty for an unknown sense -> done immediately', () async {
    final vm = await loadedReview(dueSenses: const ['unknown-01']);
    expect(vm.phase, ReviewPhase.done);
  });
}
