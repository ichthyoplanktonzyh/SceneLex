/// 场景收藏: favorited experience units, replayable, removable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../ui/theme/scenelex_tokens.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider).value ?? const {};
    final catalog = ref.watch(catalogProvider).value;
    final repository = ref.read(programRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favTitle)),
      body: favorites.isEmpty
          ? Center(
              child: Text(
                l10n.favEmpty,
                style: TextStyle(color: Color(0xFF9A9AA4)),
              ),
            )
          : FutureBuilder<List<Widget>>(
              future: _buildItems(favorites, catalog, repository),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(l10n.favLoadError(snapshot.error ?? '')),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: snapshot.data!,
                );
              },
            ),
    );
  }

  Future<List<Widget>> _buildItems(
    Set<String> favorites,
    dynamic catalog,
    dynamic repository,
  ) async {
    final items = <Widget>[];
    for (final key in favorites) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final programId = parts[0];
      final unitId = parts[1];
      // find the program via the catalog (programId → senseId)
      final senseId = catalog?.senses.values
          .where((e) => e.programId == programId)
          .map((e) => e.senseId)
          .firstOrNull;
      if (senseId == null) continue;
      try {
        final program = await repository.load(senseId);
        final unit = program.units.where((u) => u.id == unitId).firstOrNull;
        if (unit == null) continue;
        items.add(
          _FavoriteTile(
            episode: unit.experience.episode,
            onRemove: () async {
              final local = ref.read(localRepositoryProvider);
              await local.removeFavorite(key);
              ref.invalidate(favoritesProvider);
              setState(() {});
            },
          ),
        );
      } catch (_) {}
    }
    return items;
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.episode, required this.onRemove});

  final String episode;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              episode,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.6,
                color: kColorInk,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.favUnfavorite,
            icon: const Icon(Icons.star, color: kColorEmber),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
