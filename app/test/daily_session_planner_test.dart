/// Daily Session planner tests: mode rules, empty plans and graceful
/// degradation of the session planner.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_models.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_planner.dart';
import 'package:scenelex/features/daily_session_prototype/session_learner_state.dart';

// The real asset I/O must run in the real async zone; the tests preload it
// once and inject it through in-memory loaders.
String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  return BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  const planner = DailySessionPlanner();

  test('standard mode plans Recall + Discover + Boundary '
      '(no transfer by default)', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.standard(catalog);
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );

    expect(plan.tasks.map((t) => t.type).toList(), [
      DailySessionTaskType.recall,
      DailySessionTaskType.discover,
      DailySessionTaskType.boundary,
    ]);
    expect(plan.tasks[0].primarySenseId, 'reluctant-01');
    expect(plan.tasks[1].primarySenseId, 'messy-01');
    expect(plan.tasks[2].primarySenseId, 'messy-01');
    expect(plan.tasks[2].secondarySenseId, 'dirty-01');
    expect(plan.countOf(DailySessionTaskType.transfer), 0);
    // Deterministic: same input, same plan.
    final again = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );
    expect(
      again.tasks.map((t) => t.id).toList(),
      plan.tasks.map((t) => t.id).toList(),
    );
  });

  test('review-only mode contains only due recalls', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.standard(catalog);
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.reviewOnly,
    );

    expect(plan.tasks, isNotEmpty);
    expect(
      plan.tasks.every((t) => t.type == DailySessionTaskType.recall),
      isTrue,
    );
    expect(plan.tasks.single.primarySenseId, 'reluctant-01');
  });

  test('learn-only mode contains no recall', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.standard(catalog);
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.learnOnly,
    );

    expect(plan.countOf(DailySessionTaskType.recall), 0);
    expect(plan.tasks.map((t) => t.type).toList(), [
      DailySessionTaskType.discover,
      DailySessionTaskType.boundary,
    ]);
    expect(plan.tasks[0].primarySenseId, 'messy-01');
  });

  test('review-only returns an empty plan when nothing is due', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.fromByLemma(
      catalog: catalog,
      byLemma: {
        'reluctant': SessionSenseStatus.mastered,
        'dirty': SessionSenseStatus.mastered,
      },
    );
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.reviewOnly,
    );

    expect(plan.isEmpty, isTrue);
  });

  test('learn-only returns an empty plan when nothing is unseen', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.fromByLemma(
      catalog: catalog,
      byLemma: {
        'reluctant': SessionSenseStatus.learning,
        'dirty': SessionSenseStatus.mastered,
        'messy': SessionSenseStatus.mastered,
        'almost': SessionSenseStatus.mastered,
      },
    );
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.learnOnly,
    );

    expect(plan.isEmpty, isTrue);
  });

  test('discover still runs when no boundary is available', () async {
    final catalog = await loadCatalog();
    // dirty unseen → the messy/dirty boundary has no learned partner, but
    // messy must still be discoverable.
    final learner = SessionLearnerState.fromByLemma(
      catalog: catalog,
      byLemma: {
        'reluctant': SessionSenseStatus.learning,
        'dirty': SessionSenseStatus.unseen,
      },
    );
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );

    expect(plan.countOf(DailySessionTaskType.discover), 1);
    expect(plan.countOf(DailySessionTaskType.boundary), 0);
    expect(plan.tasks.any((t) => t.primarySenseId == 'messy-01'), isTrue);
  });

  test('missing senses in the catalog are dropped, never crash', () async {
    final catalog = await loadCatalog();
    // Remove almost and dirty entirely: nothing referencing them may appear.
    final trimmed = WordSenseCatalog(
      senses: {
        for (final entry in catalog.senses.values)
          if (entry.senseId != 'almost-01' && entry.senseId != 'dirty-01')
            entry.senseId: entry,
      },
      bundleVersion: catalog.bundleVersion,
      schemaVersion: catalog.schemaVersion,
    );
    final learner = SessionLearnerState.fromByLemma(
      catalog: trimmed,
      byLemma: {
        'reluctant': SessionSenseStatus.learning,
        'messy': SessionSenseStatus.unseen,
      },
    );
    final plan = planner.plan(
      catalog: trimmed,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );

    expect(plan.isEmpty, isFalse);
    expect(
      plan.tasks.every(
        (t) =>
            trimmed.senses.containsKey(t.primarySenseId) &&
            (t.secondarySenseId == null ||
                trimmed.senses.containsKey(t.secondarySenseId)),
      ),
      isTrue,
    );
    // Without dirty, no boundary task can reference it.
    expect(plan.countOf(DailySessionTaskType.boundary), 0);
  });

  test('estimatedMinutes uses the per-task duration weights', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.standard(catalog);
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );

    // recall 1 + discover 5 + boundary 2 = 8 minutes.
    expect(kDailySessionTaskMinutes[DailySessionTaskType.recall], 1);
    expect(kDailySessionTaskMinutes[DailySessionTaskType.discover], 5);
    expect(kDailySessionTaskMinutes[DailySessionTaskType.boundary], 2);
    expect(kDailySessionTaskMinutes[DailySessionTaskType.transfer], 2);
    expect(plan.estimatedMinutes, 8);

    final reviewOnly = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.reviewOnly,
    );
    expect(reviewOnly.estimatedMinutes, 1);
  });

  test('learner state resolution never crashes on unknown lemmas', () async {
    final catalog = await loadCatalog();
    final learner = SessionLearnerState.fromByLemma(
      catalog: catalog,
      byLemma: {
        'reluctant': SessionSenseStatus.learning,
        'nonexistent-word': SessionSenseStatus.mastered,
      },
    );
    expect(learner.isLearned('reluctant-01'), isTrue);
    expect(learner.statusFor('nonexistent-word'), SessionSenseStatus.unseen);
    final plan = planner.plan(
      catalog: catalog,
      learnerState: learner,
      mode: DailySessionMode.standard,
    );
    expect(plan.tasks, isNotEmpty);
    expect(
      plan.tasks.every((t) => t.primarySenseId != 'nonexistent-word'),
      isTrue,
    );
  });
}
