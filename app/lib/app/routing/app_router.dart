/// Product v1 routing (go_router): the new IA replaces the legacy four-tab
/// shell. Mobile keeps the immersive home + sheet/slide page relation; large
/// screens use the rail shell (docs/product-v1-app.md §1/§8).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/completion/group_complete_page.dart';
import '../../features/content_library/content_library_page.dart';
import '../../features/content_library/favorites_page.dart';
import '../../features/content_library/learned_page.dart';
import '../../features/content_library/notes_page.dart';
import '../../features/content_library/preview_list_page.dart';
import '../../features/content_library/replay_page.dart';
import '../../features/concept_map/concept_map_page.dart';
import '../../features/home/home_page.dart';
import '../../features/learn/learn_session_page.dart';
import '../../features/preferences/preferences_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/review_runtime/review_session_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/study/study_page.dart';
import '../shell/root_shell.dart';

/// Sheet-like pages rise from the bottom; flow pages fade; profile slides in.
Page _sheetPage(Widget child) => CustomTransitionPage(
  key: ValueKey(child.runtimeType),
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: FadeTransition(opacity: animation, child: child),
      ),
);

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          RootShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const MaterialPage(child: HomePage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              pageBuilder: (context, state) =>
                  const MaterialPage(child: ConceptMapPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/content',
              pageBuilder: (context, state) =>
                  const MaterialPage(child: ContentLibraryPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/study',
              pageBuilder: (context, state) =>
                  const MaterialPage(child: StudyPage()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/learn',
      pageBuilder: (context, state) =>
          const MaterialPage(child: LearnSessionPage()),
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) => MaterialPage(
        child: ReviewSessionPage(
          transferMode: state.uri.queryParameters['mode'] == 'transfer',
        ),
      ),
    ),
    GoRoute(
      path: '/finish',
      pageBuilder: (context, state) =>
          const MaterialPage(child: GroupCompletePage()),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _sheetPage(const ProfilePage()),
    ),
    GoRoute(
      path: '/preferences',
      pageBuilder: (context, state) =>
          const MaterialPage(child: PreferencesPage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          const MaterialPage(child: SettingsPage()),
    ),
    GoRoute(
      path: '/content/replay',
      pageBuilder: (context, state) => const MaterialPage(child: ReplayPage()),
    ),
    GoRoute(
      path: '/content/preview',
      pageBuilder: (context, state) =>
          const MaterialPage(child: PreviewListPage()),
    ),
    GoRoute(
      path: '/content/learned',
      pageBuilder: (context, state) => const MaterialPage(child: LearnedPage()),
    ),
    GoRoute(
      path: '/content/favorites',
      pageBuilder: (context, state) =>
          const MaterialPage(child: FavoritesPage()),
    ),
    GoRoute(
      path: '/content/notes',
      pageBuilder: (context, state) => const MaterialPage(child: NotesPage()),
    ),
  ],
);
