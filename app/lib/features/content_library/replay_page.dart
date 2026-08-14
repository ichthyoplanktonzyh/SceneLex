/// 经验回放: replay experiences of learned senses — episodes only, never the
/// target word; favorites toggle; previous/next navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../ui/theme/scenelex_tokens.dart';

class ReplayPage extends ConsumerStatefulWidget {
  const ReplayPage({super.key});

  @override
  ConsumerState<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends ConsumerState<ReplayPage> {
  int _index = 0;
  List<ExperienceUnit>? _units;
  String? _programId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final states = ref.watch(learningStatesProvider).value ?? const {};
    final catalog = ref.watch(catalogProvider).value;
    final repository = ref.read(programRepositoryProvider);
    final learned =
        catalog?.ordered.where((e) => states.containsKey(e.senseId)).toList() ??
        const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.replayTitle)),
      body: learned.isEmpty
          ? _Empty(title: l10n.replayEmptyTitle, hint: l10n.replayEmptyBody)
          : FutureBuilder<List<ExperienceUnit>>(
              future: _loadUnits(learned, repository),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(l10n.replayLoadError(snapshot.error ?? '')),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                _units = snapshot.data!;
                if (_units!.isEmpty) {
                  return _Empty(title: l10n.replayNoExperience, hint: '');
                }
                final unit = _units![_index];
                return _Player(
                  unit: unit,
                  index: _index,
                  total: _units!.length,
                  isFavorite: _isFavorite(unit),
                  onFavorite: () async {
                    final local = ref.read(localRepositoryProvider);
                    final key = '$_programId:${unit.id}';
                    final fav = await local.isFavorite(key);
                    if (fav) {
                      await local.removeFavorite(key);
                    } else {
                      await local.addFavorite(
                        programId: _programId ?? '',
                        experienceUnitId: unit.id,
                      );
                    }
                    ref.invalidate(favoritesProvider);
                    setState(() {});
                  },
                  onPrevious: _index > 0
                      ? () => setState(() => _index -= 1)
                      : null,
                  onNext: _index < _units!.length - 1
                      ? () => setState(() => _index += 1)
                      : null,
                );
              },
            ),
    );
  }

  bool _isFavorite(ExperienceUnit unit) {
    final favorites = ref.watch(favoritesProvider).value ?? const {};
    return favorites.contains('$_programId:${unit.id}');
  }

  Future<List<ExperienceUnit>> _loadUnits(
    List<dynamic> learned,
    dynamic repository,
  ) async {
    final units = <ExperienceUnit>[];
    for (final entry in learned) {
      try {
        final program = await repository.load(entry.senseId);
        _programId = program.programId;
        units.addAll(program.units);
      } catch (_) {}
    }
    return units;
  }
}

class _Player extends StatelessWidget {
  const _Player({
    required this.unit,
    required this.index,
    required this.total,
    required this.isFavorite,
    required this.onFavorite,
    required this.onPrevious,
    required this.onNext,
  });

  final ExperienceUnit unit;
  final int index;
  final int total;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.replayCounter(index + 1, total),
                      style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: isFavorite
                          ? l10n.replayUnfavorite
                          : l10n.replayFavorite,
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? kColorEmber : null,
                      ),
                      onPressed: onFavorite,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 19,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(kRadiusCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.replayOnlyScene,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8B8B96),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          unit.experience.episode,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.78,
                            color: kColorInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.replayPrev,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPrevious,
                  ),
                  IconButton(
                    tooltip: l10n.replayNext,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, size: 48, color: Color(0xFF9A9AA4)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(color: Color(0xFF9A9AA4))),
        ],
      ),
    );
  }
}
