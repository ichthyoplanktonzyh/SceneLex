/// 我的内容: replay / preview / transfer acceptance / lists / favorites /
/// notes — every entry opens a real page or a real empty state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../ui/theme/scenelex_tokens.dart';

class ContentLibraryPage extends ConsumerWidget {
  const ContentLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider).value;
    final states = ref.watch(learningStatesProvider).value ?? const {};
    final favorites = ref.watch(favoritesProvider).value ?? const {};
    final notes = ref.watch(notesProvider).value ?? const [];

    final learnedCount = states.length;
    final recentCount = states.values
        .where(
          (s) =>
              s.lastReviewedAt != null &&
              DateTime.now().difference(s.lastReviewedAt!) <
                  const Duration(days: 7),
        )
        .length;

    final recentLabel = recentCount > 0
        ? l10n.libRecent7d(recentCount)
        : l10n.libNone;
    final catalogSize = catalog?.senses.length ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    l10n.libTitle,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                // 经验回放 / 预习
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 17,
                      child: _ReplayCard(
                        title: l10n.libReplay,
                        subtitle: l10n.libReplayBody(learnedCount),
                        onTap: () => context.push('/content/replay'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 10,
                      child: _ReplayCard(
                        title: l10n.libPreview,
                        subtitle: l10n.libPreviewBody(
                          (catalogSize - learnedCount).clamp(0, 999),
                        ),
                        color: kColorTealSignal,
                        onTap: () => context.push('/content/preview'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 迁移验收
                Row(
                  children: [
                    Expanded(
                      flex: 17,
                      child: _ReplayCard(
                        title: l10n.libTransfer,
                        subtitle: l10n.libTransferBody,
                        icon: Icons.track_changes,
                        color: const Color(0xFF3FB99B),
                        onTap: () => context.push('/review?mode=transfer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 在学词单
                _GroupCard(
                  children: [
                    _Row(
                      icon: Icons.menu_book_outlined,
                      iconBg: const Color(0xFFDFF5EE),
                      iconColor: const Color(0xFF13A583),
                      title: l10n.libStudyLists,
                      value: l10n.libStudyListsBody(learnedCount),
                      onTap: () => context.push('/content/learned'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _GroupCard(
                  children: [
                    _Row(
                      icon: Icons.event_available,
                      iconBg: const Color(0xFFFDF0D8),
                      iconColor: const Color(0xFFE9A020),
                      title: l10n.libRecentLearned,
                      value: recentLabel,
                      onTap: () => context.push('/content/learned?recent=true'),
                    ),
                    _Row(
                      icon: Icons.check_circle_outline,
                      iconBg: const Color(0xFFFDF3DC),
                      iconColor: const Color(0xFFE8A72A),
                      title: l10n.libAllLearned,
                      value: l10n.libStudyListsBody(learnedCount),
                      onTap: () => context.push('/content/learned'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _GroupCard(
                  children: [
                    _Row(
                      icon: Icons.hub_outlined,
                      iconBg: const Color(0xFFE6ECFD),
                      iconColor: const Color(0xFF4A76E8),
                      title: l10n.libConceptMap,
                      value: l10n.libConceptMapBody(catalogSize),
                      onTap: () => context.go('/map'),
                    ),
                    _Row(
                      icon: Icons.format_quote,
                      iconBg: const Color(0xFFE6ECFD),
                      iconColor: const Color(0xFF4A76E8),
                      title: l10n.libFavorites,
                      value: l10n.libFavoritesBody(favorites.length),
                      onTap: () => context.push('/content/favorites'),
                    ),
                    _Row(
                      icon: Icons.edit_note,
                      iconBg: const Color(0xFFE9EDFF),
                      iconColor: const Color(0xFF5772EA),
                      title: l10n.libNotes,
                      value: l10n.libNotesBody(notes.length),
                      onTap: () => context.push('/content/notes'),
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
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.replay,
    this.color = const Color(0xFF8878D0),
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusCard),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: color == kColorTealSignal
                  ? const [Color(0xFFBFEADE), Color(0xFFD6F3EA)]
                  : const [Color(0xFFE2DCF4), Color(0xFFEFE9F8)],
            ),
            borderRadius: BorderRadius.circular(kRadiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: color,
                    child: Icon(icon, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(kRadiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title == l10n.libReplay
                          ? l10n.libReviewLabel
                          : title == l10n.libPreview
                          ? l10n.libLookFirst
                          : l10n.libToday,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kColorInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8F8F97),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.7),
                        child: Icon(Icons.play_arrow, size: 14, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (not a colored Container) so the ListTile ink + background
    // paint on a real Material ancestor.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
        child: Icon(icon, size: 21, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFFA0A0A8)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC2C2CA)),
        ],
      ),
    );
  }
}
