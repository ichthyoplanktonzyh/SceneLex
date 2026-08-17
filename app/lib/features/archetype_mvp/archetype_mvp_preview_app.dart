/// Teaching Archetype MVP — standalone 14-day preview entry.
///
/// `--dart-define=SCENELEX_ARCHETYPE_MVP=true` boots this app: it loads the
/// real generated Holistic Course bundle (`archetype-mvp.v1.json`) and runs
/// a memory-only Today Session (no login / server / database / sync, mock
/// clock). The production App and all other previews are unchanged.
///
/// Dev-only URL params (screenshot driver; see
/// docs/prototypes/archetype-mvp/README.md §9):
///   ?day=N          initial simulated day (1..14)
///   ?seed=demo      seed deterministic progress: courses before `day` are
///                   bound & consolidating (reviews become due)
///   ?seed=partial   seed "mid-course" state: day-1 course paused before its
///                   natural breakpoint (must continue next session)
///   ?session=1      auto-open today's session
///   ?step=N         start the session at plan item N (dev time jump)
///   ?view=overview  auto-open the dev overview sheet
library;

import 'package:flutter/material.dart';

import '../../../data/content/mvp_bundle_repository.dart';
import '../../../ui/theme/scenelex_tokens.dart';
import 'archetype_mvp_dev_overview.dart';
import 'archetype_mvp_home_page.dart';
import 'archetype_mvp_models.dart';
import 'archetype_mvp_session_page.dart';
import 'learner_state.dart';
import 'today_planner.dart';

class ArchetypeMvpPreviewApp extends StatefulWidget {
  const ArchetypeMvpPreviewApp({super.key});

  @override
  State<ArchetypeMvpPreviewApp> createState() => _ArchetypeMvpPreviewAppState();
}

class _ArchetypeMvpPreviewAppState extends State<ArchetypeMvpPreviewApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  MvpBundle? _bundle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bundle = await const MvpBundleRepository().load();
      if (!mounted) return;
      setState(() => _bundle = bundle);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => 'Teaching Archetype MVP',
      theme: buildSceneLexTheme(),
      home: _buildHome(),
    );
  }

  Map<String, String> get _params => Uri.base.queryParameters;

  int _initialDay() {
    final raw = _params['day'];
    final day = int.tryParse(raw ?? '');
    if (day == null) return 1;
    return day.clamp(1, 14);
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'bundle 加载失败：$_error\n\n请先运行\n'
              'python3 tools/build_archetype_mvp_bundle.py',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
      );
    }
    final bundle = _bundle;
    if (bundle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final state = LearnerState(bundle: bundle)..setDay(_initialDay());
    _seedIfRequested(state, bundle);

    final labCourse = _params['lab'];
    if (labCourse != null) {
      // Dev-only renderer lab: ?lab=<sense_id>&step=<idx> renders one real
      // course step in the MVP session chrome (screenshot driver).
      final course = bundle.courseFor(labCourse);
      final labStep = int.tryParse(_params['step'] ?? '') ?? 0;
      if (course != null && labStep < course.steps.length) {
        final step = course.steps[labStep];
        final labPlan = DayPlan(
          day: state.day,
          items: [
            PlanItem(
              courseId: labCourse,
              stepIndex: labStep,
              step: step,
              kind: PlanItemKind.newChapter,
            ),
          ],
          deferred: const [],
        );
        return ArchetypeMvpSessionPage(state: state, plan: labPlan);
      }
    }

    final openSession = _params['session'] == '1';
    final stepParam = int.tryParse(_params['step'] ?? '');
    final autoOverview = _params['view'] == 'overview';
    return ArchetypeMvpHomePage(
      state: state,
      autoOpenSession: openSession
          ? _initialSessionStep(state, stepParam)
          : null,
      autoOpenOverview: autoOverview,
      onOpenDevOverview: () => _openDevOverview(state),
    );
  }

  /// Dev-only deterministic progress seeding for screenshots. `demo`:
  /// every course before the current day is bound & consolidating, so due
  /// reviews mix with the new course. `partial`: the day-1 course is paused
  /// mid-chapter before its natural breakpoint (must continue).
  void _seedIfRequested(LearnerState state, MvpBundle bundle) {
    final seed = _params['seed'];
    if (seed == null) return;
    final day = state.day;
    for (final entry in bundle.curriculum) {
      final courseId = entry['course'] as String? ?? '';
      final courseDay = entry['day'] as int? ?? 1;
      final course = bundle.courseFor(courseId);
      if (course == null) continue;
      if (seed == 'demo' && courseDay < day) {
        final flowCount = course.steps
            .where((s) => s.stage == 'learning_flow')
            .length;
        state.seedProgress(
          CourseProgress(
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
          ),
        );
      } else if (seed == 'partial' &&
          courseId == bundle.orderedCourseIds.first) {
        // 只完成第一步：未到自然断点 → 次日必须继续该课程
        state.seedProgress(
          const CourseProgress(
            senseId: 'messy-01',
            phase: CoursePhase.inCourse,
            nextStepIndex: 1,
          ),
        );
      }
    }
  }

  int? _initialSessionStep(LearnerState state, int? stepParam) {
    if (stepParam == null) return null;
    final plan = state.plan();
    if (stepParam >= plan.items.length) return plan.items.length; // completion
    return stepParam;
  }

  void _openDevOverview(LearnerState state) {
    // 用 navigatorKey 而不是 App 层 context：App 的 context 在 MaterialApp
    // 之上，找不到 Navigator。
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ArchetypeMvpDevOverview(state: state),
      ),
    );
  }
}
