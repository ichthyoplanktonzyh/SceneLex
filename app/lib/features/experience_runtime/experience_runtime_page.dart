/// Experience Runtime: a first-run learning flow driven entirely by one
/// ExperienceProgram (Contract v1).
///
/// concept units → symbol binding → grounding → complete. The page is
/// deliberately independent of the legacy review player, the Server contract,
/// FSRS and sync — it consumes only a [ExperienceRuntimeViewModel].
library;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'experience_runtime_view_model.dart';
import 'views/complete_view.dart';
import 'views/concept_unit_view.dart';
import 'views/grounding_view.dart';
import 'views/symbol_binding_view.dart';

/// Warm accent for concept formation; calm teal for binding/grounding.
const Color _kConceptSeed = Color(0xFFB45309);
const Color _kBindingSeed = Color(0xFF0F766E);

class ExperienceRuntimePage extends StatelessWidget {
  const ExperienceRuntimePage({
    super.key,
    required this.viewModel,
    this.onPronounce,
  });

  final ExperienceRuntimeViewModel viewModel;

  /// Optional pronunciation hook (e.g. TtsService); binding stage only.
  final Future<void> Function(String text)? onPronounce;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final phase = viewModel.phase;
        final scheme = switch (phase) {
          ExperienceRuntimePhase.symbolBinding ||
          ExperienceRuntimePhase.grounding ||
          ExperienceRuntimePhase.complete => ColorScheme.fromSeed(
            seedColor: _kBindingSeed,
          ),
          _ => ColorScheme.fromSeed(seedColor: _kConceptSeed),
        };
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: scheme),
          child: Scaffold(body: SafeArea(child: _buildBody(context))),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (viewModel.phase) {
      case ExperienceRuntimePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case ExperienceRuntimePhase.loadError:
        return _LoadErrorView(
          message: viewModel.errorMessage ?? '',
          onRetry: viewModel.load,
        );
      case ExperienceRuntimePhase.conceptUnit:
        return Column(
          children: [
            _ProgressHeader(
              current: viewModel.unitIndex + 1,
              total: viewModel.totalQuestions,
              answered: viewModel.answeredUnitCount,
            ),
            Expanded(
              child: ConceptUnitView(
                unit: viewModel.currentUnit!,
                selectedAnswerId: _selectedAnswerId(viewModel),
                onAnswerSelected: viewModel.answer,
              ),
            ),
            _BottomBar(
              canGoBack: viewModel.canGoBack,
              canProceed: viewModel.canProceed,
              onBack: viewModel.back,
              onProceed: viewModel.proceed,
            ),
          ],
        );
      case ExperienceRuntimePhase.symbolBinding:
        final reveal = viewModel.program!.symbolBinding.reveal;
        return Column(
          children: [
            _ProgressHeader(
              current: viewModel.totalQuestions + 1,
              total: viewModel.totalQuestions + 2,
              answered: viewModel.totalQuestions,
            ),
            Expanded(
              child: SymbolBindingView(
                reveal: reveal,
                minimalL1Gloss: viewModel.program!.symbolBinding.minimalL1Gloss,
                onPronounce: onPronounce == null
                    ? null
                    : () => onPronounce!(reveal.l2Word),
              ),
            ),
            _BottomBar(
              canGoBack: false,
              canProceed: true,
              onBack: null,
              onProceed: viewModel.proceed,
            ),
          ],
        );
      case ExperienceRuntimePhase.grounding:
        final program = viewModel.program!;
        return Column(
          children: [
            _ProgressHeader(
              current: viewModel.totalQuestions + 2,
              total: viewModel.totalQuestions + 2,
              answered: viewModel.totalQuestions,
            ),
            Expanded(
              child: GroundingView(
                grounding: program.grounding,
                sourceUnit: program.units.firstWhere(
                  (u) => u.id == program.grounding.sourceExperienceId,
                ),
              ),
            ),
            _BottomBar(
              canGoBack: false,
              canProceed: true,
              onBack: null,
              onProceed: viewModel.proceed,
            ),
          ],
        );
      case ExperienceRuntimePhase.complete:
        return CompleteView(
          answeredExperiences: viewModel.answeredUnitCount,
          firstAttemptCorrect: viewModel.firstAttemptCorrect,
          totalQuestions: viewModel.totalQuestions,
          onReplay: viewModel.restart,
        );
    }
  }

  static String? _selectedAnswerId(ExperienceRuntimeViewModel viewModel) {
    final unit = viewModel.currentUnit;
    if (unit == null) return null;
    return viewModel.recordFor(unit.id)?.answer.id;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.answered,
  });

  final int current;
  final int total;
  final int answered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : current / total,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.experienceRuntimeProgress(current, total),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canGoBack,
    required this.canProceed,
    required this.onBack,
    required this.onProceed,
  });

  final bool canGoBack;
  final bool canProceed;
  final VoidCallback? onBack;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            if (canGoBack)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: Text(l10n.experienceRuntimeBack),
                  ),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: canProceed ? onProceed : null,
                child: Text(l10n.experienceRuntimeContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                l10n.experienceRuntimeLoadErrorTitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.experienceRuntimeRetry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
