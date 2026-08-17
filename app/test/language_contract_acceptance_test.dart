/// Learning Presentation Language Contract v1 acceptance tests.
///
/// Verifies the five acceptance screens end to end with zh-CN content:
/// 1. zh-CN Discover (pre-binding): no target L2, Chinese scenes.
/// 2. Symbol Binding: the L2 word and IPA appear for the first time.
/// 3. Grounding: natural L2 realization after binding.
/// 4. zh-CN Boundary with L2 options (dirty / messy).
/// 5. zh-CN Early Recall: no L2 before reveal, L2 after reveal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_models.dart';
import 'package:scenelex/features/daily_session_prototype/views/session_boundary_view.dart';
import 'package:scenelex/features/daily_session_prototype/views/session_recall_view.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_page.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';

import 'fixtures/zh_contract_program.dart';

class _MemoryRepository implements ExperienceProgramRepository {
  _MemoryRepository(this._program);
  final ExperienceProgram _program;

  @override
  Future<ExperienceProgram> load(String senseId) async => _program;
}

String _allVisibleText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' ');
  final semantics = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .join(' ');
  return '$texts $semantics';
}

Future<ExperienceRuntimeViewModel> _pumpRuntime(
  WidgetTester tester, {
  required ExperienceProgram program,
}) async {
  final vm = ExperienceRuntimeViewModel(_MemoryRepository(program), program.programId);
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

Future<void> _answerAndContinue(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('answer-a1'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Continue'));
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('1. zh-CN Discover (pre-binding) shows no target L2 and '
      'no English passage', (tester) async {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    final vm = await _pumpRuntime(tester, program: program);
    expect(vm.phase, ExperienceRuntimePhase.conceptUnit);

    final text = _allVisibleText(tester).toLowerCase();
    expect(text, isNot(contains('messy')),
        reason: '绑定前出现了目标 L2 词');
    expect(text, isNot(contains('desk looks')), reason: '绑定前出现成段英语');
    expect(text, isNot(contains('the')), reason: '绑定前出现英文段落');
    // 中文经验叙事可见。
    expect(text, contains('书桌'));
    expect(text, contains('笔记本斜躺在键盘上'));
  });

  testWidgets('1b. zh-CN Discover question/answers/feedback are Chinese',
      (tester) async {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    await _pumpRuntime(tester, program: program);
    final text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('这张书桌的状态和平时一样吗'));
    expect(text, contains('不一样'));
    final finder = find.byKey(const ValueKey('answer-a1'));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 300));
    final feedback = _allVisibleText(tester).toLowerCase();
    expect(feedback, contains('物品大多不在原位'));
  });

  testWidgets('2. Symbol Binding shows the L2 word and IPA for the first time',
      (tester) async {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    final vm = await _pumpRuntime(tester, program: program);
    for (var i = 0; i < program.units.length; i++) {
      await _answerAndContinue(tester);
    }
    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
    final text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('messy'));
    expect(text, contains('/ˈmesi/'));
    expect(text, contains('凌乱'), reason: '极短 L1 确认可见');
  });

  testWidgets('3. Grounding shows natural L2 realization after binding',
      (tester) async {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    final vm = await _pumpRuntime(tester, program: program);
    for (var i = 0; i < program.units.length; i++) {
      await _answerAndContinue(tester);
    }
    expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.phase, ExperienceRuntimePhase.grounding);
    final text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('the desk looks messy after dinner'));
  });

  testWidgets('4. Boundary: Chinese scene, L2 options, Chinese feedback',
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
    final scene = '午休后的办公室：文件散在桌上，椅子歪在过道里，'
        '抽屉半开着，但桌面没有灰尘和污渍。';
    final view = SessionBoundaryView(
      sceneEpisode: scene,
      options: [entry('dirty-01', 'dirty'), entry('messy-01', 'messy')],
      revealed: true,
      choiceSenseId: 'messy-01',
      correctSenseId: 'messy-01',
      onChoose: (_) {},
    );
    await tester.pumpWidget(_wrap(view));
    final text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('办公室'), reason: '中文场景');
    expect(text, contains('dirty'), reason: '选项可显示已绑定 L2 lemma');
    expect(text, contains('messy'));
    expect(text, isNot(contains('the office is')), reason: '不得整段英语解释');
  });

  testWidgets('5. Early Recall: no L2 before reveal, L2 after reveal',
      (tester) async {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    final reviewEpisode = (program.reviewPool.first.experience?['episode'] as String? ??
        '');
    bool revealed = false;
    String? minimalGloss;
    var grades = <DailySessionRecallGrade>[];
    final view = StatefulBuilder(
      builder: (context, setState) => SessionRecallView(
        episode: reviewEpisode,
        revealed: revealed,
        reveal: program.symbolBinding.reveal,
        minimalGloss: minimalGloss,
        onReveal: () => setState(() => revealed = true),
        onGrade: (grade) => setState(() => grades.add(grade)),
      ),
    );
    await tester.pumpWidget(_wrap(view));

    var text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('厨房操作台'), reason: '中文复习场景');
    expect(text, isNot(contains('messy')), reason: 'reveal 前不得出现目标 L2');

    await tester.tap(find.text('Reveal'));
    await tester.pump(const Duration(milliseconds: 320));
    text = _allVisibleText(tester).toLowerCase();
    expect(text, contains('messy'), reason: 'reveal 后出现目标 L2');
    expect(text, contains('/ˈmesi/'));
  });

  test('ExperienceProgram parses language_policy and rejects mismatch', () {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    expect(program.languagePolicy.policyVersion, 1);
    expect(program.languagePolicy.learnerL1, 'zh-CN');
    expect(program.languagePolicy.targetL2, 'en');
    expect(program.target.localeL1, 'zh');

    final mismatched = zhContractProgramJson();
    (mismatched['target'] as Map<String, Object?>)['locale_l1'] = 'en';
    expect(
      () => ExperienceProgram.fromJson(Map<String, dynamic>.from(mismatched)),
      throwsA(isA<ExperienceProgramFormatException>()),
    );

    final legacy = Map<String, Object?>.from(zhContractProgramJson())
      ..remove('language_policy');
    expect(
      () => ExperienceProgram.fromJson(Map<String, dynamic>.from(legacy)),
      throwsA(isA<ExperienceProgramFormatException>()),
      reason: 'legacy v0 无 language_policy, App 不得渲染 (显式兼容策略)',
    );
  });

  test('ReviewItem exposes scaffold_level', () {
    final program = ExperienceProgram.fromJson(
      Map<String, dynamic>.from(zhContractProgramJson()),
    );
    expect(program.reviewPool.single.scaffoldLevel, 'early_post_binding');
  });
}
