import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';

/// Read-only tag browser (Settings > Tags).
///
/// Tags are derived from each sense's metadata (`type:<semanticType>` and
/// `pos:<part of speech>`) — there is no user-generated tag concept in v1, so
/// this page only lists tags with their studied-word counts and jumps into a
/// tag-filtered review. No rename/delete (nothing is editable here).
class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWorkspaceTags)),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
        data: (lib) {
          final tags = lib.tagCounts.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.tagsScreenSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (tags.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.tagsScreenEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final entry in tags)
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(entry.key),
                    subtitle: Text(l10n.tagsScreenLearnedCount(entry.value)),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () {
                      ref
                          .read(reviewFilterProvider.notifier)
                          .set(ReviewFilter.tags({entry.key}));
                      ref.read(selectedTabProvider.notifier).setTab(0);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
