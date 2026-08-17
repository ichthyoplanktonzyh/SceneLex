/// Session semantic map — the learner's semantic world for the Daily
/// Session prototype: every node from the real catalog, colored by the
/// session learner state, with prototype boundary edges.
library;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_store.dart';
import 'session_semantic_graph.dart';

const Size _kMapCanvas = Size(560, 300);
const Map<String, Offset> _kMapPositions = {
  'reluctant-01': Offset(150, 60),
  'dirty-01': Offset(80, 230),
  'messy-01': Offset(320, 240),
  'almost-01': Offset(430, 70),
};

Offset _mapPositionFor(String senseId) =>
    _kMapPositions[senseId] ?? const Offset(280, 150);

class SessionSemanticMapPage extends StatelessWidget {
  const SessionSemanticMapPage({super.key, required this.store});

  final DailySessionStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final graph = store.graph;
    return Scaffold(
      backgroundColor: const Color(0xFFF7E8CA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.sessionMapTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kColorInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  children: [
                    Text(
                      l10n.sessionMapHint,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6F6F79),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth.clamp(320.0, 620.0);
                        final scale = width / _kMapCanvas.width;
                        return SizedBox(
                          width: width,
                          height: _kMapCanvas.height * scale,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _EdgePainter(
                                      graph: graph,
                                      scale: scale,
                                    ),
                                  ),
                                ),
                              ),
                              for (final node in graph.nodes)
                                Positioned(
                                  left:
                                      _mapPositionFor(node.senseId).dx * scale -
                                      30,
                                  top:
                                      _mapPositionFor(node.senseId).dy * scale -
                                      18,
                                  child: _MapNode(node: node),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    _Legend(graph: graph),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({required this.node});

  final SessionGraphNode node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unseen = node.status == SessionNodeStatus.unseen;
    final fill = switch (node.status) {
      SessionNodeStatus.mastered => kColorTealSignal,
      SessionNodeStatus.learning => kColorEmber,
      SessionNodeStatus.newlyLearned => kColorEmber,
      SessionNodeStatus.unseen => Colors.white.withValues(alpha: 0.6),
    };
    return Tooltip(
      message: _statusLabel(l10n, node.status),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 60,
            height: 36,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unseen ? const Color(0xFFC9C9D2) : Colors.transparent,
              ),
            ),
            child: Center(
              child: Text(
                node.lemma,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: unseen ? const Color(0xFF8B8B96) : Colors.white,
                ),
              ),
            ),
          ),
          if (node.status == SessionNodeStatus.newlyLearned)
            Positioned(
              top: -8,
              right: -14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFB7761C),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  l10n.sessionCompleteNewBadge,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, SessionNodeStatus status) =>
      switch (status) {
        SessionNodeStatus.mastered => l10n.sessionMapStatusMastered,
        SessionNodeStatus.learning => l10n.sessionMapStatusLearning,
        SessionNodeStatus.newlyLearned => l10n.sessionMapStatusNewlyLearned,
        SessionNodeStatus.unseen => l10n.sessionMapStatusUnseen,
      };
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.graph, required this.scale});

  final SessionSemanticGraph graph;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final source = _mapPositionFor(edge.sourceSenseId) * scale;
      final target = _mapPositionFor(edge.targetSenseId) * scale;
      final paint = Paint()
        ..color = edge.isNewBoundary
            ? kColorEmber.withValues(alpha: 0.9)
            : const Color(0xFFB9B9C4)
        ..strokeWidth = edge.isNewBoundary ? 2.4 : 1.3;
      canvas.drawLine(source, target, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.graph != graph || oldDelegate.scale != scale;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.graph});

  final SessionSemanticGraph graph;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasNewBoundary = graph.edges.any((e) => e.isNewBoundary);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: kColorTealSignal,
          label: l10n.sessionMapStatusMastered,
        ),
        _LegendItem(color: kColorEmber, label: l10n.sessionMapStatusLearning),
        _LegendItem(
          color: const Color(0xFFB7761C),
          label: l10n.sessionMapStatusNewlyLearned,
        ),
        _LegendItem(
          color: Colors.white.withValues(alpha: 0.6),
          borderColor: const Color(0xFFC9C9D2),
          label: l10n.sessionMapStatusUnseen,
        ),
        if (hasNewBoundary)
          _LegendItem(
            color: kColorEmber.withValues(alpha: 0.9),
            isLine: true,
            label: l10n.sessionCompleteNewBoundary,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.borderColor,
    this.isLine = false,
  });

  final Color color;
  final String label;
  final Color? borderColor;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLine)
            Container(width: 14, height: 2.4, color: color)
          else
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A54),
            ),
          ),
        ],
      ),
    );
  }
}
