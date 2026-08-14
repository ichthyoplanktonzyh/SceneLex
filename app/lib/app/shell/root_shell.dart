/// Product v1 shell: mobile = immersive home + tabbar (map/content/study);
/// tablet/desktop = NavigationRail with a centered content column.
/// Never renders fake phone frames or status bars.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kBreakpointTablet;
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (icon: Icons.home_outlined, selected: Icons.home, label: l10n.tabHome),
      (icon: Icons.hub_outlined, selected: Icons.hub, label: l10n.tabMap),
      (
        icon: Icons.layers_outlined,
        selected: Icons.layers,
        label: l10n.tabContent,
      ),
      (
        icon: Icons.insights_outlined,
        selected: Icons.insights,
        label: l10n.tabStudy,
      ),
    ];
    return wide
        ? _railLayout(context, destinations)
        : _mobileLayout(context, destinations);
  }

  Widget _mobileLayout(
    BuildContext context,
    List<({IconData icon, IconData selected, String label})> destinations,
  ) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(kRadiusPill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A1E1E24),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              navigationShell.goBranch(index, initialLocation: index == 0),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _railLayout(
    BuildContext context,
    List<({IconData icon, IconData selected, String label})> destinations,
  ) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) =>
                navigationShell.goBranch(index, initialLocation: index == 0),
            labelType: NavigationRailLabelType.all,
            minWidth: 96,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
