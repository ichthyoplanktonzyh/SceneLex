/// Temporary manual-verification smoke: full Experience Runtime flow on a
/// real surface with the bundled content. VM drives the state machine; the
/// UI is asserted on every frame (real rendering, real localization).
/// Not part of the committed test suite; kept only for this round's smoke.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_page.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';

String allVisibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' ')
    .toLowerCase();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reluctant-01 full flow on real surface', (tester) async {
    // physicalSize 是物理像素; 逻辑尺寸 = physicalSize / dpr → 430x932
    tester.view.physicalSize = const Size(430 * 3, 932 * 3);
    tester.view.devicePixelRatio = 3.0;
    final vm = ExperienceRuntimeViewModel(
      BundledExperienceProgramRepository(),
      'reluctant-01',
    );
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExperienceRuntimePage(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    expect(vm.totalQuestions, 5);
    for (var i = 0; i < 5; i++) {
      expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
      final text = allVisibleText(tester);
      expect(
        text.contains('reluctant'),
        isFalse,
        reason: 'unit ${i + 1} 揭示前出现目标词',
      );
      vm.answer('a1');
      await tester.pumpAndSettle();
      expect(
        allVisibleText(tester),
        contains('正确'),
        reason: 'unit ${i + 1} 反馈缺失',
      );
      vm.proceed();
      await tester.pumpAndSettle();
    }

    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
    expect(allVisibleText(tester), contains('reluctant'));
    expect(allVisibleText(tester), contains('rɪˈlʌktənt'));
    vm.proceed();
    await tester.pumpAndSettle();

    expect(vm.phase, ExperienceRuntimePhase.grounding);
    expect(allVisibleText(tester), contains('reluctant'));
    expect(
      allVisibleText(tester),
      contains('leo was reluctant to eat his greens'),
    );
    vm.proceed();
    await tester.pumpAndSettle();

    expect(vm.phase, ExperienceRuntimePhase.complete);
    expect(allVisibleText(tester), contains('首次作答正确 5/5'));

    vm.restart();
    await tester.pumpAndSettle();
    expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
    expect(vm.unitIndex, 0);
  });
}
