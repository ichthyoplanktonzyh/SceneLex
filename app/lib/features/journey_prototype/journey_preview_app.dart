/// Journey preview entry: the product prototype behind
/// `--dart-define=SCENELEX_JOURNEY_PREVIEW=true`.
///
/// A standalone app that needs no login, no server, no workspace, no sync —
/// it boots straight into a bundled-catalog "Today's Journey". The production
/// SceneLex App is untouched; only [main] switches on this define. Everything
/// under `features/journey_prototype` is deletable as one directory.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../data/content/content_catalog_repository.dart';
import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'journey_home_page.dart';
import 'journey_preview_store.dart';

class JourneyPreviewApp extends StatelessWidget {
  const JourneyPreviewApp({super.key});

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
      home: const _JourneyPreviewBoot(),
    );
  }
}

/// Loads the real bundled catalog and builds the prototype store.
class _JourneyPreviewBoot extends StatefulWidget {
  const _JourneyPreviewBoot();

  @override
  State<_JourneyPreviewBoot> createState() => _JourneyPreviewBootState();
}

class _JourneyPreviewBootState extends State<_JourneyPreviewBoot> {
  late final Future<JourneyPreviewStore> _store;

  @override
  void initState() {
    super.initState();
    // Desktop preview: keep the semantics tree generated so assistive
    // technology (and tooling driving the prototype) can read the UI.
    SemanticsBinding.instance.ensureSemantics();
    _store = _build();
  }

  Future<JourneyPreviewStore> _build() async {
    final catalog = await BundledContentCatalogRepository().load();
    return JourneyPreviewStore.standard(catalog: catalog);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JourneyPreviewStore>(
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
        return JourneyHomePage(
          store: store,
          repository: BundledExperienceProgramRepository(),
        );
      },
    );
  }
}
