/// Session-complete view: honest first-run statistics, no fabricated
/// persistence, no FSRS scores.
library;

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class CompleteView extends StatelessWidget {
  const CompleteView({
    super.key,
    required this.answeredExperiences,
    required this.firstAttemptCorrect,
    required this.totalQuestions,
    required this.onReplay,
  });

  final int answeredExperiences;
  final int firstAttemptCorrect;
  final int totalQuestions;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.emoji_events_outlined,
                size: 48,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.experienceRuntimeCompleteTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '$answeredExperiences',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      l10n.experienceRuntimeCompleteExperiences,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.experienceRuntimeCompleteFirstAttempt(
                        firstAttemptCorrect,
                        totalQuestions,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.replay),
                label: Text(l10n.experienceRuntimeReplay),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
