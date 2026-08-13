/// Immutable, strongly-typed consumer model for the ExperienceProgram
/// Contract v1 (snake_case wire format).
///
/// This model is the *App-side* contract consumer. It deliberately re-checks
/// only crash-safety and release-status guardrails (schema version, status,
/// sequence continuity, answer well-formedness, grounding references). The
/// Compiler's full nine-dimension semantic validation stays on the build
/// side; the App does not re-implement it.
library;

import 'experience_unit.dart';
import 'parsing.dart';
import 'symbol_binding.dart';

/// Raised when a program fails Contract v1 parsing or runtime checks.
class ExperienceProgramFormatException extends FormatException {
  const ExperienceProgramFormatException(super.message, [super.source]);
}

/// Release states an App is allowed to run. `draft` never reaches the App.
enum ProgramStatus { reviewed, published }

/// Release states recognized by Contract v1 wire format.
const Set<String> kProgramStatusWireNames = {'reviewed', 'published'};

/// Target header of a program (the WordSense being taught).
class ProgramTarget {
  const ProgramTarget({
    required this.senseId,
    required this.lemma,
    required this.pos,
    required this.ipa,
    required this.localeL1,
  });

  factory ProgramTarget.fromJson(Map<String, dynamic> json) => ProgramTarget(
    senseId: jsonString(json, 'sense_id'),
    lemma: jsonString(json, 'lemma'),
    pos: jsonString(json, 'pos'),
    ipa: jsonString(json, 'ipa'),
    localeL1: jsonString(json, 'locale_l1'),
  );

  final String senseId;
  final String lemma;
  final String pos;
  final String ipa;
  final String localeL1;
}

/// Metadata attached to a program. The Runtime only keeps the raw record;
/// nothing in here is rendered by the learner-facing UI.
class ProgramMetadata {
  const ProgramMetadata({required this.raw});

  factory ProgramMetadata.fromJson(Map<String, dynamic> json) =>
      ProgramMetadata(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;
}

/// Contract v1 ExperienceProgram: one teachable, versioned semantic program.
class ExperienceProgram {
  const ExperienceProgram({
    required this.schemaVersion,
    required this.programId,
    required this.programVersion,
    required this.status,
    required this.target,
    required this.units,
    required this.symbolBinding,
    required this.grounding,
    required this.reviewPool,
    required this.metadata,
    required this.semanticModel,
  });

  /// Parses and runtime-checks a Contract v1 program map.
  ///
  /// Throws [ExperienceProgramFormatException] on any violation. This is a
  /// crash-safety and release-status gate, not the Compiler's semantic gate.
  factory ExperienceProgram.fromJson(Map<String, dynamic> json) {
    final schemaVersion = jsonString(json, 'schema_version');
    if (schemaVersion != '1.0') {
      throw ExperienceProgramFormatException(
        'schema_version 必须是 "1.0"，实际是 "$schemaVersion"',
      );
    }

    final statusWire = jsonString(json, 'status');
    if (!kProgramStatusWireNames.contains(statusWire)) {
      throw ExperienceProgramFormatException(
        'status 必须是 reviewed 或 published，实际是 "$statusWire"',
      );
    }
    final status = ProgramStatus.values.firstWhere(
      (s) => s.name == statusWire,
      orElse: () =>
          throw ExperienceProgramFormatException('未知 status "$statusWire"'),
    );

    final programId = jsonString(json, 'program_id');
    final programVersion = jsonInt(json, 'program_version');
    if (programVersion < 1) {
      throw ExperienceProgramFormatException(
        'program_version 必须 >= 1，实际是 $programVersion',
      );
    }
    final target = ProgramTarget.fromJson(jsonMap(json, 'target'));

    final unitsJson = jsonList(json, 'units');
    if (unitsJson.isEmpty) {
      throw const ExperienceProgramFormatException('units 不能为空');
    }
    final units = <ExperienceUnit>[];
    for (final (index, raw) in unitsJson.indexed) {
      final unit = ExperienceUnit.fromJson(
        (raw as Map<String, dynamic>),
        index: index,
      );
      if (unit.sequence != index + 1) {
        throw ExperienceProgramFormatException(
          'unit[${index + 1}] 的 sequence=${unit.sequence}，'
          '必须与数组顺序一致 (${index + 1})',
        );
      }
      units.add(unit);
    }

    final binding = SymbolBinding.fromJson(jsonMap(json, 'symbol_binding'));
    final grounding = Grounding.fromJson(jsonMap(json, 'grounding'));
    if (!units.any((u) => u.id == grounding.sourceExperienceId)) {
      throw ExperienceProgramFormatException(
        'grounding.source_experience_id "${grounding.sourceExperienceId}" '
        '找不到对应 unit',
      );
    }
    final reviewPool = jsonList(json, 'review_pool')
        .map((raw) => ReviewItem.fromJson(raw as Map<String, dynamic>))
        .toList(growable: false);

    final semanticModel = json['semantic_model'];
    if (semanticModel != null && semanticModel is! Map) {
      throw const ExperienceProgramFormatException('semantic_model 必须是对象');
    }

    return ExperienceProgram(
      schemaVersion: schemaVersion,
      programId: programId,
      programVersion: programVersion,
      status: status,
      target: target,
      units: List<ExperienceUnit>.unmodifiable(units),
      symbolBinding: binding,
      grounding: grounding,
      reviewPool: reviewPool,
      metadata: ProgramMetadata.fromJson(jsonMap(json, 'metadata')),
      semanticModel: semanticModel is Map
          ? Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(semanticModel),
            )
          : null,
    );
  }

  final String schemaVersion;
  final String programId;
  final int programVersion;
  final ProgramStatus status;
  final ProgramTarget target;
  final List<ExperienceUnit> units;
  final SymbolBinding symbolBinding;
  final Grounding grounding;
  final List<ReviewItem> reviewPool;
  final ProgramMetadata metadata;

  /// The Compiler's semantic model. Kept for future downstream use; the
  /// learner-facing UI must never render it.
  final Map<String, dynamic>? semanticModel;
}
