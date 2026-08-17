/// scalar_threshold renderer — drag a value along a min..max scale with an
/// authored threshold; outcome markers distinguish "not reached" (almost)
/// from "just reached" (barely); then the Author's judgment question.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import '../../journey_prototype/views/journey_shell.dart';
import 'holistic_step_chrome.dart';

class ScalarThresholdRenderer extends StatefulWidget {
  const ScalarThresholdRenderer({
    super.key,
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  State<ScalarThresholdRenderer> createState() => _ScalarThresholdState();
}

class _ScalarThresholdState extends State<ScalarThresholdRenderer> {
  late double _value;

  double get _min =>
      ((widget.step.content['scale'] as Map?)?['min'] as num? ?? 0).toDouble();
  double get _max =>
      ((widget.step.content['scale'] as Map?)?['max'] as num? ?? 100)
          .toDouble();

  @override
  void initState() {
    super.initState();
    _value =
        (widget.step.content['initial_value'] as num?)?.toDouble() ??
        (_min + _max) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final episode = content['episode'] as String? ?? '';
    final scaleLabel = (content['scale'] as Map?)?['label'] as String? ?? '';
    final threshold = (content['threshold'] as num?)?.toDouble();
    final markers = content['outcome_markers'] is Map
        ? (content['outcome_markers'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final question = content['question'] as String? ?? '';
    final options = (content['options'] as List?) ?? const [];
    final answered = widget.state.choiceId != null;
    final correctId = widget.step.correctOptionId;
    final reached = threshold != null && _value >= threshold;

    return HolisticStepScroll(
      children: [
        if (episode.isNotEmpty) JourneySceneCard(text: episode),
        const SizedBox(height: 18),
        HolisticNote('拖动滑块，观察是否越过阈值（${threshold?.toStringAsFixed(0) ?? '?'}）。'),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F0EC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2DED4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    scaleLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A746A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '当前 ${_value.toStringAsFixed(0)}',
                    key: const ValueKey('scalar-value'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kColorInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Slider(
                key: const ValueKey('scalar-slider'),
                value: _value.clamp(_min, _max),
                min: _min,
                max: _max,
                divisions: ((_max - _min) * 2).round().clamp(2, 200),
                onChanged: answered
                    ? null
                    : (value) => setState(() => _value = value),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      _min.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B8B96),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _max.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B8B96),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('scalar-outcome'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: reached
                      ? kSignalSuccess.withValues(alpha: 0.12)
                      : kSignalError.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  reached
                      ? (markers['reached'] as String? ?? '达到了')
                      : (markers['not_reached'] as String? ?? '还没到'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: reached ? kSignalSuccess : kSignalError,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (question.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScalarOptionTile(
              key: ValueKey('scalar-option-${option['id']}'),
              label: option['text'] as String? ?? '',
              state: _choiceState(
                option['id'],
                correctId,
                widget.state.choiceId,
              ),
              onTap: answered
                  ? null
                  : () => widget.onChoose(option['id'] as String),
            ),
          ),
        if (answered)
          HolisticFeedbackCard(
            text: _feedbackFor(options, widget.state.choiceId),
          ),
      ],
    );
  }

  JourneyChoiceState _choiceState(
    Object? id,
    String? correctId,
    String? chosen,
  ) {
    if (chosen == null) return JourneyChoiceState.idle;
    if (id == correctId) return JourneyChoiceState.correct;
    if (id == chosen) return JourneyChoiceState.wrong;
    return JourneyChoiceState.muted;
  }

  String _feedbackFor(List<dynamic> options, String? chosen) {
    for (final option in options) {
      if (option['id'] == chosen) {
        return option['feedback'] as String? ?? '';
      }
    }
    return '';
  }
}

class _ScalarOptionTile extends StatelessWidget {
  const _ScalarOptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final JourneyChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: switch (state) {
        JourneyChoiceState.correct => kSignalSuccessBg,
        JourneyChoiceState.wrong => kSignalErrorBg,
        _ => Colors.white.withValues(alpha: 0.62),
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: switch (state) {
            JourneyChoiceState.correct => kSignalSuccess,
            JourneyChoiceState.wrong => kSignalError,
            _ => const Color(0xFFD9D9E2),
          },
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: kColorInk,
            ),
          ),
        ),
      ),
    );
  }
}
