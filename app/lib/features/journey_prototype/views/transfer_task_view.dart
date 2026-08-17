/// Transfer task view: a brand-new situation (the program's real transfer
/// unit) — the concept must survive the move.
///
/// After the judgment, the unit's own real feedback is shown.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/experience_unit.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/scenelex_tokens.dart';
import 'journey_shell.dart';

class TransferTaskView extends StatelessWidget {
  const TransferTaskView({
    super.key,
    required this.unit,
    required this.revealed,
    required this.choiceAnswerId,
    required this.onChoose,
  });

  final ExperienceUnit unit;
  final bool revealed;
  final String? choiceAnswerId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final correctId = unit.interaction.correctAnswer.id;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.journeyTransferHint,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF84848F),
            ),
          ),
          const SizedBox(height: 12),
          JourneySceneCard(text: unit.experience.episode),
          const SizedBox(height: 22),
          Text(
            unit.interaction.question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
          const SizedBox(height: 12),
          for (final answer in unit.interaction.answers)
            JourneyChoiceTile(
              key: ValueKey('transfer-${answer.id}'),
              label: answer.text,
              state: _stateFor(answer.id, correctId),
              onTap: revealed ? null : () => onChoose(answer.id),
            ),
          if (revealed) _Feedback(answer: _picked()),
        ],
      ),
    );
  }

  Answer? _picked() {
    for (final answer in unit.interaction.answers) {
      if (answer.id == choiceAnswerId) return answer;
    }
    return null;
  }

  JourneyChoiceState _stateFor(String answerId, String correctId) {
    if (!revealed) return JourneyChoiceState.idle;
    if (answerId == correctId) return JourneyChoiceState.correct;
    if (answerId == choiceAnswerId) return JourneyChoiceState.wrong;
    return JourneyChoiceState.muted;
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.answer});

  final Answer? answer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final answer = this.answer;
    if (answer == null) return const SizedBox.shrink();
    final correct = answer.isCorrect;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct
            ? kSignalSuccessBg.withValues(alpha: 0.4)
            : kSignalErrorBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correct ? l10n.journeyTransferCorrect : l10n.journeyTransferIncorrect,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: correct ? kSignalSuccess : kSignalError,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer.feedback,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF3D3D47),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
