import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

const _uuidGen = Uuid();

/// Local-first writes: entity first, then outbox, in one transaction.
class LocalRepository {
  LocalRepository(this.db);

  final AppDatabase db;

  // ------------------------------------------------------------------
  // Learning states
  // ------------------------------------------------------------------

  Future<List<LocalLearningState>> allStates(String workspaceId) {
    return (db.select(db.localLearningStates)..where((t) => t.deletedAt.isNull()))
        .get();
  }

  /// All review events in local order (single-workspace client: no workspace
  /// filter; the sync engine only pulls the selected workspace's history).
  Future<List<LocalReviewEvent>> allReviewEvents() =>
      db.select(db.localReviewEvents).get();

  Future<LocalLearningState?> stateFor(String wordSenseId) {
    return (db.select(db.localLearningStates)
          ..where((t) => t.wordSenseId.equals(wordSenseId)))
        .getSingleOrNull();
  }

  /// Create a learning state locally (new card) and queue an outbox upsert.
  Future<void> createLearningState({
    required String workspaceId,
    required String wordSenseId,
    required String nowIso,
  }) async {
    final operationId = _uuidGen.v4();
    await db.transaction(() async {
      await db.into(db.localLearningStates).insertOnConflictUpdate(
            LocalLearningStatesCompanion.insert(
              wordSenseId: wordSenseId,
              learningStateId: _uuidGen.v4(),
              reps: 0,
              lapses: 0,
              fsrsCardState: 'new',
              clientUpdatedAt: nowIso,
              lastModifiedByReplicaId: _uuidGen.v4(),
              lastOperationId: operationId,
            ),
          );
      await _enqueueOutbox(
        workspaceId: workspaceId,
        operationId: operationId,
        entityType: 'learning_state',
        entityId: wordSenseId,
        action: 'upsert',
        clientUpdatedAt: nowIso,
        payload: {
          'learningStateId': _uuidGen.v4(),
          'wordSenseId': wordSenseId,
          'dueAt': null,
          'reps': 0,
          'lapses': 0,
          'fsrsStability': null,
          'fsrsDifficulty': null,
          'fsrsLastReviewedAt': null,
          'fsrsScheduledDays': null,
          'fsrsCardState': 'new',
          'fsrsStepIndex': null,
          'clientUpdatedAt': nowIso,
          'lastModifiedByReplicaId': _uuidGen.v4(),
          'lastOperationId': operationId,
          'deletedAt': null,
        },
      );
    });
  }

  /// Locally apply a learning-state snapshot (from bootstrap/pull).
  Future<void> applyLearningState({
    required String wordSenseId,
    required String payloadJson,
  }) async {
    final p = jsonDecode(payloadJson) as Map<String, dynamic>;
    await db.into(db.localLearningStates).insertOnConflictUpdate(
          LocalLearningStatesCompanion.insert(
            wordSenseId: wordSenseId,
            learningStateId: p['learningStateId']?.toString() ?? wordSenseId,
            dueAt: Value(_dt(p['dueAt'])),
            reps: (p['reps'] as num?)?.toInt() ?? 0,
            lapses: (p['lapses'] as num?)?.toInt() ?? 0,
            fsrsStability: Value((p['fsrsStability'] as num?)?.toDouble()),
            fsrsDifficulty: Value((p['fsrsDifficulty'] as num?)?.toDouble()),
            fsrsLastReviewedAt: Value(_dt(p['fsrsLastReviewedAt'])),
            fsrsScheduledDays: Value((p['fsrsScheduledDays'] as num?)?.toInt()),
            fsrsCardState: p['fsrsCardState']?.toString() ?? 'new',
            fsrsStepIndex: Value((p['fsrsStepIndex'] as num?)?.toInt()),
            clientUpdatedAt: p['clientUpdatedAt']?.toString() ?? '',
            lastModifiedByReplicaId:
                p['lastModifiedByReplicaId']?.toString() ?? _uuidGen.v4(),
            lastOperationId: p['lastOperationId']?.toString() ?? _uuidGen.v4(),
            deletedAt: Value(_dt(p['deletedAt'])),
          ),
        );
  }

  /// Commit a review locally (offline): append event + update state + queue
  /// two outbox records (review_event append + learning_state upsert).
  Future<({String reviewEventId, String stateOpId})> commitReviewLocally({
    required String workspaceId,
    required String wordSenseId,
    required String learningStateId,
    required int programVersion,
    required String experienceUnitId,
    required int rating,
    required String reviewedAtClientIso,
    required String newStateJson,
  }) async {
    final reviewEventId = _uuidGen.v4();
    final stateOpId = _uuidGen.v4();
    final reviewedLocalDate = _localDateString(DateTime.now());

    await db.transaction(() async {
      await db.into(db.localReviewEvents).insert(
            LocalReviewEventsCompanion.insert(
              reviewEventId: reviewEventId,
              wordSenseId: wordSenseId,
              programVersion: programVersion,
              experienceUnitId: experienceUnitId,
              rating: rating,
              reviewedAtClient: DateTime.parse(reviewedAtClientIso).toUtc(),
              reviewedTimeZone: Value(DateTime.now().timeZoneName),
              reviewedLocalDate: Value(reviewedLocalDate),
            ),
          );

      final state = jsonDecode(newStateJson) as Map<String, dynamic>;
      await db.into(db.localLearningStates).insertOnConflictUpdate(
            LocalLearningStatesCompanion.insert(
              wordSenseId: wordSenseId,
              learningStateId: learningStateId,
              dueAt: Value(_dt(state['dueAt'])),
              reps: (state['reps'] as num?)?.toInt() ?? 0,
              lapses: (state['lapses'] as num?)?.toInt() ?? 0,
              fsrsStability: Value((state['fsrsStability'] as num?)?.toDouble()),
              fsrsDifficulty: Value((state['fsrsDifficulty'] as num?)?.toDouble()),
              fsrsLastReviewedAt: Value(_dt(state['fsrsLastReviewedAt'])),
              fsrsScheduledDays: Value((state['fsrsScheduledDays'] as num?)?.toInt()),
              fsrsCardState: state['fsrsCardState']?.toString() ?? 'learning',
              fsrsStepIndex: Value((state['fsrsStepIndex'] as num?)?.toInt()),
              clientUpdatedAt: reviewedAtClientIso,
              lastModifiedByReplicaId: _uuidGen.v4(),
              lastOperationId: stateOpId,
            ),
          );

      // Outbox: review_event first, then state upsert (matches reference order).
      await _enqueueOutbox(
        workspaceId: workspaceId,
        operationId: reviewEventId,
        entityType: 'review_event',
        entityId: wordSenseId,
        action: 'append',
        clientUpdatedAt: reviewedAtClientIso,
        payload: {
          'reviewEventId': reviewEventId,
          'wordSenseId': wordSenseId,
          'programVersion': programVersion,
          'experienceUnitId': experienceUnitId,
          'clientEventId': reviewEventId,
          'rating': rating,
          'reviewedAtClient': reviewedAtClientIso,
          'reviewedTimeZone': DateTime.now().timeZoneName,
          'reviewedLocalDate': reviewedLocalDate,
        },
      );
      await _enqueueOutbox(
        workspaceId: workspaceId,
        operationId: stateOpId,
        entityType: 'learning_state',
        entityId: wordSenseId,
        action: 'upsert',
        clientUpdatedAt: reviewedAtClientIso,
        payload: {
          'learningStateId': learningStateId,
          'wordSenseId': wordSenseId,
          'dueAt': state['dueAt'],
          'reps': state['reps'],
          'lapses': state['lapses'],
          'fsrsStability': state['fsrsStability'],
          'fsrsDifficulty': state['fsrsDifficulty'],
          'fsrsLastReviewedAt': state['fsrsLastReviewedAt'],
          'fsrsScheduledDays': state['fsrsScheduledDays'],
          'fsrsCardState': state['fsrsCardState'],
          'fsrsStepIndex': state['fsrsStepIndex'],
          'clientUpdatedAt': reviewedAtClientIso,
          'lastModifiedByReplicaId': _uuidGen.v4(),
          'lastOperationId': stateOpId,
          'deletedAt': null,
        },
      );
    });

    return (reviewEventId: reviewEventId, stateOpId: stateOpId);
  }

  // ------------------------------------------------------------------
  // Outbox
  // ------------------------------------------------------------------

  Future<List<OutboxRecord>> pendingOperations(String workspaceId) {
    return (db.select(db.outboxRecords)
          ..where((t) => t.workspaceId.equals(workspaceId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> _enqueueOutbox({
    required String workspaceId,
    required String operationId,
    required String entityType,
    required String entityId,
    required String action,
    required String clientUpdatedAt,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.outboxRecords).insert(
          OutboxRecordsCompanion.insert(
            operationId: operationId,
            workspaceId: workspaceId,
            entityType: entityType,
            entityId: entityId,
            action: action,
            clientUpdatedAt: clientUpdatedAt,
            payloadJson: jsonEncode(payload),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> removeOutboxOperation(String operationId) async {
    await (db.delete(db.outboxRecords)
          ..where((t) => t.operationId.equals(operationId)))
        .go();
  }

  Future<void> markOutboxFailure(String operationId, String error) async {
    await (db.update(db.outboxRecords)
          ..where((t) => t.operationId.equals(operationId)))
        .write(OutboxRecordsCompanion(
          attemptCount: const Value(1),
          lastError: Value(error),
        ));
  }

  // ------------------------------------------------------------------
  // Sync state (cursors)
  // ------------------------------------------------------------------

  Future<SyncStateTableData> syncState(String workspaceId) async {
    final existing = await (db.select(db.syncStateTable)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .getSingleOrNull();
    if (existing != null) return existing;
    return SyncStateTableData(
      workspaceId: workspaceId,
      lastAppliedHotChangeId: 0,
      lastAppliedReviewSequenceId: 0,
      hasHydratedHotState: false,
      hasHydratedReviewHistory: false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> setHotCursor(String workspaceId, int changeId) async {
    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            workspaceId: workspaceId,
            lastAppliedHotChangeId: Value(changeId),
            hasHydratedHotState: const Value(true),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> setHydrated(String workspaceId, {bool hot = true}) async {
    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            workspaceId: workspaceId,
            hasHydratedHotState: Value(hot),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  // ------------------------------------------------------------------
  // Content cache
  // ------------------------------------------------------------------

  Future<void> cacheSenses(List<Map<String, dynamic>> senses) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.localSenses,
        [
          for (final s in senses)
            LocalSensesCompanion.insert(
              wordSenseId: s['wordSenseId'] as String,
              senseKey: s['senseKey'] as String,
              lemma: s['lemma'] as String,
              pos: s['pos']?.toString() ?? '',
              semanticType: s['semanticType']?.toString() ?? '',
              localeL1: s['localeL1']?.toString() ?? '',
              programVersion: Value(s['programVersion'] as int?),
              programId: Value(s['programId'] as String?),
            ),
        ],
      );
    });
  }

  Future<List<LocalSense>> cachedSenses() => db.select(db.localSenses).get();

  Future<void> cacheProgram(
      String programId, Map<String, dynamic> program) async {
    await db.into(db.localPrograms).insertOnConflictUpdate(
          LocalProgramsCompanion.insert(
            programId: programId,
            json: jsonEncode(program),
          ),
        );
  }

  Future<Map<String, dynamic>?> cachedProgram(String programId) async {
    final row = await (db.select(db.localPrograms)
          ..where((t) => t.programId.equals(programId)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.json) as Map<String, dynamic>;
  }

  Future<void> cacheWorkspaceSettings(
      String workspaceId, Map<String, dynamic> settings) async {
    await db.into(db.localWorkspaceSettings).insertOnConflictUpdate(
          LocalWorkspaceSettingsCompanion.insert(
            workspaceId: workspaceId,
            json: jsonEncode(settings),
          ),
        );
  }

  Future<Map<String, dynamic>?> cachedWorkspaceSettings(
      String workspaceId) async {
    final row = await (db.select(db.localWorkspaceSettings)
          ..where((t) => t.workspaceId.equals(workspaceId)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.json) as Map<String, dynamic>;
  }

  /// Update workspace scheduler settings locally and queue an outbox upsert
  /// (entity + outbox in the same transaction).
  Future<void> updateWorkspaceSettings({
    required String workspaceId,
    required Map<String, dynamic> settings,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final operationId = _uuidGen.v4();
    final settingsJson = jsonEncode(settings);

    await db.transaction(() async {
      await db.into(db.localWorkspaceSettings).insertOnConflictUpdate(
            LocalWorkspaceSettingsCompanion.insert(
              workspaceId: workspaceId,
              json: settingsJson,
            ),
          );
      await _enqueueOutbox(
        workspaceId: workspaceId,
        operationId: operationId,
        entityType: 'workspace_scheduler_settings',
        entityId: workspaceId,
        action: 'upsert',
        clientUpdatedAt: nowIso,
        payload: {...settings, 'clientUpdatedAt': nowIso},
      );
    });
  }
}

DateTime? _dt(dynamic v) =>
    v == null ? null : DateTime.parse(v.toString()).toUtc();

/// YYYY-MM-DD in the device-local timezone (streak/progress bucket key).
String _localDateString(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';
