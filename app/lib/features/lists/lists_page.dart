import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../api/models.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../l10n/gen/app_localizations.dart';

const _uuidGen = Uuid();

/// Word lists (smart filters). "All Cards" is the built-in system item and is
/// not editable; custom lists must carry at least one tag.
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.listsTitle)),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
        data: (lib) {
          final lists = lib.lists;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.style),
                title: Text(l10n.listsAllCards),
                subtitle: Text(l10n.listsAllCardsBody(lib.states.length)),
                onTap: null,
              ),
              const Divider(height: 1),
              if (lists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.listsEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                for (final list in lists)
                  ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(list.name),
                    subtitle: Text(l10n.listsMatchedCount(
                        lib.matchedCount(list))),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ListDetailPage(list: list),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const ListEditorPage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.listsCreate),
      ),
    );
  }
}

/// Word list detail: rule, stats, matched senses, and "Review this deck".
class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({super.key, required this.list});

  final WordList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            tooltip: l10n.listsEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ListEditorPage(existing: list),
              ),
            ),
          ),
        ],
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
        data: (lib) {
          final matched = lib.senses
              .where((s) =>
                  lib.states.containsKey(s.wordSenseId) &&
                  lib.senseHasAnyTag(s.wordSenseId, list.tags))
              .toList();
          final due = matched.where((s) {
            final state = lib.states[s.wordSenseId];
            return state != null && state.isDue;
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.listsDetailRules, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in list.tags) _TagChip(tag: tag),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.listsDetailStats, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(
                        label: l10n.listsStatMatched,
                        value: matched.length,
                      ),
                      _StatColumn(
                        label: l10n.listsStatDue,
                        value: due,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.style),
                label: Text(l10n.listsReviewThisDeck),
                onPressed: () {
                  ref.read(reviewFilterProvider.notifier).set(
                        ReviewFilter.list(list.listId),
                      );
                  ref.read(selectedTabProvider.notifier).setTab(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              const SizedBox(height: 24),
              Text(
                l10n.listsDetailMatched,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (matched.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.listsMatchedEmpty,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final sense in matched)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.abc),
                    title: Text(sense.lemma),
                    subtitle: Text(sense.senseKey),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Create / edit a word list. Requires a name and at least one tag.
class ListEditorPage extends ConsumerStatefulWidget {
  const ListEditorPage({super.key, this.existing});

  final WordList? existing;

  @override
  ConsumerState<ListEditorPage> createState() => _ListEditorPageState();
}

class _ListEditorPageState extends ConsumerState<ListEditorPage> {
  late final TextEditingController _nameController;
  late final Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _selectedTags = {...?existing?.tags};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _selectedTags.isNotEmpty;

  Future<void> _save() async {
    final ws = await ref.read(workspaceProvider.future);
    final existing = widget.existing;
    final list = WordList(
      listId: existing?.listId ?? _uuidGen.v4(),
      name: _nameController.text.trim(),
      tags: _selectedTags.toList()..sort(),
    );
    await ref.read(localRepositoryProvider).saveList(
          workspaceId: ws,
          list: list,
        );
    ref.read(syncTriggerProvider)();
    ref.invalidate(libraryProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? l10n.listsCreate : l10n.listsEdit,
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: l10n.listsDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.listsNameLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.listsTagsLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          library.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(l10n.loadingFailed('$e')),
            data: (lib) {
              final tags = lib.tagCounts.keys.toList()..sort();
              if (tags.isEmpty) {
                return Text(l10n.listsNoTags, style: Theme.of(context).textTheme.bodySmall);
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text('$tag (${lib.tagCounts[tag]})'),
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.listsSaveHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.listsDeleteTitle),
        content: Text(l10n.listsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.signOutCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.listsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ws = await ref.read(workspaceProvider.future);
    await ref.read(localRepositoryProvider).saveList(
          workspaceId: ws,
          list: widget.existing!,
          deletedAt: DateTime.now(),
        );
    ref.read(syncTriggerProvider)();
    ref.invalidate(libraryProvider);
    if (!context.mounted) return;
    Navigator.pop(context);
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(tag, style: theme.textTheme.labelMedium),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
