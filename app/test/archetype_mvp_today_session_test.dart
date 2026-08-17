/// Today Session tests for the Teaching Archetype MVP (spec §12.3):
/// home without L2 leakage, planner rules (reviews first, course
/// continuity, breakpoints, budget deferral, no review starvation,
/// due_after_days scheduling, modes), runner on_error routing, symbol
/// binding status, and day switching producing different plans.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenelex/features/archetype_mvp/archetype_mvp_home_page.dart';
import 'package:scenelex/features/archetype_mvp/archetype_mvp_models.dart';
import 'package:scenelex/features/archetype_mvp/archetype_mvp_session_page.dart';
import 'package:scenelex/features/archetype_mvp/learner_state.dart';
import 'package:scenelex/features/archetype_mvp/today_planner.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_models.dart';

// --------------------------------------------------------------------------- //
// fixture
// --------------------------------------------------------------------------- //

HolisticStep _step(
  String id,
  HolisticPrimitive primitive, {
  Map<String, dynamic> content = const {},
  Map<String, dynamic> evaluation = const {'kind': 'none'},
  HolisticTrigger trigger = HolisticTrigger.initial,
  String stage = 'learning_flow',
  int? estimatedSeconds,
  bool? canPauseAfter,
  int? dueAfterDays,
}) => HolisticStep(
  id: id,
  stage: stage,
  trigger: trigger,
  primitive: primitive,
  purpose: 'p-$id',
  addresses: const [],
  content: content,
  evaluation: evaluation,
  estimatedSeconds: estimatedSeconds,
  canPauseAfter: canPauseAfter,
  dueAfterDays: dueAfterDays,
);

HolisticCourse _course(
  String senseId,
  String lemma,
  List<HolisticStep> steps,
) => HolisticCourse(
  courseId: '$senseId-course',
  target: {
    'sense_id': senseId,
    'lemma': lemma,
    'pos': 'adjective',
    'ipa': '/x/',
    'learner_l1': 'zh-CN',
    'target_l2': 'en',
  },
  authorIntent: const {
    'course_thesis': 'x',
    'learner_start': 'x',
    'intended_outcome': '能够使用目标词。',
    'design_rationale': 'fixture',
  },
  steps: steps,
);

/// 一门最小课程：观察 → 绑定 → 判断（choice），带两条结构化复习。
HolisticCourse _messyCourse() => _course('messy-01', 'messy', [
  _step(
    's1',
    HolisticPrimitive.sceneObservation,
    content: {'episode': '书桌上东西散落。'},
    estimatedSeconds: 30,
  ),
  _step(
    's2',
    HolisticPrimitive.symbolReveal,
    content: {
      'l2_word': 'messy',
      'ipa': '/ˈmɛsi/',
      'presentation': '这种状态叫 messy。',
      'minimal_l1_gloss': '乱的',
    },
    estimatedSeconds: 25,
    canPauseAfter: true,
  ),
  _step(
    's3',
    HolisticPrimitive.singleChoice,
    content: {
      'episode': '房间很乱。',
      'question': '这是什么状态？',
      'options': [
        {'id': 'a', 'text': '乱', 'feedback': '对。'},
        {'id': 'b', 'text': '脏', 'feedback': '不对。'},
      ],
    },
    evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
    estimatedSeconds: 40,
  ),
  _step(
    'r1',
    HolisticPrimitive.recallReveal,
    stage: 'review_progression',
    trigger: HolisticTrigger.scheduledReview,
    dueAfterDays: 1,
    content: {
      'episode': '厨房台面乱糟糟。',
      'l2_word': 'messy',
      'ipa': '/ˈmɛsi/',
      'minimal_gloss': '乱的',
    },
    estimatedSeconds: 30,
  ),
  _step(
    'r2',
    HolisticPrimitive.recallSelfGrade,
    stage: 'review_progression',
    trigger: HolisticTrigger.scheduledReview,
    dueAfterDays: 3,
    content: {'l2_word': 'messy', 'ipa': '/ˈmɛsi/'},
    estimatedSeconds: 20,
  ),
]);

HolisticCourse _dirtyCourse() => _course('dirty-01', 'dirty', [
  _step(
    's1',
    HolisticPrimitive.sceneObservation,
    content: {'episode': '窗台有灰尘。'},
    estimatedSeconds: 30,
  ),
  _step(
    's2',
    HolisticPrimitive.symbolReveal,
    content: {
      'l2_word': 'dirty',
      'ipa': '/ˈdɜːrti/',
      'presentation': '这种状态叫 dirty。',
      'minimal_l1_gloss': '脏的',
    },
    estimatedSeconds: 25,
  ),
  _step(
    's3',
    HolisticPrimitive.singleChoice,
    content: {
      'question': '这是什么状态？',
      'options': [
        {'id': 'a', 'text': '脏', 'feedback': '对。'},
        {'id': 'b', 'text': '乱', 'feedback': '不对。'},
      ],
    },
    evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
    estimatedSeconds: 40,
  ),
]);

HolisticCourse _almostCourse() => _course('almost-01', 'almost', [
  _step(
    's1',
    HolisticPrimitive.sceneObservation,
    content: {'episode': '水快开了。'},
    estimatedSeconds: 30,
  ),
  _step(
    's2',
    HolisticPrimitive.symbolReveal,
    content: {
      'l2_word': 'almost',
      'ipa': '/ˈɔːlmoʊst/',
      'presentation': '这种状态叫 almost。',
      'minimal_l1_gloss': '几乎',
    },
    estimatedSeconds: 25,
  ),
  _step(
    's3',
    HolisticPrimitive.singleChoice,
    content: {
      'question': '这是什么状态？',
      'options': [
        {'id': 'a', 'text': '几乎', 'feedback': '对。'},
        {'id': 'b', 'text': '勉强', 'feedback': '不对。'},
      ],
    },
    evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
    estimatedSeconds: 40,
  ),
]);

MvpBundle _fixtureBundle() => MvpBundle(
  schemaVersion: '1.0',
  bundleVersion: 1,
  capabilityVersion: 1,
  curriculum: const [
    {'day': 1, 'course': 'messy-01'},
    {'day': 2, 'course': 'dirty-01'},
    {'day': 3, 'course': 'almost-01'},
  ],
  archetypes: const [
    MvpArchetype(
      id: 'visible_attribute',
      semanticTypes: ['attribute'],
      teachingArchetype: 'visible_attribute',
      experienceMechanism: 'm',
      suggestedCapabilities: ['scene_observation'],
      specialRisks: ['conflated_pair'],
      pairs: [
        MvpPair(
          pairId: 'messy_dirty',
          between: ['messy-01', 'dirty-01'],
          allowed: 'both',
          insufficientEvidenceAllowed: false,
          courses: ['messy-01', 'dirty-01'],
        ),
      ],
    ),
  ],
  pairRelations: const [
    MvpPair(
      pairId: 'messy_dirty',
      between: ['messy-01', 'dirty-01'],
      allowed: 'both',
      insufficientEvidenceAllowed: false,
      courses: ['messy-01', 'dirty-01'],
    ),
  ],
  courses: {
    'messy-01': _messyCourse(),
    'dirty-01': _dirtyCourse(),
    'almost-01': _almostCourse(),
  },
  inputDigests: const {},
);

LearnerState _state({int day = 1, int budget = 600}) =>
    LearnerState(bundle: _fixtureBundle(), budgetSeconds: budget)..setDay(day);

void main() {
  group('planner', () {
    test('day1: 一门新课程进入计划且顺序不被重排', () {
      final state = _state();
      final plan = state.plan();
      expect(plan.newCourseCount, 1);
      expect(plan.newCourseStarted, true);
      final plannedIds = [
        for (final item in plan.items.where(
          (item) =>
              item.courseId == 'messy-01' &&
              item.kind == PlanItemKind.newChapter,
        ))
          item.step.id,
      ];
      // 新课程章节在声明的自然断点（绑定后）结束；步骤严格按 Author 顺序
      expect(plannedIds, ['s1', 's2']);
      // 顺序不被重排：同课程的 stepIndex 严格递增
      final indices = [
        for (final item in plan.items)
          if (item.courseId == 'messy-01') item.stepIndex,
      ];
      expect(indices, [...indices]..sort(), reason: '课程步骤不得被重排');
    });

    test('到期复习按 due_after_days 出现', () {
      final state = _state(day: 1);
      // 第 1 天完成 messy 全部首学（绑定 day=1）
      final messy = state.bundle.courseFor('messy-01')!;
      for (final step in messy.steps) {
        if (step.stage != 'learning_flow') break;
        state.applyCompletion(
          courseId: 'messy-01',
          step: step,
          outcome: step.isChoice
              ? const StepOutcome(answered: true, correct: true)
              : null,
        );
        if (step.primitive == HolisticPrimitive.symbolReveal) {
          expect(state.progressFor('messy-01').bindingDay, 1);
        }
      }
      // 第 2 天：r1（due=1）到期，r2（due=3）未到期
      state.setDay(2);
      final plan2 = state.plan();
      expect(plan2.reviewCount, 1);
      expect(plan2.items.any((i) => i.step.id == 'r1'), true);
      expect(plan2.items.any((i) => i.step.id == 'r2'), false);
      // 第 4 天：r2（due=3, binding=1 → 第 4 天）到期
      state.setDay(4);
      final plan4 = state.plan();
      expect(plan4.items.any((i) => i.step.id == 'r2'), true);
    });

    test('未到自然断点不能切换课程（保持连续）', () {
      final state = _state(day: 1);
      // messy 进行到 s2（s1 完成，s1 未声明断点 → 必须继续）
      final messy = state.bundle.courseFor('messy-01')!;
      state.applyCompletion(
        courseId: 'messy-01',
        step: messy.steps[0],
        outcome: null,
      );
      state.setDay(1);
      final plan = state.plan();
      final messyItems = [
        for (final i in plan.items)
          if (i.courseId == 'messy-01') i.step.id,
      ];
      expect(messyItems.first, 's2'); // 必须继续 messy，而不是开 dirty
      // 不能切换到新课程：新课程在 continuation 之后才可能开始
      expect(plan.items.first.courseId, 'messy-01');
    });

    test('到自然断点可以退出恢复（可切换课程）', () {
      final state = _state(day: 1);
      final messy = state.bundle.courseFor('messy-01')!;
      // s1 → s2 完成；s2（binding）声明 canPauseAfter=true → 已到断点
      state.applyCompletion(
        courseId: 'messy-01',
        step: messy.steps[0],
        outcome: null,
      );
      state.applyCompletion(
        courseId: 'messy-01',
        step: messy.steps[1],
        outcome: null,
      );
      state.setDay(2);
      final plan = state.plan();
      // 断点后可暂停 messy；今日新课程 dirty 可以进入计划
      expect(plan.newCourseCount, 1);
      expect(plan.items.any((i) => i.courseId == 'dirty-01'), true);
    });

    test('超出时间预算时延后新课并诚实说明', () {
      // messy 带两条第 2 天到期的复习（30s + 40s），预算只有 50s：
      // 复习吃掉预算 → 新课程 dirty 延后，首页显示诚实原因。
      final messy = _messyCourse();
      final extra = _step(
        'r1b',
        HolisticPrimitive.recallReveal,
        stage: 'review_progression',
        trigger: HolisticTrigger.scheduledReview,
        dueAfterDays: 1,
        content: {
          'episode': '客厅也乱了。',
          'l2_word': 'messy',
          'ipa': '/ˈmɛsi/',
          'minimal_gloss': '乱的',
        },
        estimatedSeconds: 40,
      );
      final heavy = HolisticCourse(
        courseId: messy.courseId,
        target: messy.target,
        authorIntent: messy.authorIntent,
        steps: [...messy.steps, extra],
      );
      final bundle = MvpBundle(
        schemaVersion: '1.0',
        bundleVersion: 1,
        capabilityVersion: 1,
        curriculum: const [
          {'day': 1, 'course': 'messy-01'},
          {'day': 2, 'course': 'dirty-01'},
        ],
        archetypes: const [],
        pairRelations: const [],
        courses: {'messy-01': heavy, 'dirty-01': _dirtyCourse()},
        inputDigests: const {},
      );
      final state = LearnerState(bundle: bundle, budgetSeconds: 50)..setDay(2);
      state.seedProgress(
        const CourseProgress(
          senseId: 'messy-01',
          phase: CoursePhase.consolidating,
          nextStepIndex: 3,
          bindingDay: 1,
        ),
      );
      final plan = state.plan();
      expect(plan.items.any((i) => i.step.id == 'r1'), true);
      expect(plan.newCourseStarted, false); // 预算被到期复习占满
      expect(plan.deferred, isNotEmpty);
      expect(plan.deferred.join(), contains('延后'));
    });

    test('复习不会永久饿死新课程（预留新课程时间片）', () {
      // 5 条到期复习（30+60×4=270s）> 预算 300s 中可给复习的部分
      // （预留新课程 40% 时间片）→ 复习被裁剪，新课程仍进入计划
      final messy = _messyCourse();
      final extra = [
        for (var i = 0; i < 4; i++)
          _step(
            'x$i',
            HolisticPrimitive.recallReveal,
            stage: 'review_progression',
            trigger: HolisticTrigger.scheduledReview,
            dueAfterDays: 1,
            content: {
              'episode': '场景$i。',
              'l2_word': 'messy',
              'ipa': '/ˈmɛsi/',
              'minimal_gloss': '乱的',
            },
            estimatedSeconds: 60,
          ),
      ];
      final heavy = HolisticCourse(
        courseId: messy.courseId,
        target: messy.target,
        authorIntent: messy.authorIntent,
        steps: [...messy.steps, ...extra],
      );
      final bundle = MvpBundle(
        schemaVersion: '1.0',
        bundleVersion: 1,
        capabilityVersion: 1,
        curriculum: const [
          {'day': 1, 'course': 'messy-01'},
          {'day': 2, 'course': 'dirty-01'},
        ],
        archetypes: const [],
        pairRelations: const [],
        courses: {'messy-01': heavy, 'dirty-01': _dirtyCourse()},
        inputDigests: const {},
      );
      final state = LearnerState(bundle: bundle, budgetSeconds: 300)..setDay(2);
      state.seedProgress(
        const CourseProgress(
          senseId: 'messy-01',
          phase: CoursePhase.consolidating,
          nextStepIndex: 3,
          bindingDay: 1,
        ),
      );
      final plan = state.plan();
      expect(plan.deferred.any((r) => r.contains('预留新课程时间')), true);
      expect(plan.newCourseStarted, true); // 新课程没有被饿死
      expect(plan.reviewCount, lessThan(5)); // 复习被裁剪
    });

    test('三种 session mode 真正影响 planner', () {
      final state = _state(day: 2);
      state.seedProgress(
        const CourseProgress(
          senseId: 'messy-01',
          phase: CoursePhase.consolidating,
          nextStepIndex: 3,
          bindingDay: 1,
        ),
      );
      final normal = state.plan();
      expect(normal.reviewCount, greaterThan(0));
      expect(normal.newCourseCount, greaterThan(0));

      state.setMode(SessionMode.reviewOnly);
      final reviewOnly = state.plan();
      expect(reviewOnly.reviewCount, greaterThan(0));
      expect(reviewOnly.newCourseCount, 0);

      state.setMode(SessionMode.newOnly);
      final newOnly = state.plan();
      expect(newOnly.reviewCount, 0);
      expect(newOnly.newCourseCount, greaterThan(0));
    });

    test('14 天切换产生不同计划', () {
      final state = _state(day: 1);
      // 第 1 天完成 messy 首学（绑定 day=1）
      final messy = state.bundle.courseFor('messy-01')!;
      for (final step in messy.steps) {
        if (step.stage != 'learning_flow') break;
        state.applyCompletion(courseId: 'messy-01', step: step, outcome: null);
      }
      state.setDay(2);
      final planDay2 = state.plan(); // r1 + dirty 新课程
      state.setDay(5);
      final planDay5 = state.plan(); // r1+r2 都到期 + dirty 新课程
      expect(
        planDay2.items.map((i) => i.step.id).toSet(),
        isNot(planDay5.items.map((i) => i.step.id).toSet()),
      );
      expect(planDay5.items.any((i) => i.step.id == 'r2'), true);
    });
  });

  group('runner', () {
    testWidgets('错误触发 Author 的 on_error 步骤', (tester) async {
      final course = _course('messy-01', 'messy', [
        _step(
          's1',
          HolisticPrimitive.sceneObservation,
          content: {'episode': '书桌上东西散落。'},
        ),
        _step(
          's2',
          HolisticPrimitive.symbolReveal,
          content: {
            'l2_word': 'messy',
            'ipa': '/ˈmɛsi/',
            'presentation': 'x',
            'minimal_l1_gloss': '乱的',
          },
        ),
        _step(
          's3',
          HolisticPrimitive.singleChoice,
          content: {
            'question': '这是什么状态？',
            'options': [
              {'id': 'a', 'text': '乱', 'feedback': '对。'},
              {'id': 'b', 'text': '脏', 'feedback': '不对。'},
            ],
          },
          evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
        ),
        _step(
          'e1',
          HolisticPrimitive.evidenceHighlight,
          trigger: HolisticTrigger.onError,
          content: {
            'episode': '再看一遍：东西不在原位。',
            'evidence': ['位置错乱'],
          },
        ),
      ]);
      final bundle = MvpBundle(
        schemaVersion: '1.0',
        bundleVersion: 1,
        capabilityVersion: 1,
        curriculum: const [
          {'day': 1, 'course': 'messy-01'},
        ],
        archetypes: const [],
        pairRelations: const [],
        courses: {'messy-01': course},
        inputDigests: const {},
      );
      final state = LearnerState(bundle: bundle);
      final plan = state.plan();
      await tester.pumpWidget(
        MaterialApp(
          home: ArchetypeMvpSessionPage(state: state, plan: plan),
        ),
      );
      // s1 观察 → 继续
      await tester.tap(find.byKey(const ValueKey('session-proceed')));
      await tester.pump();
      // s2 绑定 → 继续
      await tester.tap(find.byKey(const ValueKey('session-proceed')));
      await tester.pump();
      // s3 判断 → 答错（选 b），继续
      await tester.tap(find.text('脏'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('session-proceed')));
      await tester.pump();
      // Author 的 on_error 步骤被插入并显示
      expect(find.textContaining('再看一遍'), findsOneWidget);
      // 补救步骤完成后回到主线
      await tester.tap(find.byKey(const ValueKey('session-proceed')));
      await tester.pump();
      expect(state.progressFor('messy-01').phase, CoursePhase.consolidating);
    });

    test('symbol binding 完成后更新课程状态', () {
      final state = _state();
      final messy = state.bundle.courseFor('messy-01')!;
      state.applyCompletion(
        courseId: 'messy-01',
        step: messy.steps[0],
        outcome: null,
      );
      expect(state.progressFor('messy-01').phase, CoursePhase.inCourse);
      state.applyCompletion(
        courseId: 'messy-01',
        step: messy.steps[1],
        outcome: null,
      );
      final p = state.progressFor('messy-01');
      expect(p.phase, CoursePhase.symbolBound);
      expect(p.bindingDay, 1);
      expect(p.bound, true);
    });

    test('没有 on_error 时错误不中断、课程进入 needs_remediation', () {
      final state = _state();
      final messy = state.bundle.courseFor('messy-01')!;
      for (final step in messy.steps.take(3)) {
        state.applyCompletion(
          courseId: 'messy-01',
          step: step,
          outcome: step.isChoice
              ? const StepOutcome(answered: true, correct: false)
              : null,
        );
      }
      final p = state.progressFor('messy-01');
      expect(p.errorCount, 1);
      expect(p.failedStepIds, contains('s3'));
      expect(p.phase, CoursePhase.needsRemediation);
    });
  });

  group('home', () {
    testWidgets('首页不泄露未绑定目标 lemma', (tester) async {
      final state = _state(day: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: ArchetypeMvpHomePage(state: state, onOpenDevOverview: () {}),
        ),
      );
      expect(find.text('继续今日学习'), findsOneWidget);
      // 未绑定课程的目标 L2 lemma 不得出现在首页
      expect(find.textContaining('messy'), findsNothing);
      expect(find.textContaining('dirty'), findsNothing);
      expect(find.textContaining('almost'), findsNothing);
      // 计数以"次回想/门新义项课"形式出现
      expect(find.textContaining('新义项课'), findsOneWidget);
    });

    testWidgets('只有绑定后的课程才在首页显示回想计数', (tester) async {
      final state = _state(day: 2);
      state.seedProgress(
        const CourseProgress(
          senseId: 'messy-01',
          phase: CoursePhase.consolidating,
          nextStepIndex: 3,
          bindingDay: 1,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ArchetypeMvpHomePage(state: state, onOpenDevOverview: () {}),
        ),
      );
      expect(find.textContaining('次回想'), findsOneWidget);
    });
  });
}
