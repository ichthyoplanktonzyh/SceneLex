/// Recall task view: a new experience from the review pool, the learner
/// recalls the word in their mind, then reveals and self-grades.
///
/// The target L2 symbol is never shown before the reveal — mirroring the
/// reverse-retrieval rule of the review flow.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/symbol_binding.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/scenelex_tokens.dart';
import 'journey_shell.dart';

class RecallTaskView extends StatelessWidget {
  const RecallTaskView({
    super.key,
    required this.episode,
    required this.revealed,
    required this.reveal,
    this.minimalGloss,
    required this.onReveal,
    required this.onGrade,
  });

  /// The new experience (review_pool item) the learner sees first.
  final String episode;

  final bool revealed;
  final Reveal reveal;
  final String? minimalGloss;
  final VoidCallback onReveal;
  final ValueChanged<int> onGrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneySceneCard(text: episode),
                if (!revealed)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      children: [
                        Text(
                          l10n.journeyRecallPrompt,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: kColorInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.journeyRecallHint,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF84848F),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _RecallAnswer(
                    reveal: reveal,
                    minimalGloss: minimalGloss,
                  ),
              ],
            ),
          ),
        ),
        if (!revealed)
          JourneyFooterButton(
            label: l10n.journeyRecallReveal,
            accent: kColorDusk,
            onTap: onReveal,
          )
        else
          _RecallGradeRow(l10n: l10n, onGrade: onGrade),
      ],
    );
  }
}

class _RecallAnswer extends StatelessWidget {
  const _RecallAnswer({required this.reveal, this.minimalGloss});

  final Reveal reveal;
  final String? minimalGloss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Text(
              reveal.l2Word,
              key: ValueKey(reveal.l2Word),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: Color(0xFF131318),
              ),
            ),
          ),
          if (reveal.ipa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                reveal.ipa,
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF4A4A54),
                ),
              ),
            ),
          if (minimalGloss != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                minimalGloss!,
                style: const TextStyle(fontSize: 15.5, color: Color(0xFF3D3D47)),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecallGradeRow extends StatelessWidget {
  const _RecallGradeRow({required this.l10n, required this.onGrade});

  final AppLocalizations l10n;
  final ValueChanged<int> onGrade;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (l10n.journeyRecallForgot, kSignalError),
      (l10n.journeyRecallHard, const Color(0xFFE0A021)),
      (l10n.journeyRecallGotIt, kSignalSuccess),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.62),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: labels[i].$2.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onGrade(i),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        labels[i].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kColorInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
