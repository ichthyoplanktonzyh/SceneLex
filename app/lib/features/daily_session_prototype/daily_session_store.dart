/// Daily Session store — the prototype-local, memory-only state container
/// that owns the active plan, the current task index and every produced
/// result, so a session can be exited and resumed without losing progress.
///
/// Nothing here is persisted, synced or written to a database: quitting the
/// prototype app loses the state (documented limitation). The store is
/// created by the preview entry and passed down by constructor — no Riverpod,
/// no server.
///
/// The store is the single source of truth for session progress; the
/// [DailySessionViewModel] (one per session page) only orchestrates the
/// *current* task and writes results back through this store.
library;

import 'package:flutter/foundation.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import 'daily_session_models.dart';
import 'daily_session_planner.dart';
import 'session_learner_state.dart';
import 'session_semantic_graph.dart';

/// Whether a session run exists and how far it got.
enum SessionRunState {
  /// No session started yet (or the last one was discarded).
  idle,

  /// A session is mid-flight and can be resumed.
  active,

  /// The last session finished; the home offers a re-experience.
  completed,
}

class DailySessionStore extends ChangeNotifier {
  DailySessionStore({
    required this.catalog,
    required this.repository,
    required this.planner,
    required SessionLearnerState initialLearnerState,
    required SessionSemanticGraph initialGraph,
    required DailySessionMode initialMode,
  }) : _learnerState = initialLearnerState,
       _graph = initialGraph,
       _mode = initialMode;

  /// Standard demo store: the canonical learner state (reluctant due, dirty
  /// stable, messy + almost unseen), standard mode.
  factory DailySessionStore.standard({
    required WordSenseCatalog catalog,
    required ExperienceProgramRepository repository,
    DailySessionPlanner planner = const DailySessionPlanner(),
    Map<String, SessionSenseStatus> byLemma = const {
      'reluctant': SessionSenseStatus.learning,
      'dirty': SessionSenseStatus.mastered,
      'messy': SessionSenseStatus.unseen,
      'almost': SessionSenseStatus.unseen,
    },
    DailySessionMode mode = DailySessionMode.standard,
  }) {
    final learnerState = SessionLearnerState.fromByLemma(
      catalog: catalog,
      byLemma: byLemma,
    );
    final graph = SessionSemanticGraph.fromCatalog(
      catalog: catalog,
      learnerState: learnerState,
      boundaryRelations: planner.boundaryRelations,
    );
    return DailySessionStore(
      catalog: catalog,
      repository: repository,
      planner: planner,
      initialLearnerState: learnerState,
      initialGraph: graph,
      initialMode: mode,
    );
  }

  final WordSenseCatalog catalog;
  final ExperienceProgramRepository repository;
  final DailySessionPlanner planner;

  DailySessionMode _mode;
  DailySessionMode get mode => _mode;

  SessionRunState _runState = SessionRunState.idle;
  SessionRunState get runState => _runState;

  bool get hasActiveSession => _runState == SessionRunState.active;

  DailySessionPlan? _activePlan;
  DailySessionPlan? get activePlan => _activePlan;

  int _currentTaskIndex = 0;
  int get currentTaskIndex => _currentTaskIndex;

  /// Results keyed by task id — answered tasks are never double-counted
  /// (a re-graded task is a no-op, and re-entering the session starts at the
  /// first *unanswered* task).
  final Map<String, DailySessionResult> _results = {};

  /// Senses that got a remedial transfer this session (deduped by sense).
  final Set<String> _insertedTransferSenseIds = {};

  /// Senses for which a remedial transfer was inserted (read-only view).
  Set<String> get insertedTransferSenseIds =>
      Set.unmodifiable(_insertedTransferSenseIds);

  /// ExperienceRuntime snapshots (toJson) for discover tasks, keyed by task
  /// id, so an interrupted discover resumes at the same question.
  final Map<String, Map<String, dynamic>> _discoverSnapshots = {};

  DailySessionCompletion? _completion;
  DailySessionCompletion? get completion => _completion;

  SessionLearnerState _learnerState;
  SessionLearnerState get learnerState => _learnerState;

  SessionSemanticGraph _graph;
  SessionSemanticGraph get graph => _graph;

  // -------------------------------------------------------------------------
  // Planning
  // -------------------------------------------------------------------------

  /// The plan the home page should present: the active plan while a session
  /// runs (so a dynamic transfer insertion updates the summary), otherwise
  /// a fresh plan for the current mode.
  DailySessionPlan get plan => hasActiveSession
      ? _activePlan!
      : planner.plan(
          catalog: catalog,
          learnerState: _learnerState,
          mode: _mode,
        );

  /// Switches the mode. Any unfinished session is dropped (the UI confirms
  /// with the user before calling this).
  void setMode(DailySessionMode next) {
    if (_mode == next) return;
    _mode = next;
    _discardSession();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Session lifecycle
  // -------------------------------------------------------------------------

  /// Starts a fresh session for the current mode. Returns false when the
  /// plan is empty (nothing due / nothing unseen) so callers can route to
  /// the empty state instead of entering a broken session.
  bool startSession() {
    final fresh = planner.plan(
      catalog: catalog,
      learnerState: _learnerState,
      mode: _mode,
    );
    if (fresh.isEmpty) return false;
    _activePlan = fresh;
    _currentTaskIndex = 0;
    _results.clear();
    _insertedTransferSenseIds.clear();
    _discoverSnapshots.clear();
    _completion = null;
    _runState = SessionRunState.active;
    notifyListeners();
    return true;
  }

  /// Discards an unfinished session (used by mode switching after user
  /// confirmation). A completed session is not discarded by this.
  void _discardSession() {
    _runState = SessionRunState.idle;
    _activePlan = null;
    _currentTaskIndex = 0;
    _results.clear();
    _insertedTransferSenseIds.clear();
    _discoverSnapshots.clear();
    _completion = null;
  }

  // -------------------------------------------------------------------------
  // Session progress (driven by the view model)
  // -------------------------------------------------------------------------

  /// The task the session is currently on (null when no active session).
  DailySessionTask? get currentTask {
    if (!hasActiveSession || _activePlan == null) return null;
    final tasks = _activePlan!.tasks;
    if (_currentTaskIndex >= tasks.length) return null;
    return tasks[_currentTaskIndex];
  }

  bool hasResult(String taskId) => _results.containsKey(taskId);

  void recordResult(DailySessionResult result) {
    _results[result.taskId] = result;
    notifyListeners();
  }

  /// Inserts a remedial transfer task for [senseId] right after the current
  /// task. The same task is never inserted twice (id-based dedupe), so a
  /// Forgot never duplicates drills. The plan (and therefore the task count
  /// shown to the learner) grows by one.
  void insertTransferFor(String senseId) {
    final plan = _activePlan;
    if (plan == null) return;
    final id = 'transfer-$senseId';
    if (plan.tasks.any((t) => t.id == id)) return;
    _activePlan = plan.insertingAfter(
      _currentTaskIndex,
      DailySessionTask(
        id: id,
        type: DailySessionTaskType.transfer,
        primarySenseId: senseId,
      ),
    );
    _insertedTransferSenseIds.add(senseId);
    notifyListeners();
  }

  /// Moves to the next task, or completes the session when the plan is
  /// exhausted. The completion is built from the recorded results only.
  void advance() {
    if (!hasActiveSession || _activePlan == null) return;
    if (_currentTaskIndex + 1 >= _activePlan!.tasks.length) {
      _complete();
      return;
    }
    _currentTaskIndex += 1;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Discover interruption snapshots (resume mid-question)
  // -------------------------------------------------------------------------

  void saveDiscoverSnapshot(String taskId, Map<String, dynamic> snapshot) {
    _discoverSnapshots[taskId] = snapshot;
  }

  Map<String, dynamic>? takeDiscoverSnapshot(String taskId) {
    final snapshot = _discoverSnapshots[taskId];
    _discoverSnapshots.remove(taskId);
    return snapshot;
  }

  void clearDiscoverSnapshot(String taskId) {
    _discoverSnapshots.remove(taskId);
  }

  // -------------------------------------------------------------------------
  // Completion
  // -------------------------------------------------------------------------

  void _complete() {
    final completion = DailySessionCompletion(
      results: List.unmodifiable(_results.values),
      completedAt: DateTime.now(),
      insertedTransferSenseIds: Set.unmodifiable(_insertedTransferSenseIds),
    );
    _completion = completion;

    // Grow the learner state and the semantic graph with what this session
    // actually established.
    final established = <String>{
      for (final result in completion.results)
        if (result.type == DailySessionTaskType.discover) result.primarySenseId,
    };
    final boundaryPairs = <(String, String)>[];
    for (final result in completion.results) {
      final secondary = result.secondarySenseId;
      if (result.type == DailySessionTaskType.boundary && secondary != null) {
        boundaryPairs.add((result.primarySenseId, secondary));
      }
    }
    _learnerState = _learnerState.applyingCompletion(
      newlyEstablishedSenseIds: established,
    );
    _graph = _graph.applyingCompletion(
      newlyEstablishedSenseIds: established,
      newBoundaryPairs: boundaryPairs,
    );

    _runState = SessionRunState.completed;
    _discoverSnapshots.clear();
    notifyListeners();
  }
}
