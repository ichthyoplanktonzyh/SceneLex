/// Memory-only learner state + Course Runner for the Teaching Archetype
/// MVP. No login / server / database / sync; mock clock via [day].
///
/// The runner executes the Course Author's steps strictly in order, routes
/// wrong answers to Author-declared on_error steps when present, and
/// otherwise records failures (→ needs_remediation). It never re-plans,
/// reorders, or adds teaching content.
library;

import 'package:flutter/foundation.dart';

import '../holistic_course_prototype/holistic_course_models.dart';
import 'archetype_mvp_models.dart';
import 'today_planner.dart';

/// Outcome of evaluating one answerable step.
@immutable
class StepOutcome {
  const StepOutcome({required this.answered, this.correct = false});

  final bool answered;
  final bool correct;
}

/// Evaluates an answer against the Author's evaluation block.
/// Non-answerable steps (kind none / self_grade) return answered=false.
StepOutcome evaluateAnswer(HolisticStep step, String answer) {
  switch (step.evaluation['kind']) {
    case 'choice':
      return StepOutcome(
        answered: true,
        correct: answer == step.correctOptionId,
      );
    case 'multi_choice':
      final chosen = answer.split(',').toSet()..remove('');
      final correct = step.correctOptionIds.toSet();
      return StepOutcome(
        answered: true,
        correct: chosen.length == correct.length && chosen.containsAll(correct),
      );
    case 'sense_choice':
      return StepOutcome(
        answered: true,
        correct: answer == step.correctSenseId,
      );
    case 'path_choice':
      return StepOutcome(answered: true, correct: answer == step.correctPathId);
    default:
      return const StepOutcome(answered: false);
  }
}

class LearnerState extends ChangeNotifier {
  LearnerState({required this.bundle, this.budgetSeconds = 600})
    : assert(bundle.courses.isNotEmpty, 'bundle 必须包含课程');

  final MvpBundle bundle;
  final int budgetSeconds;

  int day = 1;
  SessionMode mode = SessionMode.normal;

  final Map<String, CourseProgress> _progress = {};

  CourseProgress progressFor(String senseId) =>
      _progress.putIfAbsent(senseId, () => CourseProgress(senseId: senseId));

  /// Seed progress (dev tooling / tests; memory-only).
  void seedProgress(CourseProgress progress) {
    _progress[progress.senseId] = progress;
  }

  Map<String, CourseProgress> get progress => Map.unmodifiable(_progress);

  DayPlan plan() => const TodayPlanner().plan(
    day: day,
    bundle: bundle,
    progress: _progress,
    budgetSeconds: budgetSeconds,
    mode: mode,
  );

  void setDay(int newDay) {
    final clamped = newDay.clamp(1, 14);
    if (clamped == day) return;
    day = clamped;
    notifyListeners();
  }

  void setMode(SessionMode newMode) {
    if (newMode == mode) return;
    mode = newMode;
    notifyListeners();
  }

  /// Whether the learner can exit a course at this point (only at Author
  /// breakpoints before binding).
  bool canPauseAt(HolisticStep step) => step.canPauseAfter == true;

  /// 演示进度（模拟"已经学到了今天"）：当前日之前进入候选的课程全部视为
  /// 已绑定并进入巩固期，跨天复习因此真实到期。内容全部来自真实课程；
  /// 这只是把 memory-only 的学习态预置为演示状态（?seed=demo / 切日期
  /// 对话框的"填充演示进度"）。
  void seedDemoProgress() {
    for (final entry in bundle.curriculum) {
      final courseId = entry['course'] as String? ?? '';
      final courseDay = entry['day'] as int? ?? 1;
      if (courseDay >= day) continue;
      final course = bundle.courseFor(courseId);
      if (course == null) continue;
      final flowCount = course.steps
          .where((s) => s.stage == 'learning_flow')
          .length;
      _progress[courseId] = CourseProgress(
        senseId: courseId,
        phase: CoursePhase.consolidating,
        nextStepIndex: flowCount,
        bindingDay: courseDay,
        completedReviewIds: {
          for (final s in course.steps)
            if (s.stage == 'review_progression' &&
                s.dueAfterDays != null &&
                courseDay + s.dueAfterDays! < day)
              s.id,
        },
      );
    }
    notifyListeners();
  }

  /// 演示进度（partial）：第 1 门课只完成第一步、未到自然断点 —— 次日必须
  /// 继续该课程（首页显示"保持连续"）。
  void seedPartialProgress() {
    final ordered = bundle.orderedCourseIds;
    if (ordered.isEmpty) return;
    final first = ordered.first;
    _progress[first] = const CourseProgress(
      senseId: 'messy-01',
      phase: CoursePhase.inCourse,
      nextStepIndex: 1,
    );
    notifyListeners();
  }

  /// Applies one completed step to progress. Returns the updated progress.
  CourseProgress applyCompletion({
    required String courseId,
    required HolisticStep step,
    required StepOutcome? outcome,
  }) {
    final course = bundle.courseFor(courseId);
    final p = progressFor(courseId);
    // 第一步完成即进入课程（unseen → in_course）
    var next = p.phase == CoursePhase.unseen
        ? p.copyWith(phase: CoursePhase.inCourse)
        : p;

    if (step.primitive == HolisticPrimitive.symbolReveal) {
      next = next.copyWith(
        phase: CoursePhase.symbolBound,
        bindingDay: p.bindingDay ?? day,
      );
    }

    final isReview =
        step.stage == 'review_progression' &&
        step.trigger == HolisticTrigger.scheduledReview;
    if (isReview) {
      next = next.copyWith(
        completedReviewIds: {...next.completedReviewIds, step.id},
      );
    }

    if (outcome != null && outcome.answered && !outcome.correct) {
      // wrong answer: route to Author's on_error step if any (runner does
      // that); here we record the failure.
      next = next.copyWith(errorCount: next.errorCount + 1);
      final hasOnError =
          course != null &&
          course.steps.any((s) => s.trigger == HolisticTrigger.onError);
      if (!hasOnError) {
        next = next.copyWith(failedStepIds: {...next.failedStepIds, step.id});
        if (next.phase.index < CoursePhase.needsRemediation.index) {
          next = next.copyWith(phase: CoursePhase.needsRemediation);
        }
      }
    }

    if (course != null && next.nextStepIndex < course.steps.length) {
      next = next.copyWith(nextStepIndex: next.nextStepIndex + 1);
    }

    // chapter complete（learning_flow 全部完成）→ consolidating
    if (course != null && next.phase != CoursePhase.unseen) {
      final flowCount = course.steps
          .where((s) => s.stage == 'learning_flow')
          .length;
      if (next.nextStepIndex >= flowCount &&
          next.phase.index < CoursePhase.consolidating.index) {
        next = next.copyWith(phase: CoursePhase.consolidating);
      }
    }
    // all scheduled reviews done → stable
    if (course != null) {
      final reviewIds = {
        for (final s in course.steps)
          if (s.stage == 'review_progression' &&
              s.trigger == HolisticTrigger.scheduledReview)
            s.id,
      };
      if (reviewIds.isNotEmpty &&
          reviewIds.every(next.completedReviewIds.contains)) {
        next = next.copyWith(phase: CoursePhase.stable);
      }
    }

    _progress[courseId] = next;
    notifyListeners();
    return next;
  }

  void startCourse(String courseId) {
    final p = progressFor(courseId);
    if (p.phase != CoursePhase.unseen) return;
    _progress[courseId] = p.copyWith(phase: CoursePhase.inCourse);
    notifyListeners();
  }

  /// Author-declared on_error steps for a course (in flow order).
  List<HolisticStep> onErrorSteps(String courseId) {
    final course = bundle.courseFor(courseId);
    if (course == null) return const [];
    return [
      for (final s in course.steps)
        if (s.trigger == HolisticTrigger.onError) s,
    ];
  }
}
