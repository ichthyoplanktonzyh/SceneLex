/// Learner semantic map prototype: a real graph (not a card list).
///
/// Nodes are senses, positioned on a canvas; edges are boundaries. Status
/// (mastered / learning / newly learned / unseen) comes from the prototype
/// semantic graph, which grows when a journey completes. The prototype
/// relation (dirty ↔ messy) is the only edge — it never touches the real
/// catalog.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'journey_preview_store.dart';
import 'prototype_semantic_graph.dart';

const Size _kMapCanvasSize = Size(440, 400);

/// Canvas positions of the prototype nodes (senseId → offset).
const Map<String, Offset> _kNodePositions = {
  'reluctant-01': Offset(140, 56),
  'dirty-01': Offset(78, 290),
  'messy-01': Offset(316, 300),
  'almost-01': Offset(382, 66),
};

Offset _positionFor(String senseId) =>
    _kNodePositions[senseId] ?? const Offset(220, 200);

class JourneySemanticMapPage extends StatelessWidget {
  const JourneySemanticMapPage({
    super.key,
    required this.store,
    required this.repository,
  });

  final JourneyPreviewStore store;
  final ExperienceProgramRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.journeyMapTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.journeyMapHint,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8B8B96),
                    ),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(120),
                    minScale: 0.7,
                    maxScale: 2.2,
                    child: SizedBox(
                      width: _kMapCanvasSize.width,
                      height: _kMapCanvasSize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _EdgePainter(graph: store.graph),
                              ),
                            ),
                          ),
                          for (final node in store.graph.nodes)
                            Positioned(
                              left: _positionFor(node.senseId).dx - 46,
                              top: _positionFor(node.senseId).dy - 30,
                              child: _MapNode(
                                node: node,
                                isNewBoundaryNode: _isNewBoundarySide(
                                  store.graph,
                                  node.senseId,
                                ),
                                onTap: () => _showDetails(
                                  context,
                                  node,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _Legend(statuses: store.graph.nodes),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isNewBoundarySide(
    PrototypeSemanticGraph graph,
    String senseId,
  ) {
    for (final edge in graph.edges) {
      if (edge.isNewBoundary &&
          (edge.sourceSenseId == senseId || edge.targetSenseId == senseId)) {
        return true;
      }
    }
    return false;
  }

  void _showDetails(BuildContext context, PrototypeGraphNode node) {
    final l10n = AppLocalizations.of(context);
    final entry = store.catalog.entryFor(node.senseId);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    node.lemma,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: kColorInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DetailChip(
                    label: l10n.journeyMapStatusNewlyLearned,
                    visible: node.status == PrototypeNodeStatus.newlyLearned,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.pos} · ${entry.semanticType}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9AA4)),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.journeyMapDetailStatus,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF8B8B96),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _statusLabel(l10n, node.status),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kColorInk,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<String>(
                future: _loadMinimalGloss(node.senseId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return _DetailBlock(
                    label: l10n.journeyMapDetailSymbol,
                    child: Text(
                      snapshot.data!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5C5C68),
                      ),
                    ),
                  );
                },
              ),
              if (entry.invariant.isNotEmpty)
                _DetailBlock(
                  label: l10n.journeyMapDetailMeaning,
                  child: Text(
                    entry.invariant,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF5C5C68),
                      height: 1.6,
                    ),
                  ),
                ),
              for (final edge in _boundariesOf(node.senseId)) ...[
                const SizedBox(height: 14),
                _DetailBlock(
                  label: l10n.journeyMapDetailBoundary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.journeyMapBoundaryEdge(
                              store.catalog.entryFor(edge.sourceSenseId).lemma,
                              store.catalog.entryFor(edge.targetSenseId).lemma,
                            ),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: kColorEmber,
                            ),
                          ),
                          if (edge.isNewBoundary)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _DetailChip(
                                label: l10n.journeyCompleteNewBoundary,
                                visible: true,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _BoundaryContrast(
                        store: store,
                        sourceSenseId: edge.sourceSenseId,
                        targetSenseId: edge.targetSenseId,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PrototypeGraphEdge> _boundariesOf(String senseId) =>
      store.graph.edges
          .where(
            (e) => e.sourceSenseId == senseId || e.targetSenseId == senseId,
          )
          .toList();

  Future<String> _loadMinimalGloss(String senseId) async {
    try {
      final program = await repository.load(senseId);
      return program.symbolBinding.minimalL1Gloss ?? '';
    } catch (_) {
      return '';
    }
  }

  String _statusLabel(AppLocalizations l10n, PrototypeNodeStatus status) =>
      switch (status) {
        PrototypeNodeStatus.mastered => l10n.journeyMapStatusMastered,
        PrototypeNodeStatus.learning => l10n.journeyMapStatusLearning,
        PrototypeNodeStatus.newlyLearned => l10n.journeyMapStatusNewlyLearned,
        PrototypeNodeStatus.unseen => l10n.journeyMapStatusUnseen,
      };
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.node,
    required this.isNewBoundaryNode,
    required this.onTap,
  });

  final PrototypeGraphNode node;
  final bool isNewBoundaryNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = node.status;
    final unseen = status == PrototypeNodeStatus.unseen;
    final fill = switch (status) {
      PrototypeNodeStatus.mastered => kColorTealSignal,
      PrototypeNodeStatus.learning => kColorEmber,
      PrototypeNodeStatus.newlyLearned => kColorEmber,
      PrototypeNodeStatus.unseen => Colors.white.withValues(alpha: 0.55),
    };
    final textColor = unseen ? const Color(0xFF8B8B96) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isNewBoundaryNode
                        ? kColorEmber.withValues(alpha: 0.9)
                        : unseen
                        ? const Color(0xFFC9C9D2)
                        : Colors.transparent,
                    width: isNewBoundaryNode ? 2.5 : 1.5,
                  ),
                  boxShadow: status == PrototypeNodeStatus.newlyLearned
                      ? [
                          BoxShadow(
                            color: kColorEmber.withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      node.lemma,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (status == PrototypeNodeStatus.newlyLearned)
                const Positioned(
                  top: -4,
                  right: -10,
                  child: _NewBadge(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFB7761C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l10n.journeyCompleteNewBadge,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.graph});

  final PrototypeSemanticGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final source = _positionFor(edge.sourceSenseId);
      final target = _positionFor(edge.targetSenseId);
      final paint = Paint()
        ..color = edge.isNewBoundary
            ? kColorEmber.withValues(alpha: 0.85)
            : const Color(0xFFB9B9C4)
        ..strokeWidth = edge.isNewBoundary ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(source, target, paint);
      if (edge.isNewBoundary) {
        final mid = Offset(
          (source.dx + target.dx) / 2,
          (source.dy + target.dy) / 2,
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'New boundary',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: kColorEmber,
              backgroundColor: const Color(0xFFF7E8CA),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          mid - Offset(textPainter.width / 2, -8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.graph != graph;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.statuses});

  final List<PrototypeGraphNode> statuses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 14,
      children: [
        _LegendItem(color: kColorTealSignal, label: l10n.journeyMapStatusMastered),
        _LegendItem(color: kColorEmber, label: l10n.journeyMapStatusLearning),
        _LegendItem(
          color: kColorEmber.withValues(alpha: 0.55),
          label: l10n.journeyMapStatusNewlyLearned,
        ),
        _LegendItem(
          color: const Color(0xFFC9C9D2),
          label: l10n.journeyMapStatusUnseen,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6D6D78)),
        ),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _BoundaryContrast extends StatelessWidget {
  const _BoundaryContrast({
    required this.store,
    required this.sourceSenseId,
    required this.targetSenseId,
  });

  final JourneyPreviewStore store;
  final String sourceSenseId;
  final String targetSenseId;

  @override
  Widget build(BuildContext context) {
    final source = store.catalog.entryFor(sourceSenseId);
    final target = store.catalog.entryFor(targetSenseId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in [source, target])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.lemma} — ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kColorInk,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.invariant,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5C5C68),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tiny chip used inside the detail sheet.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.visible});

  final String label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: kColorEmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kColorEmber,
        ),
      ),
    );
  }
}
