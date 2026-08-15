/// Daily Session view model tests: the full task progression with dynamic
/// remedial-transfer insertion, resume behavior and graceful skips.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_models.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_store.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_view_model.dart';
import 'package:scenelex/features/daily_session_prototype/session_learner_state.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';

String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  return BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
}

BundledExperienceProgramRepository buildRepository() =>
    BundledExperienceProgramRepository(bundleLoader: () async => _bundleText!);

DailySessionStore buildStore({
  required WordSenseCatalog catalog,
  required ExperienceProgramRepository repository,
  Map<String, SessionSenseStatus> byLemma = const {
    'reluctant': SessionSenseStatus.learning,
    'dirty': SessionSenseStatus.mastered,
    'messy': SessionSenseStatus.unseen,
    'almost': SessionSenseStatus.unseen,
  },
  DailySessionMode mode = DailySessionMode.standard,
}) => DailySessionStore.standard(
  catalog: catalog,
  repository: repository,
  byLemma: byLemma,
  mode: mode,
);

Future<DailySessionViewModel> openSession(DailySessionStore store) async {
  expect(store.startSession(), isTrue);
  final vm = DailySessionViewModel(
    store: store,
    catalog: store.catalog,
    repository: store.repository,
  );
  await vm.load();
  return vm;
}

/// Repository that fails to load programs for given senses.
class _FailingRepository implements ExperienceProgramRepository {
  _FailingRepository(this._inner, this._failing);

  final ExperienceProgramRepository _inner;
  final Set<String> _failing;

  @override
  Future<ExperienceProgram> load(String senseId) async {
    if (_failing.contains(senseId)) throw SenseNotFoundException(senseId);
    return _inner.load(senseId);
  }
}

/// Repository that serves programs without transfer units for given senses
/// (content degradation: transferUnit missing must be skippable).
class _NoTransferUnitRepository implements ExperienceProgramRepository {
  _NoTransferUnitRepository(this._inner, this._stripped);

  final ExperienceProgramRepository _inner;
  final Set<String> _stripped;

  @override
  Future<ExperienceProgram> load(String senseId) async {
    final program = await _inner.load(senseId);
    if (!_stripped.contains(senseId)) return program;
    final root = jsonDecode(_bundleText!) as Map<String, dynamic>;
    final programs = root['programs'] as Map<String, dynamic>;
    final raw = Map<String, dynamic>.from(programs[senseId] as Map);
    raw['units'] = (raw['units'] as List)
        .whereType<Map>()
        .where((u) => u['role'] != 'transfer')
        .toList();
    return ExperienceProgram.fromJson(raw);
  }
}

/// Completes the current discover task by answering every unit correctly.
Future<void> completeCurrentDiscover(DailySessionViewModel vm) async {
  for (var guard = 0; guard < 30; guard++) {
    final discover = vm.discoverVm;
    if (discover == null) return;
    if (discover.phase == ExperienceRuntimePhase.loading) {
      await pumpEventQueue();
      continue;
    }
    if (discover.phase == ExperienceRuntimePhase.loadError) {
      vm.proceedTask();
      return;
    }
    if (discover.phase == ExperienceRuntimePhase.complete) {
      vm.proceedTask();
      await pumpEventQueue();
      return;
    }
    if (discover.phase == ExperienceRuntimePhase.conceptUnit &&
        !discover.isCurrentUnitAnswered) {
      discover.answer(discover.currentUnit!.interaction.correctAnswer.id);
    }
    vm.proceedTask();
    await pumpEventQueue();
  }
  fail('discover task did not complete');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  test(
    'standard mode progresses recall → discover → boundary → complete',
    () async {
      final catalog = await loadCatalog();
      final store = buildStore(catalog: catalog, repository: buildRepository());
      final vm = await openSession(store);

      expect(vm.phase, DailySessionPhase.active);
      expect(vm.currentTask.type, DailySessionTaskType.recall);
      expect(vm.currentTask.primarySenseId, 'reluctant-01');

      vm.proceedTask();
      expect(vm.recallRevealed, isTrue);
      vm.gradeRecall(DailySessionRecallGrade.gotIt);
      await pumpEventQueue();
      expect(vm.currentTask.type, DailySessionTaskType.discover);
      expect(vm.currentTask.primarySenseId, 'messy-01');

      await completeCurrentDiscover(vm);
      expect(vm.currentTask.type, DailySessionTaskType.boundary);
      expect(vm.currentTask.secondarySenseId, 'dirty-01');

      vm.chooseBoundary(vm.currentTask.primarySenseId);
      expect(vm.boundaryRevealed, isTrue);
      vm.proceedTask();
      await pumpEventQueue();

      expect(vm.isComplete, isTrue);
      expect(store.runState, SessionRunState.completed);
      final results = store.completion!.results;
      expect(results.length, 3);
      expect(results[0].recallGrade, DailySessionRecallGrade.gotIt);
      expect(results[1].primarySenseId, 'messy-01');
      expect(results[2].boundaryCorrect, isTrue);
    },
  );

  test(
    'Forgot inserts exactly one remedial transfer for the session',
    () async {
      final catalog = await loadCatalog();
      final store = buildStore(catalog: catalog, repository: buildRepository());
      final vm = await openSession(store);

      vm.proceedTask(); // reveal
      vm.gradeRecall(DailySessionRecallGrade.forgot);
      await pumpEventQueue();

      final plan = store.activePlan!;
      expect(plan.countOf(DailySessionTaskType.transfer), 1);
      expect(plan.tasks[1].id, 'transfer-reluctant-01');
      expect(plan.tasks[1].type, DailySessionTaskType.transfer);
      expect(plan.tasks[1].primarySenseId, 'reluctant-01');
      expect(store.insertedTransferSenseIds, {'reluctant-01'});

      // Dedupe: inserting again is a no-op (the same task is never duplicated).
      store.insertTransferFor('reluctant-01');
      expect(store.activePlan!.countOf(DailySessionTaskType.transfer), 1);

      // The inserted task runs as a real transfer drill, then the session
      // continues with discover.
      expect(vm.currentTask.type, DailySessionTaskType.transfer);
      final unit = vm.transferUnit;
      expect(unit, isNotNull);
      vm.chooseTransfer(unit!.interaction.correctAnswer.id);
      vm.proceedTask();
      await pumpEventQueue();
      expect(vm.currentTask.type, DailySessionTaskType.discover);

      await completeCurrentDiscover(vm);
      vm.chooseBoundary(vm.currentTask.primarySenseId);
      vm.proceedTask();
      await pumpEventQueue();
      expect(vm.isComplete, isTrue);
      // Transfer result is counted exactly once.
      expect(
        store.completion!.results
            .where((r) => r.type == DailySessionTaskType.transfer)
            .length,
        1,
      );
      expect(store.completion!.insertedTransferSenseIds, {'reluctant-01'});
    },
  );

  test('Hard and Got it do not insert a remedial transfer', () async {
    for (final grade in [
      DailySessionRecallGrade.hard,
      DailySessionRecallGrade.gotIt,
    ]) {
      final catalog = await loadCatalog();
      final store = buildStore(catalog: catalog, repository: buildRepository());
      final vm = await openSession(store);
      vm.proceedTask();
      vm.gradeRecall(grade);
      await pumpEventQueue();
      expect(
        store.activePlan!.countOf(DailySessionTaskType.transfer),
        0,
        reason: 'grade $grade must not add transfer tasks',
      );
      expect(store.insertedTransferSenseIds, isEmpty);
      expect(store.activePlan!.tasks.length, 3);
    }
  });

  test('resuming keeps the current task index and results', () async {
    final catalog = await loadCatalog();
    final store = buildStore(catalog: catalog, repository: buildRepository());
    final vm = await openSession(store);
    vm.proceedTask();
    vm.gradeRecall(DailySessionRecallGrade.hard);
    await pumpEventQueue();
    expect(vm.currentTask.type, DailySessionTaskType.discover);

    // "Quit": a fresh view model on the same store resumes at the same task.
    final resumed = DailySessionViewModel(
      store: store,
      catalog: catalog,
      repository: store.repository,
    );
    await resumed.load();
    expect(resumed.currentTask.type, DailySessionTaskType.discover);
    expect(resumed.currentTask.primarySenseId, 'messy-01');
    // The answered recall is not re-graded: results still have one entry.
    expect(store.activePlan!.tasks.length, 3);
    expect(store.hasResult('recall-reluctant-01'), isTrue);
  });

  test('a failed program is skipped and the session still completes', () async {
    final catalog = await loadCatalog();
    final failing = _FailingRepository(buildRepository(), {'messy-01'});
    final store = buildStore(catalog: catalog, repository: failing);
    final vm = await openSession(store);

    vm.proceedTask();
    vm.gradeRecall(DailySessionRecallGrade.gotIt);
    await pumpEventQueue();

    // Discover messy cannot load → the task is skipped without a result.
    expect(vm.currentTask.type, DailySessionTaskType.discover);
    expect(vm.discoverVm!.phase, ExperienceRuntimePhase.loadError);
    vm.proceedTask();
    await pumpEventQueue();

    // Boundary needs messy's program too → skip as well.
    expect(vm.currentTask.type, DailySessionTaskType.boundary);
    expect(vm.currentTaskHasError, isTrue);
    vm.proceedTask();
    await pumpEventQueue();

    expect(vm.isComplete, isTrue);
    expect(store.runState, SessionRunState.completed);
    final results = store.completion!.results;
    expect(results.length, 1);
    expect(results.single.type, DailySessionTaskType.recall);
  });

  test(
    'a missing transfer unit is skippable and the session continues',
    () async {
      final catalog = await loadCatalog();
      final stripped = _NoTransferUnitRepository(buildRepository(), {
        'reluctant-01',
      });
      final store = buildStore(catalog: catalog, repository: stripped);
      final vm = await openSession(store);

      vm.proceedTask();
      vm.gradeRecall(DailySessionRecallGrade.forgot);
      await pumpEventQueue();

      // The inserted transfer cannot render (no transfer unit) → skip.
      expect(vm.currentTask.type, DailySessionTaskType.transfer);
      expect(vm.currentTaskHasError, isTrue);
      expect(vm.transferUnit, isNull);
      vm.proceedTask();
      await pumpEventQueue();

      expect(vm.currentTask.type, DailySessionTaskType.discover);
      await completeCurrentDiscover(vm);
      vm.chooseBoundary(vm.currentTask.primarySenseId);
      vm.proceedTask();
      await pumpEventQueue();
      expect(vm.isComplete, isTrue);
    },
  );

  test('mode switching discards an unfinished session', () async {
    final catalog = await loadCatalog();
    final store = buildStore(catalog: catalog, repository: buildRepository());
    final vm = await openSession(store);
    vm.proceedTask();
    vm.gradeRecall(DailySessionRecallGrade.hard);
    await pumpEventQueue();
    expect(store.hasActiveSession, isTrue);

    store.setMode(DailySessionMode.reviewOnly);
    expect(store.hasActiveSession, isFalse);
    expect(store.runState, SessionRunState.idle);
    expect(
      store.plan.tasks.every((t) => t.type == DailySessionTaskType.recall),
      isTrue,
    );
    expect(store.hasResult('recall-reluctant-01'), isFalse);
  });

  test(
    'empty plan: startSession refuses and never enters a broken session',
    () async {
      final catalog = await loadCatalog();
      final store = buildStore(
        catalog: catalog,
        repository: buildRepository(),
        byLemma: {
          'reluctant': SessionSenseStatus.mastered,
          'dirty': SessionSenseStatus.mastered,
        },
        mode: DailySessionMode.reviewOnly,
      );
      expect(store.plan.isEmpty, isTrue);
      expect(store.startSession(), isFalse);
      expect(store.hasActiveSession, isFalse);
    },
  );
}
