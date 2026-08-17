/// Journey session view model test: the full task progression
/// (recall → discover → boundary → transfer → discover → complete).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/domain/experience_program/experience_unit.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/features/journey_prototype/journey_session_view_model.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_plan.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_planner.dart';
import 'package:scenelex/features/journey_prototype/prototype_learner_state.dart';

String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  return BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
}

Future<JourneySessionViewModel> buildSession({
  required WordSenseCatalog catalog,
  required List<JourneyTaskType> expectedSequence,
  required void Function(JourneyCompletion) onComplete,
}) async {
  final learner = PrototypeLearnerState.resolve(
    catalog: catalog,
    byLemma: PrototypeLearnerState.defaultByLemma,
  );
  final plan = const PrototypeJourneyPlanner().plan(
    catalog: catalog,
    learnerState: learner,
  );
  expect(plan.tasks.map((t) => t.type).toList(), expectedSequence);
  final repository = BundledExperienceProgramRepository(
    bundleLoader: () async => _bundleText!,
  );
  final vm = JourneySessionViewModel(
    plan: plan,
    catalog: catalog,
    repository: repository,
    onComplete: onComplete,
  );
  await vm.load();
  return vm;
}

/// Completes the current discover task by answering every unit correctly.
Future<void> completeCurrentDiscover(JourneySessionViewModel vm) async {
  for (var guard = 0; guard < 30; guard++) {
    final discover = vm.discoverVm;
    if (discover == null) return;
    if (discover.phase == ExperienceRuntimePhase.loading) {
      await pumpEventQueue();
      continue;
    }
    if (discover.phase == ExperienceRuntimePhase.loadError) {
      fail('discover task failed to load');
    }
    if (discover.phase == ExperienceRuntimePhase.complete) {
      vm.proceedTask(); // advance to the next journey task
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

  test('journey progresses task 1 → 2 → 3 → … → complete', () async {
    final catalog = await loadCatalog();
    JourneyCompletion? completion;
    final vm = await buildSession(
      catalog: catalog,
      expectedSequence: [
        JourneyTaskType.recall,
        JourneyTaskType.newConcept,
        JourneyTaskType.discrimination,
        JourneyTaskType.transfer,
        JourneyTaskType.newConcept,
      ],
      onComplete: (result) => completion = result,
    );

    expect(vm.phase, JourneySessionPhase.active);
    expect(vm.taskIndex, 0);
    expect(vm.currentTask.type, JourneyTaskType.recall);

    // Task 1: recall — reveal, then grade (no FSRS write involved).
    expect(vm.recallRevealed, isFalse);
    vm.proceedTask();
    expect(vm.recallRevealed, isTrue);
    vm.gradeRecall(JourneyRecallGrade.gotIt);
    await pumpEventQueue();
    expect(vm.taskIndex, 1);
    expect(vm.currentTask.type, JourneyTaskType.newConcept);

    // Task 2: discover messy (real ExperienceProgram flow).
    expect(vm.currentTask.primarySenseId, 'messy-01');
    await completeCurrentDiscover(vm);
    expect(vm.taskIndex, 2);
    expect(vm.currentTask.type, JourneyTaskType.discrimination);

    // Task 3: boundary — choose the primary (messy) side, then continue.
    expect(vm.currentTask.primarySenseId, 'messy-01');
    expect(vm.currentTask.secondarySenseId, 'dirty-01');
    expect(vm.boundaryRevealed, isFalse);
    vm.chooseBoundary(vm.currentTask.primarySenseId);
    expect(vm.boundaryRevealed, isTrue);
    expect(vm.boundaryChoiceId, 'messy-01');
    vm.proceedTask();
    await pumpEventQueue();
    expect(vm.taskIndex, 3);
    expect(vm.currentTask.type, JourneyTaskType.transfer);

    // Task 4: transfer (the real transfer unit of reluctant).
    expect(vm.currentTask.primarySenseId, 'reluctant-01');
    final unit = vm.transferUnit;
    expect(unit, isNotNull);
    expect(unit!.role, UnitRole.transfer);    vm.chooseTransfer(unit.interaction.correctAnswer.id);
    expect(vm.transferRevealed, isTrue);
    vm.proceedTask();
    await pumpEventQueue();
    expect(vm.taskIndex, 4);
    expect(vm.currentTask.type, JourneyTaskType.newConcept);

    // Task 5: discover almost, then the journey completes.
    expect(vm.currentTask.primarySenseId, 'almost-01');
    await completeCurrentDiscover(vm);
    expect(vm.isComplete, isTrue);

    expect(completion, isNotNull);
    final results = completion!.results;
    expect(results.length, 5);
    expect(results[0].type, JourneyTaskType.recall);
    expect(results[0].recallGrade, JourneyRecallGrade.gotIt);
    expect(results[1].type, JourneyTaskType.newConcept);
    expect(results[1].primarySenseId, 'messy-01');
    expect(results[2].boundaryCorrect, isTrue);
    expect(results[3].transferCorrect, isTrue);
    expect(results[4].primarySenseId, 'almost-01');
    expect(results[4].discoverTotalQuestions, 4);
  });

  test('wrong boundary and transfer choices are recorded honestly', () async {
    final catalog = await loadCatalog();
    JourneyCompletion? completion;
    final vm = await buildSession(
      catalog: catalog,
      expectedSequence: [
        JourneyTaskType.recall,
        JourneyTaskType.newConcept,
        JourneyTaskType.discrimination,
        JourneyTaskType.transfer,
        JourneyTaskType.newConcept,
      ],
      onComplete: (result) => completion = result,
    );

    vm.proceedTask(); // reveal
    vm.gradeRecall(JourneyRecallGrade.forgot);
    await pumpEventQueue();
    await completeCurrentDiscover(vm);

    // Deliberately choose the wrong side (dirty) in the boundary.
    vm.chooseBoundary(vm.currentTask.secondarySenseId!);
    expect(vm.boundaryChoiceId, vm.currentTask.secondarySenseId);
    expect(vm.boundaryRevealed, isTrue);
    vm.proceedTask();
    await pumpEventQueue();

    // Deliberately choose the wrong transfer answer.
    final unit = vm.transferUnit!;
    final wrongAnswer = unit.interaction.answers
        .firstWhere((a) => !a.isCorrect);
    vm.chooseTransfer(wrongAnswer.id);
    vm.proceedTask();
    await pumpEventQueue();
    await completeCurrentDiscover(vm);

    expect(vm.isComplete, isTrue);
    final results = completion!.results;
    expect(results[2].boundaryCorrect, isFalse);
    expect(results[3].transferCorrect, isFalse);
    expect(results[0].recallGrade, JourneyRecallGrade.forgot);
  });
}
