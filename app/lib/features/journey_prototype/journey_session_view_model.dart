/// Journey session view model — one continuous session that runs every task
/// of a [JourneyPlan] in order.
///
/// The discover (new concept) tasks delegate to the real
/// [ExperienceRuntimeViewModel]; recall / boundary / transfer have small
/// task-local machines here. All content (episodes, reveal, review pool,
/// transfer unit, invariants) comes from the real catalog + programs; only
/// the task orchestration and per-task grading are prototype logic.
library;

import 'package:flutter/foundation.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../domain/experience_program/symbol_binding.dart';
import '../experience_runtime/experience_runtime_view_model.dart';
import 'prototype_journey_plan.dart';

enum JourneySessionPhase { loading, active, complete }

class JourneySessionViewModel extends ChangeNotifier {
  JourneySessionViewModel({
    required this.plan,
    required this.catalog,
    required this.repository,
    required this.onComplete,
  });

  final JourneyPlan plan;
  final WordSenseCatalog catalog;
  final ExperienceProgramRepository repository;
  final ValueChanged<JourneyCompletion> onComplete;

  JourneySessionPhase _phase = JourneySessionPhase.loading;
  JourneySessionPhase get phase => _phase;

  bool get isComplete => _phase == JourneySessionPhase.complete;

  int _taskIndex = 0;
  int get taskIndex => _taskIndex;
  int get taskCount => plan.tasks.length;

  JourneyTask get currentTask => plan.tasks[_taskIndex];
  bool get isLastTask => _taskIndex == plan.tasks.length - 1;

  /// Programs loaded for non-discover tasks (recall / boundary / transfer),
  /// keyed by sense id.
  final Map<String, ExperienceProgram> _programs = {};

  /// Sense ids whose program failed to load (graceful skip).
  final Set<String> _failedSenseIds = {};

  ExperienceRuntimeViewModel? _discoverVm;
  ExperienceRuntimeViewModel? get discoverVm => _discoverVm;

  final Map<String, JourneyTaskResult> _results = {};

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

  /// Loads the programs the non-discover tasks need, then opens the first
  /// task. A missing program never crashes the session: the affected task
  /// shows a skip state instead.
  Future<void> load() async {
    _phase = JourneySessionPhase.loading;
    notifyListeners();
    for (final task in plan.tasks) {
      if (task.type == JourneyTaskType.newConcept) continue;
      if (_programs.containsKey(task.primarySenseId)) continue;
      try {
        _programs[task.primarySenseId] = await repository.load(
          task.primarySenseId,
        );
      } on ExperienceProgramLoadException {
        _failedSenseIds.add(task.primarySenseId);
      }
    }
    _taskIndex = 0;
    _phase = JourneySessionPhase.active;
    await _openCurrentTask();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Task accessors
  // -------------------------------------------------------------------------

  bool get currentTaskHasError =>
      _failedSenseIds.contains(currentTask.primarySenseId) ||
      (currentTask.type == JourneyTaskType.transfer &&
          transferUnit == null);

  String? get currentTaskErrorMessage => switch (currentTask.type) {
    JourneyTaskType.recall => 'recall',
    _ => null,
  };

  ExperienceProgram? _programForCurrent() =>
      _programs[currentTask.primarySenseId];

  /// Recall: the review-pool scene (a real review_pool item) and the reveal.
  ReviewItem? get recallItem =>
      _programForCurrent()?.reviewPool.firstOrNull;

  Reveal? get recallReveal =>
      _programForCurrent()?.symbolBinding.reveal;

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
    // Secondary (already-learned) first, primary (just discovered) second.
    return [
      catalog.entryFor(secondary),
      catalog.entryFor(primary),
    ];
  }

  /// Transfer: the program's transfer unit (real content).
  ExperienceUnit? get transferUnit {
    final program = _programForCurrent();
    if (program == null) return null;
    return program.units
        .where((u) => u.role == UnitRole.transfer)
        .firstOrNull;
  }

  // -------------------------------------------------------------------------
  // Task actions
  // -------------------------------------------------------------------------

  /// The single "primary action" of the current task (reveal / continue /
  /// next task / finish).
  void proceedTask() {
    if (_phase != JourneySessionPhase.active) return;
    switch (currentTask.type) {
      case JourneyTaskType.recall:
        if (!_recallRevealed) {
          _recallRevealed = true;
          notifyListeners();
        }
      case JourneyTaskType.newConcept:
        final vm = _discoverVm;
        if (vm == null ||
            vm.phase == ExperienceRuntimePhase.complete ||
            vm.phase == ExperienceRuntimePhase.loadError) {
          _advanceToNextTask();
        } else {
          vm.proceed();
        }
      case JourneyTaskType.discrimination:
        if (_boundaryRevealed) _advanceToNextTask();
      case JourneyTaskType.transfer:
        if (_transferRevealed) _advanceToNextTask();
    }
  }

  /// Recall grading (prototype-only; no FSRS write). Grading advances.
  void gradeRecall(JourneyRecallGrade grade) {
    if (currentTask.type != JourneyTaskType.recall) return;
    if (_results.containsKey(currentTask.id)) return;
    _results[currentTask.id] = JourneyTaskResult(
      taskId: currentTask.id,
      type: currentTask.type,
      primarySenseId: currentTask.primarySenseId,
      recallGrade: grade,
    );
    _advanceToNextTask();
  }

  /// Locks the boundary choice and reveals the explanation.
  void chooseBoundary(String senseId) {
    if (currentTask.type != JourneyTaskType.discrimination) return;
    if (_boundaryRevealed) return;
    _boundaryChoiceId = senseId;
    _boundaryRevealed = true;
    _results[currentTask.id] = JourneyTaskResult(
      taskId: currentTask.id,
      type: currentTask.type,
      primarySenseId: currentTask.primarySenseId,
      secondarySenseId: currentTask.secondarySenseId,
      boundaryCorrect: senseId == currentTask.primarySenseId,
    );
    notifyListeners();
  }

  /// Locks the transfer answer and reveals the feedback.
  void chooseTransfer(String answerId) {
    if (currentTask.type != JourneyTaskType.transfer) return;
    if (_transferRevealed) return;
    final unit = transferUnit;
    if (unit == null) return;
    Answer? picked;
    for (final answer in unit.interaction.answers) {
      if (answer.id == answerId) picked = answer;
    }
    if (picked == null) return;
    _transferChoiceId = answerId;
    _transferRevealed = true;
    _results[currentTask.id] = JourneyTaskResult(
      taskId: currentTask.id,
      type: currentTask.type,
      primarySenseId: currentTask.primarySenseId,
      transferCorrect: picked.isCorrect,
    );
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Progression
  // -------------------------------------------------------------------------

  Future<void> _openCurrentTask() async {
    _recallRevealed = false;
    _boundaryChoiceId = null;
    _boundaryRevealed = false;
    _transferChoiceId = null;
    _transferRevealed = false;
    final previous = _discoverVm;
    if (previous != null) {
      previous.removeListener(_forwardDiscoverChange);
      _discoverVm = null;
    }
    if (currentTask.type == JourneyTaskType.newConcept) {
      final vm = ExperienceRuntimeViewModel(
        repository,
        currentTask.primarySenseId,
      );
      _discoverVm = vm;
      vm.addListener(_forwardDiscoverChange);
      await vm.load();
    }
    notifyListeners();
  }

  void _forwardDiscoverChange() => notifyListeners();

  void _recordDiscoverResult() {
    final vm = _discoverVm;
    if (vm == null) return;
    _results[currentTask.id] = JourneyTaskResult(
      taskId: currentTask.id,
      type: currentTask.type,
      primarySenseId: currentTask.primarySenseId,
      discoverFirstAttemptCorrect: vm.firstAttemptCorrect,
      discoverTotalQuestions: vm.totalQuestions,
    );
  }

  void _advanceToNextTask() {
    if (_phase != JourneySessionPhase.active) return;
    if (currentTask.type == JourneyTaskType.newConcept) {
      _recordDiscoverResult();
    }
    if (isLastTask) {
      _completeSession();
      return;
    }
    _taskIndex += 1;
    _openCurrentTask();
  }

  void _completeSession() {
    _phase = JourneySessionPhase.complete;
    onComplete(
      JourneyCompletion(
        results: List.unmodifiable(_results.values),
        completedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
