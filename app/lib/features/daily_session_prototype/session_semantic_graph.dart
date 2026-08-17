/// Session semantic graph — the learner's growing "semantic world" for the
/// Daily Session prototype.
///
/// A prototype-local graph: node statuses derive from the session learner
/// state and session completions; edges come from prototype boundary
/// relations (the real catalog's `relations.boundaries` is still empty).
/// It never writes into the real catalog or any production contract.
library;

import 'package:flutter/foundation.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import 'session_learner_state.dart';

/// Visual state of a node in the learner's semantic map.
enum SessionNodeStatus { mastered, learning, newlyLearned, unseen }

/// One sense as a node in the learner's semantic map.
@immutable
class SessionGraphNode {
  const SessionGraphNode({
    required this.senseId,
    required this.lemma,
    required this.status,
  });

  final String senseId;
  final String lemma;
  final SessionNodeStatus status;

  SessionGraphNode withStatus(SessionNodeStatus next) =>
      SessionGraphNode(senseId: senseId, lemma: lemma, status: next);
}

/// One relation between two nodes (prototype: only boundaries for now).
@immutable
class SessionGraphEdge {
  const SessionGraphEdge({
    required this.sourceSenseId,
    required this.targetSenseId,
    required this.isNewBoundary,
  });

  final String sourceSenseId;
  final String targetSenseId;

  /// True when the boundary was established by today's session.
  final bool isNewBoundary;

  bool connects(String a, String b) =>
      (sourceSenseId == a && targetSenseId == b) ||
      (sourceSenseId == b && targetSenseId == a);
}

/// A boundary relation definition used by the planner (lemma-level, resolved
/// through the catalog). Prototype-only content: the real catalog has no
/// `relations.boundaries` data yet, so the demo pair lives here.
@immutable
class SessionBoundaryRelation {
  const SessionBoundaryRelation({
    required this.primaryLemma,
    required this.secondaryLemma,
  });

  final String primaryLemma;
  final String secondaryLemma;
}

/// The prototype demo boundary: messy ↔ dirty.
const List<SessionBoundaryRelation> kSessionBoundaryRelations = [
  SessionBoundaryRelation(primaryLemma: 'messy', secondaryLemma: 'dirty'),
];

/// Immutable snapshot of the learner's semantic world.
class SessionSemanticGraph {
  const SessionSemanticGraph({required this.nodes, required this.edges});

  factory SessionSemanticGraph.fromCatalog({
    required WordSenseCatalog catalog,
    required SessionLearnerState learnerState,
    required List<SessionBoundaryRelation> boundaryRelations,
  }) {
    final nodes = <SessionGraphNode>[
      for (final entry in catalog.senses.values)
        SessionGraphNode(
          senseId: entry.senseId,
          lemma: entry.lemma,
          status: switch (learnerState.statusFor(entry.senseId)) {
            SessionSenseStatus.mastered => SessionNodeStatus.mastered,
            SessionSenseStatus.learning => SessionNodeStatus.learning,
            SessionSenseStatus.unseen => SessionNodeStatus.unseen,
          },
        ),
    ];
    return SessionSemanticGraph(
      nodes: List.unmodifiable(nodes),
      edges: const [],
    );
  }

  final List<SessionGraphNode> nodes;
  final List<SessionGraphEdge> edges;

  SessionGraphNode? nodeFor(String senseId) {
    for (final node in nodes) {
      if (node.senseId == senseId) return node;
    }
    return null;
  }

  String? lemmaFor(String senseId) => nodeFor(senseId)?.lemma;

  /// What a completed session grew: senses that went from unseen to newly
  /// learned, and boundary edges that were established.
  SessionSemanticGraph applyingCompletion({
    required Set<String> newlyEstablishedSenseIds,
    required List<(String, String)> newBoundaryPairs,
  }) {
    final nextNodes = <SessionGraphNode>[
      for (final node in nodes)
        node.withStatus(
          newlyEstablishedSenseIds.contains(node.senseId)
              ? SessionNodeStatus.newlyLearned
              : node.status,
        ),
    ];
    final nextEdges = <SessionGraphEdge>[...edges];
    for (final (a, b) in newBoundaryPairs) {
      if (!nextEdges.any((e) => e.connects(a, b))) {
        nextEdges.add(
          SessionGraphEdge(
            sourceSenseId: a,
            targetSenseId: b,
            isNewBoundary: true,
          ),
        );
      }
    }
    return SessionSemanticGraph(
      nodes: List.unmodifiable(nextNodes),
      edges: List.unmodifiable(nextEdges),
    );
  }

  /// Resolves a boundary relation (defined by lemma) against real sense ids.
  /// Returns null when either side does not exist.
  (String, String)? resolveBoundary(SessionBoundaryRelation relation) {
    String? byLemma(String lemma) {
      for (final node in nodes) {
        if (node.lemma == lemma) return node.senseId;
      }
      return null;
    }

    final primary = byLemma(relation.primaryLemma);
    final secondary = byLemma(relation.secondaryLemma);
    if (primary == null || secondary == null) return null;
    return (primary, secondary);
  }
}
