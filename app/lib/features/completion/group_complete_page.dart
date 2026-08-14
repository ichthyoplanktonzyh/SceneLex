/// Group complete: honest statistics (senses, experiences, first-attempt
/// discrimination, real elapsed time) and the next action chosen by the
/// 符号检索验收时机 preference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/learning/preferences.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../learn/learn_session_page.dart' show groupResultProvider;

class GroupCompletePage extends ConsumerWidget {
  const GroupCompletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final result = ref.watch(groupResultProvider);
    if (result == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch_outlined, size: 48),
              const SizedBox(height: 16),
              Text(l10n.groupNoneInProgress),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: Text(l10n.groupBackHome),
              ),
            ],
          ),
        ),
      );
    }

    final senseCount = result.senseIds.length;
    final experienceCount = result.outcomes.values.fold<int>(
      0,
      (sum, o) => sum + o.answeredExperiences,
    );
    final questionCount = result.outcomes.values.fold<int>(
      0,
      (sum, o) => sum + o.totalQuestions,
    );
    final correctCount = result.outcomes.values.fold<int>(
      0,
      (sum, o) => sum + o.firstAttemptCorrect,
    );
    final accuracy = questionCount == 0
        ? 100
        : (correctCount / questionCount * 100).round();
    final minutes = (result.durationSeconds / 60).ceil().clamp(1, 1 << 31);

    return Scaffold(
      backgroundColor: const Color(0xFFF7E8CA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 110, 26, 24),
            child: Column(
              children: [
                const Icon(Icons.celebration, size: 52, color: kColorEmber),
                const SizedBox(height: 14),
                Text(
                  l10n.groupDoneTitle,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.groupDoneBody(senseCount),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6F6F79),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    _StatTile(
                      label: l10n.groupNewExperiences,
                      value: '$experienceCount',
                    ),
                    _StatTile(
                      label: l10n.groupBoundaryDiscrimination,
                      value: '$accuracy%',
                    ),
                    _StatTile(label: l10n.groupMinutes, value: '$minutes'),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                  ),
                  child: Text(
                    _nextActionNote(l10n, result.transferTiming),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7C7C88),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _PrimaryButton(
                  label: _nextActionLabel(l10n, result.transferTiming),
                  onTap: () =>
                      context.go(_nextActionRoute(result.transferTiming)),
                ),
                const SizedBox(height: 11),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: Text(
                    l10n.groupRest,
                    style: TextStyle(fontSize: 16.5, color: Color(0xFF3A3A42)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _nextActionNote(AppLocalizations l10n, TransferTiming timing) =>
      switch (timing) {
        TransferTiming.endOfDay => l10n.transferIntro + l10n.transferIntro2,
        TransferTiming.firstReview => l10n.transferDeferred,
        TransferTiming.endOfFirstLearning => l10n.transferAtEnd,
      };

  String _nextActionLabel(AppLocalizations l10n, TransferTiming timing) =>
      switch (timing) {
        TransferTiming.endOfDay => l10n.groupStartRecall,
        TransferTiming.firstReview => l10n.groupGoReview,
        TransferTiming.endOfFirstLearning => l10n.groupGoReview,
      };

  String _nextActionRoute(TransferTiming timing) => switch (timing) {
    TransferTiming.endOfDay => '/review?mode=transfer',
    TransferTiming.firstReview => '/review',
    TransferTiming.endOfFirstLearning => '/review',
  };
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A84)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onTap, child: Text(label)),
    );
  }
}
