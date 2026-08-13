import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/locale_controller.dart';
import 'auth/auth_controller.dart';
import 'data/content/experience_program_repository.dart';
import 'data/providers.dart';
import 'features/experience_runtime/experience_runtime_page.dart';
import 'features/experience_runtime/experience_runtime_view_model.dart';
import 'features/login/login_page.dart';
import 'features/settings/notifications_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'shell/app_shell.dart';

/// Development-only entry: `--dart-define=SCENELEX_EXPERIENCE_PREVIEW=<sense>`
/// opens the Experience Runtime directly, without login, API, workspace or
/// sync. An empty define keeps the normal app behavior.
const String kExperiencePreviewSense = String.fromEnvironment(
  'SCENELEX_EXPERIENCE_PREVIEW',
);

void main() {
  final Widget app = kExperiencePreviewSense.isEmpty
      ? const SceneLexApp()
      : ExperiencePreviewApp(senseId: kExperiencePreviewSense);
  runApp(ProviderScope(child: app));
}

/// Standalone Experience Runtime preview shell (no auth, no server, no db).
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
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

class SceneLexApp extends ConsumerWidget {
  const SceneLexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    // Record app activity (inactivity reminders) and clear delivered badges.
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isSignedIn && !(previous?.isSignedIn ?? false)) {
        NotificationsService().clearBadge();
        recordActivity();
      }
    });

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      locale: locale.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: switch (auth.status) {
        AuthStatus.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        AuthStatus.signedOut => const LoginPage(),
        AuthStatus.signedIn => const AppShell(),
      },
    );
  }
}
