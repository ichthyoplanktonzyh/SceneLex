/// Completion page — capability outcomes (not just word counts):
/// what the learner built today, actual time, steps done, course state
/// changes and the next expected return time.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_prototype/holistic_course_models.dart';
import '../journey_prototype/views/journey_shell.dart';
import 'learner_state.dart';
import 'today_planner.dart';

class ArchetypeMvpCompletionPage extends StatelessWidget {
  const ArchetypeMvpCompletionPage({
    super.key,
    required this.state,
    required this.plan,
  });

  final LearnerState state;
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final outcomes = _outcomes();
    final nextReturn = _nextReturnDay();
    return Scaffold(
      appBar: AppBar(title: const Text('今日完成')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.flag_circle, size: 52, color: kColorEmber),
              const SizedBox(height: 12),
              const Text(
                '今天你：',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              for (final line in outcomes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Text('· ', style: TextStyle(color: kColorEmber)),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: kColorInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (outcomes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '完成了今天的全部计划内容。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Color(0xFF5C5C68)),
                  ),
                ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      label: '实际完成时间',
                      value: '约 ${(plan.estimatedSeconds / 60).ceil()} 分钟',
                    ),
                    _StatRow(label: '完成步骤', value: '${plan.items.length} 步'),
                    _StatRow(
                      label: '课程状态变化',
                      value: _phaseChanges().isEmpty
                          ? '无'
                          : _phaseChanges().join('、'),
                    ),
                    _StatRow(
                      label: '下一次预计返回',
                      value: nextReturn == null ? '暂无到期复习' : '第 $nextReturn 天',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              JourneyFooterButton(
                key: const ValueKey('finish-session'),
                label: '回到首页',
                accent: kColorDusk,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deterministic capability outcomes derived from what actually ran.
  List<String> _outcomes() {
    final lines = <String>[];
    final bound = <String>{};
    final boundaryPairs = <String>{};
    final transfers = <String>{};
    final reviews = <int>{};
    for (final item in plan.items) {
      final course = state.bundle.courseFor(item.courseId);
      final senseId = item.courseId;
      final archetype = state.bundle.archetypeFor(senseId) ?? '';
      if (item.step.primitive == HolisticPrimitive.symbolReveal) {
        bound.add(senseId);
      }
      if (item.step.primitive == HolisticPrimitive.boundaryChoice) {
        boundaryPairs.add(senseId);
      }
      if (item.step.primitive == HolisticPrimitive.transferJudgment) {
        transfers.add(senseId);
      }
      if (item.kind == PlanItemKind.review) reviews.add(plan.day);
      if (course != null && item.kind == PlanItemKind.newChapter) {
        final outcome = course.authorIntent['intended_outcome'] as String?;
        if (outcome != null && outcome.isNotEmpty) {
          lines.add('$outcome（$archetype）');
        }
      }
    }
    for (final senseId in bound) {
      lines.add('绑定了 ${_lemma(state, senseId)}');
    }
    if (boundaryPairs.isNotEmpty) {
      lines.add(
        '再次区分了 ${boundaryPairs.map((s) => _lemma(state, s)).join(' / ')}',
      );
    }
    if (transfers.isNotEmpty) {
      lines.add('在新情境中迁移了 ${transfers.map((s) => _lemma(state, s)).join('、')}');
    }
    if (reviews.isNotEmpty) {
      lines.add('完成了 ${reviews.length} 组定时复习（回想 + 自评）');
    }
    return lines;
  }

  String _lemma(LearnerState state, String senseId) {
    final course = state.bundle.courseFor(senseId);
    return (course?.target['lemma'] as String?) ?? senseId;
  }

  List<String> _phaseChanges() {
    final changes = <String>[];
    final coursesDone = plan.items.map((i) => i.courseId).toSet();
    for (final senseId in coursesDone) {
      final p = state.progressFor(senseId);
      changes.add('$senseId → ${p.phase.name}');
    }
    return changes;
  }

  int? _nextReturnDay() {
    int? earliest;
    for (final courseId in state.bundle.orderedCourseIds) {
      final course = state.bundle.courseFor(courseId);
      final p = state.progressFor(courseId);
      if (course == null) continue;
      final bindingDay = p.bindingDay;
      if (bindingDay == null) continue;
      for (final step in course.steps) {
        if (step.stage != 'review_progression') continue;
        final due = step.dueAfterDays;
        if (due == null) continue;
        if (p.completedReviewIds.contains(step.id)) continue;
        final dueDay = bindingDay + due;
        if (dueDay > plan.day && (earliest == null || dueDay < earliest)) {
          earliest = dueDay;
        }
      }
    }
    return earliest;
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF8B8B96)),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ],
      ),
    );
  }
}
