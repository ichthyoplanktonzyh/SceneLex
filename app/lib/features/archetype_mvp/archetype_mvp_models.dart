/// Teaching Archetype MVP — domain models.
///
/// The MVP is a standalone 14-day simulation over the real Holistic Course
/// bundle (`app/assets/content/archetype-mvp.v1.json`): courses come from
/// the Course Author (never re-planned here), the curriculum only decides
/// which new course becomes available on which day, and scheduling uses
/// the Author-declared `due_after_days` + `can_pause_after` + time budget.
library;

import 'package:flutter/foundation.dart';

import '../holistic_course_prototype/holistic_course_models.dart';

/// Course lifecycle phases (per spec §10.4).
enum CoursePhase {
  unseen,
  inCourse,
  symbolBound,
  consolidating,
  stable,
  needsRemediation;

  static CoursePhase parse(String? raw) => switch (raw) {
    'in_course' => CoursePhase.inCourse,
    'symbol_bound' => CoursePhase.symbolBound,
    'consolidating' => CoursePhase.consolidating,
    'stable' => CoursePhase.stable,
    'needs_remediation' => CoursePhase.needsRemediation,
    _ => CoursePhase.unseen,
  };
}

/// One teaching archetype from the manifest (advisory, not user-visible
/// modes).
@immutable
class MvpArchetype {
  const MvpArchetype({
    required this.id,
    required this.semanticTypes,
    required this.teachingArchetype,
    required this.experienceMechanism,
    required this.suggestedCapabilities,
    required this.specialRisks,
    required this.pairs,
  });

  factory MvpArchetype.fromJson(Map<String, dynamic> json) => MvpArchetype(
    id: json['id'] as String? ?? '',
    semanticTypes: [
      for (final s in (json['semantic_types'] as List?) ?? const [])
        s as String,
    ],
    teachingArchetype: json['teaching_archetype'] as String? ?? '',
    experienceMechanism: json['experience_mechanism'] as String? ?? '',
    suggestedCapabilities: [
      for (final c in (json['suggested_capabilities'] as List?) ?? const [])
        c as String,
    ],
    specialRisks: [
      for (final r in (json['special_risks'] as List?) ?? const []) r as String,
    ],
    pairs: [
      for (final p in (json['pairs'] as List?) ?? const [])
        if (p is Map) MvpPair.fromJson(p.cast<String, dynamic>()),
    ],
  );

  final String id;
  final List<String> semanticTypes;
  final String teachingArchetype;
  final String experienceMechanism;
  final List<String> suggestedCapabilities;
  final List<String> specialRisks;
  final List<MvpPair> pairs;
}

/// A minimal pair: both senses, boundary answer allowance, course order.
@immutable
class MvpPair {
  const MvpPair({
    required this.pairId,
    required this.between,
    required this.allowed,
    required this.insufficientEvidenceAllowed,
    required this.courses,
  });

  factory MvpPair.fromJson(Map<String, dynamic> json) => MvpPair(
    pairId: json['pair_id'] as String? ?? '',
    between: [
      for (final s in (json['between'] as List?) ?? const []) s as String,
    ],
    allowed: json['allowed'] as String? ?? 'one',
    insufficientEvidenceAllowed: json['insufficient_evidence_allowed'] == true,
    courses: [
      for (final c in (json['courses'] as List?) ?? const []) c as String,
    ],
  );

  final String pairId;
  final List<String> between;
  final String allowed;
  final bool insufficientEvidenceAllowed;
  final List<String> courses;
}

/// The whole MVP bundle (byte-stable, built by
/// tools/build_archetype_mvp_bundle.py).
@immutable
class MvpBundle {
  const MvpBundle({
    required this.schemaVersion,
    required this.bundleVersion,
    required this.capabilityVersion,
    required this.curriculum,
    required this.archetypes,
    required this.pairRelations,
    required this.courses,
    required this.inputDigests,
  });

  factory MvpBundle.fromJson(Map<String, dynamic> json) => MvpBundle(
    schemaVersion: json['schema_version'] as String? ?? '',
    bundleVersion: json['bundle_version'] as int? ?? 0,
    capabilityVersion: json['capability_version'] as int? ?? 0,
    curriculum: [
      for (final entry in (json['curriculum'] as List?) ?? const [])
        if (entry is Map) (entry.cast<String, dynamic>()),
    ],
    archetypes: [
      for (final a in (json['archetypes'] as List?) ?? const [])
        if (a is Map) MvpArchetype.fromJson(a.cast<String, dynamic>()),
    ],
    pairRelations: [
      for (final p in (json['pair_relations'] as List?) ?? const [])
        if (p is Map) MvpPair.fromJson(p.cast<String, dynamic>()),
    ],
    courses: {
      for (final course in (json['courses'] as List?) ?? const [])
        if (course is Map)
          MvpBundle._courseKey(course): HolisticCourse.fromJson(
            course.cast<String, dynamic>(),
          ),
    },
    inputDigests: {
      for (final entry
          in ((json['input_digests'] as Map?) ?? const <String, dynamic>{})
              .entries)
        entry.key: entry.value as String,
    },
  );

  static String _courseKey(Map<dynamic, dynamic> course) {
    final target = course['target'];
    return (target is Map ? target['sense_id'] : null) as String? ?? '';
  }

  final String schemaVersion;
  final int bundleVersion;
  final int capabilityVersion;

  /// [{day: 1, course: 'messy-01'}, ...] — only decides which new course
  /// becomes available on which day.
  final List<Map<String, dynamic>> curriculum;
  final List<MvpArchetype> archetypes;
  final List<MvpPair> pairRelations;

  /// sense_id → lowered Holistic Course.
  final Map<String, HolisticCourse> courses;
  final Map<String, String> inputDigests;

  HolisticCourse? courseFor(String senseId) => courses[senseId];

  /// The archetype id that owns this sense (dev overview / completion).
  String? archetypeFor(String senseId) {
    for (final archetype in archetypes) {
      for (final pair in archetype.pairs) {
        if (pair.courses.contains(senseId)) return archetype.id;
      }
    }
    return null;
  }

  /// Day on which this course enters the candidate range (1-based).
  int? curriculumDayFor(String senseId) {
    for (final entry in curriculum) {
      if (entry['course'] == senseId) return entry['day'] as int?;
    }
    return null;
  }

  /// Ordered course ids by curriculum day (unstarted courses only matter).
  List<String> get orderedCourseIds => [
    for (final entry in curriculum) entry['course'] as String,
  ];
}

/// Memory-only progress of one course (mock clock; no persistence).
@immutable
class CourseProgress {
  const CourseProgress({
    required this.senseId,
    this.phase = CoursePhase.unseen,
    this.nextStepIndex = 0,
    this.bindingDay,
    this.errorCount = 0,
    this.failedStepIds = const {},
    this.completedReviewIds = const {},
    this.lastAnswers = const {},
  });

  final String senseId;
  final CoursePhase phase;

  /// Index of the next step to run in the course's strict order.
  final int nextStepIndex;
  final int? bindingDay;
  final int errorCount;

  /// Steps answered wrong with no Author-declared on_error recovery.
  final Set<String> failedStepIds;

  /// Review items already completed (by step id).
  final Set<String> completedReviewIds;

  /// step id → last learner answer (dev overview).
  final Map<String, String> lastAnswers;

  CourseProgress copyWith({
    CoursePhase? phase,
    int? nextStepIndex,
    int? bindingDay,
    int? errorCount,
    Set<String>? failedStepIds,
    Set<String>? completedReviewIds,
    Map<String, String>? lastAnswers,
  }) => CourseProgress(
    senseId: senseId,
    phase: phase ?? this.phase,
    nextStepIndex: nextStepIndex ?? this.nextStepIndex,
    bindingDay: bindingDay ?? this.bindingDay,
    errorCount: errorCount ?? this.errorCount,
    failedStepIds: failedStepIds ?? this.failedStepIds,
    completedReviewIds: completedReviewIds ?? this.completedReviewIds,
    lastAnswers: lastAnswers ?? this.lastAnswers,
  );

  bool get bound => phase.index >= CoursePhase.symbolBound.index;
}

/// Session mode — real planner inputs, not UI filters.
enum SessionMode { normal, reviewOnly, newOnly }
