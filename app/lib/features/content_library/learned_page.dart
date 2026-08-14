/// 已理解列表（全部/近 7 天）: senses with an active learning state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../ui/theme/scenelex_tokens.dart';

class LearnedPage extends ConsumerWidget {
  const LearnedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recent =
        GoRouterState.of(context).uri.queryParameters['recent'] == 'true';
    final catalog = ref.watch(catalogProvider);
    final states = ref.watch(learningStatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(recent ? l10n.learnedRecent : l10n.learnedAll),
      ),
      body: catalog.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.learnedLoadError(error))),
        data: (data) {
          final all = states.value ?? const {};
          final entries = data.ordered.where((e) {
            final state = all[e.senseId];
            if (state == null) return false;
            if (!recent) return true;
            final refTime = state.lastReviewedAt;
            return refTime != null &&
                DateTime.now().difference(refTime) < const Duration(days: 7);
          }).toList();
          if (entries.isEmpty) {
            return Center(child: Text(l10n.learnedEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final state = all[entry.senseId]!;
              return _LearnedRow(
                lemma: entry.lemma,
                pos: entry.pos,
                semanticType: entry.semanticType,
                dueLabel: state.isDue
                    ? l10n.learnedDue
                    : _repsLabel(l10n, state.reps),
                onTap: () => context.push('/review'),
              );
            },
          );
        },
      ),
    );
  }

  String _repsLabel(AppLocalizations l10n, int reps) =>
      reps <= 0 ? l10n.learnedDue : l10n.learnedReviewedN(reps);
}

class _LearnedRow extends StatelessWidget {
  const _LearnedRow({
    required this.lemma,
    required this.pos,
    required this.semanticType,
    required this.dueLabel,
    required this.onTap,
  });

  final String lemma;
  final String pos;
  final String semanticType;
  final String dueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusCard),
        ),
        title: Text(
          lemma,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('$pos · $semanticType'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: dueLabel == l10n.learnedDue
                ? kSignalWarnBg
                : const Color(0xFFEFF0F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dueLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: dueLabel == l10n.learnedDue
                  ? kSignalWarn
                  : const Color(0xFF6E6E79),
            ),
          ),
        ),
      ),
    );
  }
}
