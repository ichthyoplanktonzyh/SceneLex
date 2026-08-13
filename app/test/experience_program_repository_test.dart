/// BundledExperienceProgramRepository tests: caching, error distinction,
/// release-status guardrail.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';

const String _validBundle = '''
{
  "bundle_version": 1,
  "schema_version": "1.0",
  "programs": {
    "test-01": {
      "schema_version": "1.0",
      "program_id": "test-program",
      "program_version": 1,
      "status": "reviewed",
      "target": {
        "sense_id": "test-01",
        "lemma": "test",
        "pos": "noun",
        "ipa": "t",
        "locale_l1": "zh"
      },
      "units": [
        {
          "id": "unit-1",
          "sequence": 1,
          "role": "anchor",
          "experience": {
            "episode": "e",
            "observable_evidence": ["o"],
            "surface_dimensions": [
              {"name": "d", "baseline": "b", "deviation": "v"}
            ]
          },
          "interaction": {
            "question": "q",
            "answers": [
              {"id": "a1", "text": "correct", "is_correct": true, "feedback": "f"},
              {"id": "a2", "text": "wrong", "is_correct": false, "feedback": "f"}
            ]
          }
        }
      ],
      "symbol_binding": {
        "reveal": {
          "l2_word": "test",
          "ipa": "t",
          "presentation": "p"
        },
        "minimal_l1_gloss": "测试"
      },
      "grounding": {
        "source_experience_id": "unit-1",
        "l2_realization": "r",
        "constructions": ["c"],
        "collocations": ["c"]
      },
      "review_pool": [],
      "metadata": {"compiler_version": "1.0.0"}
    }
  }
}
''';

void main() {
  group('BundledExperienceProgramRepository', () {
    test('loads a reviewed program', () async {
      final repo = BundledExperienceProgramRepository(
        bundleLoader: () async => _validBundle,
      );
      final program = await repo.load('test-01');
      expect(program.target.senseId, 'test-01');
      expect(program.units.single.role.name, 'anchor');
    });

    test('parses the bundle exactly once and caches', () async {
      var loaderCalls = 0;
      final repo = BundledExperienceProgramRepository(
        bundleLoader: () async {
          loaderCalls += 1;
          return _validBundle;
        },
      );
      await repo.load('test-01');
      await repo.load('test-01');
      expect(loaderCalls, 1);
    });

    test('unknown sense -> SenseNotFoundException', () async {
      final repo = BundledExperienceProgramRepository(
        bundleLoader: () async => _validBundle,
      );
      expect(
        () => repo.load('nope-01'),
        throwsA(isA<SenseNotFoundException>()),
      );
    });

    test('corrupt bundle JSON -> ExperienceProgramCorruptException', () async {
      final repo = BundledExperienceProgramRepository(
        bundleLoader: () async => '{not json',
      );
      expect(
        () => repo.load('test-01'),
        throwsA(isA<ExperienceProgramCorruptException>()),
      );
    });

    test(
      'draft program in bundle -> ExperienceProgramNotReviewableException',
      () async {
        final root = jsonDecode(_validBundle) as Map<String, dynamic>;
        final programs = Map<String, dynamic>.from(root['programs'] as Map);
        final program = Map<String, dynamic>.from(programs['test-01'] as Map)
          ..['status'] = 'draft';
        programs['test-01'] = program;
        final text = jsonEncode({'programs': programs});
        final repo = BundledExperienceProgramRepository(
          bundleLoader: () async => text,
        );
        expect(
          () => repo.load('test-01'),
          throwsA(isA<ExperienceProgramNotReviewableException>()),
        );
      },
    );

    test('structurally broken program -> corrupt (no crash)', () async {
      final root = jsonDecode(_validBundle) as Map<String, dynamic>;
      final programs = Map<String, dynamic>.from(root['programs'] as Map);
      final program = Map<String, dynamic>.from(programs['test-01'] as Map)
        ..['units'] = [];
      programs['test-01'] = program;
      final repo = BundledExperienceProgramRepository(
        bundleLoader: () async => jsonEncode({'programs': programs}),
      );
      expect(
        () => repo.load('test-01'),
        throwsA(isA<ExperienceProgramCorruptException>()),
      );
    });
  });
}
