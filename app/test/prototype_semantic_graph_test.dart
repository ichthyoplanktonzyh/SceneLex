/// Prototype semantic graph tests: node statuses follow journey completion.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/features/journey_prototype/journey_preview_store.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_plan.dart';
import 'package:scenelex/features/journey_prototype/prototype_semantic_graph.dart';

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

  test('initial graph reflects the prototype learner state', () async {
    final catalog = await loadCatalog();
    final store = JourneyPreviewStore.standard(catalog: catalog);

    final statusOf = {
      for (final node in store.graph.nodes) node.senseId: node.status,
    };
    expect(statusOf['reluctant-01'], PrototypeNodeStatus.learning);
    expect(statusOf['dirty-01'], PrototypeNodeStatus.mastered);
    expect(statusOf['messy-01'], PrototypeNodeStatus.unseen);
    expect(statusOf['almost-01'], PrototypeNodeStatus.unseen);
    expect(store.graph.edges, isEmpty);
    expect(store.journeyCompletedToday, isFalse);
  });

  test('node statuses update when the journey completes', () async {
    final catalog = await loadCatalog();
    final store = JourneyPreviewStore.standard(catalog: catalog);

    store.completeJourney(
      JourneyCompletion(
        completedAt: DateTime(2026, 8, 15, 9),
        results: const [
          JourneyTaskResult(
            taskId: 'recall-reluctant-01',
            type: JourneyTaskType.recall,
            primarySenseId: 'reluctant-01',
            recallGrade: JourneyRecallGrade.gotIt,
          ),
          JourneyTaskResult(
            taskId: 'discover-messy-01',
            type: JourneyTaskType.newConcept,
            primarySenseId: 'messy-01',
            discoverTotalQuestions: 4,
          ),
          JourneyTaskResult(
            taskId: 'discover-almost-01',
            type: JourneyTaskType.newConcept,
            primarySenseId: 'almost-01',
            discoverTotalQuestions: 4,
          ),
        ],
      ),
    );

    final statusOf = {
      for (final node in store.graph.nodes) node.senseId: node.status,
    };
    // Learned senses keep their status; discovered senses become newly
    // learned; unseen stays unseen.
    expect(statusOf['reluctant-01'], PrototypeNodeStatus.learning);
    expect(statusOf['dirty-01'], PrototypeNodeStatus.mastered);
    expect(statusOf['messy-01'], PrototypeNodeStatus.newlyLearned);
    expect(statusOf['almost-01'], PrototypeNodeStatus.newlyLearned);

    // The prototype boundary (dirty ↔ messy) appears as a new edge.
    expect(store.graph.edges.length, 1);
    final edge = store.graph.edges.single;
    expect(edge.connects('dirty-01', 'messy-01'), isTrue);
    expect(edge.isNewBoundary, isTrue);
    expect(store.journeyCompletedToday, isTrue);
  });

  test('graph relations resolve through the catalog, not lemma strings',
      () async {
    final catalog = await loadCatalog();
    final store = JourneyPreviewStore.standard(catalog: catalog);

    store.completeJourney(
      JourneyCompletion(
        completedAt: DateTime(2026, 8, 15, 9),
        results: const [
          JourneyTaskResult(
            taskId: 'discover-messy-01',
            type: JourneyTaskType.newConcept,
            primarySenseId: 'messy-01',
          ),
        ],
      ),
    );

    // The boundary relation is defined by lemma (messy/dirty) in the
    // prototype config but stored with real sense ids.
    final edge = store.graph.edges.single;
    expect(edge.sourceSenseId, 'messy-01');
    expect(edge.targetSenseId, 'dirty-01');
  });
}
