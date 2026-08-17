/// Holistic Course preview — widget tests for the strict-order executor.
///
/// The preview must execute the Course Author's learning_flow (then
/// review_progression) exactly as authored: no re-planning, no added tasks,
/// no author notes shown to the learner, no L2 before symbol binding, and
/// dev time-jump may only filter by the Author's declared triggers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_models.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_preview_page.dart';

Map<String, dynamic> _step({
  required String id,
  required String primitive,
  String trigger = 'initial',
  String stage = 'learning_flow',
  required Map<String, dynamic> content,
  Map<String, dynamic> evaluation = const {'kind': 'none'},
  String purpose = '内部意图',
  List<String> addresses = const [],
}) => {
  'id': id,
  'stage': stage,
  'trigger': trigger,
  'primitive': primitive,
  'purpose': purpose,
  'addresses': addresses,
  'timing': null,
  'scaffold_level': null,
  'content': content,
  'evaluation': evaluation,
};

/// scene → binding → grounding → review reveal (no choice steps).
Map<String, dynamic> _linearCourse({int extraScenes = 0}) => {
  'schema_version': '1.0',
  'course_id': 'holistic-test',
  'target': {
    'sense_id': 'messy-01',
    'lemma': 'messy',
    'pos': 'adjective',
    'ipa': '/ˈmɛsi/',
    'learner_l1': 'zh-CN',
    'target_l2': 'en',
  },
  'author_intent': {
    'course_thesis': '内部主线',
    'learner_start': '零基础',
    'intended_outcome': '会用',
    'design_rationale': '内部理由',
  },
  'steps': [
    for (var i = 0; i < extraScenes; i++)
      _step(
        id: 'e$i',
        primitive: 'scene_observation',
        content: {'episode': '场景 ${i + 1}：东西不在原位。'},
      ),
    _step(
      id: 's1',
      primitive: 'scene_observation',
      content: {'episode': '书桌上东西散落，书本叠放方向不一。'},
    ),
    _step(
      id: 's2',
      primitive: 'symbol_reveal',
      content: {
        'l2_word': 'messy',
        'ipa': '/ˈmɛsi/',
        'presentation': '刚才看到的这种状态，就叫这个名字。',
        'minimal_l1_gloss': '乱的',
      },
    ),
    _step(
      id: 's3',
      primitive: 'l2_grounding',
      content: {
        'l2_realization': 'The desk was messy.',
        'constructions': ['[place] is messy'],
        'collocations': ['messy room'],
      },
    ),
    _step(
      id: 'r1',
      stage: 'review_progression',
      trigger: 'scheduled_review',
      primitive: 'recall_reveal',
      content: {
        'episode': '厨房台面上三样东西都不在原位。',
        'l2_word': 'messy',
        'ipa': '/ˈmɛsi/',
      },
    ),
  ],
};

Future<void> _pumpPage(
  WidgetTester tester,
  HolisticCourse course, {
  bool devMode = true,
  int initialStepIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HolisticCoursePreviewPage(
        course: course,
        devMode: devMode,
        initialStepIndex: initialStepIndex,
      ),
    ),
  );
  await tester.pump();
}

Finder _proceed() => find.byKey(const ValueKey('proceed'));

/// Walks the whole course by tapping the footer button until the completion
/// page appears. On recall-reveal steps the button first reveals the answer,
/// then advances — each tap always makes progress.
Future<void> _walkToCompletion(WidgetTester tester) async {
  for (var guard = 0; guard < 40; guard++) {
    if (find.text('课程完成').evaluate().isNotEmpty) return;
    await tester.tap(_proceed());
    await tester.pump();
  }
  fail('未到达完成页');
}

void main() {
  testWidgets('preview follows learning_flow strictly in Author order', (
    tester,
  ) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    await _pumpPage(tester, course);

    // Step 1 visible; later steps not yet.
    expect(find.text('书桌上东西散落，书本叠放方向不一。'), findsOneWidget);
    expect(find.text('刚才看到的这种状态，就叫这个名字。'), findsNothing);

    await tester.tap(_proceed());
    await tester.pump();
    // Step 2 (symbol binding); step 1 no longer rendered.
    expect(find.text('刚才看到的这种状态，就叫这个名字。'), findsOneWidget);
    expect(find.text('书桌上东西散落，书本叠放方向不一。'), findsNothing);

    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('The desk was messy.'), findsOneWidget);

    await tester.tap(_proceed());
    await tester.pump();
    // Review step (scheduled_review) comes after the flow, in Author order.
    expect(find.text('厨房台面上三样东西都不在原位。'), findsOneWidget);
    // Reveal the recalled word, then finish.
    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('messy'), findsOneWidget);
    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('课程完成'), findsOneWidget);
  });

  testWidgets('runs fine without Boundary', (tester) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    expect(
      course.steps.where(
        (s) => s.primitive == HolisticPrimitive.boundaryChoice,
      ),
      isEmpty,
    );
    await _pumpPage(tester, course);
    await _walkToCompletion(tester);
    expect(find.text('课程完成'), findsOneWidget);
  });

  testWidgets('runs fine without Transfer', (tester) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    expect(
      course.steps.where(
        (s) => s.primitive == HolisticPrimitive.transferJudgment,
      ),
      isEmpty,
    );
    await _pumpPage(tester, course);
    await _walkToCompletion(tester);
    expect(find.text('课程完成'), findsOneWidget);
  });

  testWidgets('runs with different step counts (2 and 7)', (tester) async {
    final two = HolisticCourse.fromJson({
      ..._linearCourse(),
      'steps': [
        _step(
          id: 's1',
          primitive: 'symbol_reveal',
          content: {
            'l2_word': 'messy',
            'ipa': '/ˈmɛsi/',
            'presentation': '绑定。',
          },
        ),
        _step(
          id: 's2',
          primitive: 'l2_grounding',
          content: {'l2_realization': 'The desk was messy.'},
        ),
      ],
    });
    await _pumpPage(tester, two);
    await tester.tap(_proceed());
    await tester.pump();
    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('课程完成'), findsOneWidget);

    final seven = HolisticCourse.fromJson(_linearCourse(extraScenes: 3));
    expect(seven.steps.length, 7);
    await _pumpPage(tester, seven);
    await _walkToCompletion(tester);
    expect(find.text('课程完成'), findsOneWidget);
  });

  testWidgets('no target L2 shown before symbol binding', (tester) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    await _pumpPage(tester, course, devMode: false);

    expect(find.text('书桌上东西散落，书本叠放方向不一。'), findsOneWidget);
    expect(find.textContaining('messy'), findsNothing);

    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('messy'), findsOneWidget); // binding reveals it
  });

  testWidgets('internal author notes are never shown to the learner', (
    tester,
  ) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    await _pumpPage(tester, course, devMode: false);

    expect(find.text('内部意图'), findsNothing); // purpose
    expect(find.text('内部主线'), findsNothing); // course_thesis
    expect(find.text('内部理由'), findsNothing); // design_rationale
    expect(find.byKey(const ValueKey('dev-overview')), findsNothing);
  });

  testWidgets('dev overview shows author intent and full flow', (tester) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    await _pumpPage(tester, course, devMode: true);

    await tester.tap(find.byKey(const ValueKey('dev-overview')));
    await tester.pumpAndSettle();
    expect(find.text('课程总览（仅开发者可见）'), findsOneWidget);
    expect(find.text('内部主线'), findsOneWidget);
    expect(find.text('内部理由'), findsOneWidget);
    expect(find.textContaining('purpose: 内部意图'), findsWidgets);
  });

  testWidgets('dev time-jump filters by Author trigger only', (tester) async {
    final course = HolisticCourse.fromJson(_linearCourse());
    await _pumpPage(tester, course, devMode: true);

    await tester.tap(find.byKey(const ValueKey('dev-overview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jump-scheduledReview')));
    await tester.pumpAndSettle();

    // Landed on the Author's scheduled review step; order still intact.
    expect(find.text('厨房台面上三样东西都不在原位。'), findsOneWidget);
    expect(find.text('课程完成'), findsNothing);
  });

  testWidgets('choice steps gate progress until answered', (tester) async {
    final course = HolisticCourse.fromJson({
      ..._linearCourse(),
      'steps': [
        _step(
          id: 'c1',
          primitive: 'binary_judgment',
          content: {
            'episode': '只有一支笔不在原位。',
            'question': '这算整体可见的乱吗？',
            'options': [
              {'id': 'a1', 'text': '算', 'is_correct': true, 'feedback': '对'},
              {'id': 'a2', 'text': '不算', 'is_correct': false, 'feedback': '错'},
            ],
          },
          evaluation: {'kind': 'choice', 'correct_option_id': 'a1'},
        ),
        _step(
          id: 'c2',
          primitive: 'symbol_reveal',
          content: {
            'l2_word': 'messy',
            'ipa': '/ˈmɛsi/',
            'presentation': '绑定。',
          },
        ),
      ],
    });
    await _pumpPage(tester, course);

    // Not answered yet → proceed disabled (no navigation).
    await tester.tap(_proceed(), warnIfMissed: false);
    await tester.pump();
    expect(find.text('只有一支笔不在原位。'), findsOneWidget);

    await tester.tap(find.text('算'));
    await tester.pump();
    expect(find.text('对'), findsOneWidget); // feedback shown

    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('绑定。'), findsOneWidget);
  });

  testWidgets('boundary step renders two sense options and explanation', (
    tester,
  ) async {
    final course = HolisticCourse.fromJson({
      ..._linearCourse(),
      'steps': [
        _step(
          id: 'b1',
          primitive: 'symbol_reveal',
          content: {
            'l2_word': 'messy',
            'ipa': '/ˈmɛsi/',
            'presentation': '绑定。',
          },
        ),
        _step(
          id: 'b2',
          primitive: 'boundary_choice',
          content: {
            'episode': '东西乱放但每件都干净。',
            'options': [
              {'sense_id': 'messy-01', 'lemma': 'messy'},
              {'sense_id': 'dirty-01', 'lemma': 'dirty'},
            ],
            'correct_sense_id': 'messy-01',
            'explanation': [
              {'sense_id': 'messy-01', 'note': '判断的是位置秩序。'},
              {'sense_id': 'dirty-01', 'note': '判断的是表面污物。'},
            ],
          },
          evaluation: {'kind': 'sense_choice', 'correct_sense_id': 'messy-01'},
        ),
      ],
    });
    await _pumpPage(tester, course);
    await tester.tap(_proceed());
    await tester.pump();

    expect(find.text('messy'), findsOneWidget);
    expect(find.text('dirty'), findsOneWidget);
    expect(find.text('判断的是位置秩序。'), findsNothing); // explanation after answer

    await tester.tap(find.text('messy'));
    await tester.pump();
    expect(find.text('判断的是位置秩序。'), findsOneWidget);
    expect(find.text('判断的是表面污物。'), findsOneWidget);
  });

  testWidgets('self-grade step requires a grade before proceeding', (
    tester,
  ) async {
    final course = HolisticCourse.fromJson({
      ..._linearCourse(),
      'steps': [
        _step(
          id: 'g1',
          primitive: 'symbol_reveal',
          content: {
            'l2_word': 'messy',
            'ipa': '/ˈmɛsi/',
            'presentation': '绑定。',
          },
        ),
        _step(
          id: 'g2',
          primitive: 'recall_self_grade',
          content: {'l2_word': 'messy', 'ipa': '/ˈmɛsi/'},
          evaluation: {'kind': 'self_grade'},
        ),
      ],
    });
    await _pumpPage(tester, course);
    await tester.tap(_proceed());
    await tester.pump();

    await tester.tap(_proceed(), warnIfMissed: false);
    await tester.pump();
    expect(find.text('课程完成'), findsNothing);

    await tester.tap(find.text('记住了'));
    await tester.pump();
    await tester.tap(_proceed());
    await tester.pump();
    expect(find.text('课程完成'), findsOneWidget);
  });
}
