/// Daily Session preview entry: the product prototype behind
/// `--dart-define=SCENELEX_SESSION_PREVIEW=true`.
///
/// A standalone app that needs no login, no server, no workspace, no sync —
/// it boots straight into a bundled-catalog "Today's Session" with a single
/// primary entry and dynamic task orchestration. The production SceneLex App
/// and the Journey preview are untouched; only [main] switches on this
/// define. Everything under `features/daily_session_prototype` is deletable
/// as one directory.
///
/// Screenshot support: when the URL carries `?shot=<name>` (web builds only)
/// the app renders a fixed page state instead of the home, so prototype
/// screenshots can be captured at 1200×870 with a headless browser. This is
/// prototype-only plumbing; production never sees it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../data/content/content_catalog_repository.dart';
import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_home_page.dart';
import 'daily_session_store.dart';
import 'screenshot_driver.dart';

class SessionPreviewApp extends StatelessWidget {
  const SessionPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const _SessionPreviewBoot(),
    );
  }
}

/// Loads the real bundled catalog and builds the prototype store.
class _SessionPreviewBoot extends StatefulWidget {
  const _SessionPreviewBoot();

  @override
  State<_SessionPreviewBoot> createState() => _SessionPreviewBootState();
}

class _SessionPreviewBootState extends State<_SessionPreviewBoot> {
  late final Future<DailySessionStore> _store;

  @override
  void initState() {
    super.initState();
    // Desktop preview: keep the semantics tree generated so assistive
    // technology (and tooling driving the prototype) can read the UI.
    SemanticsBinding.instance.ensureSemantics();
    _store = _build();
  }

  Future<DailySessionStore> _build() async {
    final catalog = await BundledContentCatalogRepository().load();
    return DailySessionStore.standard(
      catalog: catalog,
      repository: BundledExperienceProgramRepository(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailySessionStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Catalog load failed: ${snapshot.error}'),
              ),
            ),
          );
        }
        final store = snapshot.data!;
        final repository = BundledExperienceProgramRepository();
        final shot = Uri.base.queryParameters['shot'];
        if (shot != null && shot.isNotEmpty) {
          return ScreenshotDriver(
            store: store,
            repository: repository,
            shot: shot,
          );
        }
        return DailySessionHomePage(store: store, repository: repository);
      },
    );
  }
}
