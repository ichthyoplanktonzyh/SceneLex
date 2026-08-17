/// Golden-based screenshot generator for the Daily Session prototype.
///
/// Renders every documented page state at phone size (390×844 @2x, output
/// 780×1688) with real fonts (system Arial Unicode covers Latin + CJK),
/// producing the PNGs under docs/prototypes/daily-session/.
///
/// The page states are produced by the prototype's own `ScreenshotDriver`
/// (same `?shot=` states the web preview exposes), so the screenshots match
/// what a real browser shows.
///
/// Generation is opt-in so the regular test suite stays hermetic: the tests
/// are skipped unless `SCENELEX_GEN_SHOTS` is defined, and the golden paths
/// are absolute (LocalFileComparator behaves unreliably with relative
/// paths on this setup):
///
///   flutter test test/daily_session_screenshots_test.dart \
///     --update-goldens --dart-define=SCENELEX_GEN_SHOTS=true
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_store.dart';
import 'package:scenelex/features/daily_session_prototype/screenshot_driver.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';
import 'package:scenelex/ui/theme/scenelex_tokens.dart';

/// Screenshot generation is opt-in; skipped in the regular test suite.
const bool kGenShots = bool.fromEnvironment('SCENELEX_GEN_SHOTS');

String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  return BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
}

BundledExperienceProgramRepository buildRepository() =>
    BundledExperienceProgramRepository(bundleLoader: () async => _bundleText!);

/// Pumps fake time until [finder] matches (route pushes and the session VM
/// load asynchronously).
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('never found $finder');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
    // Real glyphs (Latin + CJK) instead of the test-only Ahem blocks.
    final data = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('UniFont')
      ..addFont(Future.value(ByteData.sublistView(data)));
    await loader.load();
  });

  Future<DailySessionStore> pumpShot(
    WidgetTester tester,
    String shot,
    String expectedText,
  ) async {
    final catalog = await loadCatalog();
    final store = DailySessionStore.standard(
      catalog: catalog,
      repository: buildRepository(),
    );
    final theme = buildSceneLexTheme().copyWith(
      textTheme: buildSceneLexTheme().textTheme.apply(fontFamily: 'UniFont'),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenshotDriver(
          store: store,
          repository: buildRepository(),
          shot: shot,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntilFound(tester, find.text(expectedText));
    // Let the current frame settle (scene cards, sheet animations, etc).
    await tester.pump(const Duration(milliseconds: 400));
    return store;
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    String shot,
    String expectedText,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    debugPrint(
      'VIEW physical=${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio}',
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpShot(tester, shot, expectedText);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '/Users/shadow/SceneLex/docs/prototypes/daily-session/$name.png',
      ),
    );
  }

  testWidgets('01 home', (tester) async {
    await capture(tester, '01-home', 'home', 'Start Learning');
  }, skip: !kGenShots);

  testWidgets('02 mode sheet', (tester) async {
    await capture(tester, '02-mode-sheet', 'mode', 'Standard');
  }, skip: !kGenShots);

  testWidgets('03 recall', (tester) async {
    await capture(tester, '03-recall', 'recall', 'Reveal');
  }, skip: !kGenShots);

  testWidgets('04 discover', (tester) async {
    await capture(tester, '04-discover', 'discover', 'Core sense');
  }, skip: !kGenShots);

  testWidgets('05 boundary', (tester) async {
    await capture(tester, '05-boundary', 'boundary', 'Boundary check');
  }, skip: !kGenShots);

  testWidgets('06 transfer (inserted after Forgot)', (tester) async {
    await capture(tester, '06-transfer-inserted', 'transfer', 'Transfer drill');
  }, skip: !kGenShots);

  testWidgets('07 continue (paused)', (tester) async {
    await capture(tester, '07-continue', 'continue', 'Continue this session');
  }, skip: !kGenShots);

  testWidgets('08 completion', (tester) async {
    await capture(tester, '08-completion', 'completion', 'Session complete');
  }, skip: !kGenShots);
}
