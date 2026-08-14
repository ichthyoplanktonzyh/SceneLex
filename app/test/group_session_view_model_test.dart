/// GroupSessionViewModel: multi-sense learn coordination, Known Check
/// semantics, group completion and interrupted-session recovery.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/experience_program/experience_unit.dart';
import 'package:scenelex/domain/learning/preferences.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/features/learn/group_session_view_model.dart';

import 'fixtures/program_factory.dart';

ExperienceProgramRepository repoFor(Map<String, Object> program) {
  return BundledExperienceProgramRepository(
    bundleLoader: () async => jsonEncode({
      'bundle_version': 1,
      'programs': {'synthetic-01': program, 'synthetic-02': program},
    }),
  );
}

Map<String, Object> programWithTransferUnit() {
  final json = programJsonWithUnitCount(2);
  (json['units'] as List<Object?>).add({
    'id': 'unit-transfer',
    'sequence': 3,
    'role': 'transfer',
    'experience': {
      'episode': 'transfer episode',
      'observable_evidence': <String>[],
      'surface_dimensions': [
        {'name': 'd', 'baseline': 'b', 'deviation': 'v'},
      ],
    },
    'interaction': {
      'question': 'transfer?',
      'answers': [
        {
          'id': 't1',
          'text': 'yes',
          'is_correct': true,
          'feedback': 'right',
        },
        {
          'id': 't2',
          'text': 'no',
          'is_correct': false,
          'feedback': 'wrong',
        },
      ],
    },
  });
  return json;
}

Future<GroupSessionViewModel> loadedGroup({
  List<String> senseIds = const ['synthetic-01', 'synthetic-02'],
  Map<String, Object>? program,
}) async {
  final vm = GroupSessionViewModel(
    repository: repoFor(program ?? programJsonWithUnitCount(1)),
    senseIds: senseIds,
    preferences: const LearningPreferences(),
  );
  await vm.load();
  return vm;
}

Future<void> completeSense(GroupSessionViewModel vm, int unitCount) async {
  // The sense opens asynchronously; wait for the runtime VM to finish
  // loading before driving it.
  for (
    var i = 0;
    i < 50 &&
        (vm.currentVm == null ||
            vm.currentVm!.phase == ExperienceRuntimePhase.loading);
    i++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(vm.currentVm, isNotNull);
  expect(
    vm.currentVm!.phase,
    ExperienceRuntimePhase.conceptUnit,
    reason: 'sense must finish loading before driving',
  );
  for (var i = 0; i < unitCount; i++) {
    vm.answer('a1');
    vm.proceed(); // continue to next unit
  }
  // symbol binding -> proceed; grounding -> proceed completes the sense.
  vm.proceed();
  vm.proceed();
}

void main() {
  test('loads the first sense and exposes its runtime VM', () async {
    final vm = await loadedGroup();
    expect(vm.loaded, isTrue);
    expect(vm.currentSenseId, 'synthetic-01');
    expect(vm.currentVm, isNotNull);
    expect(vm.currentVm!.phase, ExperienceRuntimePhase.conceptUnit);
  });

  test('answers forward to the runtime VM and rebuild the UI (bridge)', () async {
    final vm = await loadedGroup();
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.answer('a1');
    expect(vm.currentVm!.isCurrentUnitAnswered, isTrue);
    expect(notifications, greaterThan(0),
        reason: 'runtime notify must bridge to the group VM');
  });

  test('completing all senses finishes the group with outcomes', () async {
    final vm = await loadedGroup();
    expect(vm.finished, isFalse);
    await completeSense(vm, 1);
    expect(vm.senseIndex, 1);
    expect(vm.finished, isFalse);
    await completeSense(vm, 1);
    expect(vm.finished, isTrue);
    expect(vm.currentVm, isNull);
    expect(vm.outcomes.keys, unorderedEquals(['synthetic-01', 'synthetic-02']));
    final first = vm.outcomes['synthetic-01']!;
    expect(first.totalQuestions, 1);
    expect(first.firstAttemptCorrect, 1);
  });

  group('known check', () {
    test('not offered when the program has no transfer unit', () async {
      final vm = await loadedGroup(program: programJsonWithUnitCount(2));
      expect(vm.canOfferKnownCheck, isFalse);
    });

    test('opening the check exposes the transfer unit; passing skips the '
        'rest of the concept units', () async {
      final vm = await loadedGroup(program: programWithTransferUnit());
      expect(vm.canOfferKnownCheck, isTrue);
      vm.startKnownCheck();
      expect(vm.knownCheckActive, isTrue);
      expect(vm.knownCheckUnit, isNotNull);
      expect(vm.knownCheckUnit!.role, UnitRole.transfer);

      vm.completeKnownCheck(passed: true);
      expect(vm.knownCheckActive, isFalse);
      expect(vm.currentVm!.phase, ExperienceRuntimePhase.symbolBinding,
          reason: 'a passed check skips the remaining concept units');
    });

    test('failing the check returns to the anchor flow', () async {
      final vm = await loadedGroup(program: programWithTransferUnit());
      vm.startKnownCheck();
      vm.completeKnownCheck(passed: false);
      expect(vm.knownCheckActive, isFalse);
      expect(vm.currentVm!.phase, ExperienceRuntimePhase.conceptUnit);
      expect(vm.currentVm!.unitIndex, 0);
    });
  });

  group('resume', () {
    Map<String, dynamic> snapshotOf(GroupSessionViewModel vm) =>
        jsonDecode(vm.toJson()!) as Map<String, dynamic>;

    test('serialized state restores sense index, phase and answers', () async {
      final vm = await loadedGroup();
      vm.answer('a1');
      final serialized = snapshotOf(vm);
      expect(serialized['senseIndex'], 0);
      expect((serialized['currentVm'] as Map)['answers'], isNotEmpty);

      final restored = await loadedGroup();
      await restored.load(restoreState: serialized);
      expect(restored.currentSenseId, 'synthetic-01');
      expect(restored.currentVm!.isCurrentUnitAnswered, isTrue);
      expect(restored.currentVm!.recordFor('unit-1')!.answer.id, 'a1');
    });

    test('restored mid-group state continues to the next sense', () async {
      final vm = await loadedGroup();
      await completeSense(vm, 1);
      final serialized = snapshotOf(vm);
      expect(serialized['senseIndex'], 1);

      final restored = await loadedGroup();
      await restored.load(restoreState: serialized);
      expect(restored.currentSenseId, 'synthetic-02');
      expect(restored.outcomes.keys, contains('synthetic-01'));
    });

    test('restored finished group stays finished', () async {
      final vm = await loadedGroup();
      await completeSense(vm, 1);
      await completeSense(vm, 1);
      final restored = await loadedGroup();
      await restored.load(restoreState: snapshotOf(vm));
      expect(restored.finished, isTrue);
      expect(restored.outcomes, hasLength(2));
    });
  });

  test('error surface: unknown sense id surfaces a load error', () async {
    final vm = await loadedGroup(senseIds: const ['missing-01']);
    expect(vm.errorMessage, isNotNull);
    expect(vm.loaded, isFalse);
  });
}
