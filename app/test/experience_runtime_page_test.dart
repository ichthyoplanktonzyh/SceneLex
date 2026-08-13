/// ExperienceRuntimePage widget tests: learner-facing content rules
/// (no L2 word before binding, no internal fields), full dynamic flow, and
/// overflow safety at 320×568 and 1440×900.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_page.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';

// 真实 asset 的 I/O 必须在真实 async zone 完成 (testWidgets 的 FakeAsync
// zone 无法完成 rootBundle 的异步 channel), 故在 setUpAll 一次性预读,
// 测试内通过内存 loader 注入。
String? _bundleText;

Future<ExperienceRuntimeViewModel> pumpRuntime(
  WidgetTester tester, {
  String senseId = 'reluctant-01',
  double width = 800,
  double height = 1000,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final vm = ExperienceRuntimeViewModel(
    BundledExperienceProgramRepository(bundleLoader: () async => _bundleText!),
    senseId,
  );
  await vm.load();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExperienceRuntimePage(viewModel: vm),
    ),
  );
  await tester.pump();
  return vm;
}

String allVisibleText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' ');
  final semantics = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .join(' ');
  return '$texts $semantics'.toLowerCase();
}

Future<void> answerCurrent(WidgetTester tester, String answerId) async {
  final finder = find.byKey(ValueKey('answer-$answerId'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapContinue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  testWidgets('concept phase renders no target word anywhere '
      '(all 5 units incl. transfer)', (tester) async {
    final vm = await pumpRuntime(tester);
    expect(vm.totalQuestions, 5);
    for (var i = 0; i < 5; i++) {
      expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
      final text = allVisibleText(tester);
      expect(
        text.contains('reluctant'),
        isFalse,
        reason: 'unit ${i + 1} 揭示前出现了目标词',
      );
      expect(text.contains('rɪˈlʌktənt'), isFalse);
      await answerCurrent(tester, 'a1');
      await tapContinue(tester);
    }
    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
  });

  testWidgets('symbol binding shows the L2 word and IPA for the first time', (
    tester,
  ) async {
    final vm = await pumpRuntime(tester);
    for (var i = 0; i < 5; i++) {
      await answerCurrent(tester, 'a1');
      await tapContinue(tester);
    }
    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
    final text = allVisibleText(tester);
    expect(text, contains('reluctant'));
    expect(text, contains('rɪˈlʌktənt'));
    await tapContinue(tester);
    expect(vm.phase, ExperienceRuntimePhase.grounding);
    expect(allVisibleText(tester), contains('reluctant'));
  });

  testWidgets('internal semantic and compiler fields never appear', (
    tester,
  ) async {
    await pumpRuntime(tester);
    final forbidden = [
      'misc-1',
      'misc-2',
      'semantic_correctness',
      'quality_gate',
      'reluctant-01-program',
      'source_semantic_revision',
      'compiler_version',
      'hypothesis_target',
      'preserved_variables',
      'changed_variables',
      'semantic_spec',
    ];
    for (var i = 0; i < 5; i++) {
      final text = allVisibleText(tester);
      for (final fragment in forbidden) {
        expect(
          text.contains(fragment),
          isFalse,
          reason: 'concept unit ${i + 1} 泄漏了内部字段 $fragment',
        );
      }
      await answerCurrent(tester, 'a1');
      await tapContinue(tester);
    }
    await tapContinue(tester); // → grounding
    final bindingAndGrounding = allVisibleText(tester);
    for (final fragment in forbidden) {
      expect(
        bindingAndGrounding.contains(fragment),
        isFalse,
        reason: 'binding/grounding 泄漏了内部字段 $fragment',
      );
    }
  });

  testWidgets('answering reveals feedback, correct answer and continue', (
    tester,
  ) async {
    await pumpRuntime(tester);
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(
      tester.widget<FilledButton>(continueButton).onPressed,
      isNull,
      reason: '未作答时 Continue 必须禁用',
    );
    await answerCurrent(tester, 'a2'); // wrong answer
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // 所选 (错误) 答案的反馈与正确答案文本同时可见
    expect(find.textContaining('A hungry, happy eater'), findsOneWidget);
    expect(find.textContaining('He did not want to eat them'), findsOneWidget);
  });

  testWidgets('complete page shows first-attempt statistics and replay', (
    tester,
  ) async {
    final vm = await pumpRuntime(tester);
    await answerCurrent(tester, 'a1'); // correct
    await tapContinue(tester);
    await answerCurrent(tester, 'a2'); // wrong
    await tapContinue(tester);
    await answerCurrent(tester, 'a1');
    await tapContinue(tester);
    await answerCurrent(tester, 'a1');
    await tapContinue(tester);
    await answerCurrent(tester, 'a1');
    await tapContinue(tester);
    await tapContinue(tester);
    await tapContinue(tester);
    expect(vm.phase, ExperienceRuntimePhase.complete);
    expect(vm.firstAttemptCorrect, 4);
    expect(vm.totalQuestions, 5);
    final text = allVisibleText(tester);
    expect(text, contains('4 of 5 correct on the first try'));
    expect(find.text('Re-experience'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 and 1440x900', (tester) async {
    for (final size in [(320.0, 568.0), (1440.0, 900.0)]) {
      await pumpRuntime(tester, width: size.$1, height: size.$2);
      for (var i = 0; i < 5; i++) {
        await answerCurrent(tester, 'a1');
        await tapContinue(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: '${size.$1}x${size.$2} 在 unit ${i + 1} 溢出',
        );
      }
      await tapContinue(tester);
      await tapContinue(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.$1}x${size.$2} 在 grounding 溢出',
      );
    }
  });

  testWidgets('missing sense shows a clear error page', (tester) async {
    final vm = await pumpRuntime(tester, senseId: 'does-not-exist-01');
    expect(vm.phase, ExperienceRuntimePhase.loadError);
    expect(find.text('Could not load this experience'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
