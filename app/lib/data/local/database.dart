import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local learning state mirror (offline source of truth).
class LocalLearningStates extends Table {
  TextColumn get wordSenseId => text()();
  TextColumn get learningStateId => text()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  IntColumn get reps => integer()();
  IntColumn get lapses => integer()();
  RealColumn get fsrsStability => real().nullable()();
  RealColumn get fsrsDifficulty => real().nullable()();
  DateTimeColumn get fsrsLastReviewedAt => dateTime().nullable()();
  IntColumn get fsrsScheduledDays => integer().nullable()();
  TextColumn get fsrsCardState => text()();
  IntColumn get fsrsStepIndex => integer().nullable()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get lastModifiedByReplicaId => text()();
  TextColumn get lastOperationId => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {wordSenseId};
}

/// Append-only local review events.
class LocalReviewEvents extends Table {
  TextColumn get reviewEventId => text()();
  TextColumn get wordSenseId => text()();
  IntColumn get programVersion => integer()();
  TextColumn get experienceUnitId => text()();
  IntColumn get rating => integer()();
  DateTimeColumn get reviewedAtClient => dateTime()();
  TextColumn get reviewedTimeZone => text().nullable()();
  TextColumn get reviewedLocalDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {reviewEventId};
}

/// Outbox: pending sync operations, ordered by creation.
class OutboxRecords extends Table {
  TextColumn get operationId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Sync cursors: hot state + review history lanes.
class SyncStateTable extends Table {
  TextColumn get workspaceId => text()();
  IntColumn get lastAppliedHotChangeId =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastAppliedReviewSequenceId =>
      integer().withDefault(const Constant(0))();
  BoolColumn get hasHydratedHotState =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hasHydratedReviewHistory =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {workspaceId};
}

/// Content channel cache: senses catalog + experience programs (offline playback).
class LocalSenses extends Table {
  TextColumn get wordSenseId => text()();
  TextColumn get senseKey => text()();
  TextColumn get lemma => text()();
  TextColumn get pos => text()();
  TextColumn get semanticType => text()();
  TextColumn get localeL1 => text()();
  IntColumn get programVersion => integer().nullable()();
  TextColumn get programId => text().nullable()();

  @override
  Set<Column> get primaryKey => {wordSenseId};
}

class LocalPrograms extends Table {
  TextColumn get programId => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {programId};
}

/// Workspace scheduler settings (from bootstrap) for offline FSRS.
class LocalWorkspaceSettings extends Table {
  TextColumn get workspaceId => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {workspaceId};
}

/// Word lists (smart filters: name + tag rule, at least one tag).
class LocalLists extends Table {
  TextColumn get listId => text()();
  TextColumn get name => text()();
  TextColumn get filterDefinitionJson => text()();
  TextColumn get clientUpdatedAt => text()();
  TextColumn get lastModifiedByReplicaId => text()();
  TextColumn get lastOperationId => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {listId};
}

@DriftDatabase(
  tables: [
    LocalLearningStates,
    LocalReviewEvents,
    OutboxRecords,
    SyncStateTable,
    LocalSenses,
    LocalPrograms,
    LocalWorkspaceSettings,
    LocalLists,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
      : super(executor ??
            driftDatabase(
              name: 'scenelex',
              // Web assets (sqlite3.wasm + drift_worker.js) live in web/.
              // Ignored on native platforms.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(
              localReviewEvents,
              localReviewEvents.reviewedLocalDate,
            );
          }
          if (from < 3) {
            await migrator.createTable(localLists);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
