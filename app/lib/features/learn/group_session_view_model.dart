/// Group session coordinator: runs a learn group (several WordSenses) by
/// driving one [ExperienceRuntimeViewModel] per sense.
///
/// Flow per sense: all concept units → symbol binding → grounding → next
/// sense → group complete. Unit count and roles are fully dynamic (from the
/// program). "熟" (Known Check) is never a free skip: it opens one concept
/// transfer check and only skips the remaining concept units when that check
/// passes; on failure the learner returns to the normal anchor flow.
///
/// The whole group state serializes to JSON for interrupted-session recovery.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../domain/learning/preferences.dart';
import '../experience_runtime/experience_runtime_view_model.dart';

/// Outcome recorded once a sense's flow completes.
@immutable
class SenseOutcome {
  const SenseOutcome({
    required this.senseId,
    required this.firstAttemptCorrect,
    required this.totalQuestions,
    required this.answeredExperiences,
  });

  final String senseId;
  final int firstAttemptCorrect;
  final int totalQuestions;
  final int answeredExperiences;

  Map<String, dynamic> toJson() => {
    'senseId': senseId,
    'firstAttemptCorrect': firstAttemptCorrect,
    'totalQuestions': totalQuestions,
    'answeredExperiences': answeredExperiences,
  };

  factory SenseOutcome.fromJson(Map<String, dynamic> json) => SenseOutcome(
    senseId: json['senseId'] as String,
    firstAttemptCorrect: (json['firstAttemptCorrect'] as num?)?.toInt() ?? 0,
    totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
    answeredExperiences: (json['answeredExperiences'] as num?)?.toInt() ?? 0,
  );
}

class GroupSessionViewModel extends ChangeNotifier {
  GroupSessionViewModel({
    required ExperienceProgramRepository repository,
    required this.senseIds,
    required this.preferences,
  }) : _repository = repository;

  final ExperienceProgramRepository _repository;
  final List<String> senseIds;
  final LearningPreferences preferences;

  bool _loaded = false;
  bool get loaded => _loaded;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _senseIndex = 0;
  int get senseIndex => _senseIndex;

  int get senseCount => senseIds.length;

  /// Current sense id, or null once the group is complete.
  String? get currentSenseId =>
      _senseIndex < senseIds.length ? senseIds[_senseIndex] : null;

  ExperienceRuntimeViewModel? _currentVm;
  ExperienceRuntimeViewModel? get currentVm => _currentVm;

  final Map<String, SenseOutcome> _outcomes = {};
  Map<String, SenseOutcome> get outcomes => Map.unmodifiable(_outcomes);

  /// Known Check state: true while the transfer check is open.
  bool _knownCheckActive = false;
  bool get knownCheckActive => _knownCheckActive;

  /// The sense's concept transfer unit used for the Known Check (null when
  /// the program has none — then "熟" is unavailable for that sense).
  ExperienceUnit? get knownCheckUnit {
    final program = _currentVm?.program;
    if (program == null) return null;
    return program.units.where((u) => u.role == UnitRole.transfer).firstOrNull;
  }

  bool get canOfferKnownCheck => knownCheckUnit != null && !_knownCheckActive;

  bool _finished = false;
  bool get finished => _finished;

  /// Loads the first sense (or restores a serialized group state).
  Future<void> load({Map<String, dynamic>? restoreState}) async {
    if (restoreState != null) {
      _restore(restoreState);
    }
    if (_senseIndex >= senseIds.length) {
      _finished = true;
      _loaded = true;
      notifyListeners();
      return;
    }
    await _openCurrentSense();
  }

  Future<void> _openCurrentSense() async {
    final senseId = currentSenseId;
    if (senseId == null) return;
    final vm = ExperienceRuntimeViewModel(_repository, senseId);
    _currentVm?.removeListener(_forwardRuntimeChange);
    _currentVm = vm;
    _knownCheckActive = false;
    vm.addListener(_forwardRuntimeChange);
    await vm.load();
    if (vm.phase == ExperienceRuntimePhase.loadError) {
      _errorMessage = vm.errorMessage;
      notifyListeners();
      return;
    }
    final pending = _pendingVmState;
    if (pending != null) {
      _pendingVmState = null;
      vm.restore(pending);
    }
    _loaded = true;
    notifyListeners();
  }

  void _forwardRuntimeChange() => notifyListeners();

  /// Locks the answer on the current concept unit (forwards to the VM).
  void answer(String answerId) => _currentVm?.answer(answerId);

  /// Advance within the sense; when the sense completes, record the outcome
  /// and open the next sense (or finish the group).
  void proceed() {
    final vm = _currentVm;
    if (vm == null || _knownCheckActive) return;
    if (vm.phase == ExperienceRuntimePhase.complete) {
      _completeCurrentSense();
      return;
    }
    vm.proceed();
    if (vm.phase == ExperienceRuntimePhase.complete) {
      _completeCurrentSense();
    }
    notifyListeners();
  }

  void _completeCurrentSense() {
    final vm = _currentVm;
    final senseId = currentSenseId;
    if (vm == null || senseId == null) return;
    _outcomes[senseId] = SenseOutcome(
      senseId: senseId,
      firstAttemptCorrect: vm.firstAttemptCorrect,
      totalQuestions: vm.totalQuestions,
      answeredExperiences: vm.totalQuestions,
    );
    _senseIndex += 1;
    if (_senseIndex >= senseIds.length) {
      _finished = true;
      _currentVm?.removeListener(_forwardRuntimeChange);
      _currentVm = null;
      notifyListeners();
      return;
    }
    // 切换义项：正确范围内的局部状态由新 VM 自然清空。
    _openCurrentSense();
  }

  /// Back: within a sense (unit level, answer state kept), or to the
  /// previous sense's first unit when at the current sense's first step.
  void back() {
    if (_knownCheckActive) {
      _knownCheckActive = false;
      notifyListeners();
      return;
    }
    final vm = _currentVm;
    if (vm == null) return;
    if (vm.canGoBack) {
      vm.back();
      return;
    }
    if (_senseIndex > 0) {
      // 回到上一义项：移除其完成记录并重新打开（从头，义项级状态不保留完成标记）。
      _senseIndex -= 1;
      _outcomes.remove(senseIds[_senseIndex]);
      _openCurrentSense();
    }
    notifyListeners();
  }

  /// Opens the Known Check (one concept transfer question). Only available
  /// while in concept formation of a sense that has a transfer unit.
  void startKnownCheck() {
    if (!canOfferKnownCheck) return;
    _knownCheckActive = true;
    notifyListeners();
  }

  /// Result of the Known Check: pass skips the remaining concept units
  /// (binding is opened), fail returns to the anchor flow.
  void completeKnownCheck({required bool passed}) {
    if (!_knownCheckActive) return;
    _knownCheckActive = false;
    if (passed) {
      final vm = _currentVm;
      if (vm != null) {
        // 跳过剩余概念形成：直接到 binding。已答 unit 的统计保留。
        vm.skipRemainingConceptUnits();
      }
    }
    notifyListeners();
  }

  Map<String, dynamic>? _pendingVmState;

  /// Serialize the group state for interrupted-session recovery.
  String? toJson() {
    final vm = _currentVm;
    return jsonEncode({
      'senseIndex': _senseIndex,
      'finished': _finished,
      'outcomes': {
        for (final entry in _outcomes.entries) entry.key: entry.value.toJson(),
      },
      'currentVm': vm == null || vm.phase == ExperienceRuntimePhase.loading
          ? null
          : vm.toJson(),
    });
  }

  void _restore(Map<String, dynamic> json) {
    _senseIndex = (json['senseIndex'] as num?)?.toInt() ?? 0;
    _finished = json['finished'] == true;
    final rawOutcomes = json['outcomes'];
    if (rawOutcomes is Map) {
      _outcomes.clear();
      for (final entry in rawOutcomes.entries) {
        if (entry.value is Map) {
          _outcomes[entry.key as String] = SenseOutcome.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final rawVm = json['currentVm'];
    if (rawVm is Map) {
      _pendingVmState = Map<String, dynamic>.from(rawVm);
    }
  }
}
