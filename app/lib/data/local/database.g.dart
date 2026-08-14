// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalLearningStatesTable extends LocalLearningStates
    with TableInfo<$LocalLearningStatesTable, LocalLearningState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLearningStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordSenseIdMeta = const VerificationMeta(
    'wordSenseId',
  );
  @override
  late final GeneratedColumn<String> wordSenseId = GeneratedColumn<String>(
    'word_sense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _learningStateIdMeta = const VerificationMeta(
    'learningStateId',
  );
  @override
  late final GeneratedColumn<String> learningStateId = GeneratedColumn<String>(
    'learning_state_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fsrsStabilityMeta = const VerificationMeta(
    'fsrsStability',
  );
  @override
  late final GeneratedColumn<double> fsrsStability = GeneratedColumn<double>(
    'fsrs_stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fsrsDifficultyMeta = const VerificationMeta(
    'fsrsDifficulty',
  );
  @override
  late final GeneratedColumn<double> fsrsDifficulty = GeneratedColumn<double>(
    'fsrs_difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fsrsLastReviewedAtMeta =
      const VerificationMeta('fsrsLastReviewedAt');
  @override
  late final GeneratedColumn<DateTime> fsrsLastReviewedAt =
      GeneratedColumn<DateTime>(
        'fsrs_last_reviewed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fsrsScheduledDaysMeta = const VerificationMeta(
    'fsrsScheduledDays',
  );
  @override
  late final GeneratedColumn<int> fsrsScheduledDays = GeneratedColumn<int>(
    'fsrs_scheduled_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fsrsCardStateMeta = const VerificationMeta(
    'fsrsCardState',
  );
  @override
  late final GeneratedColumn<String> fsrsCardState = GeneratedColumn<String>(
    'fsrs_card_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fsrsStepIndexMeta = const VerificationMeta(
    'fsrsStepIndex',
  );
  @override
  late final GeneratedColumn<int> fsrsStepIndex = GeneratedColumn<int>(
    'fsrs_step_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastModifiedByReplicaIdMeta =
      const VerificationMeta('lastModifiedByReplicaId');
  @override
  late final GeneratedColumn<String> lastModifiedByReplicaId =
      GeneratedColumn<String>(
        'last_modified_by_replica_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastOperationIdMeta = const VerificationMeta(
    'lastOperationId',
  );
  @override
  late final GeneratedColumn<String> lastOperationId = GeneratedColumn<String>(
    'last_operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordSenseId,
    learningStateId,
    dueAt,
    reps,
    lapses,
    fsrsStability,
    fsrsDifficulty,
    fsrsLastReviewedAt,
    fsrsScheduledDays,
    fsrsCardState,
    fsrsStepIndex,
    clientUpdatedAt,
    lastModifiedByReplicaId,
    lastOperationId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_learning_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLearningState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_sense_id')) {
      context.handle(
        _wordSenseIdMeta,
        wordSenseId.isAcceptableOrUnknown(
          data['word_sense_id']!,
          _wordSenseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wordSenseIdMeta);
    }
    if (data.containsKey('learning_state_id')) {
      context.handle(
        _learningStateIdMeta,
        learningStateId.isAcceptableOrUnknown(
          data['learning_state_id']!,
          _learningStateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningStateIdMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    } else if (isInserting) {
      context.missing(_lapsesMeta);
    }
    if (data.containsKey('fsrs_stability')) {
      context.handle(
        _fsrsStabilityMeta,
        fsrsStability.isAcceptableOrUnknown(
          data['fsrs_stability']!,
          _fsrsStabilityMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_difficulty')) {
      context.handle(
        _fsrsDifficultyMeta,
        fsrsDifficulty.isAcceptableOrUnknown(
          data['fsrs_difficulty']!,
          _fsrsDifficultyMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_last_reviewed_at')) {
      context.handle(
        _fsrsLastReviewedAtMeta,
        fsrsLastReviewedAt.isAcceptableOrUnknown(
          data['fsrs_last_reviewed_at']!,
          _fsrsLastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_scheduled_days')) {
      context.handle(
        _fsrsScheduledDaysMeta,
        fsrsScheduledDays.isAcceptableOrUnknown(
          data['fsrs_scheduled_days']!,
          _fsrsScheduledDaysMeta,
        ),
      );
    }
    if (data.containsKey('fsrs_card_state')) {
      context.handle(
        _fsrsCardStateMeta,
        fsrsCardState.isAcceptableOrUnknown(
          data['fsrs_card_state']!,
          _fsrsCardStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fsrsCardStateMeta);
    }
    if (data.containsKey('fsrs_step_index')) {
      context.handle(
        _fsrsStepIndexMeta,
        fsrsStepIndex.isAcceptableOrUnknown(
          data['fsrs_step_index']!,
          _fsrsStepIndexMeta,
        ),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('last_modified_by_replica_id')) {
      context.handle(
        _lastModifiedByReplicaIdMeta,
        lastModifiedByReplicaId.isAcceptableOrUnknown(
          data['last_modified_by_replica_id']!,
          _lastModifiedByReplicaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedByReplicaIdMeta);
    }
    if (data.containsKey('last_operation_id')) {
      context.handle(
        _lastOperationIdMeta,
        lastOperationId.isAcceptableOrUnknown(
          data['last_operation_id']!,
          _lastOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOperationIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordSenseId};
  @override
  LocalLearningState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLearningState(
      wordSenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_sense_id'],
      )!,
      learningStateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_state_id'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      fsrsStability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fsrs_stability'],
      ),
      fsrsDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fsrs_difficulty'],
      ),
      fsrsLastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fsrs_last_reviewed_at'],
      ),
      fsrsScheduledDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fsrs_scheduled_days'],
      ),
      fsrsCardState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fsrs_card_state'],
      )!,
      fsrsStepIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fsrs_step_index'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      )!,
      lastModifiedByReplicaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by_replica_id'],
      )!,
      lastOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_operation_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LocalLearningStatesTable createAlias(String alias) {
    return $LocalLearningStatesTable(attachedDatabase, alias);
  }
}

class LocalLearningState extends DataClass
    implements Insertable<LocalLearningState> {
  final String wordSenseId;
  final String learningStateId;
  final DateTime? dueAt;
  final int reps;
  final int lapses;
  final double? fsrsStability;
  final double? fsrsDifficulty;
  final DateTime? fsrsLastReviewedAt;
  final int? fsrsScheduledDays;
  final String fsrsCardState;
  final int? fsrsStepIndex;
  final String clientUpdatedAt;
  final String lastModifiedByReplicaId;
  final String lastOperationId;
  final DateTime? deletedAt;
  const LocalLearningState({
    required this.wordSenseId,
    required this.learningStateId,
    this.dueAt,
    required this.reps,
    required this.lapses,
    this.fsrsStability,
    this.fsrsDifficulty,
    this.fsrsLastReviewedAt,
    this.fsrsScheduledDays,
    required this.fsrsCardState,
    this.fsrsStepIndex,
    required this.clientUpdatedAt,
    required this.lastModifiedByReplicaId,
    required this.lastOperationId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_sense_id'] = Variable<String>(wordSenseId);
    map['learning_state_id'] = Variable<String>(learningStateId);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    if (!nullToAbsent || fsrsStability != null) {
      map['fsrs_stability'] = Variable<double>(fsrsStability);
    }
    if (!nullToAbsent || fsrsDifficulty != null) {
      map['fsrs_difficulty'] = Variable<double>(fsrsDifficulty);
    }
    if (!nullToAbsent || fsrsLastReviewedAt != null) {
      map['fsrs_last_reviewed_at'] = Variable<DateTime>(fsrsLastReviewedAt);
    }
    if (!nullToAbsent || fsrsScheduledDays != null) {
      map['fsrs_scheduled_days'] = Variable<int>(fsrsScheduledDays);
    }
    map['fsrs_card_state'] = Variable<String>(fsrsCardState);
    if (!nullToAbsent || fsrsStepIndex != null) {
      map['fsrs_step_index'] = Variable<int>(fsrsStepIndex);
    }
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['last_modified_by_replica_id'] = Variable<String>(
      lastModifiedByReplicaId,
    );
    map['last_operation_id'] = Variable<String>(lastOperationId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalLearningStatesCompanion toCompanion(bool nullToAbsent) {
    return LocalLearningStatesCompanion(
      wordSenseId: Value(wordSenseId),
      learningStateId: Value(learningStateId),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      reps: Value(reps),
      lapses: Value(lapses),
      fsrsStability: fsrsStability == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsStability),
      fsrsDifficulty: fsrsDifficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsDifficulty),
      fsrsLastReviewedAt: fsrsLastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsLastReviewedAt),
      fsrsScheduledDays: fsrsScheduledDays == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsScheduledDays),
      fsrsCardState: Value(fsrsCardState),
      fsrsStepIndex: fsrsStepIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(fsrsStepIndex),
      clientUpdatedAt: Value(clientUpdatedAt),
      lastModifiedByReplicaId: Value(lastModifiedByReplicaId),
      lastOperationId: Value(lastOperationId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalLearningState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLearningState(
      wordSenseId: serializer.fromJson<String>(json['wordSenseId']),
      learningStateId: serializer.fromJson<String>(json['learningStateId']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
      fsrsStability: serializer.fromJson<double?>(json['fsrsStability']),
      fsrsDifficulty: serializer.fromJson<double?>(json['fsrsDifficulty']),
      fsrsLastReviewedAt: serializer.fromJson<DateTime?>(
        json['fsrsLastReviewedAt'],
      ),
      fsrsScheduledDays: serializer.fromJson<int?>(json['fsrsScheduledDays']),
      fsrsCardState: serializer.fromJson<String>(json['fsrsCardState']),
      fsrsStepIndex: serializer.fromJson<int?>(json['fsrsStepIndex']),
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      lastModifiedByReplicaId: serializer.fromJson<String>(
        json['lastModifiedByReplicaId'],
      ),
      lastOperationId: serializer.fromJson<String>(json['lastOperationId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordSenseId': serializer.toJson<String>(wordSenseId),
      'learningStateId': serializer.toJson<String>(learningStateId),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
      'fsrsStability': serializer.toJson<double?>(fsrsStability),
      'fsrsDifficulty': serializer.toJson<double?>(fsrsDifficulty),
      'fsrsLastReviewedAt': serializer.toJson<DateTime?>(fsrsLastReviewedAt),
      'fsrsScheduledDays': serializer.toJson<int?>(fsrsScheduledDays),
      'fsrsCardState': serializer.toJson<String>(fsrsCardState),
      'fsrsStepIndex': serializer.toJson<int?>(fsrsStepIndex),
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'lastModifiedByReplicaId': serializer.toJson<String>(
        lastModifiedByReplicaId,
      ),
      'lastOperationId': serializer.toJson<String>(lastOperationId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalLearningState copyWith({
    String? wordSenseId,
    String? learningStateId,
    Value<DateTime?> dueAt = const Value.absent(),
    int? reps,
    int? lapses,
    Value<double?> fsrsStability = const Value.absent(),
    Value<double?> fsrsDifficulty = const Value.absent(),
    Value<DateTime?> fsrsLastReviewedAt = const Value.absent(),
    Value<int?> fsrsScheduledDays = const Value.absent(),
    String? fsrsCardState,
    Value<int?> fsrsStepIndex = const Value.absent(),
    String? clientUpdatedAt,
    String? lastModifiedByReplicaId,
    String? lastOperationId,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocalLearningState(
    wordSenseId: wordSenseId ?? this.wordSenseId,
    learningStateId: learningStateId ?? this.learningStateId,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    fsrsStability: fsrsStability.present
        ? fsrsStability.value
        : this.fsrsStability,
    fsrsDifficulty: fsrsDifficulty.present
        ? fsrsDifficulty.value
        : this.fsrsDifficulty,
    fsrsLastReviewedAt: fsrsLastReviewedAt.present
        ? fsrsLastReviewedAt.value
        : this.fsrsLastReviewedAt,
    fsrsScheduledDays: fsrsScheduledDays.present
        ? fsrsScheduledDays.value
        : this.fsrsScheduledDays,
    fsrsCardState: fsrsCardState ?? this.fsrsCardState,
    fsrsStepIndex: fsrsStepIndex.present
        ? fsrsStepIndex.value
        : this.fsrsStepIndex,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    lastModifiedByReplicaId:
        lastModifiedByReplicaId ?? this.lastModifiedByReplicaId,
    lastOperationId: lastOperationId ?? this.lastOperationId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocalLearningState copyWithCompanion(LocalLearningStatesCompanion data) {
    return LocalLearningState(
      wordSenseId: data.wordSenseId.present
          ? data.wordSenseId.value
          : this.wordSenseId,
      learningStateId: data.learningStateId.present
          ? data.learningStateId.value
          : this.learningStateId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      fsrsStability: data.fsrsStability.present
          ? data.fsrsStability.value
          : this.fsrsStability,
      fsrsDifficulty: data.fsrsDifficulty.present
          ? data.fsrsDifficulty.value
          : this.fsrsDifficulty,
      fsrsLastReviewedAt: data.fsrsLastReviewedAt.present
          ? data.fsrsLastReviewedAt.value
          : this.fsrsLastReviewedAt,
      fsrsScheduledDays: data.fsrsScheduledDays.present
          ? data.fsrsScheduledDays.value
          : this.fsrsScheduledDays,
      fsrsCardState: data.fsrsCardState.present
          ? data.fsrsCardState.value
          : this.fsrsCardState,
      fsrsStepIndex: data.fsrsStepIndex.present
          ? data.fsrsStepIndex.value
          : this.fsrsStepIndex,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      lastModifiedByReplicaId: data.lastModifiedByReplicaId.present
          ? data.lastModifiedByReplicaId.value
          : this.lastModifiedByReplicaId,
      lastOperationId: data.lastOperationId.present
          ? data.lastOperationId.value
          : this.lastOperationId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLearningState(')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('learningStateId: $learningStateId, ')
          ..write('dueAt: $dueAt, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('fsrsStability: $fsrsStability, ')
          ..write('fsrsDifficulty: $fsrsDifficulty, ')
          ..write('fsrsLastReviewedAt: $fsrsLastReviewedAt, ')
          ..write('fsrsScheduledDays: $fsrsScheduledDays, ')
          ..write('fsrsCardState: $fsrsCardState, ')
          ..write('fsrsStepIndex: $fsrsStepIndex, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('lastModifiedByReplicaId: $lastModifiedByReplicaId, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    wordSenseId,
    learningStateId,
    dueAt,
    reps,
    lapses,
    fsrsStability,
    fsrsDifficulty,
    fsrsLastReviewedAt,
    fsrsScheduledDays,
    fsrsCardState,
    fsrsStepIndex,
    clientUpdatedAt,
    lastModifiedByReplicaId,
    lastOperationId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLearningState &&
          other.wordSenseId == this.wordSenseId &&
          other.learningStateId == this.learningStateId &&
          other.dueAt == this.dueAt &&
          other.reps == this.reps &&
          other.lapses == this.lapses &&
          other.fsrsStability == this.fsrsStability &&
          other.fsrsDifficulty == this.fsrsDifficulty &&
          other.fsrsLastReviewedAt == this.fsrsLastReviewedAt &&
          other.fsrsScheduledDays == this.fsrsScheduledDays &&
          other.fsrsCardState == this.fsrsCardState &&
          other.fsrsStepIndex == this.fsrsStepIndex &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.lastModifiedByReplicaId == this.lastModifiedByReplicaId &&
          other.lastOperationId == this.lastOperationId &&
          other.deletedAt == this.deletedAt);
}

class LocalLearningStatesCompanion extends UpdateCompanion<LocalLearningState> {
  final Value<String> wordSenseId;
  final Value<String> learningStateId;
  final Value<DateTime?> dueAt;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<double?> fsrsStability;
  final Value<double?> fsrsDifficulty;
  final Value<DateTime?> fsrsLastReviewedAt;
  final Value<int?> fsrsScheduledDays;
  final Value<String> fsrsCardState;
  final Value<int?> fsrsStepIndex;
  final Value<String> clientUpdatedAt;
  final Value<String> lastModifiedByReplicaId;
  final Value<String> lastOperationId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalLearningStatesCompanion({
    this.wordSenseId = const Value.absent(),
    this.learningStateId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.fsrsStability = const Value.absent(),
    this.fsrsDifficulty = const Value.absent(),
    this.fsrsLastReviewedAt = const Value.absent(),
    this.fsrsScheduledDays = const Value.absent(),
    this.fsrsCardState = const Value.absent(),
    this.fsrsStepIndex = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.lastModifiedByReplicaId = const Value.absent(),
    this.lastOperationId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLearningStatesCompanion.insert({
    required String wordSenseId,
    required String learningStateId,
    this.dueAt = const Value.absent(),
    required int reps,
    required int lapses,
    this.fsrsStability = const Value.absent(),
    this.fsrsDifficulty = const Value.absent(),
    this.fsrsLastReviewedAt = const Value.absent(),
    this.fsrsScheduledDays = const Value.absent(),
    required String fsrsCardState,
    this.fsrsStepIndex = const Value.absent(),
    required String clientUpdatedAt,
    required String lastModifiedByReplicaId,
    required String lastOperationId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordSenseId = Value(wordSenseId),
       learningStateId = Value(learningStateId),
       reps = Value(reps),
       lapses = Value(lapses),
       fsrsCardState = Value(fsrsCardState),
       clientUpdatedAt = Value(clientUpdatedAt),
       lastModifiedByReplicaId = Value(lastModifiedByReplicaId),
       lastOperationId = Value(lastOperationId);
  static Insertable<LocalLearningState> custom({
    Expression<String>? wordSenseId,
    Expression<String>? learningStateId,
    Expression<DateTime>? dueAt,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<double>? fsrsStability,
    Expression<double>? fsrsDifficulty,
    Expression<DateTime>? fsrsLastReviewedAt,
    Expression<int>? fsrsScheduledDays,
    Expression<String>? fsrsCardState,
    Expression<int>? fsrsStepIndex,
    Expression<String>? clientUpdatedAt,
    Expression<String>? lastModifiedByReplicaId,
    Expression<String>? lastOperationId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordSenseId != null) 'word_sense_id': wordSenseId,
      if (learningStateId != null) 'learning_state_id': learningStateId,
      if (dueAt != null) 'due_at': dueAt,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (fsrsStability != null) 'fsrs_stability': fsrsStability,
      if (fsrsDifficulty != null) 'fsrs_difficulty': fsrsDifficulty,
      if (fsrsLastReviewedAt != null)
        'fsrs_last_reviewed_at': fsrsLastReviewedAt,
      if (fsrsScheduledDays != null) 'fsrs_scheduled_days': fsrsScheduledDays,
      if (fsrsCardState != null) 'fsrs_card_state': fsrsCardState,
      if (fsrsStepIndex != null) 'fsrs_step_index': fsrsStepIndex,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (lastModifiedByReplicaId != null)
        'last_modified_by_replica_id': lastModifiedByReplicaId,
      if (lastOperationId != null) 'last_operation_id': lastOperationId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLearningStatesCompanion copyWith({
    Value<String>? wordSenseId,
    Value<String>? learningStateId,
    Value<DateTime?>? dueAt,
    Value<int>? reps,
    Value<int>? lapses,
    Value<double?>? fsrsStability,
    Value<double?>? fsrsDifficulty,
    Value<DateTime?>? fsrsLastReviewedAt,
    Value<int?>? fsrsScheduledDays,
    Value<String>? fsrsCardState,
    Value<int?>? fsrsStepIndex,
    Value<String>? clientUpdatedAt,
    Value<String>? lastModifiedByReplicaId,
    Value<String>? lastOperationId,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return LocalLearningStatesCompanion(
      wordSenseId: wordSenseId ?? this.wordSenseId,
      learningStateId: learningStateId ?? this.learningStateId,
      dueAt: dueAt ?? this.dueAt,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      fsrsStability: fsrsStability ?? this.fsrsStability,
      fsrsDifficulty: fsrsDifficulty ?? this.fsrsDifficulty,
      fsrsLastReviewedAt: fsrsLastReviewedAt ?? this.fsrsLastReviewedAt,
      fsrsScheduledDays: fsrsScheduledDays ?? this.fsrsScheduledDays,
      fsrsCardState: fsrsCardState ?? this.fsrsCardState,
      fsrsStepIndex: fsrsStepIndex ?? this.fsrsStepIndex,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      lastModifiedByReplicaId:
          lastModifiedByReplicaId ?? this.lastModifiedByReplicaId,
      lastOperationId: lastOperationId ?? this.lastOperationId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordSenseId.present) {
      map['word_sense_id'] = Variable<String>(wordSenseId.value);
    }
    if (learningStateId.present) {
      map['learning_state_id'] = Variable<String>(learningStateId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (fsrsStability.present) {
      map['fsrs_stability'] = Variable<double>(fsrsStability.value);
    }
    if (fsrsDifficulty.present) {
      map['fsrs_difficulty'] = Variable<double>(fsrsDifficulty.value);
    }
    if (fsrsLastReviewedAt.present) {
      map['fsrs_last_reviewed_at'] = Variable<DateTime>(
        fsrsLastReviewedAt.value,
      );
    }
    if (fsrsScheduledDays.present) {
      map['fsrs_scheduled_days'] = Variable<int>(fsrsScheduledDays.value);
    }
    if (fsrsCardState.present) {
      map['fsrs_card_state'] = Variable<String>(fsrsCardState.value);
    }
    if (fsrsStepIndex.present) {
      map['fsrs_step_index'] = Variable<int>(fsrsStepIndex.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (lastModifiedByReplicaId.present) {
      map['last_modified_by_replica_id'] = Variable<String>(
        lastModifiedByReplicaId.value,
      );
    }
    if (lastOperationId.present) {
      map['last_operation_id'] = Variable<String>(lastOperationId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLearningStatesCompanion(')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('learningStateId: $learningStateId, ')
          ..write('dueAt: $dueAt, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('fsrsStability: $fsrsStability, ')
          ..write('fsrsDifficulty: $fsrsDifficulty, ')
          ..write('fsrsLastReviewedAt: $fsrsLastReviewedAt, ')
          ..write('fsrsScheduledDays: $fsrsScheduledDays, ')
          ..write('fsrsCardState: $fsrsCardState, ')
          ..write('fsrsStepIndex: $fsrsStepIndex, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('lastModifiedByReplicaId: $lastModifiedByReplicaId, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalReviewEventsTable extends LocalReviewEvents
    with TableInfo<$LocalReviewEventsTable, LocalReviewEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalReviewEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reviewEventIdMeta = const VerificationMeta(
    'reviewEventId',
  );
  @override
  late final GeneratedColumn<String> reviewEventId = GeneratedColumn<String>(
    'review_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordSenseIdMeta = const VerificationMeta(
    'wordSenseId',
  );
  @override
  late final GeneratedColumn<String> wordSenseId = GeneratedColumn<String>(
    'word_sense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programVersionMeta = const VerificationMeta(
    'programVersion',
  );
  @override
  late final GeneratedColumn<int> programVersion = GeneratedColumn<int>(
    'program_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _experienceUnitIdMeta = const VerificationMeta(
    'experienceUnitId',
  );
  @override
  late final GeneratedColumn<String> experienceUnitId = GeneratedColumn<String>(
    'experience_unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewedAtClientMeta = const VerificationMeta(
    'reviewedAtClient',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAtClient =
      GeneratedColumn<DateTime>(
        'reviewed_at_client',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _reviewedTimeZoneMeta = const VerificationMeta(
    'reviewedTimeZone',
  );
  @override
  late final GeneratedColumn<String> reviewedTimeZone = GeneratedColumn<String>(
    'reviewed_time_zone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewedLocalDateMeta = const VerificationMeta(
    'reviewedLocalDate',
  );
  @override
  late final GeneratedColumn<String> reviewedLocalDate =
      GeneratedColumn<String>(
        'reviewed_local_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    reviewEventId,
    wordSenseId,
    programVersion,
    experienceUnitId,
    rating,
    reviewedAtClient,
    reviewedTimeZone,
    reviewedLocalDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_review_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalReviewEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('review_event_id')) {
      context.handle(
        _reviewEventIdMeta,
        reviewEventId.isAcceptableOrUnknown(
          data['review_event_id']!,
          _reviewEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewEventIdMeta);
    }
    if (data.containsKey('word_sense_id')) {
      context.handle(
        _wordSenseIdMeta,
        wordSenseId.isAcceptableOrUnknown(
          data['word_sense_id']!,
          _wordSenseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wordSenseIdMeta);
    }
    if (data.containsKey('program_version')) {
      context.handle(
        _programVersionMeta,
        programVersion.isAcceptableOrUnknown(
          data['program_version']!,
          _programVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programVersionMeta);
    }
    if (data.containsKey('experience_unit_id')) {
      context.handle(
        _experienceUnitIdMeta,
        experienceUnitId.isAcceptableOrUnknown(
          data['experience_unit_id']!,
          _experienceUnitIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_experienceUnitIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('reviewed_at_client')) {
      context.handle(
        _reviewedAtClientMeta,
        reviewedAtClient.isAcceptableOrUnknown(
          data['reviewed_at_client']!,
          _reviewedAtClientMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtClientMeta);
    }
    if (data.containsKey('reviewed_time_zone')) {
      context.handle(
        _reviewedTimeZoneMeta,
        reviewedTimeZone.isAcceptableOrUnknown(
          data['reviewed_time_zone']!,
          _reviewedTimeZoneMeta,
        ),
      );
    }
    if (data.containsKey('reviewed_local_date')) {
      context.handle(
        _reviewedLocalDateMeta,
        reviewedLocalDate.isAcceptableOrUnknown(
          data['reviewed_local_date']!,
          _reviewedLocalDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reviewEventId};
  @override
  LocalReviewEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalReviewEvent(
      reviewEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_event_id'],
      )!,
      wordSenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_sense_id'],
      )!,
      programVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_version'],
      )!,
      experienceUnitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}experience_unit_id'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      reviewedAtClient: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at_client'],
      )!,
      reviewedTimeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_time_zone'],
      ),
      reviewedLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reviewed_local_date'],
      ),
    );
  }

  @override
  $LocalReviewEventsTable createAlias(String alias) {
    return $LocalReviewEventsTable(attachedDatabase, alias);
  }
}

class LocalReviewEvent extends DataClass
    implements Insertable<LocalReviewEvent> {
  final String reviewEventId;
  final String wordSenseId;
  final int programVersion;
  final String experienceUnitId;
  final int rating;
  final DateTime reviewedAtClient;
  final String? reviewedTimeZone;
  final String? reviewedLocalDate;
  const LocalReviewEvent({
    required this.reviewEventId,
    required this.wordSenseId,
    required this.programVersion,
    required this.experienceUnitId,
    required this.rating,
    required this.reviewedAtClient,
    this.reviewedTimeZone,
    this.reviewedLocalDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['review_event_id'] = Variable<String>(reviewEventId);
    map['word_sense_id'] = Variable<String>(wordSenseId);
    map['program_version'] = Variable<int>(programVersion);
    map['experience_unit_id'] = Variable<String>(experienceUnitId);
    map['rating'] = Variable<int>(rating);
    map['reviewed_at_client'] = Variable<DateTime>(reviewedAtClient);
    if (!nullToAbsent || reviewedTimeZone != null) {
      map['reviewed_time_zone'] = Variable<String>(reviewedTimeZone);
    }
    if (!nullToAbsent || reviewedLocalDate != null) {
      map['reviewed_local_date'] = Variable<String>(reviewedLocalDate);
    }
    return map;
  }

  LocalReviewEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalReviewEventsCompanion(
      reviewEventId: Value(reviewEventId),
      wordSenseId: Value(wordSenseId),
      programVersion: Value(programVersion),
      experienceUnitId: Value(experienceUnitId),
      rating: Value(rating),
      reviewedAtClient: Value(reviewedAtClient),
      reviewedTimeZone: reviewedTimeZone == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedTimeZone),
      reviewedLocalDate: reviewedLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedLocalDate),
    );
  }

  factory LocalReviewEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalReviewEvent(
      reviewEventId: serializer.fromJson<String>(json['reviewEventId']),
      wordSenseId: serializer.fromJson<String>(json['wordSenseId']),
      programVersion: serializer.fromJson<int>(json['programVersion']),
      experienceUnitId: serializer.fromJson<String>(json['experienceUnitId']),
      rating: serializer.fromJson<int>(json['rating']),
      reviewedAtClient: serializer.fromJson<DateTime>(json['reviewedAtClient']),
      reviewedTimeZone: serializer.fromJson<String?>(json['reviewedTimeZone']),
      reviewedLocalDate: serializer.fromJson<String?>(
        json['reviewedLocalDate'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reviewEventId': serializer.toJson<String>(reviewEventId),
      'wordSenseId': serializer.toJson<String>(wordSenseId),
      'programVersion': serializer.toJson<int>(programVersion),
      'experienceUnitId': serializer.toJson<String>(experienceUnitId),
      'rating': serializer.toJson<int>(rating),
      'reviewedAtClient': serializer.toJson<DateTime>(reviewedAtClient),
      'reviewedTimeZone': serializer.toJson<String?>(reviewedTimeZone),
      'reviewedLocalDate': serializer.toJson<String?>(reviewedLocalDate),
    };
  }

  LocalReviewEvent copyWith({
    String? reviewEventId,
    String? wordSenseId,
    int? programVersion,
    String? experienceUnitId,
    int? rating,
    DateTime? reviewedAtClient,
    Value<String?> reviewedTimeZone = const Value.absent(),
    Value<String?> reviewedLocalDate = const Value.absent(),
  }) => LocalReviewEvent(
    reviewEventId: reviewEventId ?? this.reviewEventId,
    wordSenseId: wordSenseId ?? this.wordSenseId,
    programVersion: programVersion ?? this.programVersion,
    experienceUnitId: experienceUnitId ?? this.experienceUnitId,
    rating: rating ?? this.rating,
    reviewedAtClient: reviewedAtClient ?? this.reviewedAtClient,
    reviewedTimeZone: reviewedTimeZone.present
        ? reviewedTimeZone.value
        : this.reviewedTimeZone,
    reviewedLocalDate: reviewedLocalDate.present
        ? reviewedLocalDate.value
        : this.reviewedLocalDate,
  );
  LocalReviewEvent copyWithCompanion(LocalReviewEventsCompanion data) {
    return LocalReviewEvent(
      reviewEventId: data.reviewEventId.present
          ? data.reviewEventId.value
          : this.reviewEventId,
      wordSenseId: data.wordSenseId.present
          ? data.wordSenseId.value
          : this.wordSenseId,
      programVersion: data.programVersion.present
          ? data.programVersion.value
          : this.programVersion,
      experienceUnitId: data.experienceUnitId.present
          ? data.experienceUnitId.value
          : this.experienceUnitId,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviewedAtClient: data.reviewedAtClient.present
          ? data.reviewedAtClient.value
          : this.reviewedAtClient,
      reviewedTimeZone: data.reviewedTimeZone.present
          ? data.reviewedTimeZone.value
          : this.reviewedTimeZone,
      reviewedLocalDate: data.reviewedLocalDate.present
          ? data.reviewedLocalDate.value
          : this.reviewedLocalDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalReviewEvent(')
          ..write('reviewEventId: $reviewEventId, ')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('programVersion: $programVersion, ')
          ..write('experienceUnitId: $experienceUnitId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAtClient: $reviewedAtClient, ')
          ..write('reviewedTimeZone: $reviewedTimeZone, ')
          ..write('reviewedLocalDate: $reviewedLocalDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    reviewEventId,
    wordSenseId,
    programVersion,
    experienceUnitId,
    rating,
    reviewedAtClient,
    reviewedTimeZone,
    reviewedLocalDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalReviewEvent &&
          other.reviewEventId == this.reviewEventId &&
          other.wordSenseId == this.wordSenseId &&
          other.programVersion == this.programVersion &&
          other.experienceUnitId == this.experienceUnitId &&
          other.rating == this.rating &&
          other.reviewedAtClient == this.reviewedAtClient &&
          other.reviewedTimeZone == this.reviewedTimeZone &&
          other.reviewedLocalDate == this.reviewedLocalDate);
}

class LocalReviewEventsCompanion extends UpdateCompanion<LocalReviewEvent> {
  final Value<String> reviewEventId;
  final Value<String> wordSenseId;
  final Value<int> programVersion;
  final Value<String> experienceUnitId;
  final Value<int> rating;
  final Value<DateTime> reviewedAtClient;
  final Value<String?> reviewedTimeZone;
  final Value<String?> reviewedLocalDate;
  final Value<int> rowid;
  const LocalReviewEventsCompanion({
    this.reviewEventId = const Value.absent(),
    this.wordSenseId = const Value.absent(),
    this.programVersion = const Value.absent(),
    this.experienceUnitId = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviewedAtClient = const Value.absent(),
    this.reviewedTimeZone = const Value.absent(),
    this.reviewedLocalDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalReviewEventsCompanion.insert({
    required String reviewEventId,
    required String wordSenseId,
    required int programVersion,
    required String experienceUnitId,
    required int rating,
    required DateTime reviewedAtClient,
    this.reviewedTimeZone = const Value.absent(),
    this.reviewedLocalDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : reviewEventId = Value(reviewEventId),
       wordSenseId = Value(wordSenseId),
       programVersion = Value(programVersion),
       experienceUnitId = Value(experienceUnitId),
       rating = Value(rating),
       reviewedAtClient = Value(reviewedAtClient);
  static Insertable<LocalReviewEvent> custom({
    Expression<String>? reviewEventId,
    Expression<String>? wordSenseId,
    Expression<int>? programVersion,
    Expression<String>? experienceUnitId,
    Expression<int>? rating,
    Expression<DateTime>? reviewedAtClient,
    Expression<String>? reviewedTimeZone,
    Expression<String>? reviewedLocalDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reviewEventId != null) 'review_event_id': reviewEventId,
      if (wordSenseId != null) 'word_sense_id': wordSenseId,
      if (programVersion != null) 'program_version': programVersion,
      if (experienceUnitId != null) 'experience_unit_id': experienceUnitId,
      if (rating != null) 'rating': rating,
      if (reviewedAtClient != null) 'reviewed_at_client': reviewedAtClient,
      if (reviewedTimeZone != null) 'reviewed_time_zone': reviewedTimeZone,
      if (reviewedLocalDate != null) 'reviewed_local_date': reviewedLocalDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalReviewEventsCompanion copyWith({
    Value<String>? reviewEventId,
    Value<String>? wordSenseId,
    Value<int>? programVersion,
    Value<String>? experienceUnitId,
    Value<int>? rating,
    Value<DateTime>? reviewedAtClient,
    Value<String?>? reviewedTimeZone,
    Value<String?>? reviewedLocalDate,
    Value<int>? rowid,
  }) {
    return LocalReviewEventsCompanion(
      reviewEventId: reviewEventId ?? this.reviewEventId,
      wordSenseId: wordSenseId ?? this.wordSenseId,
      programVersion: programVersion ?? this.programVersion,
      experienceUnitId: experienceUnitId ?? this.experienceUnitId,
      rating: rating ?? this.rating,
      reviewedAtClient: reviewedAtClient ?? this.reviewedAtClient,
      reviewedTimeZone: reviewedTimeZone ?? this.reviewedTimeZone,
      reviewedLocalDate: reviewedLocalDate ?? this.reviewedLocalDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reviewEventId.present) {
      map['review_event_id'] = Variable<String>(reviewEventId.value);
    }
    if (wordSenseId.present) {
      map['word_sense_id'] = Variable<String>(wordSenseId.value);
    }
    if (programVersion.present) {
      map['program_version'] = Variable<int>(programVersion.value);
    }
    if (experienceUnitId.present) {
      map['experience_unit_id'] = Variable<String>(experienceUnitId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (reviewedAtClient.present) {
      map['reviewed_at_client'] = Variable<DateTime>(reviewedAtClient.value);
    }
    if (reviewedTimeZone.present) {
      map['reviewed_time_zone'] = Variable<String>(reviewedTimeZone.value);
    }
    if (reviewedLocalDate.present) {
      map['reviewed_local_date'] = Variable<String>(reviewedLocalDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalReviewEventsCompanion(')
          ..write('reviewEventId: $reviewEventId, ')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('programVersion: $programVersion, ')
          ..write('experienceUnitId: $experienceUnitId, ')
          ..write('rating: $rating, ')
          ..write('reviewedAtClient: $reviewedAtClient, ')
          ..write('reviewedTimeZone: $reviewedTimeZone, ')
          ..write('reviewedLocalDate: $reviewedLocalDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxRecordsTable extends OutboxRecords
    with TableInfo<$OutboxRecordsTable, OutboxRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    workspaceId,
    entityType,
    entityId,
    action,
    clientUpdatedAt,
    payloadJson,
    attemptCount,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  OutboxRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRecord(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxRecordsTable createAlias(String alias) {
    return $OutboxRecordsTable(attachedDatabase, alias);
  }
}

class OutboxRecord extends DataClass implements Insertable<OutboxRecord> {
  final String operationId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final String action;
  final String clientUpdatedAt;
  final String payloadJson;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  const OutboxRecord({
    required this.operationId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.clientUpdatedAt,
    required this.payloadJson,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['payload_json'] = Variable<String>(payloadJson);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxRecordsCompanion toCompanion(bool nullToAbsent) {
    return OutboxRecordsCompanion(
      operationId: Value(operationId),
      workspaceId: Value(workspaceId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      clientUpdatedAt: Value(clientUpdatedAt),
      payloadJson: Value(payloadJson),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRecord(
      operationId: serializer.fromJson<String>(json['operationId']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxRecord copyWith({
    String? operationId,
    String? workspaceId,
    String? entityType,
    String? entityId,
    String? action,
    String? clientUpdatedAt,
    String? payloadJson,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxRecord(
    operationId: operationId ?? this.operationId,
    workspaceId: workspaceId ?? this.workspaceId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    payloadJson: payloadJson ?? this.payloadJson,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRecord copyWithCompanion(OutboxRecordsCompanion data) {
    return OutboxRecord(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRecord(')
          ..write('operationId: $operationId, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    workspaceId,
    entityType,
    entityId,
    action,
    clientUpdatedAt,
    payloadJson,
    attemptCount,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRecord &&
          other.operationId == this.operationId &&
          other.workspaceId == this.workspaceId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.payloadJson == this.payloadJson &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxRecordsCompanion extends UpdateCompanion<OutboxRecord> {
  final Value<String> operationId;
  final Value<String> workspaceId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> action;
  final Value<String> clientUpdatedAt;
  final Value<String> payloadJson;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxRecordsCompanion({
    this.operationId = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxRecordsCompanion.insert({
    required String operationId,
    required String workspaceId,
    required String entityType,
    required String entityId,
    required String action,
    required String clientUpdatedAt,
    required String payloadJson,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       workspaceId = Value(workspaceId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       action = Value(action),
       clientUpdatedAt = Value(clientUpdatedAt),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<OutboxRecord> custom({
    Expression<String>? operationId,
    Expression<String>? workspaceId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<String>? clientUpdatedAt,
    Expression<String>? payloadJson,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxRecordsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? workspaceId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? action,
    Value<String>? clientUpdatedAt,
    Value<String>? payloadJson,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxRecordsCompanion(
      operationId: operationId ?? this.operationId,
      workspaceId: workspaceId ?? this.workspaceId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      payloadJson: payloadJson ?? this.payloadJson,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRecordsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTableTable extends SyncStateTable
    with TableInfo<$SyncStateTableTable, SyncStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAppliedHotChangeIdMeta =
      const VerificationMeta('lastAppliedHotChangeId');
  @override
  late final GeneratedColumn<int> lastAppliedHotChangeId = GeneratedColumn<int>(
    'last_applied_hot_change_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAppliedReviewSequenceIdMeta =
      const VerificationMeta('lastAppliedReviewSequenceId');
  @override
  late final GeneratedColumn<int> lastAppliedReviewSequenceId =
      GeneratedColumn<int>(
        'last_applied_review_sequence_id',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _hasHydratedHotStateMeta =
      const VerificationMeta('hasHydratedHotState');
  @override
  late final GeneratedColumn<bool> hasHydratedHotState = GeneratedColumn<bool>(
    'has_hydrated_hot_state',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_hydrated_hot_state" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasHydratedReviewHistoryMeta =
      const VerificationMeta('hasHydratedReviewHistory');
  @override
  late final GeneratedColumn<bool> hasHydratedReviewHistory =
      GeneratedColumn<bool>(
        'has_hydrated_review_history',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_hydrated_review_history" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    workspaceId,
    lastAppliedHotChangeId,
    lastAppliedReviewSequenceId,
    hasHydratedHotState,
    hasHydratedReviewHistory,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('last_applied_hot_change_id')) {
      context.handle(
        _lastAppliedHotChangeIdMeta,
        lastAppliedHotChangeId.isAcceptableOrUnknown(
          data['last_applied_hot_change_id']!,
          _lastAppliedHotChangeIdMeta,
        ),
      );
    }
    if (data.containsKey('last_applied_review_sequence_id')) {
      context.handle(
        _lastAppliedReviewSequenceIdMeta,
        lastAppliedReviewSequenceId.isAcceptableOrUnknown(
          data['last_applied_review_sequence_id']!,
          _lastAppliedReviewSequenceIdMeta,
        ),
      );
    }
    if (data.containsKey('has_hydrated_hot_state')) {
      context.handle(
        _hasHydratedHotStateMeta,
        hasHydratedHotState.isAcceptableOrUnknown(
          data['has_hydrated_hot_state']!,
          _hasHydratedHotStateMeta,
        ),
      );
    }
    if (data.containsKey('has_hydrated_review_history')) {
      context.handle(
        _hasHydratedReviewHistoryMeta,
        hasHydratedReviewHistory.isAcceptableOrUnknown(
          data['has_hydrated_review_history']!,
          _hasHydratedReviewHistoryMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId};
  @override
  SyncStateTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateTableData(
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      )!,
      lastAppliedHotChangeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_applied_hot_change_id'],
      )!,
      lastAppliedReviewSequenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_applied_review_sequence_id'],
      )!,
      hasHydratedHotState: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_hydrated_hot_state'],
      )!,
      hasHydratedReviewHistory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_hydrated_review_history'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncStateTableTable createAlias(String alias) {
    return $SyncStateTableTable(attachedDatabase, alias);
  }
}

class SyncStateTableData extends DataClass
    implements Insertable<SyncStateTableData> {
  final String workspaceId;
  final int lastAppliedHotChangeId;
  final int lastAppliedReviewSequenceId;
  final bool hasHydratedHotState;
  final bool hasHydratedReviewHistory;
  final DateTime updatedAt;
  const SyncStateTableData({
    required this.workspaceId,
    required this.lastAppliedHotChangeId,
    required this.lastAppliedReviewSequenceId,
    required this.hasHydratedHotState,
    required this.hasHydratedReviewHistory,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['last_applied_hot_change_id'] = Variable<int>(lastAppliedHotChangeId);
    map['last_applied_review_sequence_id'] = Variable<int>(
      lastAppliedReviewSequenceId,
    );
    map['has_hydrated_hot_state'] = Variable<bool>(hasHydratedHotState);
    map['has_hydrated_review_history'] = Variable<bool>(
      hasHydratedReviewHistory,
    );
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncStateTableCompanion toCompanion(bool nullToAbsent) {
    return SyncStateTableCompanion(
      workspaceId: Value(workspaceId),
      lastAppliedHotChangeId: Value(lastAppliedHotChangeId),
      lastAppliedReviewSequenceId: Value(lastAppliedReviewSequenceId),
      hasHydratedHotState: Value(hasHydratedHotState),
      hasHydratedReviewHistory: Value(hasHydratedReviewHistory),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateTableData(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      lastAppliedHotChangeId: serializer.fromJson<int>(
        json['lastAppliedHotChangeId'],
      ),
      lastAppliedReviewSequenceId: serializer.fromJson<int>(
        json['lastAppliedReviewSequenceId'],
      ),
      hasHydratedHotState: serializer.fromJson<bool>(
        json['hasHydratedHotState'],
      ),
      hasHydratedReviewHistory: serializer.fromJson<bool>(
        json['hasHydratedReviewHistory'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'lastAppliedHotChangeId': serializer.toJson<int>(lastAppliedHotChangeId),
      'lastAppliedReviewSequenceId': serializer.toJson<int>(
        lastAppliedReviewSequenceId,
      ),
      'hasHydratedHotState': serializer.toJson<bool>(hasHydratedHotState),
      'hasHydratedReviewHistory': serializer.toJson<bool>(
        hasHydratedReviewHistory,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncStateTableData copyWith({
    String? workspaceId,
    int? lastAppliedHotChangeId,
    int? lastAppliedReviewSequenceId,
    bool? hasHydratedHotState,
    bool? hasHydratedReviewHistory,
    DateTime? updatedAt,
  }) => SyncStateTableData(
    workspaceId: workspaceId ?? this.workspaceId,
    lastAppliedHotChangeId:
        lastAppliedHotChangeId ?? this.lastAppliedHotChangeId,
    lastAppliedReviewSequenceId:
        lastAppliedReviewSequenceId ?? this.lastAppliedReviewSequenceId,
    hasHydratedHotState: hasHydratedHotState ?? this.hasHydratedHotState,
    hasHydratedReviewHistory:
        hasHydratedReviewHistory ?? this.hasHydratedReviewHistory,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncStateTableData copyWithCompanion(SyncStateTableCompanion data) {
    return SyncStateTableData(
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      lastAppliedHotChangeId: data.lastAppliedHotChangeId.present
          ? data.lastAppliedHotChangeId.value
          : this.lastAppliedHotChangeId,
      lastAppliedReviewSequenceId: data.lastAppliedReviewSequenceId.present
          ? data.lastAppliedReviewSequenceId.value
          : this.lastAppliedReviewSequenceId,
      hasHydratedHotState: data.hasHydratedHotState.present
          ? data.hasHydratedHotState.value
          : this.hasHydratedHotState,
      hasHydratedReviewHistory: data.hasHydratedReviewHistory.present
          ? data.hasHydratedReviewHistory.value
          : this.hasHydratedReviewHistory,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateTableData(')
          ..write('workspaceId: $workspaceId, ')
          ..write('lastAppliedHotChangeId: $lastAppliedHotChangeId, ')
          ..write('lastAppliedReviewSequenceId: $lastAppliedReviewSequenceId, ')
          ..write('hasHydratedHotState: $hasHydratedHotState, ')
          ..write('hasHydratedReviewHistory: $hasHydratedReviewHistory, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    workspaceId,
    lastAppliedHotChangeId,
    lastAppliedReviewSequenceId,
    hasHydratedHotState,
    hasHydratedReviewHistory,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateTableData &&
          other.workspaceId == this.workspaceId &&
          other.lastAppliedHotChangeId == this.lastAppliedHotChangeId &&
          other.lastAppliedReviewSequenceId ==
              this.lastAppliedReviewSequenceId &&
          other.hasHydratedHotState == this.hasHydratedHotState &&
          other.hasHydratedReviewHistory == this.hasHydratedReviewHistory &&
          other.updatedAt == this.updatedAt);
}

class SyncStateTableCompanion extends UpdateCompanion<SyncStateTableData> {
  final Value<String> workspaceId;
  final Value<int> lastAppliedHotChangeId;
  final Value<int> lastAppliedReviewSequenceId;
  final Value<bool> hasHydratedHotState;
  final Value<bool> hasHydratedReviewHistory;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncStateTableCompanion({
    this.workspaceId = const Value.absent(),
    this.lastAppliedHotChangeId = const Value.absent(),
    this.lastAppliedReviewSequenceId = const Value.absent(),
    this.hasHydratedHotState = const Value.absent(),
    this.hasHydratedReviewHistory = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateTableCompanion.insert({
    required String workspaceId,
    this.lastAppliedHotChangeId = const Value.absent(),
    this.lastAppliedReviewSequenceId = const Value.absent(),
    this.hasHydratedHotState = const Value.absent(),
    this.hasHydratedReviewHistory = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : workspaceId = Value(workspaceId);
  static Insertable<SyncStateTableData> custom({
    Expression<String>? workspaceId,
    Expression<int>? lastAppliedHotChangeId,
    Expression<int>? lastAppliedReviewSequenceId,
    Expression<bool>? hasHydratedHotState,
    Expression<bool>? hasHydratedReviewHistory,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (lastAppliedHotChangeId != null)
        'last_applied_hot_change_id': lastAppliedHotChangeId,
      if (lastAppliedReviewSequenceId != null)
        'last_applied_review_sequence_id': lastAppliedReviewSequenceId,
      if (hasHydratedHotState != null)
        'has_hydrated_hot_state': hasHydratedHotState,
      if (hasHydratedReviewHistory != null)
        'has_hydrated_review_history': hasHydratedReviewHistory,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateTableCompanion copyWith({
    Value<String>? workspaceId,
    Value<int>? lastAppliedHotChangeId,
    Value<int>? lastAppliedReviewSequenceId,
    Value<bool>? hasHydratedHotState,
    Value<bool>? hasHydratedReviewHistory,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStateTableCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      lastAppliedHotChangeId:
          lastAppliedHotChangeId ?? this.lastAppliedHotChangeId,
      lastAppliedReviewSequenceId:
          lastAppliedReviewSequenceId ?? this.lastAppliedReviewSequenceId,
      hasHydratedHotState: hasHydratedHotState ?? this.hasHydratedHotState,
      hasHydratedReviewHistory:
          hasHydratedReviewHistory ?? this.hasHydratedReviewHistory,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (lastAppliedHotChangeId.present) {
      map['last_applied_hot_change_id'] = Variable<int>(
        lastAppliedHotChangeId.value,
      );
    }
    if (lastAppliedReviewSequenceId.present) {
      map['last_applied_review_sequence_id'] = Variable<int>(
        lastAppliedReviewSequenceId.value,
      );
    }
    if (hasHydratedHotState.present) {
      map['has_hydrated_hot_state'] = Variable<bool>(hasHydratedHotState.value);
    }
    if (hasHydratedReviewHistory.present) {
      map['has_hydrated_review_history'] = Variable<bool>(
        hasHydratedReviewHistory.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateTableCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('lastAppliedHotChangeId: $lastAppliedHotChangeId, ')
          ..write('lastAppliedReviewSequenceId: $lastAppliedReviewSequenceId, ')
          ..write('hasHydratedHotState: $hasHydratedHotState, ')
          ..write('hasHydratedReviewHistory: $hasHydratedReviewHistory, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSensesTable extends LocalSenses
    with TableInfo<$LocalSensesTable, LocalSense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordSenseIdMeta = const VerificationMeta(
    'wordSenseId',
  );
  @override
  late final GeneratedColumn<String> wordSenseId = GeneratedColumn<String>(
    'word_sense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senseKeyMeta = const VerificationMeta(
    'senseKey',
  );
  @override
  late final GeneratedColumn<String> senseKey = GeneratedColumn<String>(
    'sense_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lemmaMeta = const VerificationMeta('lemma');
  @override
  late final GeneratedColumn<String> lemma = GeneratedColumn<String>(
    'lemma',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _semanticTypeMeta = const VerificationMeta(
    'semanticType',
  );
  @override
  late final GeneratedColumn<String> semanticType = GeneratedColumn<String>(
    'semantic_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localeL1Meta = const VerificationMeta(
    'localeL1',
  );
  @override
  late final GeneratedColumn<String> localeL1 = GeneratedColumn<String>(
    'locale_l1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programVersionMeta = const VerificationMeta(
    'programVersion',
  );
  @override
  late final GeneratedColumn<int> programVersion = GeneratedColumn<int>(
    'program_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
    'program_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordSenseId,
    senseKey,
    lemma,
    pos,
    semanticType,
    localeL1,
    programVersion,
    programId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_senses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_sense_id')) {
      context.handle(
        _wordSenseIdMeta,
        wordSenseId.isAcceptableOrUnknown(
          data['word_sense_id']!,
          _wordSenseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wordSenseIdMeta);
    }
    if (data.containsKey('sense_key')) {
      context.handle(
        _senseKeyMeta,
        senseKey.isAcceptableOrUnknown(data['sense_key']!, _senseKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_senseKeyMeta);
    }
    if (data.containsKey('lemma')) {
      context.handle(
        _lemmaMeta,
        lemma.isAcceptableOrUnknown(data['lemma']!, _lemmaMeta),
      );
    } else if (isInserting) {
      context.missing(_lemmaMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('semantic_type')) {
      context.handle(
        _semanticTypeMeta,
        semanticType.isAcceptableOrUnknown(
          data['semantic_type']!,
          _semanticTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticTypeMeta);
    }
    if (data.containsKey('locale_l1')) {
      context.handle(
        _localeL1Meta,
        localeL1.isAcceptableOrUnknown(data['locale_l1']!, _localeL1Meta),
      );
    } else if (isInserting) {
      context.missing(_localeL1Meta);
    }
    if (data.containsKey('program_version')) {
      context.handle(
        _programVersionMeta,
        programVersion.isAcceptableOrUnknown(
          data['program_version']!,
          _programVersionMeta,
        ),
      );
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordSenseId};
  @override
  LocalSense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSense(
      wordSenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_sense_id'],
      )!,
      senseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sense_key'],
      )!,
      lemma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lemma'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      )!,
      semanticType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_type'],
      )!,
      localeL1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale_l1'],
      )!,
      programVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_version'],
      ),
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_id'],
      ),
    );
  }

  @override
  $LocalSensesTable createAlias(String alias) {
    return $LocalSensesTable(attachedDatabase, alias);
  }
}

class LocalSense extends DataClass implements Insertable<LocalSense> {
  final String wordSenseId;
  final String senseKey;
  final String lemma;
  final String pos;
  final String semanticType;
  final String localeL1;
  final int? programVersion;
  final String? programId;
  const LocalSense({
    required this.wordSenseId,
    required this.senseKey,
    required this.lemma,
    required this.pos,
    required this.semanticType,
    required this.localeL1,
    this.programVersion,
    this.programId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_sense_id'] = Variable<String>(wordSenseId);
    map['sense_key'] = Variable<String>(senseKey);
    map['lemma'] = Variable<String>(lemma);
    map['pos'] = Variable<String>(pos);
    map['semantic_type'] = Variable<String>(semanticType);
    map['locale_l1'] = Variable<String>(localeL1);
    if (!nullToAbsent || programVersion != null) {
      map['program_version'] = Variable<int>(programVersion);
    }
    if (!nullToAbsent || programId != null) {
      map['program_id'] = Variable<String>(programId);
    }
    return map;
  }

  LocalSensesCompanion toCompanion(bool nullToAbsent) {
    return LocalSensesCompanion(
      wordSenseId: Value(wordSenseId),
      senseKey: Value(senseKey),
      lemma: Value(lemma),
      pos: Value(pos),
      semanticType: Value(semanticType),
      localeL1: Value(localeL1),
      programVersion: programVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(programVersion),
      programId: programId == null && nullToAbsent
          ? const Value.absent()
          : Value(programId),
    );
  }

  factory LocalSense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSense(
      wordSenseId: serializer.fromJson<String>(json['wordSenseId']),
      senseKey: serializer.fromJson<String>(json['senseKey']),
      lemma: serializer.fromJson<String>(json['lemma']),
      pos: serializer.fromJson<String>(json['pos']),
      semanticType: serializer.fromJson<String>(json['semanticType']),
      localeL1: serializer.fromJson<String>(json['localeL1']),
      programVersion: serializer.fromJson<int?>(json['programVersion']),
      programId: serializer.fromJson<String?>(json['programId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordSenseId': serializer.toJson<String>(wordSenseId),
      'senseKey': serializer.toJson<String>(senseKey),
      'lemma': serializer.toJson<String>(lemma),
      'pos': serializer.toJson<String>(pos),
      'semanticType': serializer.toJson<String>(semanticType),
      'localeL1': serializer.toJson<String>(localeL1),
      'programVersion': serializer.toJson<int?>(programVersion),
      'programId': serializer.toJson<String?>(programId),
    };
  }

  LocalSense copyWith({
    String? wordSenseId,
    String? senseKey,
    String? lemma,
    String? pos,
    String? semanticType,
    String? localeL1,
    Value<int?> programVersion = const Value.absent(),
    Value<String?> programId = const Value.absent(),
  }) => LocalSense(
    wordSenseId: wordSenseId ?? this.wordSenseId,
    senseKey: senseKey ?? this.senseKey,
    lemma: lemma ?? this.lemma,
    pos: pos ?? this.pos,
    semanticType: semanticType ?? this.semanticType,
    localeL1: localeL1 ?? this.localeL1,
    programVersion: programVersion.present
        ? programVersion.value
        : this.programVersion,
    programId: programId.present ? programId.value : this.programId,
  );
  LocalSense copyWithCompanion(LocalSensesCompanion data) {
    return LocalSense(
      wordSenseId: data.wordSenseId.present
          ? data.wordSenseId.value
          : this.wordSenseId,
      senseKey: data.senseKey.present ? data.senseKey.value : this.senseKey,
      lemma: data.lemma.present ? data.lemma.value : this.lemma,
      pos: data.pos.present ? data.pos.value : this.pos,
      semanticType: data.semanticType.present
          ? data.semanticType.value
          : this.semanticType,
      localeL1: data.localeL1.present ? data.localeL1.value : this.localeL1,
      programVersion: data.programVersion.present
          ? data.programVersion.value
          : this.programVersion,
      programId: data.programId.present ? data.programId.value : this.programId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSense(')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('senseKey: $senseKey, ')
          ..write('lemma: $lemma, ')
          ..write('pos: $pos, ')
          ..write('semanticType: $semanticType, ')
          ..write('localeL1: $localeL1, ')
          ..write('programVersion: $programVersion, ')
          ..write('programId: $programId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    wordSenseId,
    senseKey,
    lemma,
    pos,
    semanticType,
    localeL1,
    programVersion,
    programId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSense &&
          other.wordSenseId == this.wordSenseId &&
          other.senseKey == this.senseKey &&
          other.lemma == this.lemma &&
          other.pos == this.pos &&
          other.semanticType == this.semanticType &&
          other.localeL1 == this.localeL1 &&
          other.programVersion == this.programVersion &&
          other.programId == this.programId);
}

class LocalSensesCompanion extends UpdateCompanion<LocalSense> {
  final Value<String> wordSenseId;
  final Value<String> senseKey;
  final Value<String> lemma;
  final Value<String> pos;
  final Value<String> semanticType;
  final Value<String> localeL1;
  final Value<int?> programVersion;
  final Value<String?> programId;
  final Value<int> rowid;
  const LocalSensesCompanion({
    this.wordSenseId = const Value.absent(),
    this.senseKey = const Value.absent(),
    this.lemma = const Value.absent(),
    this.pos = const Value.absent(),
    this.semanticType = const Value.absent(),
    this.localeL1 = const Value.absent(),
    this.programVersion = const Value.absent(),
    this.programId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSensesCompanion.insert({
    required String wordSenseId,
    required String senseKey,
    required String lemma,
    required String pos,
    required String semanticType,
    required String localeL1,
    this.programVersion = const Value.absent(),
    this.programId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordSenseId = Value(wordSenseId),
       senseKey = Value(senseKey),
       lemma = Value(lemma),
       pos = Value(pos),
       semanticType = Value(semanticType),
       localeL1 = Value(localeL1);
  static Insertable<LocalSense> custom({
    Expression<String>? wordSenseId,
    Expression<String>? senseKey,
    Expression<String>? lemma,
    Expression<String>? pos,
    Expression<String>? semanticType,
    Expression<String>? localeL1,
    Expression<int>? programVersion,
    Expression<String>? programId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordSenseId != null) 'word_sense_id': wordSenseId,
      if (senseKey != null) 'sense_key': senseKey,
      if (lemma != null) 'lemma': lemma,
      if (pos != null) 'pos': pos,
      if (semanticType != null) 'semantic_type': semanticType,
      if (localeL1 != null) 'locale_l1': localeL1,
      if (programVersion != null) 'program_version': programVersion,
      if (programId != null) 'program_id': programId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSensesCompanion copyWith({
    Value<String>? wordSenseId,
    Value<String>? senseKey,
    Value<String>? lemma,
    Value<String>? pos,
    Value<String>? semanticType,
    Value<String>? localeL1,
    Value<int?>? programVersion,
    Value<String?>? programId,
    Value<int>? rowid,
  }) {
    return LocalSensesCompanion(
      wordSenseId: wordSenseId ?? this.wordSenseId,
      senseKey: senseKey ?? this.senseKey,
      lemma: lemma ?? this.lemma,
      pos: pos ?? this.pos,
      semanticType: semanticType ?? this.semanticType,
      localeL1: localeL1 ?? this.localeL1,
      programVersion: programVersion ?? this.programVersion,
      programId: programId ?? this.programId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordSenseId.present) {
      map['word_sense_id'] = Variable<String>(wordSenseId.value);
    }
    if (senseKey.present) {
      map['sense_key'] = Variable<String>(senseKey.value);
    }
    if (lemma.present) {
      map['lemma'] = Variable<String>(lemma.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (semanticType.present) {
      map['semantic_type'] = Variable<String>(semanticType.value);
    }
    if (localeL1.present) {
      map['locale_l1'] = Variable<String>(localeL1.value);
    }
    if (programVersion.present) {
      map['program_version'] = Variable<int>(programVersion.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSensesCompanion(')
          ..write('wordSenseId: $wordSenseId, ')
          ..write('senseKey: $senseKey, ')
          ..write('lemma: $lemma, ')
          ..write('pos: $pos, ')
          ..write('semanticType: $semanticType, ')
          ..write('localeL1: $localeL1, ')
          ..write('programVersion: $programVersion, ')
          ..write('programId: $programId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProgramsTable extends LocalPrograms
    with TableInfo<$LocalProgramsTable, LocalProgram> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [programId, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProgram> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {programId};
  @override
  LocalProgram map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProgram(
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LocalProgramsTable createAlias(String alias) {
    return $LocalProgramsTable(attachedDatabase, alias);
  }
}

class LocalProgram extends DataClass implements Insertable<LocalProgram> {
  final String programId;
  final String json;
  const LocalProgram({required this.programId, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['program_id'] = Variable<String>(programId);
    map['json'] = Variable<String>(json);
    return map;
  }

  LocalProgramsCompanion toCompanion(bool nullToAbsent) {
    return LocalProgramsCompanion(
      programId: Value(programId),
      json: Value(json),
    );
  }

  factory LocalProgram.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProgram(
      programId: serializer.fromJson<String>(json['programId']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'programId': serializer.toJson<String>(programId),
      'json': serializer.toJson<String>(json),
    };
  }

  LocalProgram copyWith({String? programId, String? json}) => LocalProgram(
    programId: programId ?? this.programId,
    json: json ?? this.json,
  );
  LocalProgram copyWithCompanion(LocalProgramsCompanion data) {
    return LocalProgram(
      programId: data.programId.present ? data.programId.value : this.programId,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProgram(')
          ..write('programId: $programId, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(programId, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProgram &&
          other.programId == this.programId &&
          other.json == this.json);
}

class LocalProgramsCompanion extends UpdateCompanion<LocalProgram> {
  final Value<String> programId;
  final Value<String> json;
  final Value<int> rowid;
  const LocalProgramsCompanion({
    this.programId = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProgramsCompanion.insert({
    required String programId,
    required String json,
    this.rowid = const Value.absent(),
  }) : programId = Value(programId),
       json = Value(json);
  static Insertable<LocalProgram> custom({
    Expression<String>? programId,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (programId != null) 'program_id': programId,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProgramsCompanion copyWith({
    Value<String>? programId,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return LocalProgramsCompanion(
      programId: programId ?? this.programId,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProgramsCompanion(')
          ..write('programId: $programId, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWorkspaceSettingsTable extends LocalWorkspaceSettings
    with TableInfo<$LocalWorkspaceSettingsTable, LocalWorkspaceSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWorkspaceSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [workspaceId, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_workspace_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWorkspaceSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workspaceId};
  @override
  LocalWorkspaceSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWorkspaceSetting(
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LocalWorkspaceSettingsTable createAlias(String alias) {
    return $LocalWorkspaceSettingsTable(attachedDatabase, alias);
  }
}

class LocalWorkspaceSetting extends DataClass
    implements Insertable<LocalWorkspaceSetting> {
  final String workspaceId;
  final String json;
  const LocalWorkspaceSetting({required this.workspaceId, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workspace_id'] = Variable<String>(workspaceId);
    map['json'] = Variable<String>(json);
    return map;
  }

  LocalWorkspaceSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalWorkspaceSettingsCompanion(
      workspaceId: Value(workspaceId),
      json: Value(json),
    );
  }

  factory LocalWorkspaceSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWorkspaceSetting(
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workspaceId': serializer.toJson<String>(workspaceId),
      'json': serializer.toJson<String>(json),
    };
  }

  LocalWorkspaceSetting copyWith({String? workspaceId, String? json}) =>
      LocalWorkspaceSetting(
        workspaceId: workspaceId ?? this.workspaceId,
        json: json ?? this.json,
      );
  LocalWorkspaceSetting copyWithCompanion(
    LocalWorkspaceSettingsCompanion data,
  ) {
    return LocalWorkspaceSetting(
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWorkspaceSetting(')
          ..write('workspaceId: $workspaceId, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workspaceId, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWorkspaceSetting &&
          other.workspaceId == this.workspaceId &&
          other.json == this.json);
}

class LocalWorkspaceSettingsCompanion
    extends UpdateCompanion<LocalWorkspaceSetting> {
  final Value<String> workspaceId;
  final Value<String> json;
  final Value<int> rowid;
  const LocalWorkspaceSettingsCompanion({
    this.workspaceId = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWorkspaceSettingsCompanion.insert({
    required String workspaceId,
    required String json,
    this.rowid = const Value.absent(),
  }) : workspaceId = Value(workspaceId),
       json = Value(json);
  static Insertable<LocalWorkspaceSetting> custom({
    Expression<String>? workspaceId,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWorkspaceSettingsCompanion copyWith({
    Value<String>? workspaceId,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return LocalWorkspaceSettingsCompanion(
      workspaceId: workspaceId ?? this.workspaceId,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWorkspaceSettingsCompanion(')
          ..write('workspaceId: $workspaceId, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalListsTable extends LocalLists
    with TableInfo<$LocalListsTable, LocalList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filterDefinitionJsonMeta =
      const VerificationMeta('filterDefinitionJson');
  @override
  late final GeneratedColumn<String> filterDefinitionJson =
      GeneratedColumn<String>(
        'filter_definition_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta(
    'clientUpdatedAt',
  );
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastModifiedByReplicaIdMeta =
      const VerificationMeta('lastModifiedByReplicaId');
  @override
  late final GeneratedColumn<String> lastModifiedByReplicaId =
      GeneratedColumn<String>(
        'last_modified_by_replica_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastOperationIdMeta = const VerificationMeta(
    'lastOperationId',
  );
  @override
  late final GeneratedColumn<String> lastOperationId = GeneratedColumn<String>(
    'last_operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    listId,
    name,
    filterDefinitionJson,
    clientUpdatedAt,
    lastModifiedByReplicaId,
    lastOperationId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('filter_definition_json')) {
      context.handle(
        _filterDefinitionJsonMeta,
        filterDefinitionJson.isAcceptableOrUnknown(
          data['filter_definition_json']!,
          _filterDefinitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filterDefinitionJsonMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(
          data['client_updated_at']!,
          _clientUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('last_modified_by_replica_id')) {
      context.handle(
        _lastModifiedByReplicaIdMeta,
        lastModifiedByReplicaId.isAcceptableOrUnknown(
          data['last_modified_by_replica_id']!,
          _lastModifiedByReplicaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedByReplicaIdMeta);
    }
    if (data.containsKey('last_operation_id')) {
      context.handle(
        _lastOperationIdMeta,
        lastOperationId.isAcceptableOrUnknown(
          data['last_operation_id']!,
          _lastOperationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOperationIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId};
  @override
  LocalList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalList(
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      filterDefinitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_definition_json'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      )!,
      lastModifiedByReplicaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_modified_by_replica_id'],
      )!,
      lastOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_operation_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $LocalListsTable createAlias(String alias) {
    return $LocalListsTable(attachedDatabase, alias);
  }
}

class LocalList extends DataClass implements Insertable<LocalList> {
  final String listId;
  final String name;
  final String filterDefinitionJson;
  final String clientUpdatedAt;
  final String lastModifiedByReplicaId;
  final String lastOperationId;
  final DateTime? deletedAt;
  const LocalList({
    required this.listId,
    required this.name,
    required this.filterDefinitionJson,
    required this.clientUpdatedAt,
    required this.lastModifiedByReplicaId,
    required this.lastOperationId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['filter_definition_json'] = Variable<String>(filterDefinitionJson);
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['last_modified_by_replica_id'] = Variable<String>(
      lastModifiedByReplicaId,
    );
    map['last_operation_id'] = Variable<String>(lastOperationId);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalListsCompanion toCompanion(bool nullToAbsent) {
    return LocalListsCompanion(
      listId: Value(listId),
      name: Value(name),
      filterDefinitionJson: Value(filterDefinitionJson),
      clientUpdatedAt: Value(clientUpdatedAt),
      lastModifiedByReplicaId: Value(lastModifiedByReplicaId),
      lastOperationId: Value(lastOperationId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalList(
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      filterDefinitionJson: serializer.fromJson<String>(
        json['filterDefinitionJson'],
      ),
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      lastModifiedByReplicaId: serializer.fromJson<String>(
        json['lastModifiedByReplicaId'],
      ),
      lastOperationId: serializer.fromJson<String>(json['lastOperationId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'filterDefinitionJson': serializer.toJson<String>(filterDefinitionJson),
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'lastModifiedByReplicaId': serializer.toJson<String>(
        lastModifiedByReplicaId,
      ),
      'lastOperationId': serializer.toJson<String>(lastOperationId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalList copyWith({
    String? listId,
    String? name,
    String? filterDefinitionJson,
    String? clientUpdatedAt,
    String? lastModifiedByReplicaId,
    String? lastOperationId,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => LocalList(
    listId: listId ?? this.listId,
    name: name ?? this.name,
    filterDefinitionJson: filterDefinitionJson ?? this.filterDefinitionJson,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    lastModifiedByReplicaId:
        lastModifiedByReplicaId ?? this.lastModifiedByReplicaId,
    lastOperationId: lastOperationId ?? this.lastOperationId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LocalList copyWithCompanion(LocalListsCompanion data) {
    return LocalList(
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      filterDefinitionJson: data.filterDefinitionJson.present
          ? data.filterDefinitionJson.value
          : this.filterDefinitionJson,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      lastModifiedByReplicaId: data.lastModifiedByReplicaId.present
          ? data.lastModifiedByReplicaId.value
          : this.lastModifiedByReplicaId,
      lastOperationId: data.lastOperationId.present
          ? data.lastOperationId.value
          : this.lastOperationId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalList(')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('filterDefinitionJson: $filterDefinitionJson, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('lastModifiedByReplicaId: $lastModifiedByReplicaId, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    listId,
    name,
    filterDefinitionJson,
    clientUpdatedAt,
    lastModifiedByReplicaId,
    lastOperationId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalList &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.filterDefinitionJson == this.filterDefinitionJson &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.lastModifiedByReplicaId == this.lastModifiedByReplicaId &&
          other.lastOperationId == this.lastOperationId &&
          other.deletedAt == this.deletedAt);
}

class LocalListsCompanion extends UpdateCompanion<LocalList> {
  final Value<String> listId;
  final Value<String> name;
  final Value<String> filterDefinitionJson;
  final Value<String> clientUpdatedAt;
  final Value<String> lastModifiedByReplicaId;
  final Value<String> lastOperationId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalListsCompanion({
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.filterDefinitionJson = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.lastModifiedByReplicaId = const Value.absent(),
    this.lastOperationId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalListsCompanion.insert({
    required String listId,
    required String name,
    required String filterDefinitionJson,
    required String clientUpdatedAt,
    required String lastModifiedByReplicaId,
    required String lastOperationId,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       name = Value(name),
       filterDefinitionJson = Value(filterDefinitionJson),
       clientUpdatedAt = Value(clientUpdatedAt),
       lastModifiedByReplicaId = Value(lastModifiedByReplicaId),
       lastOperationId = Value(lastOperationId);
  static Insertable<LocalList> custom({
    Expression<String>? listId,
    Expression<String>? name,
    Expression<String>? filterDefinitionJson,
    Expression<String>? clientUpdatedAt,
    Expression<String>? lastModifiedByReplicaId,
    Expression<String>? lastOperationId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (filterDefinitionJson != null)
        'filter_definition_json': filterDefinitionJson,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (lastModifiedByReplicaId != null)
        'last_modified_by_replica_id': lastModifiedByReplicaId,
      if (lastOperationId != null) 'last_operation_id': lastOperationId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalListsCompanion copyWith({
    Value<String>? listId,
    Value<String>? name,
    Value<String>? filterDefinitionJson,
    Value<String>? clientUpdatedAt,
    Value<String>? lastModifiedByReplicaId,
    Value<String>? lastOperationId,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return LocalListsCompanion(
      listId: listId ?? this.listId,
      name: name ?? this.name,
      filterDefinitionJson: filterDefinitionJson ?? this.filterDefinitionJson,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      lastModifiedByReplicaId:
          lastModifiedByReplicaId ?? this.lastModifiedByReplicaId,
      lastOperationId: lastOperationId ?? this.lastOperationId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (filterDefinitionJson.present) {
      map['filter_definition_json'] = Variable<String>(
        filterDefinitionJson.value,
      );
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (lastModifiedByReplicaId.present) {
      map['last_modified_by_replica_id'] = Variable<String>(
        lastModifiedByReplicaId.value,
      );
    }
    if (lastOperationId.present) {
      map['last_operation_id'] = Variable<String>(lastOperationId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalListsCompanion(')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('filterDefinitionJson: $filterDefinitionJson, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('lastModifiedByReplicaId: $lastModifiedByReplicaId, ')
          ..write('lastOperationId: $lastOperationId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFavoritesTable extends LocalFavorites
    with TableInfo<$LocalFavoritesTable, LocalFavorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _experienceKeyMeta = const VerificationMeta(
    'experienceKey',
  );
  @override
  late final GeneratedColumn<String> experienceKey = GeneratedColumn<String>(
    'experience_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _experienceUnitIdMeta = const VerificationMeta(
    'experienceUnitId',
  );
  @override
  late final GeneratedColumn<String> experienceUnitId = GeneratedColumn<String>(
    'experience_unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    experienceKey,
    programId,
    experienceUnitId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFavorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('experience_key')) {
      context.handle(
        _experienceKeyMeta,
        experienceKey.isAcceptableOrUnknown(
          data['experience_key']!,
          _experienceKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_experienceKeyMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('experience_unit_id')) {
      context.handle(
        _experienceUnitIdMeta,
        experienceUnitId.isAcceptableOrUnknown(
          data['experience_unit_id']!,
          _experienceUnitIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_experienceUnitIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {experienceKey};
  @override
  LocalFavorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFavorite(
      experienceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}experience_key'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}program_id'],
      )!,
      experienceUnitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}experience_unit_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalFavoritesTable createAlias(String alias) {
    return $LocalFavoritesTable(attachedDatabase, alias);
  }
}

class LocalFavorite extends DataClass implements Insertable<LocalFavorite> {
  final String experienceKey;
  final String programId;
  final String experienceUnitId;
  final DateTime createdAt;
  const LocalFavorite({
    required this.experienceKey,
    required this.programId,
    required this.experienceUnitId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['experience_key'] = Variable<String>(experienceKey);
    map['program_id'] = Variable<String>(programId);
    map['experience_unit_id'] = Variable<String>(experienceUnitId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalFavoritesCompanion toCompanion(bool nullToAbsent) {
    return LocalFavoritesCompanion(
      experienceKey: Value(experienceKey),
      programId: Value(programId),
      experienceUnitId: Value(experienceUnitId),
      createdAt: Value(createdAt),
    );
  }

  factory LocalFavorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFavorite(
      experienceKey: serializer.fromJson<String>(json['experienceKey']),
      programId: serializer.fromJson<String>(json['programId']),
      experienceUnitId: serializer.fromJson<String>(json['experienceUnitId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'experienceKey': serializer.toJson<String>(experienceKey),
      'programId': serializer.toJson<String>(programId),
      'experienceUnitId': serializer.toJson<String>(experienceUnitId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalFavorite copyWith({
    String? experienceKey,
    String? programId,
    String? experienceUnitId,
    DateTime? createdAt,
  }) => LocalFavorite(
    experienceKey: experienceKey ?? this.experienceKey,
    programId: programId ?? this.programId,
    experienceUnitId: experienceUnitId ?? this.experienceUnitId,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalFavorite copyWithCompanion(LocalFavoritesCompanion data) {
    return LocalFavorite(
      experienceKey: data.experienceKey.present
          ? data.experienceKey.value
          : this.experienceKey,
      programId: data.programId.present ? data.programId.value : this.programId,
      experienceUnitId: data.experienceUnitId.present
          ? data.experienceUnitId.value
          : this.experienceUnitId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavorite(')
          ..write('experienceKey: $experienceKey, ')
          ..write('programId: $programId, ')
          ..write('experienceUnitId: $experienceUnitId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(experienceKey, programId, experienceUnitId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFavorite &&
          other.experienceKey == this.experienceKey &&
          other.programId == this.programId &&
          other.experienceUnitId == this.experienceUnitId &&
          other.createdAt == this.createdAt);
}

class LocalFavoritesCompanion extends UpdateCompanion<LocalFavorite> {
  final Value<String> experienceKey;
  final Value<String> programId;
  final Value<String> experienceUnitId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalFavoritesCompanion({
    this.experienceKey = const Value.absent(),
    this.programId = const Value.absent(),
    this.experienceUnitId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFavoritesCompanion.insert({
    required String experienceKey,
    required String programId,
    required String experienceUnitId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : experienceKey = Value(experienceKey),
       programId = Value(programId),
       experienceUnitId = Value(experienceUnitId),
       createdAt = Value(createdAt);
  static Insertable<LocalFavorite> custom({
    Expression<String>? experienceKey,
    Expression<String>? programId,
    Expression<String>? experienceUnitId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (experienceKey != null) 'experience_key': experienceKey,
      if (programId != null) 'program_id': programId,
      if (experienceUnitId != null) 'experience_unit_id': experienceUnitId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFavoritesCompanion copyWith({
    Value<String>? experienceKey,
    Value<String>? programId,
    Value<String>? experienceUnitId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalFavoritesCompanion(
      experienceKey: experienceKey ?? this.experienceKey,
      programId: programId ?? this.programId,
      experienceUnitId: experienceUnitId ?? this.experienceUnitId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (experienceKey.present) {
      map['experience_key'] = Variable<String>(experienceKey.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (experienceUnitId.present) {
      map['experience_unit_id'] = Variable<String>(experienceUnitId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFavoritesCompanion(')
          ..write('experienceKey: $experienceKey, ')
          ..write('programId: $programId, ')
          ..write('experienceUnitId: $experienceUnitId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _senseIdMeta = const VerificationMeta(
    'senseId',
  );
  @override
  late final GeneratedColumn<String> senseId = GeneratedColumn<String>(
    'sense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [senseId, noteText, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sense_id')) {
      context.handle(
        _senseIdMeta,
        senseId.isAcceptableOrUnknown(data['sense_id']!, _senseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senseIdMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    } else if (isInserting) {
      context.missing(_noteTextMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {senseId};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      senseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sense_id'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String senseId;
  final String noteText;
  final DateTime updatedAt;
  const LocalNote({
    required this.senseId,
    required this.noteText,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sense_id'] = Variable<String>(senseId);
    map['note_text'] = Variable<String>(noteText);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      senseId: Value(senseId),
      noteText: Value(noteText),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      senseId: serializer.fromJson<String>(json['senseId']),
      noteText: serializer.fromJson<String>(json['noteText']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'senseId': serializer.toJson<String>(senseId),
      'noteText': serializer.toJson<String>(noteText),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalNote copyWith({
    String? senseId,
    String? noteText,
    DateTime? updatedAt,
  }) => LocalNote(
    senseId: senseId ?? this.senseId,
    noteText: noteText ?? this.noteText,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      senseId: data.senseId.present ? data.senseId.value : this.senseId,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('senseId: $senseId, ')
          ..write('noteText: $noteText, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(senseId, noteText, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.senseId == this.senseId &&
          other.noteText == this.noteText &&
          other.updatedAt == this.updatedAt);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> senseId;
  final Value<String> noteText;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.senseId = const Value.absent(),
    this.noteText = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String senseId,
    required String noteText,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : senseId = Value(senseId),
       noteText = Value(noteText),
       updatedAt = Value(updatedAt);
  static Insertable<LocalNote> custom({
    Expression<String>? senseId,
    Expression<String>? noteText,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (senseId != null) 'sense_id': senseId,
      if (noteText != null) 'note_text': noteText,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? senseId,
    Value<String>? noteText,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      senseId: senseId ?? this.senseId,
      noteText: noteText ?? this.noteText,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (senseId.present) {
      map['sense_id'] = Variable<String>(senseId.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('senseId: $senseId, ')
          ..write('noteText: $noteText, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDailyCheckinsTable extends LocalDailyCheckins
    with TableInfo<$LocalDailyCheckinsTable, LocalDailyCheckin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDailyCheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [dayKey, checkedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_daily_checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDailyCheckin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayKey};
  @override
  LocalDailyCheckin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDailyCheckin(
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $LocalDailyCheckinsTable createAlias(String alias) {
    return $LocalDailyCheckinsTable(attachedDatabase, alias);
  }
}

class LocalDailyCheckin extends DataClass
    implements Insertable<LocalDailyCheckin> {
  final String dayKey;
  final DateTime checkedAt;
  const LocalDailyCheckin({required this.dayKey, required this.checkedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_key'] = Variable<String>(dayKey);
    map['checked_at'] = Variable<DateTime>(checkedAt);
    return map;
  }

  LocalDailyCheckinsCompanion toCompanion(bool nullToAbsent) {
    return LocalDailyCheckinsCompanion(
      dayKey: Value(dayKey),
      checkedAt: Value(checkedAt),
    );
  }

  factory LocalDailyCheckin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDailyCheckin(
      dayKey: serializer.fromJson<String>(json['dayKey']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayKey': serializer.toJson<String>(dayKey),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
    };
  }

  LocalDailyCheckin copyWith({String? dayKey, DateTime? checkedAt}) =>
      LocalDailyCheckin(
        dayKey: dayKey ?? this.dayKey,
        checkedAt: checkedAt ?? this.checkedAt,
      );
  LocalDailyCheckin copyWithCompanion(LocalDailyCheckinsCompanion data) {
    return LocalDailyCheckin(
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDailyCheckin(')
          ..write('dayKey: $dayKey, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayKey, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDailyCheckin &&
          other.dayKey == this.dayKey &&
          other.checkedAt == this.checkedAt);
}

class LocalDailyCheckinsCompanion extends UpdateCompanion<LocalDailyCheckin> {
  final Value<String> dayKey;
  final Value<DateTime> checkedAt;
  final Value<int> rowid;
  const LocalDailyCheckinsCompanion({
    this.dayKey = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDailyCheckinsCompanion.insert({
    required String dayKey,
    required DateTime checkedAt,
    this.rowid = const Value.absent(),
  }) : dayKey = Value(dayKey),
       checkedAt = Value(checkedAt);
  static Insertable<LocalDailyCheckin> custom({
    Expression<String>? dayKey,
    Expression<DateTime>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayKey != null) 'day_key': dayKey,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDailyCheckinsCompanion copyWith({
    Value<String>? dayKey,
    Value<DateTime>? checkedAt,
    Value<int>? rowid,
  }) {
    return LocalDailyCheckinsCompanion(
      dayKey: dayKey ?? this.dayKey,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDailyCheckinsCompanion(')
          ..write('dayKey: $dayKey, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSessionsTable extends LocalSessions
    with TableInfo<$LocalSessionsTable, LocalSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    kind,
    startedAt,
    endedAt,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  LocalSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSession(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $LocalSessionsTable createAlias(String alias) {
    return $LocalSessionsTable(attachedDatabase, alias);
  }
}

class LocalSession extends DataClass implements Insertable<LocalSession> {
  final String sessionId;
  final String kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  const LocalSession({
    required this.sessionId,
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['kind'] = Variable<String>(kind);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  LocalSessionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSessionsCompanion(
      sessionId: Value(sessionId),
      kind: Value(kind),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory LocalSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSession(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      kind: serializer.fromJson<String>(json['kind']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'kind': serializer.toJson<String>(kind),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  LocalSession copyWith({
    String? sessionId,
    String? kind,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) => LocalSession(
    sessionId: sessionId ?? this.sessionId,
    kind: kind ?? this.kind,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  LocalSession copyWithCompanion(LocalSessionsCompanion data) {
    return LocalSession(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSession(')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, kind, startedAt, endedAt, durationSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSession &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds);
}

class LocalSessionsCompanion extends UpdateCompanion<LocalSession> {
  final Value<String> sessionId;
  final Value<String> kind;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> durationSeconds;
  final Value<int> rowid;
  const LocalSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSessionsCompanion.insert({
    required String sessionId,
    required String kind,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       kind = Value(kind),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       durationSeconds = Value(durationSeconds);
  static Insertable<LocalSession> custom({
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? kind,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? durationSeconds,
    Value<int>? rowid,
  }) {
    return LocalSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContentCatalogTable extends LocalContentCatalog
    with TableInfo<$LocalContentCatalogTable, LocalContentCatalogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContentCatalogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_content_catalog';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContentCatalogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {version};
  @override
  LocalContentCatalogData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContentCatalogData(
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LocalContentCatalogTable createAlias(String alias) {
    return $LocalContentCatalogTable(attachedDatabase, alias);
  }
}

class LocalContentCatalogData extends DataClass
    implements Insertable<LocalContentCatalogData> {
  final int version;
  final String json;
  const LocalContentCatalogData({required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  LocalContentCatalogCompanion toCompanion(bool nullToAbsent) {
    return LocalContentCatalogCompanion(
      version: Value(version),
      json: Value(json),
    );
  }

  factory LocalContentCatalogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContentCatalogData(
      version: serializer.fromJson<int>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  LocalContentCatalogData copyWith({int? version, String? json}) =>
      LocalContentCatalogData(
        version: version ?? this.version,
        json: json ?? this.json,
      );
  LocalContentCatalogData copyWithCompanion(LocalContentCatalogCompanion data) {
    return LocalContentCatalogData(
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentCatalogData(')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContentCatalogData &&
          other.version == this.version &&
          other.json == this.json);
}

class LocalContentCatalogCompanion
    extends UpdateCompanion<LocalContentCatalogData> {
  final Value<int> version;
  final Value<String> json;
  const LocalContentCatalogCompanion({
    this.version = const Value.absent(),
    this.json = const Value.absent(),
  });
  LocalContentCatalogCompanion.insert({
    this.version = const Value.absent(),
    required String json,
  }) : json = Value(json);
  static Insertable<LocalContentCatalogData> custom({
    Expression<int>? version,
    Expression<String>? json,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (json != null) 'json': json,
    });
  }

  LocalContentCatalogCompanion copyWith({
    Value<int>? version,
    Value<String>? json,
  }) {
    return LocalContentCatalogCompanion(
      version: version ?? this.version,
      json: json ?? this.json,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentCatalogCompanion(')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalLearningStatesTable localLearningStates =
      $LocalLearningStatesTable(this);
  late final $LocalReviewEventsTable localReviewEvents =
      $LocalReviewEventsTable(this);
  late final $OutboxRecordsTable outboxRecords = $OutboxRecordsTable(this);
  late final $SyncStateTableTable syncStateTable = $SyncStateTableTable(this);
  late final $LocalSensesTable localSenses = $LocalSensesTable(this);
  late final $LocalProgramsTable localPrograms = $LocalProgramsTable(this);
  late final $LocalWorkspaceSettingsTable localWorkspaceSettings =
      $LocalWorkspaceSettingsTable(this);
  late final $LocalListsTable localLists = $LocalListsTable(this);
  late final $LocalFavoritesTable localFavorites = $LocalFavoritesTable(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $LocalDailyCheckinsTable localDailyCheckins =
      $LocalDailyCheckinsTable(this);
  late final $LocalSessionsTable localSessions = $LocalSessionsTable(this);
  late final $LocalContentCatalogTable localContentCatalog =
      $LocalContentCatalogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localLearningStates,
    localReviewEvents,
    outboxRecords,
    syncStateTable,
    localSenses,
    localPrograms,
    localWorkspaceSettings,
    localLists,
    localFavorites,
    localNotes,
    localDailyCheckins,
    localSessions,
    localContentCatalog,
  ];
}

typedef $$LocalLearningStatesTableCreateCompanionBuilder =
    LocalLearningStatesCompanion Function({
      required String wordSenseId,
      required String learningStateId,
      Value<DateTime?> dueAt,
      required int reps,
      required int lapses,
      Value<double?> fsrsStability,
      Value<double?> fsrsDifficulty,
      Value<DateTime?> fsrsLastReviewedAt,
      Value<int?> fsrsScheduledDays,
      required String fsrsCardState,
      Value<int?> fsrsStepIndex,
      required String clientUpdatedAt,
      required String lastModifiedByReplicaId,
      required String lastOperationId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$LocalLearningStatesTableUpdateCompanionBuilder =
    LocalLearningStatesCompanion Function({
      Value<String> wordSenseId,
      Value<String> learningStateId,
      Value<DateTime?> dueAt,
      Value<int> reps,
      Value<int> lapses,
      Value<double?> fsrsStability,
      Value<double?> fsrsDifficulty,
      Value<DateTime?> fsrsLastReviewedAt,
      Value<int?> fsrsScheduledDays,
      Value<String> fsrsCardState,
      Value<int?> fsrsStepIndex,
      Value<String> clientUpdatedAt,
      Value<String> lastModifiedByReplicaId,
      Value<String> lastOperationId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$LocalLearningStatesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLearningStatesTable> {
  $$LocalLearningStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningStateId => $composableBuilder(
    column: $table.learningStateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fsrsStability => $composableBuilder(
    column: $table.fsrsStability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fsrsDifficulty => $composableBuilder(
    column: $table.fsrsDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fsrsLastReviewedAt => $composableBuilder(
    column: $table.fsrsLastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fsrsScheduledDays => $composableBuilder(
    column: $table.fsrsScheduledDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fsrsCardState => $composableBuilder(
    column: $table.fsrsCardState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fsrsStepIndex => $composableBuilder(
    column: $table.fsrsStepIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalLearningStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLearningStatesTable> {
  $$LocalLearningStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningStateId => $composableBuilder(
    column: $table.learningStateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fsrsStability => $composableBuilder(
    column: $table.fsrsStability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fsrsDifficulty => $composableBuilder(
    column: $table.fsrsDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fsrsLastReviewedAt => $composableBuilder(
    column: $table.fsrsLastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fsrsScheduledDays => $composableBuilder(
    column: $table.fsrsScheduledDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fsrsCardState => $composableBuilder(
    column: $table.fsrsCardState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fsrsStepIndex => $composableBuilder(
    column: $table.fsrsStepIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalLearningStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLearningStatesTable> {
  $$LocalLearningStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learningStateId => $composableBuilder(
    column: $table.learningStateId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<double> get fsrsStability => $composableBuilder(
    column: $table.fsrsStability,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fsrsDifficulty => $composableBuilder(
    column: $table.fsrsDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fsrsLastReviewedAt => $composableBuilder(
    column: $table.fsrsLastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fsrsScheduledDays => $composableBuilder(
    column: $table.fsrsScheduledDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fsrsCardState => $composableBuilder(
    column: $table.fsrsCardState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fsrsStepIndex => $composableBuilder(
    column: $table.fsrsStepIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalLearningStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLearningStatesTable,
          LocalLearningState,
          $$LocalLearningStatesTableFilterComposer,
          $$LocalLearningStatesTableOrderingComposer,
          $$LocalLearningStatesTableAnnotationComposer,
          $$LocalLearningStatesTableCreateCompanionBuilder,
          $$LocalLearningStatesTableUpdateCompanionBuilder,
          (
            LocalLearningState,
            BaseReferences<
              _$AppDatabase,
              $LocalLearningStatesTable,
              LocalLearningState
            >,
          ),
          LocalLearningState,
          PrefetchHooks Function()
        > {
  $$LocalLearningStatesTableTableManager(
    _$AppDatabase db,
    $LocalLearningStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLearningStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLearningStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalLearningStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> wordSenseId = const Value.absent(),
                Value<String> learningStateId = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<double?> fsrsStability = const Value.absent(),
                Value<double?> fsrsDifficulty = const Value.absent(),
                Value<DateTime?> fsrsLastReviewedAt = const Value.absent(),
                Value<int?> fsrsScheduledDays = const Value.absent(),
                Value<String> fsrsCardState = const Value.absent(),
                Value<int?> fsrsStepIndex = const Value.absent(),
                Value<String> clientUpdatedAt = const Value.absent(),
                Value<String> lastModifiedByReplicaId = const Value.absent(),
                Value<String> lastOperationId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLearningStatesCompanion(
                wordSenseId: wordSenseId,
                learningStateId: learningStateId,
                dueAt: dueAt,
                reps: reps,
                lapses: lapses,
                fsrsStability: fsrsStability,
                fsrsDifficulty: fsrsDifficulty,
                fsrsLastReviewedAt: fsrsLastReviewedAt,
                fsrsScheduledDays: fsrsScheduledDays,
                fsrsCardState: fsrsCardState,
                fsrsStepIndex: fsrsStepIndex,
                clientUpdatedAt: clientUpdatedAt,
                lastModifiedByReplicaId: lastModifiedByReplicaId,
                lastOperationId: lastOperationId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordSenseId,
                required String learningStateId,
                Value<DateTime?> dueAt = const Value.absent(),
                required int reps,
                required int lapses,
                Value<double?> fsrsStability = const Value.absent(),
                Value<double?> fsrsDifficulty = const Value.absent(),
                Value<DateTime?> fsrsLastReviewedAt = const Value.absent(),
                Value<int?> fsrsScheduledDays = const Value.absent(),
                required String fsrsCardState,
                Value<int?> fsrsStepIndex = const Value.absent(),
                required String clientUpdatedAt,
                required String lastModifiedByReplicaId,
                required String lastOperationId,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLearningStatesCompanion.insert(
                wordSenseId: wordSenseId,
                learningStateId: learningStateId,
                dueAt: dueAt,
                reps: reps,
                lapses: lapses,
                fsrsStability: fsrsStability,
                fsrsDifficulty: fsrsDifficulty,
                fsrsLastReviewedAt: fsrsLastReviewedAt,
                fsrsScheduledDays: fsrsScheduledDays,
                fsrsCardState: fsrsCardState,
                fsrsStepIndex: fsrsStepIndex,
                clientUpdatedAt: clientUpdatedAt,
                lastModifiedByReplicaId: lastModifiedByReplicaId,
                lastOperationId: lastOperationId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalLearningStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLearningStatesTable,
      LocalLearningState,
      $$LocalLearningStatesTableFilterComposer,
      $$LocalLearningStatesTableOrderingComposer,
      $$LocalLearningStatesTableAnnotationComposer,
      $$LocalLearningStatesTableCreateCompanionBuilder,
      $$LocalLearningStatesTableUpdateCompanionBuilder,
      (
        LocalLearningState,
        BaseReferences<
          _$AppDatabase,
          $LocalLearningStatesTable,
          LocalLearningState
        >,
      ),
      LocalLearningState,
      PrefetchHooks Function()
    >;
typedef $$LocalReviewEventsTableCreateCompanionBuilder =
    LocalReviewEventsCompanion Function({
      required String reviewEventId,
      required String wordSenseId,
      required int programVersion,
      required String experienceUnitId,
      required int rating,
      required DateTime reviewedAtClient,
      Value<String?> reviewedTimeZone,
      Value<String?> reviewedLocalDate,
      Value<int> rowid,
    });
typedef $$LocalReviewEventsTableUpdateCompanionBuilder =
    LocalReviewEventsCompanion Function({
      Value<String> reviewEventId,
      Value<String> wordSenseId,
      Value<int> programVersion,
      Value<String> experienceUnitId,
      Value<int> rating,
      Value<DateTime> reviewedAtClient,
      Value<String?> reviewedTimeZone,
      Value<String?> reviewedLocalDate,
      Value<int> rowid,
    });

class $$LocalReviewEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reviewEventId => $composableBuilder(
    column: $table.reviewEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAtClient => $composableBuilder(
    column: $table.reviewedAtClient,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedTimeZone => $composableBuilder(
    column: $table.reviewedTimeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewedLocalDate => $composableBuilder(
    column: $table.reviewedLocalDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalReviewEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reviewEventId => $composableBuilder(
    column: $table.reviewEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAtClient => $composableBuilder(
    column: $table.reviewedAtClient,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedTimeZone => $composableBuilder(
    column: $table.reviewedTimeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewedLocalDate => $composableBuilder(
    column: $table.reviewedLocalDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalReviewEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalReviewEventsTable> {
  $$LocalReviewEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reviewEventId => $composableBuilder(
    column: $table.reviewEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAtClient => $composableBuilder(
    column: $table.reviewedAtClient,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewedTimeZone => $composableBuilder(
    column: $table.reviewedTimeZone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewedLocalDate => $composableBuilder(
    column: $table.reviewedLocalDate,
    builder: (column) => column,
  );
}

class $$LocalReviewEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalReviewEventsTable,
          LocalReviewEvent,
          $$LocalReviewEventsTableFilterComposer,
          $$LocalReviewEventsTableOrderingComposer,
          $$LocalReviewEventsTableAnnotationComposer,
          $$LocalReviewEventsTableCreateCompanionBuilder,
          $$LocalReviewEventsTableUpdateCompanionBuilder,
          (
            LocalReviewEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalReviewEventsTable,
              LocalReviewEvent
            >,
          ),
          LocalReviewEvent,
          PrefetchHooks Function()
        > {
  $$LocalReviewEventsTableTableManager(
    _$AppDatabase db,
    $LocalReviewEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalReviewEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalReviewEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalReviewEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> reviewEventId = const Value.absent(),
                Value<String> wordSenseId = const Value.absent(),
                Value<int> programVersion = const Value.absent(),
                Value<String> experienceUnitId = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<DateTime> reviewedAtClient = const Value.absent(),
                Value<String?> reviewedTimeZone = const Value.absent(),
                Value<String?> reviewedLocalDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewEventsCompanion(
                reviewEventId: reviewEventId,
                wordSenseId: wordSenseId,
                programVersion: programVersion,
                experienceUnitId: experienceUnitId,
                rating: rating,
                reviewedAtClient: reviewedAtClient,
                reviewedTimeZone: reviewedTimeZone,
                reviewedLocalDate: reviewedLocalDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String reviewEventId,
                required String wordSenseId,
                required int programVersion,
                required String experienceUnitId,
                required int rating,
                required DateTime reviewedAtClient,
                Value<String?> reviewedTimeZone = const Value.absent(),
                Value<String?> reviewedLocalDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalReviewEventsCompanion.insert(
                reviewEventId: reviewEventId,
                wordSenseId: wordSenseId,
                programVersion: programVersion,
                experienceUnitId: experienceUnitId,
                rating: rating,
                reviewedAtClient: reviewedAtClient,
                reviewedTimeZone: reviewedTimeZone,
                reviewedLocalDate: reviewedLocalDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalReviewEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalReviewEventsTable,
      LocalReviewEvent,
      $$LocalReviewEventsTableFilterComposer,
      $$LocalReviewEventsTableOrderingComposer,
      $$LocalReviewEventsTableAnnotationComposer,
      $$LocalReviewEventsTableCreateCompanionBuilder,
      $$LocalReviewEventsTableUpdateCompanionBuilder,
      (
        LocalReviewEvent,
        BaseReferences<
          _$AppDatabase,
          $LocalReviewEventsTable,
          LocalReviewEvent
        >,
      ),
      LocalReviewEvent,
      PrefetchHooks Function()
    >;
typedef $$OutboxRecordsTableCreateCompanionBuilder =
    OutboxRecordsCompanion Function({
      required String operationId,
      required String workspaceId,
      required String entityType,
      required String entityId,
      required String action,
      required String clientUpdatedAt,
      required String payloadJson,
      Value<int> attemptCount,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OutboxRecordsTableUpdateCompanionBuilder =
    OutboxRecordsCompanion Function({
      Value<String> operationId,
      Value<String> workspaceId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> action,
      Value<String> clientUpdatedAt,
      Value<String> payloadJson,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OutboxRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxRecordsTable,
          OutboxRecord,
          $$OutboxRecordsTableFilterComposer,
          $$OutboxRecordsTableOrderingComposer,
          $$OutboxRecordsTableAnnotationComposer,
          $$OutboxRecordsTableCreateCompanionBuilder,
          $$OutboxRecordsTableUpdateCompanionBuilder,
          (
            OutboxRecord,
            BaseReferences<_$AppDatabase, $OutboxRecordsTable, OutboxRecord>,
          ),
          OutboxRecord,
          PrefetchHooks Function()
        > {
  $$OutboxRecordsTableTableManager(_$AppDatabase db, $OutboxRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> workspaceId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> clientUpdatedAt = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxRecordsCompanion(
                operationId: operationId,
                workspaceId: workspaceId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                clientUpdatedAt: clientUpdatedAt,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String workspaceId,
                required String entityType,
                required String entityId,
                required String action,
                required String clientUpdatedAt,
                required String payloadJson,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxRecordsCompanion.insert(
                operationId: operationId,
                workspaceId: workspaceId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                clientUpdatedAt: clientUpdatedAt,
                payloadJson: payloadJson,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxRecordsTable,
      OutboxRecord,
      $$OutboxRecordsTableFilterComposer,
      $$OutboxRecordsTableOrderingComposer,
      $$OutboxRecordsTableAnnotationComposer,
      $$OutboxRecordsTableCreateCompanionBuilder,
      $$OutboxRecordsTableUpdateCompanionBuilder,
      (
        OutboxRecord,
        BaseReferences<_$AppDatabase, $OutboxRecordsTable, OutboxRecord>,
      ),
      OutboxRecord,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableTableCreateCompanionBuilder =
    SyncStateTableCompanion Function({
      required String workspaceId,
      Value<int> lastAppliedHotChangeId,
      Value<int> lastAppliedReviewSequenceId,
      Value<bool> hasHydratedHotState,
      Value<bool> hasHydratedReviewHistory,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableTableUpdateCompanionBuilder =
    SyncStateTableCompanion Function({
      Value<String> workspaceId,
      Value<int> lastAppliedHotChangeId,
      Value<int> lastAppliedReviewSequenceId,
      Value<bool> hasHydratedHotState,
      Value<bool> hasHydratedReviewHistory,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAppliedHotChangeId => $composableBuilder(
    column: $table.lastAppliedHotChangeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAppliedReviewSequenceId => $composableBuilder(
    column: $table.lastAppliedReviewSequenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasHydratedHotState => $composableBuilder(
    column: $table.hasHydratedHotState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasHydratedReviewHistory => $composableBuilder(
    column: $table.hasHydratedReviewHistory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAppliedHotChangeId => $composableBuilder(
    column: $table.lastAppliedHotChangeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAppliedReviewSequenceId => $composableBuilder(
    column: $table.lastAppliedReviewSequenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasHydratedHotState => $composableBuilder(
    column: $table.hasHydratedHotState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasHydratedReviewHistory => $composableBuilder(
    column: $table.hasHydratedReviewHistory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAppliedHotChangeId => $composableBuilder(
    column: $table.lastAppliedHotChangeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAppliedReviewSequenceId => $composableBuilder(
    column: $table.lastAppliedReviewSequenceId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasHydratedHotState => $composableBuilder(
    column: $table.hasHydratedHotState,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasHydratedReviewHistory => $composableBuilder(
    column: $table.hasHydratedReviewHistory,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTableTable,
          SyncStateTableData,
          $$SyncStateTableTableFilterComposer,
          $$SyncStateTableTableOrderingComposer,
          $$SyncStateTableTableAnnotationComposer,
          $$SyncStateTableTableCreateCompanionBuilder,
          $$SyncStateTableTableUpdateCompanionBuilder,
          (
            SyncStateTableData,
            BaseReferences<
              _$AppDatabase,
              $SyncStateTableTable,
              SyncStateTableData
            >,
          ),
          SyncStateTableData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableTableManager(
    _$AppDatabase db,
    $SyncStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> workspaceId = const Value.absent(),
                Value<int> lastAppliedHotChangeId = const Value.absent(),
                Value<int> lastAppliedReviewSequenceId = const Value.absent(),
                Value<bool> hasHydratedHotState = const Value.absent(),
                Value<bool> hasHydratedReviewHistory = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion(
                workspaceId: workspaceId,
                lastAppliedHotChangeId: lastAppliedHotChangeId,
                lastAppliedReviewSequenceId: lastAppliedReviewSequenceId,
                hasHydratedHotState: hasHydratedHotState,
                hasHydratedReviewHistory: hasHydratedReviewHistory,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workspaceId,
                Value<int> lastAppliedHotChangeId = const Value.absent(),
                Value<int> lastAppliedReviewSequenceId = const Value.absent(),
                Value<bool> hasHydratedHotState = const Value.absent(),
                Value<bool> hasHydratedReviewHistory = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion.insert(
                workspaceId: workspaceId,
                lastAppliedHotChangeId: lastAppliedHotChangeId,
                lastAppliedReviewSequenceId: lastAppliedReviewSequenceId,
                hasHydratedHotState: hasHydratedHotState,
                hasHydratedReviewHistory: hasHydratedReviewHistory,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTableTable,
      SyncStateTableData,
      $$SyncStateTableTableFilterComposer,
      $$SyncStateTableTableOrderingComposer,
      $$SyncStateTableTableAnnotationComposer,
      $$SyncStateTableTableCreateCompanionBuilder,
      $$SyncStateTableTableUpdateCompanionBuilder,
      (
        SyncStateTableData,
        BaseReferences<_$AppDatabase, $SyncStateTableTable, SyncStateTableData>,
      ),
      SyncStateTableData,
      PrefetchHooks Function()
    >;
typedef $$LocalSensesTableCreateCompanionBuilder =
    LocalSensesCompanion Function({
      required String wordSenseId,
      required String senseKey,
      required String lemma,
      required String pos,
      required String semanticType,
      required String localeL1,
      Value<int?> programVersion,
      Value<String?> programId,
      Value<int> rowid,
    });
typedef $$LocalSensesTableUpdateCompanionBuilder =
    LocalSensesCompanion Function({
      Value<String> wordSenseId,
      Value<String> senseKey,
      Value<String> lemma,
      Value<String> pos,
      Value<String> semanticType,
      Value<String> localeL1,
      Value<int?> programVersion,
      Value<String?> programId,
      Value<int> rowid,
    });

class $$LocalSensesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSensesTable> {
  $$LocalSensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senseKey => $composableBuilder(
    column: $table.senseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticType => $composableBuilder(
    column: $table.semanticType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localeL1 => $composableBuilder(
    column: $table.localeL1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSensesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSensesTable> {
  $$LocalSensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senseKey => $composableBuilder(
    column: $table.senseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lemma => $composableBuilder(
    column: $table.lemma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticType => $composableBuilder(
    column: $table.semanticType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localeL1 => $composableBuilder(
    column: $table.localeL1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSensesTable> {
  $$LocalSensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordSenseId => $composableBuilder(
    column: $table.wordSenseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senseKey =>
      $composableBuilder(column: $table.senseKey, builder: (column) => column);

  GeneratedColumn<String> get lemma =>
      $composableBuilder(column: $table.lemma, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get semanticType => $composableBuilder(
    column: $table.semanticType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localeL1 =>
      $composableBuilder(column: $table.localeL1, builder: (column) => column);

  GeneratedColumn<int> get programVersion => $composableBuilder(
    column: $table.programVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);
}

class $$LocalSensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSensesTable,
          LocalSense,
          $$LocalSensesTableFilterComposer,
          $$LocalSensesTableOrderingComposer,
          $$LocalSensesTableAnnotationComposer,
          $$LocalSensesTableCreateCompanionBuilder,
          $$LocalSensesTableUpdateCompanionBuilder,
          (
            LocalSense,
            BaseReferences<_$AppDatabase, $LocalSensesTable, LocalSense>,
          ),
          LocalSense,
          PrefetchHooks Function()
        > {
  $$LocalSensesTableTableManager(_$AppDatabase db, $LocalSensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordSenseId = const Value.absent(),
                Value<String> senseKey = const Value.absent(),
                Value<String> lemma = const Value.absent(),
                Value<String> pos = const Value.absent(),
                Value<String> semanticType = const Value.absent(),
                Value<String> localeL1 = const Value.absent(),
                Value<int?> programVersion = const Value.absent(),
                Value<String?> programId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSensesCompanion(
                wordSenseId: wordSenseId,
                senseKey: senseKey,
                lemma: lemma,
                pos: pos,
                semanticType: semanticType,
                localeL1: localeL1,
                programVersion: programVersion,
                programId: programId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordSenseId,
                required String senseKey,
                required String lemma,
                required String pos,
                required String semanticType,
                required String localeL1,
                Value<int?> programVersion = const Value.absent(),
                Value<String?> programId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSensesCompanion.insert(
                wordSenseId: wordSenseId,
                senseKey: senseKey,
                lemma: lemma,
                pos: pos,
                semanticType: semanticType,
                localeL1: localeL1,
                programVersion: programVersion,
                programId: programId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSensesTable,
      LocalSense,
      $$LocalSensesTableFilterComposer,
      $$LocalSensesTableOrderingComposer,
      $$LocalSensesTableAnnotationComposer,
      $$LocalSensesTableCreateCompanionBuilder,
      $$LocalSensesTableUpdateCompanionBuilder,
      (
        LocalSense,
        BaseReferences<_$AppDatabase, $LocalSensesTable, LocalSense>,
      ),
      LocalSense,
      PrefetchHooks Function()
    >;
typedef $$LocalProgramsTableCreateCompanionBuilder =
    LocalProgramsCompanion Function({
      required String programId,
      required String json,
      Value<int> rowid,
    });
typedef $$LocalProgramsTableUpdateCompanionBuilder =
    LocalProgramsCompanion Function({
      Value<String> programId,
      Value<String> json,
      Value<int> rowid,
    });

class $$LocalProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProgramsTable> {
  $$LocalProgramsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProgramsTable> {
  $$LocalProgramsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProgramsTable> {
  $$LocalProgramsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LocalProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProgramsTable,
          LocalProgram,
          $$LocalProgramsTableFilterComposer,
          $$LocalProgramsTableOrderingComposer,
          $$LocalProgramsTableAnnotationComposer,
          $$LocalProgramsTableCreateCompanionBuilder,
          $$LocalProgramsTableUpdateCompanionBuilder,
          (
            LocalProgram,
            BaseReferences<_$AppDatabase, $LocalProgramsTable, LocalProgram>,
          ),
          LocalProgram,
          PrefetchHooks Function()
        > {
  $$LocalProgramsTableTableManager(_$AppDatabase db, $LocalProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> programId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProgramsCompanion(
                programId: programId,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String programId,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => LocalProgramsCompanion.insert(
                programId: programId,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProgramsTable,
      LocalProgram,
      $$LocalProgramsTableFilterComposer,
      $$LocalProgramsTableOrderingComposer,
      $$LocalProgramsTableAnnotationComposer,
      $$LocalProgramsTableCreateCompanionBuilder,
      $$LocalProgramsTableUpdateCompanionBuilder,
      (
        LocalProgram,
        BaseReferences<_$AppDatabase, $LocalProgramsTable, LocalProgram>,
      ),
      LocalProgram,
      PrefetchHooks Function()
    >;
typedef $$LocalWorkspaceSettingsTableCreateCompanionBuilder =
    LocalWorkspaceSettingsCompanion Function({
      required String workspaceId,
      required String json,
      Value<int> rowid,
    });
typedef $$LocalWorkspaceSettingsTableUpdateCompanionBuilder =
    LocalWorkspaceSettingsCompanion Function({
      Value<String> workspaceId,
      Value<String> json,
      Value<int> rowid,
    });

class $$LocalWorkspaceSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWorkspaceSettingsTable> {
  $$LocalWorkspaceSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWorkspaceSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWorkspaceSettingsTable> {
  $$LocalWorkspaceSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWorkspaceSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWorkspaceSettingsTable> {
  $$LocalWorkspaceSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LocalWorkspaceSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWorkspaceSettingsTable,
          LocalWorkspaceSetting,
          $$LocalWorkspaceSettingsTableFilterComposer,
          $$LocalWorkspaceSettingsTableOrderingComposer,
          $$LocalWorkspaceSettingsTableAnnotationComposer,
          $$LocalWorkspaceSettingsTableCreateCompanionBuilder,
          $$LocalWorkspaceSettingsTableUpdateCompanionBuilder,
          (
            LocalWorkspaceSetting,
            BaseReferences<
              _$AppDatabase,
              $LocalWorkspaceSettingsTable,
              LocalWorkspaceSetting
            >,
          ),
          LocalWorkspaceSetting,
          PrefetchHooks Function()
        > {
  $$LocalWorkspaceSettingsTableTableManager(
    _$AppDatabase db,
    $LocalWorkspaceSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWorkspaceSettingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalWorkspaceSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalWorkspaceSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> workspaceId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWorkspaceSettingsCompanion(
                workspaceId: workspaceId,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workspaceId,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => LocalWorkspaceSettingsCompanion.insert(
                workspaceId: workspaceId,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWorkspaceSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWorkspaceSettingsTable,
      LocalWorkspaceSetting,
      $$LocalWorkspaceSettingsTableFilterComposer,
      $$LocalWorkspaceSettingsTableOrderingComposer,
      $$LocalWorkspaceSettingsTableAnnotationComposer,
      $$LocalWorkspaceSettingsTableCreateCompanionBuilder,
      $$LocalWorkspaceSettingsTableUpdateCompanionBuilder,
      (
        LocalWorkspaceSetting,
        BaseReferences<
          _$AppDatabase,
          $LocalWorkspaceSettingsTable,
          LocalWorkspaceSetting
        >,
      ),
      LocalWorkspaceSetting,
      PrefetchHooks Function()
    >;
typedef $$LocalListsTableCreateCompanionBuilder =
    LocalListsCompanion Function({
      required String listId,
      required String name,
      required String filterDefinitionJson,
      required String clientUpdatedAt,
      required String lastModifiedByReplicaId,
      required String lastOperationId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$LocalListsTableUpdateCompanionBuilder =
    LocalListsCompanion Function({
      Value<String> listId,
      Value<String> name,
      Value<String> filterDefinitionJson,
      Value<String> clientUpdatedAt,
      Value<String> lastModifiedByReplicaId,
      Value<String> lastOperationId,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$LocalListsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filterDefinitionJson => $composableBuilder(
    column: $table.filterDefinitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalListsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filterDefinitionJson => $composableBuilder(
    column: $table.filterDefinitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalListsTable> {
  $$LocalListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get filterDefinitionJson => $composableBuilder(
    column: $table.filterDefinitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastModifiedByReplicaId => $composableBuilder(
    column: $table.lastModifiedByReplicaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastOperationId => $composableBuilder(
    column: $table.lastOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalListsTable,
          LocalList,
          $$LocalListsTableFilterComposer,
          $$LocalListsTableOrderingComposer,
          $$LocalListsTableAnnotationComposer,
          $$LocalListsTableCreateCompanionBuilder,
          $$LocalListsTableUpdateCompanionBuilder,
          (
            LocalList,
            BaseReferences<_$AppDatabase, $LocalListsTable, LocalList>,
          ),
          LocalList,
          PrefetchHooks Function()
        > {
  $$LocalListsTableTableManager(_$AppDatabase db, $LocalListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> filterDefinitionJson = const Value.absent(),
                Value<String> clientUpdatedAt = const Value.absent(),
                Value<String> lastModifiedByReplicaId = const Value.absent(),
                Value<String> lastOperationId = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalListsCompanion(
                listId: listId,
                name: name,
                filterDefinitionJson: filterDefinitionJson,
                clientUpdatedAt: clientUpdatedAt,
                lastModifiedByReplicaId: lastModifiedByReplicaId,
                lastOperationId: lastOperationId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String listId,
                required String name,
                required String filterDefinitionJson,
                required String clientUpdatedAt,
                required String lastModifiedByReplicaId,
                required String lastOperationId,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalListsCompanion.insert(
                listId: listId,
                name: name,
                filterDefinitionJson: filterDefinitionJson,
                clientUpdatedAt: clientUpdatedAt,
                lastModifiedByReplicaId: lastModifiedByReplicaId,
                lastOperationId: lastOperationId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalListsTable,
      LocalList,
      $$LocalListsTableFilterComposer,
      $$LocalListsTableOrderingComposer,
      $$LocalListsTableAnnotationComposer,
      $$LocalListsTableCreateCompanionBuilder,
      $$LocalListsTableUpdateCompanionBuilder,
      (LocalList, BaseReferences<_$AppDatabase, $LocalListsTable, LocalList>),
      LocalList,
      PrefetchHooks Function()
    >;
typedef $$LocalFavoritesTableCreateCompanionBuilder =
    LocalFavoritesCompanion Function({
      required String experienceKey,
      required String programId,
      required String experienceUnitId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalFavoritesTableUpdateCompanionBuilder =
    LocalFavoritesCompanion Function({
      Value<String> experienceKey,
      Value<String> programId,
      Value<String> experienceUnitId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalFavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFavoritesTable> {
  $$LocalFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get experienceKey => $composableBuilder(
    column: $table.experienceKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFavoritesTable> {
  $$LocalFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get experienceKey => $composableBuilder(
    column: $table.experienceKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFavoritesTable> {
  $$LocalFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get experienceKey => $composableBuilder(
    column: $table.experienceKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<String> get experienceUnitId => $composableBuilder(
    column: $table.experienceUnitId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalFavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFavoritesTable,
          LocalFavorite,
          $$LocalFavoritesTableFilterComposer,
          $$LocalFavoritesTableOrderingComposer,
          $$LocalFavoritesTableAnnotationComposer,
          $$LocalFavoritesTableCreateCompanionBuilder,
          $$LocalFavoritesTableUpdateCompanionBuilder,
          (
            LocalFavorite,
            BaseReferences<_$AppDatabase, $LocalFavoritesTable, LocalFavorite>,
          ),
          LocalFavorite,
          PrefetchHooks Function()
        > {
  $$LocalFavoritesTableTableManager(
    _$AppDatabase db,
    $LocalFavoritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> experienceKey = const Value.absent(),
                Value<String> programId = const Value.absent(),
                Value<String> experienceUnitId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoritesCompanion(
                experienceKey: experienceKey,
                programId: programId,
                experienceUnitId: experienceUnitId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String experienceKey,
                required String programId,
                required String experienceUnitId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFavoritesCompanion.insert(
                experienceKey: experienceKey,
                programId: programId,
                experienceUnitId: experienceUnitId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFavoritesTable,
      LocalFavorite,
      $$LocalFavoritesTableFilterComposer,
      $$LocalFavoritesTableOrderingComposer,
      $$LocalFavoritesTableAnnotationComposer,
      $$LocalFavoritesTableCreateCompanionBuilder,
      $$LocalFavoritesTableUpdateCompanionBuilder,
      (
        LocalFavorite,
        BaseReferences<_$AppDatabase, $LocalFavoritesTable, LocalFavorite>,
      ),
      LocalFavorite,
      PrefetchHooks Function()
    >;
typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String senseId,
      required String noteText,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> senseId,
      Value<String> noteText,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalNotesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get senseId => $composableBuilder(
    column: $table.senseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get senseId => $composableBuilder(
    column: $table.senseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get senseId =>
      $composableBuilder(column: $table.senseId, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (
            LocalNote,
            BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>,
          ),
          LocalNote,
          PrefetchHooks Function()
        > {
  $$LocalNotesTableTableManager(_$AppDatabase db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> senseId = const Value.absent(),
                Value<String> noteText = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                senseId: senseId,
                noteText: noteText,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String senseId,
                required String noteText,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                senseId: senseId,
                noteText: noteText,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>),
      LocalNote,
      PrefetchHooks Function()
    >;
typedef $$LocalDailyCheckinsTableCreateCompanionBuilder =
    LocalDailyCheckinsCompanion Function({
      required String dayKey,
      required DateTime checkedAt,
      Value<int> rowid,
    });
typedef $$LocalDailyCheckinsTableUpdateCompanionBuilder =
    LocalDailyCheckinsCompanion Function({
      Value<String> dayKey,
      Value<DateTime> checkedAt,
      Value<int> rowid,
    });

class $$LocalDailyCheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDailyCheckinsTable> {
  $$LocalDailyCheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDailyCheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDailyCheckinsTable> {
  $$LocalDailyCheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDailyCheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDailyCheckinsTable> {
  $$LocalDailyCheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$LocalDailyCheckinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDailyCheckinsTable,
          LocalDailyCheckin,
          $$LocalDailyCheckinsTableFilterComposer,
          $$LocalDailyCheckinsTableOrderingComposer,
          $$LocalDailyCheckinsTableAnnotationComposer,
          $$LocalDailyCheckinsTableCreateCompanionBuilder,
          $$LocalDailyCheckinsTableUpdateCompanionBuilder,
          (
            LocalDailyCheckin,
            BaseReferences<
              _$AppDatabase,
              $LocalDailyCheckinsTable,
              LocalDailyCheckin
            >,
          ),
          LocalDailyCheckin,
          PrefetchHooks Function()
        > {
  $$LocalDailyCheckinsTableTableManager(
    _$AppDatabase db,
    $LocalDailyCheckinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDailyCheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDailyCheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDailyCheckinsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> dayKey = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDailyCheckinsCompanion(
                dayKey: dayKey,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dayKey,
                required DateTime checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalDailyCheckinsCompanion.insert(
                dayKey: dayKey,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDailyCheckinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDailyCheckinsTable,
      LocalDailyCheckin,
      $$LocalDailyCheckinsTableFilterComposer,
      $$LocalDailyCheckinsTableOrderingComposer,
      $$LocalDailyCheckinsTableAnnotationComposer,
      $$LocalDailyCheckinsTableCreateCompanionBuilder,
      $$LocalDailyCheckinsTableUpdateCompanionBuilder,
      (
        LocalDailyCheckin,
        BaseReferences<
          _$AppDatabase,
          $LocalDailyCheckinsTable,
          LocalDailyCheckin
        >,
      ),
      LocalDailyCheckin,
      PrefetchHooks Function()
    >;
typedef $$LocalSessionsTableCreateCompanionBuilder =
    LocalSessionsCompanion Function({
      required String sessionId,
      required String kind,
      required DateTime startedAt,
      required DateTime endedAt,
      required int durationSeconds,
      Value<int> rowid,
    });
typedef $$LocalSessionsTableUpdateCompanionBuilder =
    LocalSessionsCompanion Function({
      Value<String> sessionId,
      Value<String> kind,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> durationSeconds,
      Value<int> rowid,
    });

class $$LocalSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );
}

class $$LocalSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSessionsTable,
          LocalSession,
          $$LocalSessionsTableFilterComposer,
          $$LocalSessionsTableOrderingComposer,
          $$LocalSessionsTableAnnotationComposer,
          $$LocalSessionsTableCreateCompanionBuilder,
          $$LocalSessionsTableUpdateCompanionBuilder,
          (
            LocalSession,
            BaseReferences<_$AppDatabase, $LocalSessionsTable, LocalSession>,
          ),
          LocalSession,
          PrefetchHooks Function()
        > {
  $$LocalSessionsTableTableManager(_$AppDatabase db, $LocalSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSessionsCompanion(
                sessionId: sessionId,
                kind: kind,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String kind,
                required DateTime startedAt,
                required DateTime endedAt,
                required int durationSeconds,
                Value<int> rowid = const Value.absent(),
              }) => LocalSessionsCompanion.insert(
                sessionId: sessionId,
                kind: kind,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSessionsTable,
      LocalSession,
      $$LocalSessionsTableFilterComposer,
      $$LocalSessionsTableOrderingComposer,
      $$LocalSessionsTableAnnotationComposer,
      $$LocalSessionsTableCreateCompanionBuilder,
      $$LocalSessionsTableUpdateCompanionBuilder,
      (
        LocalSession,
        BaseReferences<_$AppDatabase, $LocalSessionsTable, LocalSession>,
      ),
      LocalSession,
      PrefetchHooks Function()
    >;
typedef $$LocalContentCatalogTableCreateCompanionBuilder =
    LocalContentCatalogCompanion Function({
      Value<int> version,
      required String json,
    });
typedef $$LocalContentCatalogTableUpdateCompanionBuilder =
    LocalContentCatalogCompanion Function({
      Value<int> version,
      Value<String> json,
    });

class $$LocalContentCatalogTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContentCatalogTable> {
  $$LocalContentCatalogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContentCatalogTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContentCatalogTable> {
  $$LocalContentCatalogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContentCatalogTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContentCatalogTable> {
  $$LocalContentCatalogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LocalContentCatalogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContentCatalogTable,
          LocalContentCatalogData,
          $$LocalContentCatalogTableFilterComposer,
          $$LocalContentCatalogTableOrderingComposer,
          $$LocalContentCatalogTableAnnotationComposer,
          $$LocalContentCatalogTableCreateCompanionBuilder,
          $$LocalContentCatalogTableUpdateCompanionBuilder,
          (
            LocalContentCatalogData,
            BaseReferences<
              _$AppDatabase,
              $LocalContentCatalogTable,
              LocalContentCatalogData
            >,
          ),
          LocalContentCatalogData,
          PrefetchHooks Function()
        > {
  $$LocalContentCatalogTableTableManager(
    _$AppDatabase db,
    $LocalContentCatalogTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContentCatalogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContentCatalogTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalContentCatalogTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String> json = const Value.absent(),
              }) => LocalContentCatalogCompanion(version: version, json: json),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                required String json,
              }) => LocalContentCatalogCompanion.insert(
                version: version,
                json: json,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContentCatalogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContentCatalogTable,
      LocalContentCatalogData,
      $$LocalContentCatalogTableFilterComposer,
      $$LocalContentCatalogTableOrderingComposer,
      $$LocalContentCatalogTableAnnotationComposer,
      $$LocalContentCatalogTableCreateCompanionBuilder,
      $$LocalContentCatalogTableUpdateCompanionBuilder,
      (
        LocalContentCatalogData,
        BaseReferences<
          _$AppDatabase,
          $LocalContentCatalogTable,
          LocalContentCatalogData
        >,
      ),
      LocalContentCatalogData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalLearningStatesTableTableManager get localLearningStates =>
      $$LocalLearningStatesTableTableManager(_db, _db.localLearningStates);
  $$LocalReviewEventsTableTableManager get localReviewEvents =>
      $$LocalReviewEventsTableTableManager(_db, _db.localReviewEvents);
  $$OutboxRecordsTableTableManager get outboxRecords =>
      $$OutboxRecordsTableTableManager(_db, _db.outboxRecords);
  $$SyncStateTableTableTableManager get syncStateTable =>
      $$SyncStateTableTableTableManager(_db, _db.syncStateTable);
  $$LocalSensesTableTableManager get localSenses =>
      $$LocalSensesTableTableManager(_db, _db.localSenses);
  $$LocalProgramsTableTableManager get localPrograms =>
      $$LocalProgramsTableTableManager(_db, _db.localPrograms);
  $$LocalWorkspaceSettingsTableTableManager get localWorkspaceSettings =>
      $$LocalWorkspaceSettingsTableTableManager(
        _db,
        _db.localWorkspaceSettings,
      );
  $$LocalListsTableTableManager get localLists =>
      $$LocalListsTableTableManager(_db, _db.localLists);
  $$LocalFavoritesTableTableManager get localFavorites =>
      $$LocalFavoritesTableTableManager(_db, _db.localFavorites);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$LocalDailyCheckinsTableTableManager get localDailyCheckins =>
      $$LocalDailyCheckinsTableTableManager(_db, _db.localDailyCheckins);
  $$LocalSessionsTableTableManager get localSessions =>
      $$LocalSessionsTableTableManager(_db, _db.localSessions);
  $$LocalContentCatalogTableTableManager get localContentCatalog =>
      $$LocalContentCatalogTableTableManager(_db, _db.localContentCatalog);
}
