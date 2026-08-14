/// 预习: anchor experiences of not-yet-learned senses, without revealing the
/// symbol. Entering first learning from here is supported via the group
/// route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../ui/theme/scenelex_tokens.dart';

class PreviewListPage extends ConsumerWidget {
  const PreviewListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    final states = ref.watch(learningStatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.previewTitle)),
      body: catalog.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.previewLoadError(error))),
        data: (data) {
          final learned = states.value ?? const {};
          final pending = data.ordered
              .where((e) => !learned.containsKey(e.senseId))
              .toList();
          if (pending.isEmpty) {
            return Center(child: Text(l10n.previewEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: pending.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return FilledButton.icon(
                  onPressed: () => context.push('/learn'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(l10n.previewEnterLearn),
                );
              }
              final entry = pending[index - 1];
              return _PreviewCard(
                onTap: () => context.push('/learn?preview=${entry.senseId}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.previewNewSense,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9A9AA4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.previewFromExperience,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_outline, color: kColorEmber),
            ],
          ),
        ),
      ),
    );
  }
}
