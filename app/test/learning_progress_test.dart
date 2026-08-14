/// Learning progress derivations: home numbers, learn group selection, due
/// queue, review queue and study stats. Pure domain logic, no Flutter, no DB.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';
import 'package:scenelex/domain/learning/learning_progress.dart';
import 'package:scenelex/domain/learning/study_stats.dart';

import 'fixtures/program_factory.dart';

WordSenseCatalog catalogFor(List<String> ids) {
  final catalog = <String, Map<String, dynamic>>{};
  for (final id in ids) {
    catalog[id] = {
      'sense_id': id,
      'sense_key': 'k-$id',
      'lemma': id,
      'pos': 'noun',
      'ipa': '/x/',
      'semantic_type': 'entity',
      'locale_l1': 'zh',
      'invariant': 'i-$id',
      'l1_confusables': <String>[],
      'boundaries': <Map<String, dynamic>>[],
      'boundaries_status': 'empty',
      'program_id': 'p-$id',
      'program_version': 1,
    };
  }
  return WordSenseCatalog.fromJson({
    'bundle_version': 1,
    'schema_version': '1.0',
    'catalog': catalog,
  });
}

LearningStateView stateFor(String senseId, {DateTime? dueAt, String? card}) =>
    LearningStateView(
      wordSenseId: senseId,
      dueAt: dueAt,
      fsrsCardState: card,
    );

ExperienceProgram programFor(String senseId) {
  final json = programJsonWithUnitCount(1);
  (json['program_id'] as String?)!;
  final withPool = Map<String, Object>.from(json)
    ..['review_pool'] = [
      {'id': 'r-$senseId-1', 'episode': 'ep', 'lemma': senseId},
      {'id': 'r-$senseId-2', 'episode': 'ep2', 'lemma': senseId},
    ];
  return ExperienceProgram.fromJson(withPool);
}

void main() {
  group('deriveLearningProgress', () {
    test('empty catalog and states', () {
      final p = deriveLearningProgress(
        catalog: catalogFor(const []),
        states: const [],
      );
      expect(p.catalogSize, 0);
      expect(p.learnCount, 0);
      expect(p.reviewCount, 0);
      expect(p.learnedCount, 0);
    });

    test('fresh catalog: all learnable, nothing due', () {
      final catalog = catalogFor(['s-01', 's-02', 's-03', 's-04']);
      final p = deriveLearningProgress(catalog: catalog, states: const []);
      expect(p.learnCount, 4);
      expect(p.reviewCount, 0);
      expect(p.newCount, 0);
    });

    test('learned senses are no longer learnable', () {
      final catalog = catalogFor(['s-01', 's-02']);
      final p = deriveLearningProgress(
        catalog: catalog,
        states: [
          stateFor('s-01', dueAt: DateTime.now(), card: 'learning'),
        ],
      );
      expect(p.learnCount, 1);
      expect(p.learnedCount, 1);
      expect(p.reviewCount, 1);
      expect(p.learningCount, 1);
    });

    test('fsrs distribution buckets', () {
      final catalog = catalogFor(['a', 'b', 'c', 'd', 'e', 'f']);
      final p = deriveLearningProgress(
        catalog: catalog,
        states: [
          stateFor('a', card: 'learning'),
          stateFor('b', card: 'review'),
          stateFor('c', card: 'relearning'),
          stateFor('d', card: 'new'),
          stateFor('e', dueAt: DateTime.now(), card: 'review'),
        ],
      );
      expect(p.newCount, 1);
      expect(p.learningCount, 1);
      expect(p.reviewingCount, 2);
      expect(p.relearningCount, 1);
      expect(p.reviewCount, 1, reason: 'only the due review card counts');
    });
  });

  group('nextLearnGroup', () {
    test('stable catalog order, capped by group size', () {
      final catalog = catalogFor(['c', 'a', 'b', 'd']);
      expect(
        nextLearnGroup(
          catalog: catalog,
          learnedSenseIds: const {},
          maxGroupSize: 3,
        ),
        orderedEquals(['c', 'a', 'b']),
      );
      expect(
        nextLearnGroup(
          catalog: catalog,
          learnedSenseIds: const {},
          maxGroupSize: 8,
        ),
        orderedEquals(['c', 'a', 'b', 'd']),
      );
    });

    test('learned senses are skipped', () {
      final catalog = catalogFor(['a', 'b', 'c', 'd']);
      expect(
        nextLearnGroup(
          catalog: catalog,
          learnedSenseIds: const {'a', 'c'},
          maxGroupSize: 4,
        ),
        orderedEquals(['b', 'd']),
      );
    });
  });

  group('orderedDueSenses', () {
    test('due first by ascending dueAt, others never included', () {
      final now = DateTime(2026, 8, 14, 12);
      final catalog = catalogFor(['a', 'b', 'c']);
      final order = orderedDueSenses(
        catalog: catalog,
        states: {
          'a': stateFor('a', dueAt: now.subtract(const Duration(days: 2))),
          'b': stateFor('b', dueAt: now.add(const Duration(days: 1))),
          'c': stateFor('c', dueAt: now.subtract(const Duration(hours: 1))),
        },
        now: now,
      );
      expect(order, orderedEquals(['a', 'c']));
    });

    test('states without dueAt never enter the queue', () {
      final catalog = catalogFor(['a']);
      final order = orderedDueSenses(
        catalog: catalog,
        states: {'a': stateFor('a', card: 'new')},
        now: DateTime(2026),
      );
      expect(order, isEmpty);
    });
  });

  group('buildReviewQueue', () {
    test('least-used review pool item wins; rotation across sessions', () {
      final catalog = catalogFor(['s-01']);
      final programs = {'s-01': programFor('s-01')};
      final queue1 = buildReviewQueue(
        catalog: catalog,
        states: {
          's-01': stateFor('s-01', dueAt: DateTime(2020), card: 'review'),
        },
        programs: programs,
        usedItemCounts: const {},
        transferMode: false,
      );
      expect(queue1, hasLength(1));
      expect(queue1.first.experienceUnitId, 'r-s-01-1');
      expect(queue1.first.isNewItem, isTrue);

      final queue2 = buildReviewQueue(
        catalog: catalog,
        states: {
          's-01': stateFor('s-01', dueAt: DateTime(2020), card: 'review'),
        },
        programs: programs,
        usedItemCounts: const {'r-s-01-1': 1},
        transferMode: false,
      );
      expect(queue2.first.experienceUnitId, 'r-s-01-2');
    });

    test('transfer mode uses the concept transfer unit, never review pool',
        () {
      final catalog = catalogFor(['s-01']);
      final withTransferJson = programJsonWithUnitCount(1)
        ..['review_pool'] = [
          {'id': 'r-s-01-1', 'episode': 'ep', 'lemma': 's-01'},
        ]
        ..['units'] = [
          ...(programJsonWithUnitCount(1)['units'] as List<Object?>),
          {
            'id': 'transfer-1',
            'sequence': 2,
            'role': 'transfer',
            'experience': {
              'episode': 't',
              'observable_evidence': <String>[],
              'surface_dimensions': [
                {'name': 'd', 'baseline': 'b', 'deviation': 'v'},
              ],
            },
            'interaction': {
              'question': 'q',
              'answers': [
                {
                  'id': 't1',
                  'text': 'yes',
                  'is_correct': true,
                  'feedback': 'right',
                },
                {
                  'id': 't2',
                  'text': 'no',
                  'is_correct': false,
                  'feedback': 'wrong',
                },
              ],
            },
          },
        ];
      final withTransfer = ExperienceProgram.fromJson(withTransferJson);
      final queue = buildReviewQueue(
        catalog: catalog,
        states: {'s-01': stateFor('s-01')},
        programs: {'s-01': withTransfer},
        usedItemCounts: const {},
        transferMode: true,
      );
      expect(queue, hasLength(1));
      expect(queue.first.isTransfer, isTrue);
    });

    test('cap limits the queue', () {
      final catalog = catalogFor(['a', 'b', 'c']);
      final programs = {for (final id in ['a', 'b', 'c']) id: programFor(id)};
      final states = {
        for (final id in ['a', 'b', 'c'])
          id: stateFor(id, dueAt: DateTime(2020), card: 'review'),
      };
      final queue = buildReviewQueue(
        catalog: catalog,
        states: states,
        programs: programs,
        usedItemCounts: const {},
        transferMode: false,
        cap: 2,
      );
      expect(queue, hasLength(2));
    });
  });

  group('deriveStudyStats', () {
    test('counts today, totals, streak and week calendar', () {
      final now = DateTime(2026, 8, 14, 18);
      final stats = deriveStudyStats(
        checkinDayKeys: {'2026-08-12', '2026-08-13', '2026-08-14'},
        reviewEventTimes: [
          DateTime(2026, 8, 14, 9),
          DateTime(2026, 8, 14, 20),
          DateTime(2026, 8, 13, 9),
        ],
        sessions: [
          (
            startedAt: DateTime(2026, 8, 14, 10),
            endedAt: DateTime(2026, 8, 14, 10, 5),
            durationSeconds: 300,
          ),
          (
            startedAt: DateTime(2026, 8, 10, 10),
            endedAt: DateTime(2026, 8, 10, 10, 2),
            durationSeconds: 120,
          ),
        ],
        learnedCount: 7,
        now: now,
      );
      expect(stats.todayLearnedCount, 2);
      expect(stats.totalLearnedCount, 7);
      expect(stats.todayDurationSeconds, 300);
      expect(stats.totalDurationSeconds, 420);
      expect(stats.streakDays, 3);
      expect(stats.week, hasLength(7));
      expect(stats.week.first.date.weekday, DateTime.monday);
      expect(stats.week.where((d) => d.checkedIn).length, 3);
      expect(stats.week.singleWhere((d) => d.isToday).date.day, 14);
    });

    test('broken streak restarts; yesterday grace keeps it', () {
      final now = DateTime(2026, 8, 14, 18);
      final withYesterday = deriveStudyStats(
        checkinDayKeys: {'2026-08-13', '2026-08-12'},
        reviewEventTimes: const [],
        sessions: const [],
        learnedCount: 0,
        now: now,
      );
      expect(withYesterday.streakDays, 2, reason: 'today missing, grace day');

      final broken = deriveStudyStats(
        checkinDayKeys: {'2026-08-11', '2026-08-10'},
        reviewEventTimes: const [],
        sessions: const [],
        learnedCount: 0,
        now: now,
      );
      expect(broken.streakDays, 0);
    });
  });
}
