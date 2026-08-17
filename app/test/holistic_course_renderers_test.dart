/// Widget tests for the six Teaching Archetype MVP renderers.
///
/// Each renderer is tested for: initial display, user interaction,
/// correct/wrong feedback, completion result, narrow-screen layout and
/// enlarged text (both via MediaQuery overrides).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenelex/features/holistic_course_prototype/holistic_course_models.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_renderer.dart';

HolisticStep _step(
  HolisticPrimitive primitive,
  Map<String, dynamic> content, {
  Map<String, dynamic> evaluation = const {'kind': 'none'},
  String id = 't1',
}) => HolisticStep(
  id: id,
  stage: 'learning_flow',
  trigger: HolisticTrigger.initial,
  primitive: primitive,
  purpose: 'test',
  addresses: const [],
  content: content,
  evaluation: evaluation,
);

StepActions _actions({
  ValueChanged<String>? onChoose,
  VoidCallback? onReveal,
  ValueChanged<String>? onGrade,
}) => StepActions(
  onChoose: onChoose ?? (_) {},
  onReveal: onReveal ?? () {},
  onGrade: onGrade ?? (_) {},
);

Future<void> _pump(
  WidgetTester tester,
  Widget widget, {
  double width = 390,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(home: Scaffold(body: widget)),
    ),
  );
}

/// 窄屏 + 放大文字冒烟：渲染不应抛布局异常。
Future<void> _narrowAndScaled(
  WidgetTester tester,
  Widget Function() build,
) async {
  await _pump(tester, build(), width: 320, textScale: 1.0);
  await _pump(tester, build(), width: 320, textScale: 2.0);
  await _pump(tester, build(), width: 390, textScale: 1.0);
}

void main() {
  group('multi_label_choice', () {
    final content = {
      'episode': '桌上有一个带柄的厚壁大杯。',
      'question': '这个物体可能属于哪些类别？',
      'options': [
        {'id': 'a', 'text': '杯子', 'feedback': '杯子是宽泛的饮具类别。'},
        {'id': 'b', 'text': '马克杯', 'feedback': '厚壁大杯更常叫马克杯。'},
        {'id': 'c', 'text': '勺子', 'feedback': '勺子不是容器。'},
      ],
    };
    final step = _step(
      HolisticPrimitive.multiLabelChoice,
      content,
      evaluation: {
        'kind': 'multi_choice',
        'correct_option_ids': ['a', 'b'],
      },
    );

    testWidgets('初始显示多选并禁用空提交', (tester) async {
      String? submitted;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => submitted = v),
        ),
      );
      expect(find.text('桌上有一个带柄的厚壁大杯。'), findsOneWidget);
      expect(find.byKey(const ValueKey('multi-option-a')), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('multi-submit')),
      );
      expect(submit.onPressed, isNull); // 空选择不可提交
      expect(submitted, isNull);
    });

    testWidgets('选择两个选项后提交得到编码答案与反馈', (tester) async {
      String? submitted;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => submitted = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('multi-option-a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('multi-option-b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('multi-submit')));
      await tester.pump();
      expect(submitted, 'a,b');
    });

    testWidgets('提交后锁定并显示正确/错误反馈', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(choiceId: 'a,c'), _actions()),
      );
      expect(find.text('未完全正确——正确集合是：杯子、马克杯。'), findsOneWidget);
      expect(find.text('杯子是宽泛的饮具类别。'), findsOneWidget);
      // 提交后不能再点选项
      await tester.tap(find.byKey(const ValueKey('multi-option-a')));
      await tester.pump();
      expect(find.text('未完全正确——正确集合是：杯子、马克杯。'), findsOneWidget);
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(
          step,
          const StepViewState(choiceId: 'a,b'),
          _actions(),
        ),
      );
    });
  });

  group('object_inspection', () {
    final step = _step(HolisticPrimitive.objectInspection, {
      'inspect_prompt': '观察这两个容器。',
      'hide_object_names': true,
      'objects': [
        {
          'id': 'o1',
          'name': 'cup 杯子',
          'features': ['开口较小', '常有手柄'],
          'variants': [
            {
              'id': 'o1v1',
              'label': '陶瓷款',
              'features': ['薄壁'],
            },
            {
              'id': 'o1v2',
              'label': '塑料款',
              'features': ['轻'],
            },
          ],
        },
        {
          'id': 'o2',
          'name': 'mug 马克杯',
          'features': ['厚壁', '大容量'],
        },
      ],
    });

    testWidgets('初始显示对象（名称隐藏）与特征', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      expect(find.text('观察这两个容器。'), findsOneWidget);
      expect(find.text('对象 1'), findsWidgets); // 名称隐藏（卡片+切换 chip）
      expect(find.text('开口较小'), findsOneWidget);
      expect(find.text('常有手柄'), findsOneWidget);
      expect(find.textContaining('cup 杯子'), findsNothing); // 不泄漏名称
    });

    testWidgets('切换对象与变体、点击特征高亮', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      await tester.tap(find.byKey(const ValueKey('object-chip-1')));
      await tester.pump();
      expect(find.text('厚壁'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('object-chip-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('variant-chip-0')));
      await tester.pump();
      expect(find.text('薄壁'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feature-0')));
      await tester.pump();
      // 高亮后仍渲染（点击可切换）
      expect(find.byKey(const ValueKey('feature-0')), findsOneWidget);
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(step, const StepViewState(), _actions()),
      );
    });
  });

  group('spatial_stage', () {
    final step = _step(
      HolisticPrimitive.spatialStage,
      {
        'stage_title': '穿过房间',
        'stage_width': 100,
        'stage_height': 60,
        'start': {'x': 10, 'y': 30},
        'end': {'x': 90, 'y': 30},
        'regions': [
          {'id': 'r1', 'label': '隧道', 'shape': 'rect'},
        ],
        'paths': [
          {
            'id': 'p1',
            'label': '从桥面横跨',
            'points': [
              [10, 30],
              [90, 30],
            ],
          },
          {
            'id': 'p2',
            'label': '穿过隧道',
            'points': [
              [10, 30],
              [50, 30],
              [90, 30],
            ],
          },
        ],
        'correct_path_id': 'p2',
        'feedback': '穿过内部空间才是 through。',
      },
      evaluation: {'kind': 'path_choice', 'correct_path_id': 'p2'},
    );

    testWidgets('初始显示舞台与候选路径', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      expect(find.text('穿过房间'), findsOneWidget);
      expect(find.text('从桥面横跨'), findsOneWidget);
      expect(find.text('穿过隧道'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets); // 起点/终点为画布绘制
    });

    testWidgets('选择路径触发回答并播放动画', (tester) async {
      String? chosen;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => chosen = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('path-p2')));
      await tester.pump();
      expect(chosen, 'p2');
      await tester.pump(const Duration(milliseconds: 400)); // 动画进行中
      await tester.pump(const Duration(milliseconds: 900)); // 动画结束
      expect(tester.takeException(), isNull);
    });

    testWidgets('作答后显示 Author 反馈', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(choiceId: 'p2'), _actions()),
      );
      expect(find.text('穿过内部空间才是 through。'), findsOneWidget);
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(step, const StepViewState(), _actions()),
      );
    });
  });

  group('participant_map', () {
    final step = _step(
      HolisticPrimitive.participantMap,
      {
        'episode': '小美把书借给了小明。',
        'participants': [
          {'id': 'mei', 'label': '小美', 'role': 'giver'},
          {'id': 'ming', 'label': '小明', 'role': 'receiver'},
        ],
        'transferable': {'id': 'book', 'label': '书'},
        'arrows': [
          {'id': 'a1', 'from': 'mei', 'to': 'ming', 'label': '书'},
        ],
        'perspective': {
          'current_role': 'mei',
          'roles': ['mei', 'ming'],
        },
        'question': '从小明的视角看，这个动作是？',
        'options': [
          {'id': 'x', 'text': '借入', 'feedback': '小明是接收者，是借入。'},
          {'id': 'y', 'text': '借出', 'feedback': '借出是小美的视角。'},
        ],
      },
      evaluation: {'kind': 'choice', 'correct_option_id': 'x'},
    );

    testWidgets('初始显示参与者、流向与视角', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      expect(find.text('小美把书借给了小明。'), findsOneWidget);
      expect(find.text('小美'), findsWidgets); // 节点 + 视角 chip
      expect(find.text('小明'), findsWidgets);
      expect(find.text('切换视角'), findsOneWidget);
    });

    testWidgets('切换视角并作答', (tester) async {
      String? chosen;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => chosen = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('perspective-ming')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('participant-option-x')));
      await tester.pump();
      expect(chosen, 'x');
    });

    testWidgets('作答后反馈正确/错误', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(choiceId: 'y'), _actions()),
      );
      expect(find.text('借出是小美的视角。'), findsOneWidget);
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(step, const StepViewState(), _actions()),
      );
    });
  });

  group('scalar_threshold', () {
    final step = _step(
      HolisticPrimitive.scalarThreshold,
      {
        'episode': '水慢慢接近沸点。',
        'scale': {'min': 0, 'max': 100, 'label': '温度'},
        'initial_value': 95,
        'threshold': 100,
        'direction': 'falls_short',
        'outcome_markers': {'reached': '达到了', 'not_reached': '还没到'},
        'question': '水烧开了吗？',
        'options': [
          {'id': 'a', 'text': '还没开', 'feedback': '接近但未达到沸点。'},
          {'id': 'b', 'text': '开了', 'feedback': '达到沸点才算开了。'},
        ],
      },
      evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
    );

    testWidgets('初始显示标尺与未达标记', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      expect(find.text('水慢慢接近沸点。'), findsOneWidget);
      expect(find.byKey(const ValueKey('scalar-slider')), findsOneWidget);
      expect(find.text('还没到'), findsOneWidget);
      expect(find.textContaining('当前 95'), findsOneWidget);
    });

    testWidgets('拖动越过阈值后标记变化', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('scalar-slider')),
      );
      // 拖动到最大值（越过阈值）
      await tester.drag(
        find.byKey(const ValueKey('scalar-slider')),
        const Offset(400, 0),
      );
      await tester.pump();
      expect(find.text('达到了'), findsOneWidget);
      expect(slider.onChanged, isNotNull);
    });

    testWidgets('作答后反馈', (tester) async {
      String? chosen;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => chosen = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('scalar-option-a')));
      await tester.pump();
      expect(chosen, 'a');
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(step, const StepViewState(), _actions()),
      );
    });
  });

  group('information_state', () {
    final step = _step(
      HolisticPrimitive.informationState,
      {
        'episode': '小明走进房间。',
        'agents': [
          {'id': 'ming', 'label': '小明'},
        ],
        'facts': [
          {'id': 'f1', 'text': '窗户开着'},
          {'id': 'f2', 'text': '钥匙在桌上'},
        ],
        'beats': [
          {
            'id': 'b1',
            'label': '进门',
            'visible_evidence': ['窗外吹来的风'],
            'reveals': ['f1'],
            'known_by': ['ming'],
          },
          {
            'id': 'b2',
            'label': '回想昨晚',
            'visible_evidence': [],
            'reveals': ['f2'],
            'known_by': ['ming'],
          },
        ],
        'question': '小明是注意到还是理解到？',
        'options': [
          {'id': 'a', 'text': '注意到', 'feedback': '直接看到窗户开着。'},
          {'id': 'b', 'text': '理解到', 'feedback': '需要推理才算理解到。'},
        ],
      },
      evaluation: {'kind': 'choice', 'correct_option_id': 'a'},
    );

    testWidgets('初始显示时间线并可推进', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(), _actions()),
      );
      expect(find.text('进门'), findsOneWidget);
      expect(find.textContaining('1 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('beat-next')));
      await tester.pump();
      expect(find.text('得知：窗户开着'), findsOneWidget);
      expect(find.textContaining('2 / 2'), findsOneWidget);
    });

    testWidgets('全部推进后出现判断选项', (tester) async {
      String? chosen;
      await _pump(
        tester,
        buildStepView(
          step,
          const StepViewState(),
          _actions(onChoose: (v) => chosen = v),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('beat-next')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('beat-next')));
      await tester.pump();
      expect(find.text('小明是注意到还是理解到？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('info-option-a')));
      await tester.pump();
      expect(chosen, 'a');
    });

    testWidgets('作答后显示反馈', (tester) async {
      await _pump(
        tester,
        buildStepView(step, const StepViewState(choiceId: 'b'), _actions()),
      );
      // 推进全部 beat 后选项出现；已作答则显示所选反馈
      await tester.tap(find.byKey(const ValueKey('beat-next')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('beat-next')));
      await tester.pump();
      expect(find.text('需要推理才算理解到。'), findsOneWidget);
    });

    testWidgets('窄屏与放大文字无布局异常', (tester) async {
      await _narrowAndScaled(
        tester,
        () => buildStepView(step, const StepViewState(), _actions()),
      );
    });
  });
}
