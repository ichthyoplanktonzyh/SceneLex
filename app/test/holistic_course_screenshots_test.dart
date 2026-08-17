/// Golden-based screenshot generator for the Holistic Course preview.
///
/// Loads the real generated holistic course asset
/// (`assets/content/holistic-course-preview/messy-01.json`) and renders the
/// documented page states at phone size (390×844 @2x, output 780×1688) with
/// real fonts, producing the PNGs under docs/prototypes/holistic-course/.
///
/// Shot targets are derived from the Course Author's actual course:
/// first learner-visible step, symbol binding, first post-binding step,
/// first scheduled review (dev time-jump), completion, and — only if the
/// Author designed one — the boundary step. Nothing is added to the course.
///
/// Generation is opt-in (skipped in the regular suite):
///
///   flutter test test/holistic_course_screenshots_test.dart \
///     --update-goldens --dart-define=SCENELEX_GEN_SHOTS=true
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_models.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_preview_page.dart';
import 'package:scenelex/ui/theme/scenelex_tokens.dart';

const bool kGenShots = bool.fromEnvironment('SCENELEX_GEN_SHOTS');
const String kShotDir =
    '/Users/shadow/SceneLex/docs/prototypes/holistic-course';
const String kAsset = 'assets/content/holistic-course-preview/messy-01.json';

Future<HolisticCourse> loadCourse() async {
  final raw = await rootBundle.loadString(kAsset);
  return HolisticCourse.fromJson(
    (jsonDecode(raw) as Map).cast<String, dynamic>(),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  HolisticCourse course, {
  int initialStepIndex = 0,
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = buildSceneLexTheme().copyWith(
    textTheme: buildSceneLexTheme().textTheme.apply(fontFamily: 'UniFont'),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      theme: theme,
      home: HolisticCoursePreviewPage(
        course: course,
        initialStepIndex: initialStepIndex,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$kShotDir/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Directory(kShotDir).createSync(recursive: true);
    final data = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('UniFont')
      ..addFont(Future.value(ByteData.sublistView(data)));
    await loader.load();
  });

  testWidgets('01 course overview (dev only)', (tester) async {
    final course = await loadCourse();
    await _pumpPage(tester, course);
    await tester.tap(find.byKey(const ValueKey('dev-overview')));
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(tester, '01-course-overview');
  }, skip: !kGenShots);

  testWidgets('02 first learner-visible step', (tester) async {
    final course = await loadCourse();
    await _pumpPage(tester, course, initialStepIndex: 0);
    await _capture(tester, '02-first-step');
  }, skip: !kGenShots);

  testWidgets('03 symbol binding', (tester) async {
    final course = await loadCourse();
    await _pumpPage(
      tester,
      course,
      initialStepIndex: course.symbolBindingIndex,
    );
    await _capture(tester, '03-symbol-binding');
  }, skip: !kGenShots);

  testWidgets('04 post-binding step', (tester) async {
    final course = await loadCourse();
    final index = course.symbolBindingIndex + 1;
    await _pumpPage(tester, course, initialStepIndex: index);
    await _capture(tester, '04-post-binding');
  }, skip: !kGenShots);

  testWidgets('05 scheduled review (dev time-jump)', (tester) async {
    final course = await loadCourse();
    final reviewIndex = course.steps.indexWhere(
      (s) => s.trigger == HolisticTrigger.scheduledReview,
    );
    expect(reviewIndex, greaterThanOrEqualTo(0));
    await _pumpPage(tester, course, initialStepIndex: reviewIndex);
    await _capture(tester, '05-scheduled-review');
  }, skip: !kGenShots);

  testWidgets('06 completion', (tester) async {
    final course = await loadCourse();
    // 直接定位到完成态（index 越界即完成页），避免逐题走查的脆弱性
    await _pumpPage(tester, course, initialStepIndex: course.steps.length);
    await _capture(tester, '06-completion');
  }, skip: !kGenShots);

  testWidgets('07 boundary (only if Author designed one)', (tester) async {
    final course = await loadCourse();
    final boundaryIndex = course.steps.indexWhere(
      (s) => s.primitive == HolisticPrimitive.boundaryChoice,
    );
    if (boundaryIndex < 0) {
      return; // Author 没有设计 Boundary —— 不得为截图补一个
    }
    await _pumpPage(tester, course, initialStepIndex: boundaryIndex);
    await _capture(tester, '07-boundary');
  }, skip: !kGenShots);
}
