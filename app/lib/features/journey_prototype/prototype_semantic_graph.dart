/// Prototype semantic graph — the learner's growing "semantic world".
///
/// This is a prototype-local graph: node *statuses* are derived from the
/// prototype learner state and journey completions, and the only edge
/// (dirty ↔ messy) is a prototype-level demonstration relation. It never
/// writes into the real catalog or any production semantic contract.
library;

import 'package:flutter/foundation.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import 'prototype_learner_state.dart';

/// Visual state of a node in the learner's semantic map.
enum PrototypeNodeStatus {
  mastered,
  learning,
  newlyLearned,
  unseen,
}

/// One sense as a node in the learner's semantic map.
@immutable
class PrototypeGraphNode {
  const PrototypeGraphNode({
    required this.senseId,
    required this.lemma,
    required this.status,
  });

  final String senseId;
  final String lemma;
  final PrototypeNodeStatus status;

  PrototypeGraphNode withStatus(PrototypeNodeStatus next) =>
      PrototypeGraphNode(senseId: senseId, lemma: lemma, status: next);
}

/// One relation between two nodes (prototype: only boundaries for now).
@immutable
class PrototypeGraphEdge {
  const PrototypeGraphEdge({
    required this.sourceSenseId,
    required this.targetSenseId,
    required this.isNewBoundary,
  });

  final String sourceSenseId;
  final String targetSenseId;

  /// True when the boundary was established by today's journey.
  final bool isNewBoundary;

  bool connects(String a, String b) =>
      (sourceSenseId == a && targetSenseId == b) ||
      (sourceSenseId == b && targetSenseId == a);
}

/// A boundary relation definition used by the planner (lemma-level, resolved
/// through the catalog). Prototype-only content: the real catalog has no
/// `relations.boundaries` data yet, so the demo pair lives here.
@immutable
class PrototypeBoundaryRelation {
  const PrototypeBoundaryRelation({
    required this.primaryLemma,
    required this.secondaryLemma,
  });

  final String primaryLemma;
  final String secondaryLemma;
}

/// The prototype demo boundary: dirty ↔ messy.
const List<PrototypeBoundaryRelation> kPrototypeBoundaryRelations = [
  PrototypeBoundaryRelation(primaryLemma: 'messy', secondaryLemma: 'dirty'),
];

/// Immutable-ish snapshot of the learner's semantic world.
class PrototypeSemanticGraph {
  const PrototypeSemanticGraph({required this.nodes, required this.edges});

  factory PrototypeSemanticGraph.fromCatalog({
    required WordSenseCatalog catalog,
    required PrototypeLearnerState learnerState,
    required List<PrototypeBoundaryRelation> boundaryRelations,
  }) {
    final nodes = <PrototypeGraphNode>[
      for (final entry in catalog.senses.values)
        PrototypeGraphNode(
          senseId: entry.senseId,
          lemma: entry.lemma,
          status: switch (learnerState.statusFor(entry.senseId)) {
            PrototypeSenseStatus.mastered => PrototypeNodeStatus.mastered,
            PrototypeSenseStatus.learning => PrototypeNodeStatus.learning,
            PrototypeSenseStatus.unseen => PrototypeNodeStatus.unseen,
          },
        ),
    ];
    // Prototype relations are resolved only when both sides exist.
    final resolved = <PrototypeBoundaryRelation>[];
    for (final relation in boundaryRelations) {
      final primary = _senseForLemma(catalog, relation.primaryLemma);
      final secondary = _senseForLemma(catalog, relation.secondaryLemma);
      if (primary == null || secondary == null) continue;
      resolved.add(relation);
    }
    return PrototypeSemanticGraph(nodes: nodes, edges: const []);
  }

  static String? _senseForLemma(WordSenseCatalog catalog, String lemma) {
    for (final entry in catalog.senses.values) {
      if (entry.lemma == lemma) return entry.senseId;
    }
    return null;
  }

  final List<PrototypeGraphNode> nodes;
  final List<PrototypeGraphEdge> edges;

  PrototypeGraphNode? nodeFor(String senseId) {
    for (final node in nodes) {
      if (node.senseId == senseId) return node;
    }
    return null;
  }

  /// What today's journey grew: senses that went from unseen to newly
  /// learned, and boundary edges that were established.
  PrototypeSemanticGraph applyJourneyCompletion({
    required Set<String> newlyLearnedSenseIds,
    required List<PrototypeBoundaryRelation> newBoundaryRelations,
  }) {
    final nextNodes = <PrototypeGraphNode>[
      for (final node in nodes)
        node.withStatus(
          newlyLearnedSenseIds.contains(node.senseId)
              ? PrototypeNodeStatus.newlyLearned
              : node.status,
        ),
    ];
    final nextEdges = [...edges];
    for (final relation in newBoundaryRelations) {
      final source = _senseForLemmaById(relation.primaryLemma);
      final target = _senseForLemmaById(relation.secondaryLemma);
      if (source == null || target == null) continue;
      final edge = PrototypeGraphEdge(
        sourceSenseId: source,
        targetSenseId: target,
        isNewBoundary: true,
      );
      if (!nextEdges.any((e) => e.connects(source, target))) {
        nextEdges.add(edge);
      }
    }
    return PrototypeSemanticGraph(nodes: nextNodes, edges: nextEdges);
  }

  /// Resolves the boundary relation against this graph's node ids.
  /// (Relations are defined by lemma in the prototype config; the graph
  /// knows the real sense ids.)
  String? _senseForLemmaById(String lemma) {
    for (final node in nodes) {
      if (node.lemma == lemma) return node.senseId;
    }
    return null;
  }
}
