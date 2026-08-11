import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';

/// Vocabulary surface: senses catalog with inline learning stats + local search.
class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.cardsSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
        data: (lib) {
          if (lib.senses.isEmpty) {
            return _EmptyState(message: l10n.cardsEmptyLibrary);
          }
          final query = _searchController.text.trim().toLowerCase();
          final senses = query.isEmpty
              ? lib.senses
              : lib.senses
                  .where((s) =>
                      s.lemma.toLowerCase().contains(query) ||
                      s.senseKey.toLowerCase().contains(query) ||
                      s.pos.toLowerCase().contains(query) ||
                      s.semanticType.toLowerCase().contains(query))
                  .toList();
          if (senses.isEmpty) {
            return _EmptyState(message: l10n.cardsEmptySearch);
          }
          return ListView.separated(
            itemCount: senses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sense = senses[index];
              final state = lib.states[sense.wordSenseId];
              return _SenseRow(
                sense: sense,
                state: state,
                onStudy: () async {
                  await addSenseToStudy(ref, sense.wordSenseId);
                  ref.invalidate(libraryProvider);
                },
              );            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _SenseRow extends StatelessWidget {
  const _SenseRow({
    required this.sense,
    required this.state,
    required this.onStudy,
  });

  final Sense sense;
  final LearningState? state;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final st = state;
    final isNew = st == null || st.isNew;

    return ListTile(
      title: Text(sense.lemma, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sense.pos.isNotEmpty || sense.semanticType.isNotEmpty)
            Text(
              '${sense.pos} · ${sense.semanticType}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _StatChip(
                color: isNew ? theme.colorScheme.primary : Colors.teal,
                text: _stateChipText(l10n, state),
              ),
              if (st != null && !st.isNew) ...[
                _StatChip(
                  color: st.isDue ? Colors.orange : Colors.grey,
                  text: l10n.cardStatDue(st.isDue ? 1 : 0),
                ),
                _StatChip(
                  color: Colors.grey,
                  text: l10n.cardStatReps(st.reps),
                ),
                if (st.lapses > 0)
                  _StatChip(
                    color: Colors.red,
                    text: l10n.cardStatLapses(st.lapses),
                  ),
              ],
            ],
          ),
        ],
      ),
      trailing: state == null
          ? FilledButton.tonal(
              onPressed: onStudy,
              child: Text(l10n.cardsStudy),
            )
          : Icon(Icons.check_circle, color: theme.colorScheme.primary),
      isThreeLine: true,
      onTap: state == null ? null : () => _showDetails(context, l10n),
    );
  }

  String _stateChipText(AppLocalizations l10n, LearningState? state) {
    if (state == null) return l10n.cardStateNotAdded;
    return switch (state.fsrsCardState) {
      'new' => l10n.cardStateNew,
      'learning' => l10n.cardStateLearning,
      'relearning' => l10n.cardStateRelearning,
      _ => l10n.cardStateReview,
    };
  }

  void _showDetails(BuildContext context, AppLocalizations l10n) {
    final s = state;
    if (s == null) return;
    final dueText = s.dueAt?.toLocal().toString() ?? l10n.cardStateNew;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sense.lemma, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailRow(label: l10n.cardStateNext(''), value: dueText),
            _DetailRow(label: l10n.cardStateReview, value: s.fsrsCardState),
            _DetailRow(label: l10n.cardStatReps(s.reps), value: s.reps.toString()),
            _DetailRow(label: l10n.cardStatLapses(s.lapses), value: s.lapses.toString()),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
