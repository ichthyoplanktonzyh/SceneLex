import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/locale_controller.dart';
import 'app/routing/app_router.dart';
import 'auth/auth_controller.dart';
import 'data/content/experience_program_repository.dart';
import 'data/product_providers.dart';
import 'data/providers.dart';
import 'features/daily_session_prototype/daily_session_preview_app.dart';
import 'features/experience_runtime/experience_runtime_page.dart';
import 'features/experience_runtime/experience_runtime_view_model.dart';
import 'features/journey_prototype/journey_preview_app.dart';
import 'features/login/login_page.dart';
import 'features/settings/notifications_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/theme/scenelex_tokens.dart';

/// Development-only entry: `--dart-define=SCENELEX_EXPERIENCE_PREVIEW=<sense>`
/// opens the single-program Experience Runtime directly, without login, API,
/// workspace or sync. The production App is the new IA shell (no preview
/// define); the preview does not replace the production entry.
const String kExperiencePreviewSense = String.fromEnvironment(
  'SCENELEX_EXPERIENCE_PREVIEW',
);

/// Development-only entry: `--dart-define=SCENELEX_JOURNEY_PREVIEW=true`
/// boots the "Today's Journey" product prototype (bundled catalog, prototype
/// learner state, no login / server / workspace / sync). The production App
/// behavior is unchanged; the whole prototype lives under
/// `features/journey_prototype` and can be deleted as one directory.
const String kJourneyPreviewFlag = String.fromEnvironment(
  'SCENELEX_JOURNEY_PREVIEW',
);

/// Development-only entry: `--dart-define=SCENELEX_SESSION_PREVIEW=true`
/// boots the "Daily Learning Session" product prototype (unified entry +
/// dynamic task orchestration + modes; bundled catalog, prototype learner
/// state, memory-only session resume, no login / server / workspace / sync).
/// The production App and the Journey preview are unchanged; the whole
/// prototype lives under `features/daily_session_prototype` and can be
/// deleted as one directory.
///
/// Precedence: when both SESSION_PREVIEW and JOURNEY_PREVIEW are set,
/// SESSION_PREVIEW wins — the two previews are independent prototypes and
/// must never interfere, but only one can own the entry at a time.
const String kSessionPreviewFlag = String.fromEnvironment(
  'SCENELEX_SESSION_PREVIEW',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeMode = await loadThemeMode();
  final Widget app;
  if (kSessionPreviewFlag.isNotEmpty) {
    app = const SessionPreviewApp();
  } else if (kJourneyPreviewFlag.isNotEmpty) {
    app = const JourneyPreviewApp();
  } else if (kExperiencePreviewSense.isNotEmpty) {
    app = ExperiencePreviewApp(senseId: kExperiencePreviewSense);
  } else {
    app = SceneLexApp(initialThemeMode: themeMode);
  }
  runApp(ProviderScope(child: app));
}

/// Standalone single-program preview (no auth, no server, no db).
class ExperiencePreviewApp extends StatelessWidget {
  const ExperiencePreviewApp({super.key, required this.senseId});

  final String senseId;

  @override
  Widget build(BuildContext context) {
    final viewModel = ExperienceRuntimeViewModel(
      BundledExperienceProgramRepository(),
      senseId,
    );
    viewModel.load();
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildSceneLexTheme(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ExperienceRuntimePage(viewModel: viewModel),
    );
  }
}

class SceneLexApp extends ConsumerStatefulWidget {
  const SceneLexApp({super.key, required this.initialThemeMode});

  final ThemeMode initialThemeMode;

  @override
  ConsumerState<SceneLexApp> createState() => _SceneLexAppState();
}

class _SceneLexAppState extends ConsumerState<SceneLexApp> {
  @override
  void initState() {
    super.initState();
    // Apply the persisted theme after the first frame: mutating a provider
    // during build/initState is illegal in Riverpod 3.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(appearanceThemeModeProvider.notifier)
            .setThemeMode(widget.initialThemeMode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(appearanceThemeModeProvider);

    // Record app activity (inactivity reminders) and clear delivered badges.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isSignedIn && !(previous?.isSignedIn ?? false)) {
        NotificationsService().clearBadge();
        recordActivity();
      }
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildSceneLexTheme(),
      darkTheme: buildSceneLexTheme(dark: true),
      themeMode: themeMode,
      locale: locale.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (context, child) {
        return switch (auth.status) {
          AuthStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          // Keep the Navigator (Overlay) mounted under the login page and
          // give the login page its own Overlay so text fields (selection
          // toolbars) have an Overlay ancestor.
          AuthStatus.signedOut => Stack(
            children: [
              child ?? const SizedBox.shrink(),
              Overlay(
                initialEntries: [
                  OverlayEntry(builder: (_) => const LoginPage()),
                ],
              ),
            ],
          ),
          AuthStatus.signedIn => child!,
        };
      },
    );
  }
}
