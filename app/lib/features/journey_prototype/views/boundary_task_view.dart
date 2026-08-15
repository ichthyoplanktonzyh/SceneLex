/// Boundary (discrimination) task view: one scene, two concepts, one
/// judgment, then a contrast explanation built from the real invariants.
///
/// This is the first place a learner sees two senses side by side as a
/// boundary — the L2 symbols are already known here (the "new" side was
/// just bound, the other side was learned earlier).
library;

import 'package:flutter/material.dart';

import '../../../domain/content_catalog/word_sense_catalog.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/scenelex_tokens.dart';
import 'journey_shell.dart';

class BoundaryTaskView extends StatelessWidget {
  const BoundaryTaskView({
    super.key,
    required this.sceneEpisode,
    required this.options,
    required this.revealed,
    required this.choiceSenseId,
    required this.correctSenseId,
    required this.onChoose,
  });

  /// A real scene from the "new" side's review pool.
  final String sceneEpisode;

  /// [secondary (learned), primary (just discovered)] in that order.
  final List<WordSenseCatalogEntry> options;

  final bool revealed;
  final String? choiceSenseId;
  final String correctSenseId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JourneySceneCard(text: sceneEpisode),
          const SizedBox(height: 22),
          Text(
            l10n.journeyBoundaryPrompt,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
          const SizedBox(height: 12),
          for (final entry in options)
            JourneyChoiceTile(
              key: ValueKey('boundary-${entry.senseId}'),
              label: entry.lemma,
              state: _stateFor(entry.senseId),
              onTap: revealed ? null : () => onChoose(entry.senseId),
            ),
          if (revealed) ...[
            const SizedBox(height: 6),
            _BoundaryExplanation(
              l10n: l10n,
              options: options,
              correctSenseId: correctSenseId,
              choiceSenseId: choiceSenseId,
            ),
          ],
        ],
      ),
    );
  }

  JourneyChoiceState _stateFor(String senseId) {
    if (!revealed) return JourneyChoiceState.idle;
    if (senseId == correctSenseId) return JourneyChoiceState.correct;
    if (senseId == choiceSenseId) return JourneyChoiceState.wrong;
    return JourneyChoiceState.muted;
  }
}

/// The boundary teaching moment: both concepts side by side, each with its
/// real invariant-based explanation.
class _BoundaryExplanation extends StatelessWidget {
  const _BoundaryExplanation({
    required this.l10n,
    required this.options,
    required this.correctSenseId,
    required this.choiceSenseId,
  });

  final AppLocalizations l10n;
  final List<WordSenseCatalogEntry> options;
  final String correctSenseId;
  final String? choiceSenseId;

  @override
  Widget build(BuildContext context) {
    final correct = choiceSenseId == correctSenseId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: correct ? kSignalSuccess : kSignalError,
              ),
              const SizedBox(width: 8),
              Text(
                correct
                    ? l10n.journeyBoundaryCorrect
                    : l10n.journeyBoundaryIncorrect,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: correct ? kSignalSuccess : kSignalError,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.journeyBoundaryKey,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in options)
            _ConceptCard(entry: entry, highlighted: entry.senseId == correctSenseId),
        ],
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.entry, required this.highlighted});

  final WordSenseCatalogEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? kColorEmber.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(kRadiusSm),
        border: highlighted
            ? Border.all(color: kColorEmber.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.lemma,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kColorInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.invariant,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5C5C68),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
