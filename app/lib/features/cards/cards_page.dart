import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../l10n/gen/app_localizations.dart';

/// Vocabulary surface: senses catalog with inline learning stats + local search.
class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  final _searchController = TextEditingController();

  /// Tags selected via the filter sheet (match-any over the senses).
  final Set<String> _selectedTags = {};

  /// Rows dismissed this session (removed from the tree synchronously until
  /// the library provider refreshes with the tombstoned state).
  final _removedIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the tag filter sheet (multi-select chips + clear + apply).
  void _openFilterSheet() {
    final l10n = AppLocalizations.of(context);
    final lib = ref.read(libraryProvider).value;
    if (lib == null) return;

    final draftTags = <String>{..._selectedTags};
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.cardsFilterTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (lib.tagCounts.isEmpty)
                  Text(
                    l10n.listsNoTags,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in lib.tagCounts.entries)
                        FilterChip(
                          label: Text('${entry.key} (${entry.value})'),
                          selected: draftTags.contains(entry.key),
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              draftTags.add(entry.key);
                            } else {
                              draftTags.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: draftTags.isEmpty
                          ? null
                          : () => setSheetState(draftTags.clear),
                      child: Text(l10n.cardsFilterClear),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        setState(
                          () => _selectedTags
                            ..clear()
                            ..addAll(draftTags),
                        );
                        Navigator.pop(sheetContext);
                      },
                      child: Text(l10n.cardsFilterApply),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tombstone the learning state (deletedAt set, still an upsert on the
  /// wire), then trigger sync and refresh the library.
  Future<void> _removeFromStudy(Sense sense) async {
    final local = ref.read(localRepositoryProvider);
    final ws = await ref.read(workspaceProvider.future);
    await local.tombstoneLearningState(
      workspaceId: ws,
      wordSenseId: sense.wordSenseId,
      nowIso: DateTime.now().toUtc().toIso8601String(),
    );
    ref.read(syncTriggerProvider)();
    ref.invalidate(libraryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);
    // Once the refreshed library arrives (tombstone applied), dismissed rows
    // become plain "not added" rows again and can reappear.
    ref.listen(libraryProvider, (previous, next) {
      if (next is AsyncData) {
        _removedIds.clear();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardsTitle),
        actions: [
          IconButton(
            tooltip: l10n.cardsFilterTitle,
            icon: Badge(
              isLabelVisible: _selectedTags.isNotEmpty,
              label: Text('${_selectedTags.length}'),
              child: const Icon(Icons.filter_alt_outlined),
            ),
            onPressed: _openFilterSheet,
          ),
        ],
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
          var senses = query.isEmpty
              ? lib.senses
              : lib.senses
                    .where(
                      (s) =>
                          s.lemma.toLowerCase().contains(query) ||
                          s.senseKey.toLowerCase().contains(query) ||
                          s.pos.toLowerCase().contains(query) ||
                          s.semanticType.toLowerCase().contains(query),
                    )
                    .toList();
          if (_selectedTags.isNotEmpty) {
            senses = senses
                .where((s) => lib.senseHasAnyTag(s.wordSenseId, _selectedTags))
                .toList();
          }
          if (senses.isEmpty) {
            return _EmptyState(
              message: _selectedTags.isNotEmpty
                  ? l10n.cardsFilterEmpty
                  : l10n.cardsEmptySearch,
            );
          }
          final visible = senses
              .where((s) => !_removedIds.contains(s.wordSenseId))
              .toList();
          return ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sense = visible[index];
              final state = lib.states[sense.wordSenseId];
              return _SenseRow(
                sense: sense,
                state: state,
                onStudy: () async {
                  await addSenseToStudy(ref, sense.wordSenseId);
                  ref.invalidate(libraryProvider);
                },
                onRemove: state == null ? null : () => _removeFromStudy(sense),
                onDismissed: () {
                  setState(() => _removedIds.add(sense.wordSenseId));
                },
              );
            },
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
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _SenseRow extends StatelessWidget {
  const _SenseRow({
    required this.sense,
    required this.state,
    required this.onStudy,
    this.onRemove,
    this.onDismissed,
  });

  final Sense sense;
  final LearningState? state;
  final VoidCallback onStudy;
  final Future<void> Function()? onRemove;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final st = state;
    final isNew = st == null || st.isNew;
    final remove = onRemove;

    final tile = ListTile(
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
                _StatChip(color: Colors.grey, text: l10n.cardStatReps(st.reps)),
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
          ? FilledButton.tonal(onPressed: onStudy, child: Text(l10n.cardsStudy))
          : Icon(Icons.check_circle, color: theme.colorScheme.primary),
      isThreeLine: true,
      onTap: state == null ? null : () => _showDetails(context, l10n),
    );

    // Swipe to remove from study (tombstone, synced as an upsert).
    if (remove == null || onDismissed == null) return tile;
    return Dismissible(
      key: ValueKey('remove-${sense.wordSenseId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: tile,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cardRemoveTitle),
            content: Text(l10n.cardRemoveBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.signOutCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.cardRemove),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          // Tombstone first so the next sync carries the deletion.
          await remove();
        }
        return confirmed ?? false;
      },
      onDismissed: (_) => onDismissed!(),
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
            _DetailRow(label: l10n.cardMetaDue, value: dueText),
            _DetailRow(label: l10n.cardStateReview, value: s.fsrsCardState),
            _DetailRow(
              label: l10n.cardStatReps(s.reps),
              value: s.reps.toString(),
            ),
            _DetailRow(
              label: l10n.cardStatLapses(s.lapses),
              value: s.lapses.toString(),
            ),
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
