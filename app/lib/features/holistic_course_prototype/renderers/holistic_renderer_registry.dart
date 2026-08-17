/// Holistic Renderer Registry — the single mapping from primitive id to
/// renderer widget. Keeps the pipeline readable instead of one giant
/// switch: primitive → parser/model → renderer → interaction result.
///
/// Renderers only (a) display the Course Author's learner_content,
/// (b) collect interaction results, (c) return standardized results.
/// They never add content, rewrite questions, auto-add boundaries,
/// re-plan courses, or apply archetype templates.
library;

import 'package:flutter/material.dart';

import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import 'information_state_renderer.dart';
import 'multi_label_choice_renderer.dart';
import 'object_inspection_renderer.dart';
import 'participant_map_renderer.dart';
import 'scalar_threshold_renderer.dart';
import 'spatial_stage_renderer.dart';

/// Signature of a renderer builder for one primitive.
typedef HolisticStepRenderer =
    Widget Function(
      HolisticStep step,
      StepViewState state,
      StepActions actions,
    );

/// Registry: primitive id → renderer builder (the six Teaching Archetype
/// MVP extensions; the twelve original primitives live in
/// `buildStepView` and are reached through [build] fallback).
class HolisticRendererRegistry {
  const HolisticRendererRegistry._();

  static const Map<HolisticPrimitive, HolisticStepRenderer> renderers = {
    HolisticPrimitive.multiLabelChoice: _multiLabel,
    HolisticPrimitive.objectInspection: _objectInspection,
    HolisticPrimitive.spatialStage: _spatialStage,
    HolisticPrimitive.participantMap: _participantMap,
    HolisticPrimitive.scalarThreshold: _scalarThreshold,
    HolisticPrimitive.informationState: _informationState,
  };

  /// Whether this primitive is handled by the registry (vs. the classic
  /// switch in `holistic_course_renderer.buildStepView`).
  static bool supports(HolisticPrimitive primitive) =>
      renderers.containsKey(primitive);

  /// Build the renderer for a step. Returns null for primitives outside
  /// this registry.
  static Widget? build(
    HolisticStep step,
    StepViewState state,
    StepActions actions,
  ) {
    final builder = renderers[step.primitive];
    return builder?.call(step, state, actions);
  }
}

Widget _multiLabel(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => MultiLabelChoiceRenderer(
  step: step,
  state: state,
  onChoose: actions.onChoose,
);

Widget _objectInspection(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => ObjectInspectionRenderer(step: step);

Widget _spatialStage(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => SpatialStageRenderer(step: step, state: state, onChoose: actions.onChoose);

Widget _participantMap(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => ParticipantMapRenderer(
  step: step,
  state: state,
  onChoose: actions.onChoose,
);

Widget _scalarThreshold(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => ScalarThresholdRenderer(
  step: step,
  state: state,
  onChoose: actions.onChoose,
);

Widget _informationState(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) => InformationStateRenderer(
  step: step,
  state: state,
  onChoose: actions.onChoose,
);
