import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../features/cards/cards_page.dart';
import '../features/progress/progress_page.dart';
import '../features/review/review_page.dart';
import '../features/settings/settings_page.dart';
import '../l10n/gen/app_localizations.dart';

/// Top-level shell: 4 tabs (Review / Progress / Cards / Settings).
/// The selected tab is exposed via [selectedTabProvider] so other surfaces
/// (e.g. "Review this deck") can jump to the Review tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          // Active flag lets the Review page grab keyboard focus when the
          // tab becomes visible (web/desktop shortcuts).
          for (var i = 0; i < _tabCount; i++) _buildPage(i, selectedIndex),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          ref.read(selectedTabProvider.notifier).setTab(index);
          FocusManager.instance.primaryFocus?.unfocus();
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style),
            label: l10n.tabReview,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.tabProgress,
          ),
          NavigationDestination(
            icon: const Icon(Icons.collections_bookmark_outlined),
            selectedIcon: const Icon(Icons.collections_bookmark),
            label: l10n.tabCards,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, int selectedIndex) {
    return switch (index) {
      0 => ReviewPage(active: selectedIndex == index),
      1 => const ProgressPage(),
      2 => const CardsPage(),
      _ => const SettingsPage(),
    };
  }
}
