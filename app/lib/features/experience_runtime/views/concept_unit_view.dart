/// Concept-formation view: one experience, its evidence, one question.
///
/// Strictly before symbol binding: no L2 word, no IPA, no internal semantic
/// fields anywhere on this screen.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/experience_unit.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Learner-facing label for a unit role. The wire role name is never shown.
String roleLabel(AppLocalizations l10n, UnitRole role) => switch (role) {
  UnitRole.anchor => l10n.experienceRuntimeRoleAnchor,
  UnitRole.variation => l10n.experienceRuntimeRoleVariation,
  UnitRole.perturbation => l10n.experienceRuntimeRolePerturbation,
  UnitRole.discrimination => l10n.experienceRuntimeRoleDiscrimination,
  UnitRole.transfer => l10n.experienceRuntimeRoleTransfer,
};

class ConceptUnitView extends StatelessWidget {
  const ConceptUnitView({
    super.key,
    required this.unit,
    required this.selectedAnswerId,
    required this.onAnswerSelected,
  });

  final ExperienceUnit unit;
  final String? selectedAnswerId;
  final ValueChanged<String> onAnswerSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final experience = unit.experience;
    final answered = selectedAnswerId != null;
    final correctAnswer = unit.interaction.correctAnswer;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoleChip(label: roleLabel(l10n, unit.role)),
              const SizedBox(height: 16),
              Text(
                experience.episode,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (experience.observableEvidence.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.experienceRuntimeEvidenceLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final evidence in experience.observableEvidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '· ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            evidence,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const Divider(height: 40),
              Text(
                unit.interaction.question,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              for (final answer in unit.interaction.answers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnswerTile(
                    key: ValueKey('answer-${answer.id}'),
                    answer: answer,
                    selected: answer.id == selectedAnswerId,
                    revealed: answered,
                    correctAnswerId: correctAnswer.id,
                    onTap: answered ? null : () => onAnswerSelected(answer.id),
                  ),
                ),
              if (answered) ...[
                const SizedBox(height: 8),
                _FeedbackCard(answer: _selectedAnswer(unit, selectedAnswerId!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Answer _selectedAnswer(ExperienceUnit unit, String answerId) =>
      unit.interaction.answers.firstWhere((a) => a.id == answerId);
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    super.key,
    required this.answer,
    required this.selected,
    required this.revealed,
    required this.correctAnswerId,
    required this.onTap,
  });

  final Answer answer;
  final bool selected;
  final bool revealed;
  final String correctAnswerId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCorrectAnswer = answer.id == correctAnswerId;

    Color? borderColor;
    Color? background;
    Widget? leading;
    if (revealed) {
      if (isCorrectAnswer) {
        borderColor = Colors.green.shade700;
        background = Colors.green.shade50;
        leading = const Icon(Icons.check_circle, color: Colors.green, size: 20);
      } else if (selected) {
        borderColor = scheme.error;
        background = scheme.errorContainer.withValues(alpha: 0.3);
        leading = Icon(Icons.cancel, color: scheme.error, size: 20);
      }
    }

    return Material(
      color: background ?? scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              borderColor ??
              (selected ? scheme.primary : scheme.outlineVariant),
          width: borderColor != null || selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 12)],
                Expanded(
                  child: Text(
                    answer.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.answer});

  final Answer answer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: answer.isCorrect
            ? Colors.green.shade50
            : scheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                answer.isCorrect ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: answer.isCorrect ? Colors.green.shade700 : scheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  answer.isCorrect
                      ? l10n.experienceRuntimeCorrect
                      : l10n.experienceRuntimeIncorrect,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            answer.feedback,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
