/// MVP session page — executes the day plan strictly in the planner's
/// order (which itself never reorders course steps). Wrong answers route
/// to Author-declared on_error steps; otherwise failures are recorded.
/// Internal fields (purpose / addresses / author_intent / archetype) are
/// never shown to the learner here.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_prototype/holistic_course_models.dart';
import '../holistic_course_prototype/holistic_course_renderer.dart';
import '../journey_prototype/views/journey_shell.dart';
import 'archetype_mvp_completion_page.dart';
import 'learner_state.dart';
import 'today_planner.dart';

class ArchetypeMvpSessionPage extends StatefulWidget {
  const ArchetypeMvpSessionPage({
    super.key,
    required this.state,
    required this.plan,
    this.initialStepIndex = 0,
  });

  final LearnerState state;
  final DayPlan plan;

  /// Dev-only start position (screenshot driver).
  final int initialStepIndex;

  @override
  State<ArchetypeMvpSessionPage> createState() => _ArchetypeMvpSessionState();
}

class _ArchetypeMvpSessionState extends State<ArchetypeMvpSessionPage> {
  late final List<PlanItem> _queue = [...widget.plan.items];
  late int _cursor = widget.initialStepIndex.clamp(0, _queue.length);

  final Map<String, String> _choices = {};
  final Set<String> _revealed = {};
  final Map<String, String> _grades = {};
  final Set<String> _consumedOnError = {};
  final Set<String> _applied = {};

  PlanItem? get _current => _cursor < _queue.length ? _queue[_cursor] : null;

  bool get _finished => _cursor >= _queue.length;

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return ArchetypeMvpCompletionPage(state: widget.state, plan: widget.plan);
    }
    final item = _current!;
    final step = item.step;
    return Scaffold(
      appBar: AppBar(title: Text('第 ${widget.state.day} 天 · 今日学习')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Row(
              children: [
                Text(
                  '${_cursor + 1} / ${_queue.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Color(0xFF8B8B96),
                  ),
                ),
                const Spacer(),
                JourneyChip(label: _kindLabel(item.kind)),
              ],
            ),
          ),
          Expanded(
            child: buildStepView(
              step,
              StepViewState(
                choiceId: _choices[step.id],
                revealed: _revealed.contains(step.id),
                gradeId: _grades[step.id],
              ),
              StepActions(
                onChoose: (answer) => _answer(item, step, answer),
                onReveal: () => setState(() => _revealed.add(step.id)),
                onGrade: (grade) => _grade(item, step, grade),
              ),
            ),
          ),
          JourneyFooterButton(
            key: const ValueKey('session-proceed'),
            label:
                step.primitive == HolisticPrimitive.recallReveal &&
                    !_revealed.contains(step.id)
                ? '查看答案'
                : '继续',
            accent: kColorDusk,
            onTap:
                step.primitive == HolisticPrimitive.recallReveal &&
                    !_revealed.contains(step.id)
                ? () => setState(() => _revealed.add(step.id))
                : (_answered(step) ? _advance : null),
          ),
        ],
      ),
    );
  }

  bool _answered(HolisticStep step) {
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

  void _apply(PlanItem item, StepOutcome? outcome) {
    if (_applied.contains(item.step.id)) return;
    _applied.add(item.step.id);
    widget.state.applyCompletion(
      courseId: item.courseId,
      step: item.step,
      outcome: outcome,
    );
  }

  void _answer(PlanItem item, HolisticStep step, String answer) {
    setState(() => _choices[step.id] = answer);
    final outcome = evaluateAnswer(step, answer);
    // 先记录完成（进度更新），再决定是否插入 on_error 步骤
    _apply(item, outcome);
    if (outcome.answered && !outcome.correct) {
      final onError = widget.state.onErrorSteps(item.courseId);
      final unused = onError.where((s) => !_consumedOnError.contains(s.id));
      if (unused.isNotEmpty) {
        final recovery = unused.first;
        _consumedOnError.add(recovery.id);
        // 插入 Author 设计的补救步骤（不改变课程顺序，仅插在失败之后）
        _queue.insert(
          _cursor + 1,
          PlanItem(
            courseId: item.courseId,
            stepIndex: item.stepIndex,
            step: recovery,
            kind: PlanItemKind.remedial,
          ),
        );
      }
    }
  }

  void _grade(PlanItem item, HolisticStep step, String grade) {
    setState(() => _grades[step.id] = grade);
    _apply(item, null);
  }

  void _advance() {
    final item = _current;
    if (item != null) _apply(item, null); // 观察/绑定/揭示等步骤随继续完成
    setState(() => _cursor += 1);
  }

  static String _kindLabel(PlanItemKind kind) => switch (kind) {
    PlanItemKind.review => '复习',
    PlanItemKind.remedial => '补救',
    PlanItemKind.continuation => '继续课程',
    PlanItemKind.newChapter => '新义项课',
  };
}
