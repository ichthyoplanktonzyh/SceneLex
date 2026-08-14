import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/locale_controller.dart';
import 'app/routing/app_router.dart';
import 'auth/auth_controller.dart';
import 'data/content/experience_program_repository.dart';
import 'data/product_providers.dart';
import 'data/providers.dart';
import 'features/experience_runtime/experience_runtime_page.dart';
import 'features/experience_runtime/experience_runtime_view_model.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeMode = await loadThemeMode();
  final Widget app = kExperiencePreviewSense.isEmpty
      ? SceneLexApp(initialThemeMode: themeMode)
      : ExperiencePreviewApp(senseId: kExperiencePreviewSense);
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
