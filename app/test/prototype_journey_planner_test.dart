/// Prototype journey planner tests: determinism and graceful fallback.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_plan.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_planner.dart';
import 'package:scenelex/features/journey_prototype/prototype_learner_state.dart';

// The real asset I/O must run in the real async zone; the tests preload it
// once and inject it through in-memory loaders.
String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  final catalog = await BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
  return catalog;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  test('canonical learner state produces the canonical journey, '
      'deterministically', () async {
    final catalog = await loadCatalog();
    final learner = PrototypeLearnerState.resolve(
      catalog: catalog,
      byLemma: PrototypeLearnerState.defaultByLemma,
    );
    const planner = PrototypeJourneyPlanner();

    final first = planner.plan(catalog: catalog, learnerState: learner);
    final second = planner.plan(catalog: catalog, learnerState: learner);

    expect(
      first.tasks.map((t) => t.type).toList(),
      [
        JourneyTaskType.recall,
        JourneyTaskType.newConcept,
        JourneyTaskType.discrimination,
        JourneyTaskType.transfer,
        JourneyTaskType.newConcept,
      ],
    );
    // Sense ids resolve through the catalog (not by assuming id == lemma).
    expect(first.tasks[0].primarySenseId, 'reluctant-01');
    expect(first.tasks[1].primarySenseId, 'messy-01');
    expect(first.tasks[2].primarySenseId, 'messy-01');
    expect(first.tasks[2].secondarySenseId, 'dirty-01');
    expect(first.tasks[3].primarySenseId, 'reluctant-01');
    expect(first.tasks[4].primarySenseId, 'almost-01');
    // The full plan is stable: same input, same tasks, same estimate.
    expect(
      first.tasks.map((t) => t.id).toList(),
      second.tasks.map((t) => t.id).toList(),
    );
    expect(first.estimatedMinutes, second.estimatedMinutes);
    expect(first.estimatedMinutes, 10);
    // The journey mixes task kinds (the product claim).
    expect(first.countOf(JourneyTaskType.recall), 1);
    expect(first.countOf(JourneyTaskType.newConcept), 2);
    expect(first.countOf(JourneyTaskType.discrimination), 1);
    expect(first.countOf(JourneyTaskType.transfer), 1);
  });

  test('missing sense degrades gracefully (no crash, no fake tasks)',
      () async {
    final catalog = await loadCatalog();
    // Drop almost-01 and mark dirty as unseen: no recall / boundary /
    // second discover are possible.
    final withoutAlmost = WordSenseCatalog(
      senses: {
        for (final entry in catalog.senses.values)
          if (entry.senseId != 'almost-01') entry.senseId: entry,
      },
      bundleVersion: catalog.bundleVersion,
      schemaVersion: catalog.schemaVersion,
    );
    final learner = PrototypeLearnerState.resolve(
      catalog: withoutAlmost,
      byLemma: {
        'reluctant': PrototypeSenseStatus.learning,
        'dirty': PrototypeSenseStatus.unseen,
        'messy': PrototypeSenseStatus.unseen,
      },
    );
    const planner = PrototypeJourneyPlanner();
    final plan = planner.plan(catalog: withoutAlmost, learnerState: learner);

    expect(plan.isEmpty, isFalse);
    // messy (the boundary "new side") is discovered first; dirty (now
    // unseen) is discovered last; no boundary without a learned secondary.
    expect(plan.tasks.length, 4);
    expect(plan.tasks[0].type, JourneyTaskType.recall);
    expect(plan.tasks[0].primarySenseId, 'reluctant-01');
    expect(plan.tasks[1].type, JourneyTaskType.newConcept);
    expect(plan.tasks[1].primarySenseId, 'messy-01');
    expect(plan.tasks[2].type, JourneyTaskType.transfer);
    expect(plan.tasks[2].primarySenseId, 'reluctant-01');
    expect(plan.tasks[3].type, JourneyTaskType.newConcept);
    expect(plan.tasks[3].primarySenseId, 'dirty-01');
  });

  test('learner state resolution never crashes on unknown lemmas', () async {
    final catalog = await loadCatalog();
    final learner = PrototypeLearnerState.resolve(
      catalog: catalog,
      byLemma: {
        'reluctant': PrototypeSenseStatus.learning,
        'nonexistent-word': PrototypeSenseStatus.mastered,
      },
    );
    expect(learner.isLearned('reluctant-01'), isTrue);
    expect(learner.statusFor('nonexistent-word'), PrototypeSenseStatus.unseen);
    final plan = const PrototypeJourneyPlanner().plan(
      catalog: catalog,
      learnerState: learner,
    );
    expect(plan.tasks, isNotEmpty);
    // Only the sense that really exists enters the journey.
    expect(plan.tasks.every((t) => t.primarySenseId != 'nonexistent-word'),
        isTrue);
  });
}
