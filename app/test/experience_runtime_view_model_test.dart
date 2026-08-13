/// ExperienceRuntimeViewModel state machine tests.
///
/// All behavior is driven by injected in-memory bundles — no network, no
/// model calls, no login state.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';

import 'fixtures/program_factory.dart';

ExperienceProgramRepository repoFor(Map<String, Object> program) {
  return BundledExperienceProgramRepository(
    bundleLoader: () async => jsonEncode({
      'bundle_version': 1,
      'programs': {'synthetic-01': program},
    }),
  );
}

Future<ExperienceRuntimeViewModel> loadedVm(int unitCount) async {
  final vm = ExperienceRuntimeViewModel(
    repoFor(programJsonWithUnitCount(unitCount)),
    'synthetic-01',
  );
  await vm.load();
  return vm;
}

void main() {
  group('phase machine', () {
    test('cannot proceed before answering', () async {
      final vm = await loadedVm(3);
      expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
      expect(vm.canProceed, isFalse);
      vm.proceed();
      expect(vm.unitIndex, 0);
      expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
    });

    test('answer locks and enables proceed', () async {
      final vm = await loadedVm(2);
      vm.answer('a1');
      expect(vm.isCurrentUnitAnswered, isTrue);
      expect(vm.canProceed, isTrue);
      vm.proceed();
      expect(vm.unitIndex, 1);
    });

    test('cannot answer twice; first choice stays locked', () async {
      final vm = await loadedVm(1);
      vm.answer('a1');
      vm.answer('a2');
      final record = vm.recordFor('unit-1')!;
      expect(record.answer.id, 'a1');
      expect(record.wasCorrectOnFirstAttempt, isTrue);
    });

    test('correct and wrong answers expose their own feedback', () async {
      final vm = await loadedVm(2);
      vm.answer('a1'); // correct
      expect(vm.recordFor('unit-1')!.answer.feedback, 'correct feedback');
      vm.proceed();
      vm.answer('a2'); // wrong
      expect(vm.recordFor('unit-2')!.answer.feedback, 'wrong feedback');
      expect(vm.recordFor('unit-2')!.wasCorrectOnFirstAttempt, isFalse);
    });

    test(
      'last unit leads to symbolBinding, then grounding, then complete',
      () async {
        final vm = await loadedVm(1);
        vm.answer('a1');
        vm.proceed();
        expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
        vm.proceed();
        expect(vm.phase, ExperienceRuntimePhase.grounding);
        vm.proceed();
        expect(vm.phase, ExperienceRuntimePhase.complete);
      },
    );

    test('back keeps previous answer state', () async {
      final vm = await loadedVm(3);
      vm.answer('a1');
      vm.proceed();
      vm.answer('a2');
      vm.proceed();
      expect(vm.unitIndex, 2);
      vm.back();
      expect(vm.unitIndex, 1);
      expect(vm.isCurrentUnitAnswered, isTrue);
      expect(vm.recordFor('unit-2')!.answer.id, 'a2');
      vm.back();
      expect(vm.unitIndex, 0);
      expect(vm.recordFor('unit-1')!.answer.id, 'a1');
      vm.back(); // already at first unit: no-op
      expect(vm.unitIndex, 0);
    });

    test('any unit count drives the same flow (1 and 7)', () async {
      for (final count in [1, 7]) {
        final vm = await loadedVm(count);
        for (var i = 0; i < count; i++) {
          expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
          expect(vm.unitIndex, i);
          expect(vm.canProceed, isFalse);
          vm.answer('a1');
          vm.proceed();
        }
        expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
        expect(vm.totalQuestions, count);
        vm.proceed();
        expect(vm.phase, ExperienceRuntimePhase.grounding);
        vm.proceed();
        expect(vm.phase, ExperienceRuntimePhase.complete);
      }
    });

    test('complete statistics use first-attempt results only', () async {
      final vm = await loadedVm(5);
      vm.answer('a1'); // correct
      vm.proceed();
      vm.answer('a2'); // wrong
      vm.proceed();
      vm.answer('a1');
      vm.proceed();
      vm.answer('a1');
      vm.proceed();
      vm.answer('a2'); // wrong
      vm.proceed();
      vm.proceed(); // symbolBinding → grounding
      vm.proceed(); // grounding → complete
      expect(vm.phase, ExperienceRuntimePhase.complete);
      expect(vm.firstAttemptCorrect, 3);
      expect(vm.totalQuestions, 5);
      expect(vm.answeredUnitCount, 5);
    });

    test('restart resets everything', () async {
      final vm = await loadedVm(2);
      vm.answer('a1');
      vm.proceed();
      vm.answer('a2');
      vm.proceed();
      expect(vm.phase, ExperienceRuntimePhase.symbolBinding);
      vm.restart();
      expect(vm.phase, ExperienceRuntimePhase.conceptUnit);
      expect(vm.unitIndex, 0);
      expect(vm.answeredUnitCount, 0);
      expect(vm.firstAttemptCorrect, 0);
      expect(vm.canProceed, isFalse);
    });

    test('missing sense surfaces loadError, not a spinner', () async {
      final vm = ExperienceRuntimeViewModel(
        repoFor(programJsonWithUnitCount(1)),
        'nope-01',
      );
      await vm.load();
      expect(vm.phase, ExperienceRuntimePhase.loadError);
      expect(vm.errorMessage, isNotEmpty);
    });

    test('draft program surfaces loadError', () async {
      final program = programJsonWithUnitCount(1)..['status'] = 'draft';
      final vm = ExperienceRuntimeViewModel(repoFor(program), 'synthetic-01');
      await vm.load();
      expect(vm.phase, ExperienceRuntimePhase.loadError);
    });
  });
}
