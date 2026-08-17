/// Holistic Course preview — models: parsing the deterministic lowering,
/// trigger/primitive enums, strict step order and symbol-binding index.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/features/holistic_course_prototype/holistic_course_models.dart';

Map<String, dynamic> _loweredJson() => {
  'schema_version': '1.0',
  'course_id': 'holistic-test-messy',
  'target': {
    'sense_id': 'messy-01',
    'lemma': 'messy',
    'pos': 'adjective',
    'ipa': '/ˈmɛsi/',
    'learner_l1': 'zh-CN',
    'target_l2': 'en',
  },
  'author_intent': {
    'course_thesis': '主线',
    'learner_start': '起点',
    'intended_outcome': '结果',
    'design_rationale': '理由',
  },
  'steps': [
    {
      'id': 's1',
      'stage': 'learning_flow',
      'trigger': 'initial',
      'primitive': 'scene_observation',
      'purpose': 'p1',
      'addresses': <String>[],
      'timing': null,
      'scaffold_level': null,
      'content': {'episode': '书桌上东西散落。'},
      'evaluation': {'kind': 'none'},
    },
    {
      'id': 's2',
      'stage': 'learning_flow',
      'trigger': 'initial',
      'primitive': 'symbol_reveal',
      'purpose': 'p2',
      'addresses': <String>[],
      'timing': null,
      'scaffold_level': null,
      'content': {
        'l2_word': 'messy',
        'ipa': '/ˈmɛsi/',
        'presentation': '这个状态叫这个名字。',
        'minimal_l1_gloss': '乱的',
      },
      'evaluation': {'kind': 'none'},
    },
    {
      'id': 'r1',
      'stage': 'review_progression',
      'trigger': 'scheduled_review',
      'primitive': 'recall_reveal',
      'purpose': 'p3',
      'addresses': <String>[],
      'timing': 'next_day',
      'scaffold_level': 'early_post_binding',
      'content': {'episode': '厨房台面很乱。', 'l2_word': 'messy', 'ipa': '/ˈmɛsi/'},
      'evaluation': {'kind': 'none'},
    },
  ],
};

void main() {
  test('parses lowered course and keeps Author step order', () {
    final course = HolisticCourse.fromJson(_loweredJson());
    expect(course.courseId, 'holistic-test-messy');
    expect(course.steps.map((s) => s.id).toList(), ['s1', 's2', 'r1']);
    expect(course.steps[0].primitive, HolisticPrimitive.sceneObservation);
    expect(course.steps[1].primitive, HolisticPrimitive.symbolReveal);
    expect(course.steps[2].primitive, HolisticPrimitive.recallReveal);
    expect(course.steps[2].trigger, HolisticTrigger.scheduledReview);
    expect(course.steps[2].stage, 'review_progression');
    expect(course.steps[2].timing, 'next_day');
    expect(course.steps[2].scaffoldLevel, 'early_post_binding');
  });

  test('symbolBindingIndex points at the first symbol_reveal step', () {
    final course = HolisticCourse.fromJson(_loweredJson());
    expect(course.symbolBindingIndex, 1);
  });

  test('parses all eighteen primitives and all triggers', () {
    const primitiveNames = [
      'scene_observation',
      'evidence_highlight',
      'single_choice',
      'binary_judgment',
      'symbol_reveal',
      'pronunciation',
      'l1_confirmation',
      'l2_grounding',
      'boundary_choice',
      'transfer_judgment',
      'recall_reveal',
      'recall_self_grade',
      'multi_label_choice',
      'object_inspection',
      'spatial_stage',
      'participant_map',
      'scalar_threshold',
      'information_state',
    ];
    expect(HolisticPrimitive.values.length, primitiveNames.length);
    for (final name in primitiveNames) {
      expect(HolisticPrimitive.parse(name), isNotNull);
    }
    expect(HolisticTrigger.parse('on_error'), HolisticTrigger.onError);
    expect(
      HolisticTrigger.parse('immediate_followup'),
      HolisticTrigger.immediateFollowup,
    );
    expect(
      HolisticTrigger.parse('scheduled_review'),
      HolisticTrigger.scheduledReview,
    );
  });
}
