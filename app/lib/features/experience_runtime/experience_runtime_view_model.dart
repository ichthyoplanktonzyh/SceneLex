/// ViewModel for the Experience Runtime: a pure, unit-testable state machine
/// driven entirely by one ExperienceProgram.
///
/// Flow: loading → conceptUnit(0..n-1) → symbolBinding → grounding →
/// complete. The number of units, their roles and their order come from the
/// program; nothing here assumes a fixed unit count or role sequence. The
/// flow never calls submitReview, FSRS or sync — this is first-run learning
/// only.
library;

import 'package:flutter/foundation.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/experience_program/experience_unit.dart';

/// Runtime phase of the learning flow.
enum ExperienceRuntimePhase {
  loading,
  loadError,
  conceptUnit,
  symbolBinding,
  grounding,
  complete,
}

/// A locked answer on a concept unit.
@immutable
class UnitAnswerRecord {
  const UnitAnswerRecord({
    required this.answer,
    required this.wasCorrectOnFirstAttempt,
  });

  final Answer answer;

  /// True if the very first choice on this unit was the correct answer.
  final bool wasCorrectOnFirstAttempt;
}

class ExperienceRuntimeViewModel extends ChangeNotifier {
  ExperienceRuntimeViewModel(this._repository, this._senseId);
  final ExperienceProgramRepository _repository;
  final String _senseId;

  ExperienceRuntimePhase _phase = ExperienceRuntimePhase.loading;
  ExperienceRuntimePhase get phase => _phase;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ExperienceProgram? _program;
  ExperienceProgram? get program => _program;

  int _unitIndex = 0;
  int get unitIndex => _unitIndex;

  /// unit.id → locked answer. Kept when navigating back.
  final Map<String, UnitAnswerRecord> _answers = {};

  int _firstAttemptCorrect = 0;
  int get firstAttemptCorrect => _firstAttemptCorrect;

  /// First-run concept questions are one per unit.
  int get totalQuestions => _program?.units.length ?? 0;

  ExperienceUnit? get currentUnit =>
      (_phase == ExperienceRuntimePhase.conceptUnit && _program != null)
      ? _program!.units[_unitIndex]
      : null;

  bool get isCurrentUnitAnswered =>
      currentUnit != null && _answers.containsKey(currentUnit!.id);

  /// Locked answer record for a unit (null if not yet answered).
  UnitAnswerRecord? recordFor(String unitId) => _answers[unitId];

  bool isAnswered(String unitId) => _answers.containsKey(unitId);

  bool get canProceed {
    if (_phase == ExperienceRuntimePhase.conceptUnit) {
      return isCurrentUnitAnswered;
    }
    return true;
  }

  bool get canGoBack =>
      _phase == ExperienceRuntimePhase.conceptUnit && _unitIndex > 0;

  /// Answered concept units so far.
  int get answeredUnitCount => _answers.length;

  bool get isSymbolBindingRevealed =>
      _phase.index >= ExperienceRuntimePhase.symbolBinding.index;

  /// Fetches the program and enters the concept flow. Errors surface as
  /// [loadError] with a [message] — never as an infinite spinner.
  Future<void> load() async {
    _phase = ExperienceRuntimePhase.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _program = await _repository.load(_senseId);
      _unitIndex = 0;
      _answers.clear();
      _firstAttemptCorrect = 0;
      _phase = ExperienceRuntimePhase.conceptUnit;
    } on ExperienceProgramLoadException catch (error) {
      _phase = ExperienceRuntimePhase.loadError;
      _errorMessage = error.message;
    }
    notifyListeners();
  }

  /// Locks the answer for the current unit (first choice only counts toward
  /// first-attempt statistics).
  void answer(String answerId) {
    final unit = currentUnit;
    if (unit == null) return;
    if (_answers.containsKey(unit.id)) return; // already locked
    final answer = unit.interaction.answers.firstWhere(
      (a) => a.id == answerId,
      orElse: () =>
          throw ArgumentError.value(answerId, 'answerId', '不是当前单元的答案 id'),
    );
    _answers[unit.id] = UnitAnswerRecord(
      answer: answer,
      wasCorrectOnFirstAttempt: answer.isCorrect,
    );
    if (answer.isCorrect) {
      _firstAttemptCorrect += 1;
    }
    notifyListeners();
  }

  /// Advances through concept units, then to binding → grounding → complete.
  void proceed() {
    if (_phase == ExperienceRuntimePhase.conceptUnit && !canProceed) return;
    switch (_phase) {
      case ExperienceRuntimePhase.conceptUnit:
        if (_unitIndex + 1 < (_program?.units.length ?? 0)) {
          _unitIndex += 1;
        } else {
          _phase = ExperienceRuntimePhase.symbolBinding;
        }
      case ExperienceRuntimePhase.symbolBinding:
        _phase = ExperienceRuntimePhase.grounding;
      case ExperienceRuntimePhase.grounding:
        _phase = ExperienceRuntimePhase.complete;
      case ExperienceRuntimePhase.loading:
      case ExperienceRuntimePhase.loadError:
      case ExperienceRuntimePhase.complete:
        return;
    }
    notifyListeners();
  }

  /// Back to the previous concept unit; its answer stays locked.
  void back() {
    if (!canGoBack) return;
    _unitIndex -= 1;
    notifyListeners();
  }

  /// Skips the remaining concept formation without recording answers. Used
  /// by the group-level Known Check when the learner already proved mastery.
  void skipRemainingConceptUnits() {
    if (_phase != ExperienceRuntimePhase.conceptUnit) return;
    _phase = ExperienceRuntimePhase.symbolBinding;
    notifyListeners();
  }

  /// Restart the whole flow (complete page's "re-experience" button).
  void restart() {
    _unitIndex = 0;
    _answers.clear();
    _firstAttemptCorrect = 0;
    _phase = ExperienceRuntimePhase.conceptUnit;
    notifyListeners();
  }

  /// Serializable snapshot for interrupted-session recovery. Only learner
  /// state is captured; the program itself reloads from the repository.
  Map<String, dynamic> toJson() => {
    'phase': _phase.name,
    'unitIndex': _unitIndex,
    'firstAttemptCorrect': _firstAttemptCorrect,
    'answers': {
      for (final entry in _answers.entries)
        entry.key: {
          'answerId': entry.value.answer.id,
          'wasCorrect': entry.value.wasCorrectOnFirstAttempt,
        },
    },
  };

  /// Replay a [toJson] snapshot on a freshly loaded program. Unknown unit or
  /// answer ids are skipped (content may have changed between sessions).
  void restore(Map<String, dynamic> json) {
    final program = _program;
    if (program == null) return;
    final phaseName = json['phase'];
    _phase = ExperienceRuntimePhase.values.firstWhere(
      (p) => p.name == phaseName,
      orElse: () => ExperienceRuntimePhase.conceptUnit,
    );
    _unitIndex = (json['unitIndex'] as num?)?.toInt() ?? 0;
    _unitIndex = _unitIndex.clamp(0, program.units.length);
    _firstAttemptCorrect = (json['firstAttemptCorrect'] as num?)?.toInt() ?? 0;
    _answers.clear();
    final rawAnswers = json['answers'];
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final unit = program.units.where((u) => u.id == entry.key).firstOrNull;
        final record = entry.value;
        if (unit == null || record is! Map) continue;
        final answerId = record['answerId'];
        final answer = unit.interaction.answers
            .where((a) => a.id == answerId)
            .firstOrNull;
        if (answer == null) continue;
        _answers[unit.id] = UnitAnswerRecord(
          answer: answer,
          wasCorrectOnFirstAttempt: record['wasCorrect'] == true,
        );
      }
    }
    notifyListeners();
  }
}
