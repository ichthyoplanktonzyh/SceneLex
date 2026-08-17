/// Today Planner — pure function from (day, bundle, progress, budget, mode)
/// to an ordered DayPlan.
///
/// Rules (spec §10.2):
/// - due reviews first (author `due_after_days` + mock clock), but a new
///   course is never starved: reviews may only consume the budget minus a
///   reserved new-course slice when a new course is available;
/// - a course that has not reached an Author-declared natural breakpoint
///   stays continuous — the plan never reorders course steps;
/// - no random review sampling, no shuffling of flattened cards;
/// - Author-declared on_error steps are routed by the runner, not here;
/// - the curriculum only decides which new course enters the candidate
///   range; the planner may defer it (with an honest reason).
library;

import 'package:flutter/foundation.dart';

import '../holistic_course_prototype/holistic_course_models.dart';
import 'archetype_mvp_models.dart';

/// Where a planned item comes from.
enum PlanItemKind {
  review, // scheduled review step (回想)
  remedial, // repeat of a failed step (补救)
  continuation, // continuing a course that has not reached a breakpoint
  newChapter, // a new course's first chapter (新义项课)
}

@immutable
class PlanItem {
  const PlanItem({
    required this.courseId,
    required this.stepIndex,
    required this.step,
    required this.kind,
    this.estimatedSeconds,
  });

  final String courseId;
  final int stepIndex;
  final HolisticStep step;
  final PlanItemKind kind;
  final int? estimatedSeconds;

  int get seconds => step.estimatedSeconds ?? estimatedSeconds ?? 45;
}

@immutable
class DayPlan {
  const DayPlan({
    required this.day,
    required this.items,
    required this.deferred,
  });

  final int day;
  final List<PlanItem> items;

  /// Honest reasons shown on the home page when something was deferred.
  final List<String> deferred;

  int get estimatedSeconds => items.fold(0, (sum, item) => sum + item.seconds);

  int get reviewCount =>
      items.where((i) => i.kind == PlanItemKind.review).length;

  int get remedialCount =>
      items.where((i) => i.kind == PlanItemKind.remedial).length;

  int get transferCount => items
      .where((i) => i.step.primitive == HolisticPrimitive.transferJudgment)
      .length;

  int get newCourseCount => items
      .where((i) => i.kind == PlanItemKind.newChapter)
      .map((i) => i.courseId)
      .toSet()
      .length;

  bool get newCourseStarted => newCourseCount > 0;
}

/// 从 [startIndex] 开始、连续到（含）第一个 `can_pause_after == true` 的
/// learning_flow 步骤，或到 learning_flow 结束为止的原子段。
///
/// 这段是 Course Author 决定的顺序与自然断点：调用方必须整段放入或整段
/// 延后，绝不能从中间切开，否则就破坏了"未到自然断点不得切换课程"。
List<PlanItem> _flowSegment({
  required String courseId,
  required HolisticCourse course,
  required int startIndex,
  required PlanItemKind kind,
}) {
  final segment = <PlanItem>[];
  if (startIndex >= course.steps.length) return segment;
  for (var i = startIndex; i < course.steps.length; i++) {
    final step = course.steps[i];
    if (step.stage != 'learning_flow') break;
    segment.add(
      PlanItem(courseId: courseId, stepIndex: i, step: step, kind: kind),
    );
    if (step.canPauseAfter == true) break;
  }
  return segment;
}

class TodayPlanner {
  const TodayPlanner({this.defaultBudgetSeconds = 600});

  /// Daily time budget (default 10 minutes).
  final int defaultBudgetSeconds;

  DayPlan plan({
    required int day,
    required MvpBundle bundle,
    required Map<String, CourseProgress> progress,
    int? budgetSeconds,
    SessionMode mode = SessionMode.normal,
  }) {
    final budget = budgetSeconds ?? defaultBudgetSeconds;
    final items = <PlanItem>[];
    final deferred = <String>[];

    final courses = bundle.orderedCourseIds;

    // 无进度条目 = 未开始（unseen），planner 不要求先注册进度。
    CourseProgress progressOf(String courseId) =>
        progress[courseId] ?? CourseProgress(senseId: courseId);

    // ---- 1. due reviews + remedial (order: curriculum day, then item idx)
    final reviewItems = <PlanItem>[];
    for (final courseId in courses) {
      final course = bundle.courseFor(courseId);
      final p = progressOf(courseId);
      if (course == null) continue;
      for (final (i, step) in course.steps.indexed) {
        final isReview =
            step.stage == 'review_progression' &&
            step.trigger == HolisticTrigger.scheduledReview;
        if (!isReview) continue;
        final due = step.dueAfterDays;
        final bindingDay = p.bindingDay;
        final dueDay = due != null && bindingDay != null
            ? bindingDay + due
            : null;
        if (dueDay == null || dueDay > day) continue; // 未到期（或无结构化字段）
        if (p.completedReviewIds.contains(step.id)) continue;
        if (p.phase == CoursePhase.unseen || p.phase == CoursePhase.inCourse) {
          continue; // 未绑定完成前复习不出现
        }
        reviewItems.add(
          PlanItem(
            courseId: courseId,
            stepIndex: i,
            step: step,
            kind: PlanItemKind.review,
          ),
        );
      }
      // remedial: repeated failed steps (on-error remedial steps)
      if (p.phase == CoursePhase.needsRemediation) {
        for (final failedId in p.failedStepIds) {
          for (final (i, step) in course.steps.indexed) {
            if (step.id == failedId) {
              reviewItems.add(
                PlanItem(
                  courseId: courseId,
                  stepIndex: i,
                  step: step,
                  kind: PlanItemKind.remedial,
                ),
              );
              break;
            }
          }
        }
      }
    }

    // ---- 2. continuation segments & new-course availability
    //
    // 一门尚未到达自然断点的课程，其"继续段"必须从 nextStepIndex 一直连到
    // （含）下一个 can_pause_after==true 的步骤，或到 learning_flow 结束。
    // 这一段是不可分割的原子单元：planner 绝不会只排一步就切到别的课程，
    // 也绝不会把到期复习插进这段中间（复习只能排在整段之前）。
    final continuationSegments = <PlanItem>[];
    String? availableNewCourse;
    for (final courseId in courses) {
      final course = bundle.courseFor(courseId);
      final p = progressOf(courseId);
      if (course == null) continue;
      if (p.phase == CoursePhase.inCourse &&
          p.nextStepIndex < course.steps.length) {
        final atBreakpoint =
            p.nextStepIndex > 0 &&
            course.steps[p.nextStepIndex - 1].canPauseAfter == true;
        if (!atBreakpoint) {
          continuationSegments.addAll(
            _flowSegment(
              courseId: courseId,
              course: course,
              startIndex: p.nextStepIndex,
              kind: PlanItemKind.continuation,
            ),
          );
        }
      }
      if (availableNewCourse == null &&
          p.phase == CoursePhase.unseen &&
          (bundle.curriculumDayFor(courseId) ?? day + 1) <= day) {
        availableNewCourse = courseId;
      }
    }

    final modeAllowsReviews = mode != SessionMode.newOnly;
    final modeAllowsNew = mode != SessionMode.reviewOnly;

    // ---- 3. fill the plan
    var remaining = budget;

    if (modeAllowsReviews) {
      // reviews first, but never starve a new course
      final reserveNew = modeAllowsNew && availableNewCourse != null
          ? (budget * 0.4).round().clamp(0, 300)
          : 0;
      for (final item in reviewItems) {
        if (remaining - reserveNew < item.seconds) break;
        items.add(item);
        remaining -= item.seconds;
      }
      final skipped = reviewItems.length - items.length;
      if (skipped > 0) {
        deferred.add('复习较多，今天先做最早的 $skipped 项（预留新课程时间）。');
      }
    } else if (mode == SessionMode.reviewOnly) {
      for (final item in reviewItems) {
        if (remaining < item.seconds) break;
        items.add(item);
        remaining -= item.seconds;
      }
    }

    // 未到断点的课程优先保持连续：整段放入，放不下就整段延后（不切碎）。
    if (modeAllowsNew && continuationSegments.isNotEmpty) {
      var segmentTotal = 0;
      for (final item in continuationSegments) {
        segmentTotal += item.seconds;
      }
      if (remaining < segmentTotal) {
        deferred.add('课程尚未到自然断点，今日预算不足以连续完成这一整段，延后到明天。');
      } else {
        items.addAll(continuationSegments);
        remaining -= segmentTotal;
      }
    }

    if (modeAllowsNew && availableNewCourse != null) {
      final course = bundle.courseFor(availableNewCourse)!;
      final segment = _flowSegment(
        courseId: availableNewCourse,
        course: course,
        startIndex: 0,
        kind: PlanItemKind.newChapter,
      );
      var segmentTotal = 0;
      for (final item in segment) {
        segmentTotal += item.seconds;
      }
      if (segment.isEmpty) {
        deferred.add('新课程没有可执行的首学步骤。');
      } else if (remaining < segmentTotal) {
        deferred.add('今日预算不足以完整学习新课程的自然章节，整体延后到明天。');
      } else {
        // 整段放入：新课程章节到达第一个自然断点，绝不从中间切开。
        items.addAll(segment);
        remaining -= segmentTotal;
      }
    } else if (mode == SessionMode.newOnly && availableNewCourse == null) {
      deferred.add('今天没有可开始的新课程。');
    }

    return DayPlan(day: day, items: items, deferred: deferred);
  }
}
