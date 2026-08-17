/// Holistic Course preview page — executes the Course Author's steps
/// strictly in order.
///
/// The learner flow renders only learner-visible content. Everything
/// internal (author_intent, purpose, addresses, trigger) lives in the
/// dev-only overview panel. Dev time-jump filters steps by the Author's
/// declared triggers (initial / immediate follow-up / scheduled review);
/// it never re-plans or changes the course.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import '../journey_prototype/views/journey_shell.dart';
import 'holistic_course_models.dart';
import 'holistic_course_renderer.dart';

class HolisticCoursePreviewPage extends StatefulWidget {
  const HolisticCoursePreviewPage({
    super.key,
    required this.course,
    this.devMode = true,
    this.initialStepIndex = 0,
    this.autoOpenOverview = false,
    this.onPronounce,
  });

  final HolisticCourse course;

  /// Development mode: shows the course overview button and time-jump.
  final bool devMode;

  /// Development entry point (used by screenshot driver / tests / ?step=).
  final int initialStepIndex;

  /// Dev-only: auto-open the overview sheet after the first frame
  /// (used by web screenshots via `?view=overview`).
  final bool autoOpenOverview;

  /// Optional TTS hook; pronunciation buttons are hidden when absent.
  final VoidCallback? onPronounce;

  @override
  State<HolisticCoursePreviewPage> createState() =>
      _HolisticCoursePreviewPageState();
}

class _HolisticCoursePreviewPageState extends State<HolisticCoursePreviewPage> {
  late int _index = widget.initialStepIndex.clamp(
    0,
    widget.course.steps.length,
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenOverview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openOverview();
      });
    }
  }

  final Map<String, String> _choices = {};
  final Set<String> _revealed = {};
  final Map<String, String> _grades = {};

  HolisticStep? get _current =>
      _index < widget.course.steps.length ? widget.course.steps[_index] : null;

  bool get _answered {
    final step = _current;
    if (step == null) return true;
    if (step.isChoice ||
        step.isBoundary ||
        step.isMultiChoice ||
        step.isPathChoice) {
      return _choices.containsKey(step.id);
    }
    if (step.isSelfGrade) return _grades.containsKey(step.id);
    if (step.primitive == HolisticPrimitive.recallReveal) {
      return _revealed.contains(step.id);
    }
    return true;
  }

  void _choose(String id) {
    final step = _current;
    if (step == null) return;
    setState(() => _choices[step.id] = id);
  }

  void _reveal() {
    final step = _current;
    if (step == null) return;
    setState(() => _revealed.add(step.id));
  }

  void _grade(String id) {
    final step = _current;
    if (step == null) return;
    setState(() => _grades[step.id] = id);
  }

  void _proceed() {
    if (!_answered) return;
    setState(() {
      if (_index + 1 <= widget.course.steps.length) {
        _index += 1;
      }
    });
  }

  int _firstIndexWith(HolisticTrigger trigger) {
    for (var i = 0; i < widget.course.steps.length; i++) {
      if (widget.course.steps[i].trigger == trigger) return i;
    }
    return -1;
  }

  void _timeJump(HolisticTrigger trigger) {
    final target = _firstIndexWith(trigger);
    if (target < 0) return;
    setState(() => _index = target);
  }

  void _openOverview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OverviewSheet(course: widget.course, onJump: _timeJump),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final finished = _index >= course.steps.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Holistic Course · ${course.courseId}'),
        actions: [
          if (widget.devMode)
            IconButton(
              key: const ValueKey('dev-overview'),
              tooltip: '开发者：课程总览',
              icon: const Icon(Icons.science_outlined),
              onPressed: _openOverview,
            ),
        ],
      ),
      body: finished
          ? _CompletionView(
              course: course,
              onRestart: () {
                setState(() {
                  _index = 0;
                  _choices.clear();
                  _revealed.clear();
                  _grades.clear();
                });
              },
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    children: [
                      Text(
                        '步骤 ${_index + 1} / ${course.steps.length}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: Color(0xFF8B8B96),
                        ),
                      ),
                      const Spacer(),
                      if (widget.devMode) ...[
                        JourneyChip(label: _current?.trigger.name ?? ''),
                        const SizedBox(width: 6),
                        JourneyChip(label: _current?.primitive.name ?? ''),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: buildStepView(
                    _current!,
                    StepViewState(
                      choiceId: _current == null
                          ? null
                          : _choices[_current!.id],
                      revealed:
                          _current != null && _revealed.contains(_current!.id),
                      gradeId: _current == null ? null : _grades[_current!.id],
                    ),
                    StepActions(
                      onChoose: _choose,
                      onReveal: _reveal,
                      onGrade: _grade,
                    ),
                  ),
                ),
                JourneyFooterButton(
                  key: const ValueKey('proceed'),
                  label:
                      _current?.primitive == HolisticPrimitive.recallReveal &&
                          !_revealed.contains(_current!.id)
                      ? '查看答案'
                      : '继续',
                  accent: kColorDusk,
                  onTap:
                      _current?.primitive == HolisticPrimitive.recallReveal &&
                          !_revealed.contains(_current!.id)
                      ? _reveal
                      : (_answered ? _proceed : null),
                ),
              ],
            ),
    );
  }
}

/// Dev-only course overview: full Author intent + every step's internal
/// fields, plus trigger-based time jumps.
class _OverviewSheet extends StatelessWidget {
  const _OverviewSheet({required this.course, required this.onJump});

  final HolisticCourse course;
  final ValueChanged<HolisticTrigger> onJump;

  @override
  Widget build(BuildContext context) {
    final intent = course.authorIntent;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            '课程总览（仅开发者可见）',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            course.courseId,
            style: const TextStyle(fontSize: 13, color: Color(0xFF84848F)),
          ),
          const SizedBox(height: 18),
          for (final (key, label) in [
            ('course_thesis', '教学主线'),
            ('learner_start', '学习者起点'),
            ('intended_outcome', '预期结果'),
            ('design_rationale', '设计理由'),
          ])
            if (intent[key] is String)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF8B8B96),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      intent[key] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: kColorInk,
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 32),
          const Text(
            '时间跳转（只筛选 Author 已设计的 trigger）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (trigger, label) in [
                (HolisticTrigger.initial, '首次学习'),
                (HolisticTrigger.immediateFollowup, '即时跟进'),
                (HolisticTrigger.scheduledReview, '定时复习'),
              ])
                OutlinedButton(
                  key: ValueKey('jump-${trigger.name}'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onJump(trigger);
                  },
                  child: Text(label),
                ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            '完整学习流（Author 顺序）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final (i, step) in course.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${step.id}  ·  ${step.primitive.name}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kColorInk,
                    ),
                  ),
                  Text(
                    'trigger=${step.trigger.name}  stage=${step.stage}'
                    '${step.timing != null ? '  timing=${step.timing}' : ''}'
                    '${step.scaffoldLevel != null ? '  scaffold=${step.scaffoldLevel}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF84848F),
                    ),
                  ),
                  Text(
                    'purpose: ${step.purpose}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFF5C5C68),
                    ),
                  ),
                  if (step.addresses.isNotEmpty)
                    Text(
                      'addresses: ${step.addresses.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5C5C68),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.course, required this.onRestart});

  final HolisticCourse course;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final counts = <HolisticTrigger, int>{};
    for (final step in course.steps) {
      counts[step.trigger] = (counts[step.trigger] ?? 0) + 1;
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.flag_circle, size: 48, color: kColorEmber),
            const SizedBox(height: 14),
            const Text(
              '课程完成',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${course.steps.length} 步，全部按 Author 顺序执行完毕。',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF5C5C68)),
            ),
            const SizedBox(height: 18),
            Text(
              counts.entries
                  .map((e) => '${e.key.name} × ${e.value}')
                  .join(' · '),
              style: const TextStyle(fontSize: 13, color: Color(0xFF84848F)),
            ),
            const SizedBox(height: 26),
            JourneyFooterButton(
              key: const ValueKey('restart'),
              label: '重新体验',
              accent: kColorDusk,
              onTap: onRestart,
            ),
          ],
        ),
      ),
    );
  }
}
