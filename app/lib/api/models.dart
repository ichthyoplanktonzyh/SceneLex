/// Wire models for the SceneLex API (camelCase, mirrors the server contracts).
library;

class Sense {
  const Sense({
    required this.wordSenseId,
    required this.senseKey,
    required this.lemma,
    required this.pos,
    required this.semanticType,
    required this.localeL1,
    this.programVersion,
    this.programId,
  });

  final String wordSenseId;
  final String senseKey;
  final String lemma;
  final String pos;
  final String semanticType;
  final String localeL1;
  final int? programVersion;
  final String? programId;

  factory Sense.fromJson(Map<String, dynamic> json) => Sense(
        wordSenseId: json['wordSenseId'] as String,
        senseKey: json['senseKey'] as String,
        lemma: json['lemma'] as String,
        pos: json['pos'] as String? ?? '',
        semanticType: json['semanticType'] as String? ?? '',
        localeL1: json['localeL1'] as String? ?? '',
        programVersion: json['programVersion'] as int?,
        programId: json['programId'] as String?,
      );
}

class ExperienceUnit {
  const ExperienceUnit({
    required this.experienceUnitId,
    required this.stage,
    required this.unitType,
    required this.content,
  });

  final String experienceUnitId;
  final String stage;
  final String unitType;
  final Map<String, dynamic> content;

  factory ExperienceUnit.fromJson(Map<String, dynamic> json) => ExperienceUnit(
        experienceUnitId: json['experienceUnitId'] as String,
        stage: json['stage'] as String,
        unitType: json['unitType'] as String? ?? 'narrative',
        content: (json['content'] as Map<String, dynamic>?) ?? const {},
      );

  String get title => content['title']?.toString() ?? '';
  String get synopsis => content['synopsis']?.toString() ?? '';
  List<dynamic> get learningTasks =>
      (content['learningTasks'] as List<dynamic>?) ?? const [];
}

class ExperienceProgram {
  const ExperienceProgram({
    required this.programId,
    required this.wordSenseId,
    required this.programVersion,
    required this.units,
  });

  final String programId;
  final String wordSenseId;
  final int programVersion;
  final List<ExperienceUnit> units;

  factory ExperienceProgram.fromJson(Map<String, dynamic> json) =>
      ExperienceProgram(
        programId: json['programId'] as String,
        wordSenseId: json['wordSenseId'] as String,
        programVersion: json['programVersion'] as int? ?? 1,
        units: ((json['units'] as List<dynamic>?) ?? const [])
            .map((u) => ExperienceUnit.fromJson(u as Map<String, dynamic>))
            .toList(),
      );
}

/// Per (workspace x sense) scheduler state (from bootstrap/pull payloads).
class LearningState {
  const LearningState({
    required this.wordSenseId,
    required this.reps,
    required this.lapses,
    required this.fsrsCardState,
    this.learningStateId,
    this.dueAt,
    this.fsrsStepIndex,
    this.fsrsStability,
    this.fsrsDifficulty,
    this.fsrsScheduledDays,
    this.fsrsLastReviewedAt,
    this.clientUpdatedAt,
  });

  final String wordSenseId;
  final String? learningStateId;
  final DateTime? dueAt;
  final int reps;
  final int lapses;
  final String fsrsCardState;
  final int? fsrsStepIndex;
  final double? fsrsStability;
  final double? fsrsDifficulty;
  final int? fsrsScheduledDays;
  final DateTime? fsrsLastReviewedAt;
  final String? clientUpdatedAt;

  bool get isNew => fsrsCardState == 'new';

  /// Due for review now (or new).
  bool get isDue {
    if (isNew) return true;
    final due = dueAt;
    return due != null && !due.isAfter(DateTime.now().toUtc());
  }

  factory LearningState.fromJson(Map<String, dynamic> json) => LearningState(
        wordSenseId: json['entityId'] as String,
        learningStateId: json['payload']?['learningStateId'] as String?,
        dueAt: json['payload']?['dueAt'] == null
            ? null
            : DateTime.parse(json['payload']['dueAt'] as String),
        reps: (json['payload']?['reps'] as int?) ?? 0,
        lapses: (json['payload']?['lapses'] as int?) ?? 0,
        fsrsCardState: json['payload']?['fsrsCardState']?.toString() ?? 'new',
        fsrsStepIndex: json['payload']?['fsrsStepIndex'] as int?,
        fsrsStability: (json['payload']?['fsrsStability'] as num?)?.toDouble(),
        fsrsDifficulty: (json['payload']?['fsrsDifficulty'] as num?)?.toDouble(),
        fsrsScheduledDays: json['payload']?['fsrsScheduledDays'] as int?,
        fsrsLastReviewedAt:
            json['payload']?['fsrsLastReviewedAt'] == null
                ? null
                : DateTime.parse(json['payload']['fsrsLastReviewedAt'] as String),
        clientUpdatedAt: json['clientUpdatedAt'] as String?,
      );
}

class AuthSession {
  const AuthSession({required this.token, required this.userId, required this.email});

  final String token;
  final String userId;
  final String email;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        userId: json['user']['userId'] as String,
        email: json['user']['email'] as String,
      );
}

class Workspace {
  const Workspace({
    required this.workspaceId,
    required this.name,
    required this.isSelected,
  });

  final String workspaceId;
  final String name;
  final bool isSelected;

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        workspaceId: json['workspaceId'] as String,
        name: json['name']?.toString() ?? 'Untitled',
        isSelected: json['isSelected'] as bool? ?? false,
      );
}

/// Word list: a smart filter (name + tag rule, at least one tag).
/// Mirrors the sync `list` entity (filterDefinition {version: 2, tags: [...]}).
class WordList {
  const WordList({
    required this.listId,
    required this.name,
    required this.tags,
  });

  final String listId;
  final String name;
  final List<String> tags;

  factory WordList.fromJson(Map<String, dynamic> json) {
    final filter = (json['filterDefinition'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return WordList(
      listId: json['listId'] as String,
      name: json['name']?.toString() ?? 'Untitled',
      tags: ((filter['tags'] as List<dynamic>?) ?? const [])
          .map((t) => t.toString())
          .toList(),
    );
  }

  /// Payload for outbox upsert (entity + LWW metadata).
  Map<String, dynamic> toSyncPayload({
    required String clientUpdatedAt,
    required String lastModifiedByReplicaId,
    required String lastOperationId,
    String? deletedAt,
  }) =>
      {
        'listId': listId,
        'name': name,
        'filterDefinition': {'version': 2, 'tags': tags},
        'clientUpdatedAt': clientUpdatedAt,
        'lastModifiedByReplicaId': lastModifiedByReplicaId,
        'lastOperationId': lastOperationId,
        'deletedAt': deletedAt,
      };
}
