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

final localRepositoryProvider =
    Provider<LocalRepository>((ref) => LocalRepository(ref.watch(databaseProvider)));

/// Sync engine for the selected workspace (created lazily after login).
final syncEngineProvider =
    FutureProvider.autoDispose<SyncEngine>((ref) async {
  final api = ref.watch(apiClientProvider);
  final local = ref.watch(localRepositoryProvider);
  final ws = await ref.watch(workspaceProvider.future);
  final installId = await ref.watch(installationIdProvider.future);
  final engine = SyncEngine(api: api, local: local, workspaceId: ws);
  engine.installationId = installId;
  return engine;
});

/// Runs the full sync cycle once (fire-and-forget from callers).
final syncTriggerProvider = Provider<void Function()>((ref) {
  return () async {
    final engine = await ref.read(syncEngineProvider.future);
    try {
      await engine.runSync();
    } catch (e) {
      // Offline or server error: keep local state, outbox persists.
    }
  };
});
