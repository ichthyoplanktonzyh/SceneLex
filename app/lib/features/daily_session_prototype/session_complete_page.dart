/// Session complete: this session's real ledger and the proof that the
/// semantic world changed — which senses were woken, established,
/// distinguished and drilled, plus the grown semantic graph.
///
/// Honesty note: no FSRS, long-term memory effect or learning score is
/// computed or stored — the page only reports what this session did.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_models.dart';
import 'daily_session_store.dart';
import 'session_semantic_graph.dart';
import 'session_semantic_map_page.dart';

const Size _kMiniCanvas = Size(300, 250);
const Map<String, Offset> _kMiniPositions = {
  'reluctant-01': Offset(96, 34),
  'dirty-01': Offset(52, 178),
  'messy-01': Offset(196, 184),
  'almost-01': Offset(252, 42),
};

Offset _miniPositionFor(String senseId) =>
    _kMiniPositions[senseId] ?? const Offset(150, 125);

class SessionCompletePage extends StatelessWidget {
  const SessionCompletePage({
    super.key,
    required this.store,
    required this.repository,
  });

  final DailySessionStore store;
  final ExperienceProgramRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final completion = store.completion;
    return Scaffold(
      backgroundColor: const Color(0xFFF7E8CA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 44, 26, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const Icon(Icons.celebration, size: 48, color: kColorEmber),
                  const SizedBox(height: 12),
                  Text(
                    l10n.sessionCompleteTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: kColorInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.sessionCompleteNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8B8B96),
                      height: 1.5,
                    ),
                  ),
                  if (completion != null) ...[
                    const SizedBox(height: 22),
                    _Ledger(l10n: l10n, store: store),
                  ],
                  const SizedBox(height: 24),
                  _MiniMap(graph: store.graph),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionSemanticMapPage(store: store),
                        ),
                      ),
                      icon: const Icon(Icons.hub_outlined),
                      label: Text(l10n.sessionCompleteViewMap),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: Text(
                      l10n.sessionCompleteBackHome,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3A3A42),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The session's accomplishments, one line per real task result.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.l10n, required this.store});

  final AppLocalizations l10n;
  final DailySessionStore store;

  @override
  Widget build(BuildContext context) {
    final completion = store.completion;
    final results = completion?.results ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionCompleteSection,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 10),
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 17,
                    color: kSignalSuccess,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _ledgerLine(l10n, result),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF3D3D47),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _ledgerLine(AppLocalizations l10n, DailySessionResult result) {
    final lemma = store.catalog.entryFor(result.primarySenseId).lemma;
    switch (result.type) {
      case DailySessionTaskType.recall:
        return l10n.sessionLedgerRecalled(lemma);
      case DailySessionTaskType.discover:
        return l10n.sessionLedgerEstablished(lemma);
      case DailySessionTaskType.boundary:
        final other = result.secondarySenseId == null
            ? ''
            : store.catalog.entryFor(result.secondarySenseId!).lemma;
        return l10n.sessionLedgerBoundary(lemma, other);
      case DailySessionTaskType.transfer:
        return l10n.sessionLedgerTransferred(lemma);
    }
  }
}

/// The grown semantic world, drawn small.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.graph});

  final SessionSemanticGraph graph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Center(
        child: SizedBox(
          width: _kMiniCanvas.width,
          height: _kMiniCanvas.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _MiniEdgePainter(graph: graph)),
                ),
              ),
              for (final node in graph.nodes)
                Positioned(
                  left: _miniPositionFor(node.senseId).dx - 30,
                  top: _miniPositionFor(node.senseId).dy - 18,
                  child: _MiniNode(node: node),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniNode extends StatelessWidget {
  const _MiniNode({required this.node});

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
    return Stack(
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
    );
  }
}

class _MiniEdgePainter extends CustomPainter {
  _MiniEdgePainter({required this.graph});

  final SessionSemanticGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final source = _miniPositionFor(edge.sourceSenseId);
      final target = _miniPositionFor(edge.targetSenseId);
      final paint = Paint()
        ..color = edge.isNewBoundary
            ? kColorEmber.withValues(alpha: 0.9)
            : const Color(0xFFB9B9C4)
        ..strokeWidth = edge.isNewBoundary ? 2.2 : 1.3;
      canvas.drawLine(source, target, paint);
    }
  }

  @override
  bool shouldRepaint(_MiniEdgePainter oldDelegate) =>
      oldDelegate.graph != graph;
}
