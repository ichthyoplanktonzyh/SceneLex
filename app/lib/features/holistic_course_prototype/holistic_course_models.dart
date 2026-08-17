/// Holistic Course preview domain — parses the deterministic lowering of a
/// Holistic Course Package (see tools/holistic_course_compiler.py
/// `lower_course_package` → `app/assets/content/holistic-course-preview/`).
///
/// This preview is a dev-only prototype under
/// `features/holistic_course_prototype`: it renders the Course Author's
/// `learning_flow` (then `review_progression`) strictly in order. Nothing
/// here re-plans, re-orders or adds teaching content; the production App,
/// Journey preview and Daily Session preview are untouched.
library;

import 'package:flutter/foundation.dart';

/// The Author-declared trigger of a step. Dev time-jump may only filter
/// steps by these triggers — it never changes the course.
enum HolisticTrigger {
  initial,
  onError,
  immediateFollowup,
  scheduledReview;

  static HolisticTrigger parse(String? raw) => switch (raw) {
    'on_error' => HolisticTrigger.onError,
    'immediate_followup' => HolisticTrigger.immediateFollowup,
    'scheduled_review' => HolisticTrigger.scheduledReview,
    _ => HolisticTrigger.initial,
  };
}

/// One of the App Teaching Capabilities v1 primitives (12 original +
/// 6 Teaching Archetype MVP extensions).
enum HolisticPrimitive {
  sceneObservation,
  evidenceHighlight,
  singleChoice,
  binaryJudgment,
  symbolReveal,
  pronunciation,
  l1Confirmation,
  l2Grounding,
  boundaryChoice,
  transferJudgment,
  recallReveal,
  recallSelfGrade,
  multiLabelChoice,
  objectInspection,
  spatialStage,
  participantMap,
  scalarThreshold,
  informationState;

  static HolisticPrimitive parse(String? raw) => switch (raw) {
    'scene_observation' => HolisticPrimitive.sceneObservation,
    'evidence_highlight' => HolisticPrimitive.evidenceHighlight,
    'single_choice' => HolisticPrimitive.singleChoice,
    'binary_judgment' => HolisticPrimitive.binaryJudgment,
    'symbol_reveal' => HolisticPrimitive.symbolReveal,
    'pronunciation' => HolisticPrimitive.pronunciation,
    'l1_confirmation' => HolisticPrimitive.l1Confirmation,
    'l2_grounding' => HolisticPrimitive.l2Grounding,
    'boundary_choice' => HolisticPrimitive.boundaryChoice,
    'transfer_judgment' => HolisticPrimitive.transferJudgment,
    'recall_reveal' => HolisticPrimitive.recallReveal,
    'recall_self_grade' => HolisticPrimitive.recallSelfGrade,
    'multi_label_choice' => HolisticPrimitive.multiLabelChoice,
    'object_inspection' => HolisticPrimitive.objectInspection,
    'spatial_stage' => HolisticPrimitive.spatialStage,
    'participant_map' => HolisticPrimitive.participantMap,
    'scalar_threshold' => HolisticPrimitive.scalarThreshold,
    'information_state' => HolisticPrimitive.informationState,
    _ => HolisticPrimitive.sceneObservation,
  };
}

/// One step of the Author's course (learning_flow or review_progression).
@immutable
class HolisticStep {
  const HolisticStep({
    required this.id,
    required this.stage,
    required this.trigger,
    required this.primitive,
    required this.purpose,
    required this.addresses,
    required this.content,
    required this.evaluation,
    this.timing,
    this.scaffoldLevel,
    this.estimatedSeconds,
    this.canPauseAfter,
    this.dueAfterDays,
  });

  factory HolisticStep.fromJson(Map<String, dynamic> json) => HolisticStep(
    id: json['id'] as String? ?? '',
    stage: json['stage'] as String? ?? 'learning_flow',
    trigger: HolisticTrigger.parse(json['trigger'] as String?),
    primitive: HolisticPrimitive.parse(json['primitive'] as String?),
    purpose: json['purpose'] as String? ?? '',
    addresses: [
      for (final id in (json['addresses'] as List?) ?? const []) id as String,
    ],
    content: (json['content'] as Map?)?.cast<String, dynamic>() ?? const {},
    evaluation:
        (json['evaluation'] as Map?)?.cast<String, dynamic>() ?? const {},
    timing: json['timing'] as String?,
    scaffoldLevel: json['scaffold_level'] as String?,
    estimatedSeconds: json['estimated_seconds'] as int?,
    canPauseAfter: json['can_pause_after'] as bool?,
    dueAfterDays: json['due_after_days'] as int?,
  );

  final String id;

  /// learning_flow | review_progression
  final String stage;
  final HolisticTrigger trigger;
  final HolisticPrimitive primitive;

  /// Author-facing intent; never shown to the learner.
  final String purpose;
  final List<String> addresses;

  /// learner-visible content (fields per App Teaching Capabilities).
  final Map<String, dynamic> content;

  /// {kind: none|choice|multi_choice|sense_choice|path_choice|self_grade, ...}
  final Map<String, dynamic> evaluation;
  final String? timing;
  final String? scaffoldLevel;

  /// Author-declared time & natural breakpoint (MVP scheduling).
  final int? estimatedSeconds;
  final bool? canPauseAfter;

  /// Structured review scheduling (binding day + N).
  final int? dueAfterDays;

  bool get isChoice =>
      primitive == HolisticPrimitive.singleChoice ||
      primitive == HolisticPrimitive.binaryJudgment ||
      primitive == HolisticPrimitive.transferJudgment ||
      primitive == HolisticPrimitive.participantMap ||
      primitive == HolisticPrimitive.scalarThreshold ||
      primitive == HolisticPrimitive.informationState;

  bool get isMultiChoice => primitive == HolisticPrimitive.multiLabelChoice;

  bool get isBoundary => primitive == HolisticPrimitive.boundaryChoice;

  bool get isPathChoice => primitive == HolisticPrimitive.spatialStage;

  bool get isSelfGrade => primitive == HolisticPrimitive.recallSelfGrade;

  String? get correctOptionId => evaluation['correct_option_id'] as String?;

  List<String> get correctOptionIds => [
    for (final id in (evaluation['correct_option_ids'] as List?) ?? const [])
      id as String,
  ];

  String? get correctSenseId =>
      (evaluation['correct_sense_id'] ?? content['correct_sense_id'])
          as String?;

  String? get correctPathId => evaluation['correct_path_id'] as String?;
}

/// The lowered course: author_intent is dev-only; steps are the strict
/// execution order (learning_flow first, then review_progression).
@immutable
class HolisticCourse {
  const HolisticCourse({
    required this.courseId,
    required this.target,
    required this.authorIntent,
    required this.steps,
  });

  factory HolisticCourse.fromJson(Map<String, dynamic> json) => HolisticCourse(
    courseId: json['course_id'] as String? ?? '',
    target: (json['target'] as Map?)?.cast<String, dynamic>() ?? const {},
    authorIntent:
        (json['author_intent'] as Map?)?.cast<String, dynamic>() ?? const {},
    steps: [
      for (final step in (json['steps'] as List?) ?? const [])
        HolisticStep.fromJson((step as Map).cast<String, dynamic>()),
    ],
  );

  final String courseId;
  final Map<String, dynamic> target;
  final Map<String, dynamic> authorIntent;

  /// Strict execution order, decided entirely by the Course Author.
  final List<HolisticStep> steps;

  int get symbolBindingIndex {
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].primitive == HolisticPrimitive.symbolReveal) return i;
    }
    return -1;
  }
}
