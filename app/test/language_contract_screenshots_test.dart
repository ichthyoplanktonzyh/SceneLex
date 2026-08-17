/// Language Contract v1 acceptance screenshots.
///
/// Five product acceptance screens rendered with real zh-CN content that
/// complies with the Learning Presentation Language Contract v1:
///   09-language-discover   zh-CN Discover (pre-binding, no L2)
///   10-language-binding    Symbol Binding (L2 first appears)
///   11-language-grounding  Grounding (natural L2 realization)
///   12-language-boundary   zh-CN Boundary with L2 options
///   13-language-recall     zh-CN Early Recall + L2 reveal
///
/// Generation is opt-in (same mechanism as daily_session_screenshots_test):
///
///   flutter test test/language_contract_screenshots_test.dart \
///     --update-goldens --dart-define=SCENELEX_GEN_SHOTS=true
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';
import 'package:scenelex/features/daily_session_prototype/views/session_boundary_view.dart';
import 'package:scenelex/features/daily_session_prototype/views/session_recall_view.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_page.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';
import 'package:scenelex/ui/theme/scenelex_tokens.dart';

import 'fixtures/zh_contract_program.dart';

const bool kGenShots = bool.fromEnvironment('SCENELEX_GEN_SHOTS');

class _MemoryRepository implements ExperienceProgramRepository {
  _MemoryRepository(this._program);
  final ExperienceProgram _program;

  @override
  Future<ExperienceProgram> load(String senseId) async => _program;
}

void main() {
  const goldenDir = '/Users/shadow/SceneLex/docs/prototypes/daily-session';
  late final ExperienceProgram program;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    final data = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('UniFont')
      ..addFont(Future.value(ByteData.sublistView(data)));
    await loader.load();
  });

  ThemeData theme() => buildSceneLexTheme().copyWith(
    textTheme: buildSceneLexTheme().textTheme.apply(fontFamily: 'UniFont'),
  );

  Future<ExperienceRuntimeViewModel> pumpRuntime(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = ExperienceRuntimeViewModel(
      _MemoryRepository(program),
      program.programId,
    );
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        theme: theme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExperienceRuntimePage(viewModel: vm),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return vm;
  }

  Future<void> answerAndContinue(WidgetTester tester) async {
    final finder = find.byKey(const ValueKey('answer-a1'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
    final continueButton = find.text('继续');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> captureApp(
    WidgetTester tester,
    String name,
    Widget app,
    String expectedText,
  ) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.textContaining(expectedText).evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$goldenDir/$name.png'),
    );
  }

  testWidgets('09 language-discover: zh-CN pre-binding, no L2', (tester) async {
    await pumpRuntime(tester);
    await captureApp(
      tester,
      '09-language-discover',
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      '书桌',
    );
  }, skip: !kGenShots);

  testWidgets('10 language-binding: L2 first appears', (tester) async {
    final vm = await pumpRuntime(tester);
    for (var i = 0; i < program.units.length; i++) {
      await answerAndContinue(tester);
    }
    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
    await captureApp(
      tester,
      '10-language-binding',
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      'messy',
    );
  }, skip: !kGenShots);

  testWidgets('11 language-grounding: natural L2 realization',
      (tester) async {
    final vm = await pumpRuntime(tester);
    for (var i = 0; i < program.units.length; i++) {
      await answerAndContinue(tester);
    }
    await tester.tap(find.text('继续'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(vm.phase, ExperienceRuntimePhase.grounding);
    await captureApp(
      tester,
      '11-language-grounding',
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      'The desk looks messy',
    );
  }, skip: !kGenShots);

  testWidgets('12 language-boundary: zh-CN scene + L2 options',
      (tester) async {
    WordSenseCatalogEntry entry(String senseId, String lemma) =>
        WordSenseCatalogEntry(
          senseId: senseId,
          senseKey: senseId,
          lemma: lemma,
          pos: 'adjective',
          semanticType: 'attribute',
          localeL1: 'zh',
          invariant: 'invariant',
          l1Confusables: const [],
          boundaries: const [],
          boundariesStatus: 'not_collected',
          programId: '$senseId-program',
          programVersion: 1,
        );
    final view = SessionBoundaryView(
      sceneEpisode: '午休后的办公室：文件散在桌上，椅子歪在过道里，'
          '抽屉半开着，但桌面没有灰尘和污渍。',
      options: [entry('dirty-01', 'dirty'), entry('messy-01', 'messy')],
      revealed: false,
      choiceSenseId: null,
      correctSenseId: 'messy-01',
      onChoose: (_) {},
    );
    await captureApp(
      tester,
      '12-language-boundary',
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        theme: theme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: view),
      ),
      '办公室',
    );
  }, skip: !kGenShots);

  testWidgets('13 language-recall: zh-CN scene, L2 after reveal',
      (tester) async {
    var revealed = false;
    final view = StatefulBuilder(
      builder: (context, setState) => SessionRecallView(
        episode: '厨房操作台上，面粉袋敞着口，调味瓶横七竖八地倒在台面上。',
        revealed: revealed,
        reveal: program.symbolBinding.reveal,
        minimalGloss: program.symbolBinding.minimalL1Gloss,
        onReveal: () => setState(() => revealed = true),
        onGrade: (_) {},
      ),
    );
    await captureApp(
      tester,
      '13-language-recall',
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh'),
        theme: theme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: view),
      ),
      'messy',
    );
  }, skip: !kGenShots);
}
