/// Daily Session view model — orchestrates the *current* task of an active
/// session.
///
/// The store owns the plan, the current index and the results (resume-safe);
/// this view model is created per session page and rebuilt from store state
/// on re-entry. Discover tasks delegate to the real
/// [ExperienceRuntimeViewModel]; recall / boundary / transfer have small
/// task-local machines here. All content (episodes, reveal, review pool,
/// transfer unit, invariants) comes from the real catalog + programs; only
/// the orchestration and per-task grading are prototype logic.
library;

import 'package:flutter/foundation.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../domain/experience_program/symbol_binding.dart';
import '../experience_runtime/experience_runtime_view_model.dart';
import 'daily_session_models.dart';
import 'daily_session_store.dart';

enum DailySessionPhase { loading, active, complete }

class DailySessionViewModel extends ChangeNotifier {
  DailySessionViewModel({
    required this.store,
    required this.catalog,
    required this.repository,
  });

  final DailySessionStore store;
  final WordSenseCatalog catalog;
  final ExperienceProgramRepository repository;

  DailySessionPhase _phase = DailySessionPhase.loading;
  DailySessionPhase get phase => _phase;

  bool get isComplete => _phase == DailySessionPhase.complete;

  DailySessionTask get currentTask => store.currentTask!;

  bool get isLastTask =>
      store.currentTaskIndex >= store.activePlan!.tasks.length - 1;

  /// Programs loaded for non-discover tasks (recall / boundary / transfer),
  /// keyed by sense id.
  final Map<String, ExperienceProgram> _programs = {};

  /// Sense ids whose program failed to load (graceful skip).
  final Set<String> _failedSenseIds = {};

  ExperienceRuntimeViewModel? _discoverVm;
  ExperienceRuntimeViewModel? get discoverVm => _discoverVm;

  // Recall task state.
  bool _recallRevealed = false;
  bool get recallRevealed => _recallRevealed;

  // Boundary task state.
  String? _boundaryChoiceId;
  bool _boundaryRevealed = false;
  String? get boundaryChoiceId => _boundaryChoiceId;
  bool get boundaryRevealed => _boundaryRevealed;

  // Transfer task state.
  String? _transferChoiceId;
  bool _transferRevealed = false;
  String? get transferChoiceId => _transferChoiceId;
  bool get transferRevealed => _transferRevealed;

  /// Loads the current task (resuming from the store's index when a session
  /// is re-entered). A missing program never crashes the session: the
  /// affected task shows a skip state instead.
  Future<void> load() async {
    _phase = DailySessionPhase.loading;
    notifyListeners();
    await _openCurrentTask();
    _phase = DailySessionPhase.active;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Task accessors
  // -------------------------------------------------------------------------

  bool get currentTaskHasError {
    if (_failedSenseIds.contains(currentTask.primarySenseId)) return true;
    return switch (currentTask.type) {
      DailySessionTaskType.recall => recallItem == null || recallReveal == null,
      DailySessionTaskType.discover => false,
      DailySessionTaskType.boundary => boundarySceneEpisode == null,
      DailySessionTaskType.transfer => transferUnit == null,
    };
  }

  ExperienceProgram? _programForCurrent() =>
      _programs[currentTask.primarySenseId];

  /// Recall: the review-pool scene (a real review_pool item) and the reveal.
  ReviewItem? get recallItem => _programForCurrent()?.reviewPool.firstOrNull;

  Reveal? get recallReveal => _programForCurrent()?.symbolBinding.reveal;

  String? get recallMinimalGloss =>
      _programForCurrent()?.symbolBinding.minimalL1Gloss;

  /// Boundary: the scene comes from the new side's review pool; the options
  /// are the two senses of the boundary relation.
  String? get boundarySceneEpisode {
    final program = _programForCurrent();
    if (program == null) return null;
    final item = program.reviewPool.firstOrNull;
    final experience = item?.experience;
    return experience == null ? null : Experience.fromJson(experience).episode;
  }

  List<WordSenseCatalogEntry> get boundaryOptions {
    final primary = currentTask.primarySenseId;
    final secondary = currentTask.secondarySenseId ?? primary;
    return [catalog.entryFor(secondary), catalog.entryFor(primary)];
  }

  /// Transfer: the program's transfer unit (real content).
  ExperienceUnit? get transferUnit {
    final program = _programForCurrent();
    if (program == null) return null;
    return program.units.where((u) => u.role == UnitRole.transfer).firstOrNull;
  }

  // -------------------------------------------------------------------------
  // Task actions
  // -------------------------------------------------------------------------

  /// The single "primary action" of the current task (reveal / continue /
  /// next task / finish). A task whose content is unavailable is always
  /// skippable: proceedTask advances without grading.
  void proceedTask() {
    if (_phase != DailySessionPhase.active) return;
    if (currentTaskHasError) {
      _advanceToNextTask();
      return;
    }
    switch (currentTask.type) {
      case DailySessionTaskType.recall:
        if (!_recallRevealed) {
          _recallRevealed = true;
          notifyListeners();
        }
      case DailySessionTaskType.discover:
        final vm = _discoverVm;
        if (vm == null ||
            vm.phase == ExperienceRuntimePhase.complete ||
            vm.phase == ExperienceRuntimePhase.loadError) {
          _advanceToNextTask();
        } else {
          vm.proceed();
        }
      case DailySessionTaskType.boundary:
        if (_boundaryRevealed) _advanceToNextTask();
      case DailySessionTaskType.transfer:
        if (_transferRevealed) _advanceToNextTask();
    }
  }

  /// Recall grading (prototype-only; no FSRS write). Grading advances.
  ///
  /// Remedial-transfer rule: answering **Forgot** inserts one extra transfer
  /// task for that sense later in this session (deduped — never twice).
  /// **Hard / Got it** do NOT insert an extra task.
  void gradeRecall(DailySessionRecallGrade grade) {
    if (currentTask.type != DailySessionTaskType.recall) return;
    final taskId = currentTask.id;
    if (store.hasResult(taskId)) return; // never double-count
    store.recordResult(
      DailySessionResult(
        taskId: taskId,
        type: currentTask.type,
        primarySenseId: currentTask.primarySenseId,
        recallGrade: grade,
      ),
    );
    if (grade == DailySessionRecallGrade.forgot) {
      store.insertTransferFor(currentTask.primarySenseId);
    }
    _advanceToNextTask();
  }

  /// Locks the boundary choice and reveals the explanation.
  void chooseBoundary(String senseId) {
    if (currentTask.type != DailySessionTaskType.boundary) return;
    if (_boundaryRevealed) return;
    final taskId = currentTask.id;
    if (store.hasResult(taskId)) return;
    _boundaryChoiceId = senseId;
    _boundaryRevealed = true;
    store.recordResult(
      DailySessionResult(
        taskId: taskId,
        type: currentTask.type,
        primarySenseId: currentTask.primarySenseId,
        secondarySenseId: currentTask.secondarySenseId,
        boundaryCorrect: senseId == currentTask.primarySenseId,
      ),
    );
    notifyListeners();
  }

  /// Locks the transfer answer and reveals the feedback.
  void chooseTransfer(String answerId) {
    if (currentTask.type != DailySessionTaskType.transfer) return;
    if (_transferRevealed) return;
    final taskId = currentTask.id;
    if (store.hasResult(taskId)) return;
    final unit = transferUnit;
    if (unit == null) return;
    Answer? picked;
    for (final answer in unit.interaction.answers) {
      if (answer.id == answerId) picked = answer;
    }
    if (picked == null) return;
    _transferChoiceId = answerId;
    _transferRevealed = true;
    store.recordResult(
      DailySessionResult(
        taskId: taskId,
        type: currentTask.type,
        primarySenseId: currentTask.primarySenseId,
        transferCorrect: picked.isCorrect,
      ),
    );
    notifyListeners();
  }

  /// Saves the discover runtime snapshot so an interrupted session resumes
  /// at the same question (memory-only). Called when the session page is
  /// popped; safe to call repeatedly.
  void saveCurrentDiscoverSnapshot() {
    final task = store.currentTask;
    final vm = _discoverVm;
    if (task == null || vm == null) return;
    if (task.type != DailySessionTaskType.discover) return;
    if (vm.phase == ExperienceRuntimePhase.loading) return;
    store.saveDiscoverSnapshot(task.id, vm.toJson());
  }

  // -------------------------------------------------------------------------
  // Progression
  // -------------------------------------------------------------------------

  Future<void> _openCurrentTask() async {
    _recallRevealed = false;
    _boundaryChoiceId = null;
    _boundaryRevealed = false;
    _transferChoiceId = null;
    final previous = _discoverVm;
    if (previous != null) {
      previous.removeListener(_forwardDiscoverChange);
      _discoverVm = null;
    }

    final task = store.currentTask;
    if (task == null) {
      _phase = DailySessionPhase.complete;
      return;
    }

    if (task.type == DailySessionTaskType.discover) {
      final vm = ExperienceRuntimeViewModel(repository, task.primarySenseId);
      _discoverVm = vm;
      vm.addListener(_forwardDiscoverChange);
      await vm.load();
      // Resume an interrupted discover at the exact same question.
      final snapshot = store.takeDiscoverSnapshot(task.id);
      if (snapshot != null) vm.restore(snapshot);
    } else {
      final senseId = task.primarySenseId;
      if (!_programs.containsKey(senseId) &&
          !_failedSenseIds.contains(senseId)) {
        try {
          _programs[senseId] = await repository.load(senseId);
        } on ExperienceProgramLoadException {
          _failedSenseIds.add(senseId);
        }
      }
    }
    notifyListeners();
  }

  void _forwardDiscoverChange() => notifyListeners();

  void _recordDiscoverResult() {
    final vm = _discoverVm;
    final task = store.currentTask;
    if (vm == null || task == null) return;
    if (vm.phase == ExperienceRuntimePhase.loadError) return;
    store.recordResult(
      DailySessionResult(
        taskId: task.id,
        type: task.type,
        primarySenseId: task.primarySenseId,
        discoverFirstAttemptCorrect: vm.firstAttemptCorrect,
        discoverTotalQuestions: vm.totalQuestions,
      ),
    );
  }

  void _advanceToNextTask() {
    if (_phase != DailySessionPhase.active) return;
    final task = store.currentTask;
    if (task == null) return;
    if (task.type == DailySessionTaskType.discover) {
      _recordDiscoverResult();
    }
    store.clearDiscoverSnapshot(task.id);
    store.advance();
    if (store.runState == SessionRunState.completed) {
      _phase = DailySessionPhase.complete;
      notifyListeners();
      return;
    }
    _openCurrentTask();
  }
}
