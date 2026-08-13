/// Contract v1 consumer model tests: parsing the real generated bundle,
/// runtime guardrails (status, sequence, answers, grounding).
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/domain/experience_program/experience_program.dart';

import 'fixtures/program_factory.dart';

Future<Map<String, dynamic>> loadBundleRoot() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final text = await rootBundle.loadString(
    'assets/content/experience-programs.v1.json',
  );
  final decoded = jsonDecode(text) as Map<String, dynamic>;
  return Map<String, dynamic>.from(decoded);
}

Future<ExperienceProgram> loadProgram(String senseId) async {
  final root = await loadBundleRoot();
  final programs = Map<String, dynamic>.from(root['programs'] as Map);
  return ExperienceProgram.fromJson(
    Map<String, dynamic>.from(programs[senseId] as Map),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('real bundle', () {
    test('all four programs parse successfully', () async {
      for (final senseId in [
        'reluctant-01',
        'messy-01',
        'almost-01',
        'dirty-01',
      ]) {
        final program = await loadProgram(senseId);
        expect(program.schemaVersion, '1.0');
        expect(program.status, ProgramStatus.reviewed);
        expect(program.symbolBinding.reveal.l2Word, isNotEmpty);
      }
    });

    test('unit counts and role order are preserved', () async {
      final expected = {
        'reluctant-01': [
          'anchor',
          'variation',
          'perturbation',
          'discrimination',
          'transfer',
        ],
        'messy-01': ['anchor', 'variation', 'perturbation', 'transfer'],
        'almost-01': ['anchor', 'variation', 'discrimination', 'transfer'],
        'dirty-01': [
          'anchor',
          'variation',
          'variation',
          'discrimination',
          'transfer',
        ],
      };
      for (final entry in expected.entries) {
        final program = await loadProgram(entry.key);
        expect(
          program.units.map((u) => u.role.name).toList(),
          entry.value,
          reason: '${entry.key} 的 role 顺序必须与源 fixture 一致',
        );
      }
    });

    test('grounding source_experience_id resolves to a real unit', () async {
      final program = await loadProgram('reluctant-01');
      final sourceId = program.grounding.sourceExperienceId;
      expect(program.units.any((u) => u.id == sourceId), isTrue);
    });
  });

  group('runtime guardrails', () {
    test('draft status is rejected', () {
      final json = programJsonWithUnitCount(2)..['status'] = 'draft';
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('unknown status is rejected', () {
      final json = programJsonWithUnitCount(2)..['status'] = 'in-review';
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('schema_version other than 1.0 is rejected', () {
      final json = programJsonWithUnitCount(2)..['schema_version'] = '2.0';
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('empty units are rejected', () {
      expect(
        () => ExperienceProgram.fromJson(programJsonWithUnitCount(0)),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('non-continuous sequence is rejected', () {
      final json = programJsonWithUnitCount(3);
      final units = json['units'] as List<Map<String, Object>>;
      units[2]['sequence'] = 4;
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('zero correct answers are rejected', () {
      final json = programJsonWithUnitCount(1);
      final units = json['units'] as List<Map<String, Object>>;
      final interaction = units[0]['interaction'] as Map<String, Object>;
      final answers = interaction['answers'] as List<Map<String, Object>>;
      for (final answer in answers) {
        answer['is_correct'] = false;
      }
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('two correct answers are rejected', () {
      final json = programJsonWithUnitCount(1);
      final units = json['units'] as List<Map<String, Object>>;
      final interaction = units[0]['interaction'] as Map<String, Object>;
      final answers = interaction['answers'] as List<Map<String, Object>>;
      for (final answer in answers) {
        answer['is_correct'] = true;
      }
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('unknown unit role is rejected', () {
      final json = programJsonWithUnitCount(1);
      final units = json['units'] as List<Map<String, Object>>;
      units[0]['role'] = 'climax';
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('grounding referencing a missing unit is rejected', () {
      final json = programJsonWithUnitCount(2);
      final grounding = Map<String, dynamic>.from(json['grounding'] as Map)
        ..['source_experience_id'] = 'unit-99';
      json['grounding'] = grounding;
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });

    test('duplicate answer ids are rejected', () {
      final json = programJsonWithUnitCount(1);
      final units = json['units'] as List<Map<String, Object>>;
      final interaction = units[0]['interaction'] as Map<String, Object>;
      final answers = interaction['answers'] as List<Map<String, Object>>;
      for (final answer in answers) {
        answer['id'] = 'dup';
      }
      expect(
        () => ExperienceProgram.fromJson(json),
        throwsA(isA<ExperienceProgramFormatException>()),
      );
    });
  });
}
