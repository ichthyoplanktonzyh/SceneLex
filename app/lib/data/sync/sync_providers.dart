import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../providers.dart' show installationIdProvider, workspaceProvider;
import '../local/database.dart';
import '../local/local_repository.dart';
import 'sync_engine.dart';

/// Local database (offline source of truth).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final localRepositoryProvider = Provider<LocalRepository>(
  (ref) => LocalRepository(ref.watch(databaseProvider)),
);

/// Sync engine for the selected workspace (created lazily after login).
final syncEngineProvider = FutureProvider.autoDispose<SyncEngine>((ref) async {
  final api = ref.watch(apiClientProvider);
  final local = ref.watch(localRepositoryProvider);
  final ws = await ref.watch(workspaceProvider.future);
  final installId = await ref.watch(installationIdProvider.future);
  final engine = SyncEngine(api: api, local: local, workspaceId: ws);
  engine.installationId = installId;
  return engine;
});

/// Runs the full sync cycle once (fire-and-forget from callers); updates the
/// observable [syncStatusProvider] around the cycle.
final syncTriggerProvider = Provider<void Function()>((ref) {
  return () async {
    final status = ref.read(syncStatusProvider.notifier);
    status.beginSync();
    final engine = await ref.read(syncEngineProvider.future);
    try {
      await engine.runSync();
      status.syncSucceeded();
    } catch (e) {
      status.syncFailed();
    }
  };
});

/// Observable sync status (Settings account section): synced / syncing /
/// offline, plus the last successful sync timestamp.
enum SyncStateStatus { synced, syncing, offline }

class SyncStateInfo {
  const SyncStateInfo({required this.status, this.lastSyncAt});

  final SyncStateStatus status;
  final DateTime? lastSyncAt;
}

class SyncStatusController extends Notifier<SyncStateInfo> {
  @override
  SyncStateInfo build() => const SyncStateInfo(status: SyncStateStatus.synced);

  void beginSync() => state = SyncStateInfo(
    status: SyncStateStatus.syncing,
    lastSyncAt: state.lastSyncAt,
  );

  void syncSucceeded() => state = SyncStateInfo(
    status: SyncStateStatus.synced,
    lastSyncAt: DateTime.now(),
  );

  void syncFailed() => state = SyncStateInfo(
    status: SyncStateStatus.offline,
    lastSyncAt: state.lastSyncAt,
  );
}

final syncStatusProvider =
    NotifierProvider<SyncStatusController, SyncStateInfo>(
      SyncStatusController.new,
    );
