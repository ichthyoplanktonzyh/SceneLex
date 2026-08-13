/// Learner-visible building blocks of a Contract v1 ExperienceProgram unit.
///
/// Every unit carries one experience plus one interaction. The Compiler-side
/// planning fields (hypothesis_target, preserved/changed variables,
/// semantic_spec) are kept only as raw records — the learner-facing UI must
/// never render them.
library;

import 'parsing.dart';
import 'experience_program.dart';

/// Teaching primitive of a unit. The contract does not require any fixed
/// role combination or ordering.
enum UnitRole { anchor, variation, perturbation, discrimination, transfer }

const Set<String> kUnitRoleWireNames = {
  'anchor',
  'variation',
  'perturbation',
  'discrimination',
  'transfer',
};

/// One ordered step of the first-run learning flow.
class ExperienceUnit {
  const ExperienceUnit({
    required this.id,
    required this.sequence,
    required this.role,
    required this.hypothesisTarget,
    required this.preservedVariables,
    required this.changedVariables,
    required this.semanticSpec,
    required this.experience,
    required this.interaction,
  });

  factory ExperienceUnit.fromJson(
    Map<String, dynamic> json, {
    required int index,
  }) {
    final roleWire = jsonString(json, 'role');
    if (!kUnitRoleWireNames.contains(roleWire)) {
      throw ExperienceProgramFormatException(
        'unit[${index + 1}] 的 role "$roleWire" 不是 Contract v1 合法值',
      );
    }
    final hypothesisTarget = json['hypothesis_target'];
    if (hypothesisTarget != null && hypothesisTarget is! String) {
      throw const ExperienceProgramFormatException(
        'hypothesis_target 必须是字符串或 null',
      );
    }
    final preserved = json['preserved_variables'];
    final changed = json['changed_variables'];
    if (preserved != null && preserved is! List) {
      throw const ExperienceProgramFormatException('preserved_variables 必须是数组');
    }
    if (changed != null && changed is! List) {
      throw const ExperienceProgramFormatException('changed_variables 必须是数组');
    }
    final spec = json['semantic_spec'];
    if (spec != null && spec is! Map) {
      throw const ExperienceProgramFormatException('semantic_spec 必须是对象');
    }
    return ExperienceUnit(
      id: jsonString(json, 'id'),
      sequence: jsonInt(json, 'sequence'),
      role: UnitRole.values.firstWhere((r) => r.name == roleWire),
      hypothesisTarget: hypothesisTarget as String?,
      preservedVariables: preserved == null
          ? const []
          : List<String>.unmodifiable(preserved.map((e) => e as String)),
      changedVariables: changed == null
          ? const []
          : List<String>.unmodifiable(changed.map((e) => e as String)),
      semanticSpec: spec is Map
          ? Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(spec))
          : null,
      experience: Experience.fromJson(jsonMap(json, 'experience')),
      interaction: Interaction.fromJson(jsonMap(json, 'interaction')),
    );
  }

  final String id;
  final int sequence;
  final UnitRole role;

  /// Compiler planning field; kept raw, never rendered by learner UI.
  final String? hypothesisTarget;

  /// Compiler planning fields; kept raw, never rendered by learner UI.
  final List<String> preservedVariables;
  final List<String> changedVariables;

  /// Compiler planning field; kept raw, never rendered by learner UI.
  final Map<String, dynamic>? semanticSpec;

  final Experience experience;
  final Interaction interaction;
}

/// A model-independent teaching scene (episode + observable evidence +
/// surface dimensions).
class Experience {
  const Experience({
    required this.episode,
    required this.observableEvidence,
    required this.surfaceDimensions,
  });

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
    episode: jsonString(json, 'episode'),
    observableEvidence: jsonStringList(json, 'observable_evidence'),
    surfaceDimensions: (jsonList(json, 'surface_dimensions'))
        .map((raw) => SurfaceDimension.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String episode;
  final List<String> observableEvidence;
  final List<SurfaceDimension> surfaceDimensions;
}

/// One measurable surface dimension: a baseline and its deviation.
class SurfaceDimension {
  const SurfaceDimension({
    required this.name,
    required this.baseline,
    required this.deviation,
  });

  factory SurfaceDimension.fromJson(Map<String, dynamic> json) =>
      SurfaceDimension(
        name: jsonString(json, 'name'),
        baseline: jsonString(json, 'baseline'),
        deviation: jsonString(json, 'deviation'),
      );

  final String name;
  final String baseline;
  final String deviation;
}

/// One question with its answers.
class Interaction {
  const Interaction({required this.question, required this.answers});

  factory Interaction.fromJson(Map<String, dynamic> json) {
    final answers = (jsonList(json, 'answers'))
        .map((raw) => Answer.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);
    final correctCount = answers.where((a) => a.isCorrect).length;
    if (correctCount != 1) {
      throw ExperienceProgramFormatException(
        'interaction 必须恰好一个 is_correct=true，实际是 $correctCount 个',
      );
    }
    if (answers.isEmpty) {
      throw const ExperienceProgramFormatException('interaction.answers 不能为空');
    }
    final ids = answers.map((a) => a.id).toSet();
    if (ids.length != answers.length) {
      throw const ExperienceProgramFormatException(
        'interaction.answers id 必须唯一',
      );
    }
    return Interaction(
      question: jsonString(json, 'question'),
      answers: answers,
    );
  }

  final String question;
  final List<Answer> answers;

  Answer get correctAnswer => answers.firstWhere((a) => a.isCorrect);
}

/// One answer option with its post-answer feedback.
class Answer {
  const Answer({
    required this.id,
    required this.text,
    required this.isCorrect,
    required this.feedback,
  });

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
    id: jsonString(json, 'id'),
    text: jsonString(json, 'text'),
    isCorrect: jsonBool(json, 'is_correct'),
    feedback: jsonString(json, 'feedback'),
  );

  final String id;
  final String text;
  final bool isCorrect;
  final String feedback;
}
