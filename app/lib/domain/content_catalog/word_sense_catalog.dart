/// WordSense catalog — consumer-facing content directory.
///
/// The catalog is the formal App entry point to content: one entry per
/// WordSense, linking to its currently released ExperienceProgram
/// (program_id + program_version). It carries the semantic_type,
/// locale_l1, a plain-language invariant and l1 confusables that are safe to
/// render, and an explicit boundaries list (currently empty until content
/// provides `relations.boundaries` data).
///
/// Compiler internals (semantic_model, quality_gate, ...) are never part of
/// catalog entries; the bundle generator extracts consumer fields explicitly.
library;

import '../experience_program/experience_program.dart';

/// One WordSense in the catalog.
class WordSenseCatalogEntry {
  const WordSenseCatalogEntry({
    required this.senseId,
    required this.senseKey,
    required this.lemma,
    required this.pos,
    this.ipa,
    required this.semanticType,
    required this.localeL1,
    required this.invariant,
    required this.l1Confusables,
    required this.boundaries,
    required this.boundariesStatus,
    required this.programId,
    required this.programVersion,
  });

  factory WordSenseCatalogEntry.fromJson(Map<String, dynamic> json) {
    final schema = 'word_sense_catalog_entry';
    String requireString(String key) {
      final value = json[key];
      if (value is String) return value;
      throw ExperienceProgramFormatException(
        '$schema: $key 必须是字符串，实际是 ${value.runtimeType}',
      );
    }

    int requireInt(String key) {
      final value = json[key];
      if (value is int) return value;
      throw ExperienceProgramFormatException(
        '$schema: $key 必须是整数，实际是 ${value.runtimeType}',
      );
    }

    final rawBoundaries = json['boundaries'];
    if (rawBoundaries is! List) {
      throw ExperienceProgramFormatException('$schema: boundaries 必须是数组');
    }
    final rawConfusables = json['l1_confusables'];
    if (rawConfusables is! List || rawConfusables.any((e) => e is! String)) {
      throw ExperienceProgramFormatException(
        '$schema: l1_confusables 必须是字符串数组',
      );
    }
    return WordSenseCatalogEntry(
      senseId: requireString('sense_id'),
      senseKey: requireString('sense_key'),
      lemma: requireString('lemma'),
      pos: requireString('pos'),
      ipa: json['ipa'] is String ? json['ipa'] as String : null,
      semanticType: requireString('semantic_type'),
      localeL1: requireString('locale_l1'),
      invariant: requireString('invariant'),
      l1Confusables: List<String>.unmodifiable(rawConfusables.cast<String>()),
      boundaries: List<WordSenseBoundary>.unmodifiable(
        rawBoundaries
            .whereType<Map>()
            .map(
              (e) => WordSenseBoundary.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      ),
      boundariesStatus: requireString('boundaries_status'),
      programId: requireString('program_id'),
      programVersion: requireInt('program_version'),
    );
  }

  final String senseId;
  final String senseKey;
  final String lemma;
  final String pos;
  final String? ipa;
  final String semanticType;
  final String localeL1;

  /// Plain-language statement of what the sense means (extracted, renderable).
  final String invariant;

  /// L1 confusions the learner is prone to (extracted, renderable).
  final List<String> l1Confusables;

  /// Boundary relations to other senses. Currently empty: content has not
  /// collected `relations.boundaries` yet.
  final List<WordSenseBoundary> boundaries;

  /// 'not_collected' until content provides boundary data.
  final String boundariesStatus;

  final String programId;
  final int programVersion;
}

/// A boundary relation between two WordSenses (relations.boundaries entry).
class WordSenseBoundary {
  const WordSenseBoundary({
    required this.targetSenseId,
    required this.relationType,
    required this.description,
    required this.diagnostic,
  });

  factory WordSenseBoundary.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is String) return value;
      throw ExperienceProgramFormatException(
        'word_sense_boundary: $key 必须是字符串，实际是 ${value.runtimeType}',
      );
    }

    return WordSenseBoundary(
      targetSenseId: requireString('target_sense_id'),
      relationType: requireString('relation_type'),
      description: requireString('description'),
      diagnostic: requireString('diagnostic'),
    );
  }

  final String targetSenseId;
  final String relationType;
  final String description;
  final String diagnostic;
}

/// An immutable snapshot of the content catalog.
class WordSenseCatalog {
  const WordSenseCatalog({
    required this.senses,
    required this.bundleVersion,
    required this.schemaVersion,
  });

  factory WordSenseCatalog.fromJson(Map<String, dynamic> root) {
    final rawCatalog = root['catalog'];
    if (rawCatalog is! Map) {
      throw const ExperienceProgramFormatException('catalog 必须是对象');
    }
    final senses = <String, WordSenseCatalogEntry>{};
    rawCatalog.forEach((senseId, raw) {
      if (raw is! Map) {
        throw ExperienceProgramFormatException('catalog[$senseId] 必须是对象');
      }
      final entry = WordSenseCatalogEntry.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (entry.senseId != senseId) {
        throw ExperienceProgramFormatException(
          'catalog key $senseId 与 entry.sense_id ${entry.senseId} 不一致',
        );
      }
      senses[senseId] = entry;
    });
    final bundleVersion = root['bundle_version'];
    final schemaVersion = root['schema_version'];
    return WordSenseCatalog(
      senses: Map.unmodifiable(senses),
      bundleVersion: bundleVersion is int ? bundleVersion : 0,
      schemaVersion: schemaVersion is String ? schemaVersion : '',
    );
  }

  final Map<String, WordSenseCatalogEntry> senses;
  final int bundleVersion;
  final String schemaVersion;

  WordSenseCatalogEntry entryFor(String senseId) => senses[senseId]!;

  bool contains(String senseId) => senses.containsKey(senseId);

  List<WordSenseCatalogEntry> get ordered => List.unmodifiable(senses.values);
}
