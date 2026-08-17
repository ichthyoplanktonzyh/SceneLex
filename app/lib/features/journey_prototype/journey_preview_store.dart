/// Preview store: the tiny state container that keeps the Journey preview
/// pages in sync (learner state, plan, semantic graph, today's completion).
///
/// Prototype-local by design: nothing here is persisted or synced. The store
/// is created by the preview entry and passed down by constructor — no
/// Riverpod, no DB, no server.
library;

import 'package:flutter/foundation.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import 'prototype_journey_plan.dart';
import 'prototype_journey_planner.dart';
import 'prototype_learner_state.dart';
import 'prototype_semantic_graph.dart';

class JourneyPreviewStore extends ChangeNotifier {
  JourneyPreviewStore({
    required this.catalog,
    required PrototypeLearnerState initialLearnerState,
    required PrototypeSemanticGraph initialGraph,
    required this.plan,
  }) : _learnerState = initialLearnerState,
       _graph = initialGraph;

  factory JourneyPreviewStore.standard({
    required WordSenseCatalog catalog,
    PrototypeJourneyPlanner planner = const PrototypeJourneyPlanner(),
    Map<String, PrototypeSenseStatus> byLemma =
        PrototypeLearnerState.defaultByLemma,
  }) {
    final learnerState = PrototypeLearnerState.resolve(
      catalog: catalog,
      byLemma: byLemma,
    );
    final graph = PrototypeSemanticGraph.fromCatalog(
      catalog: catalog,
      learnerState: learnerState,
      boundaryRelations: planner.boundaryRelations,
    );
    return JourneyPreviewStore(
      catalog: catalog,
      initialLearnerState: learnerState,
      initialGraph: graph,
      plan: planner.plan(catalog: catalog, learnerState: learnerState),
    );
  }

  final WordSenseCatalog catalog;
  final JourneyPlan plan;

  final PrototypeLearnerState _learnerState;
  PrototypeLearnerState get learnerState => _learnerState;

  PrototypeSemanticGraph _graph;
  PrototypeSemanticGraph get graph => _graph;

  JourneyCompletion? _completion;
  JourneyCompletion? get completion => _completion;

  /// Whether today's journey has been completed (prototype day semantics:
  /// one completion marks today done until the session re-runs).
  bool get journeyCompletedToday => _completion != null;

  /// Records a finished journey and grows the semantic graph.
  void completeJourney(JourneyCompletion completion) {
    _completion = completion;
    final newlyLearned = <String>{
      for (final result in completion.results)
        if (result.type == JourneyTaskType.newConcept) result.primarySenseId,
    };
    _graph = _graph.applyJourneyCompletion(
      newlyLearnedSenseIds: newlyLearned,
      newBoundaryRelations: kPrototypeBoundaryRelations,
    );
    notifyListeners();
  }
}
