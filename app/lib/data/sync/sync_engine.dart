import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift/drift.dart' show Value;

import '../../api/api_client.dart';
import '../local/database.dart';
import '../local/local_repository.dart';

/// Platform reported to the sync API on every request (single source of
/// truth): the browser on web, the OS name on native (ios/android/...).
String get syncPlatform => kIsWeb ? 'web' : Platform.operatingSystem;

/// Sync engine: bootstrap hydration, outbox push, hot pull, review-history pull.
/// Mirrors the reference flow: bootstrap -> push -> pull hot -> pull history.
class SyncEngine {
  SyncEngine({required this.api, required this.local, required this.workspaceId});

  final ApiClient api;
  final LocalRepository local;
  final String workspaceId;

  bool _syncing = false;

  bool get isSyncing => _syncing;

  /// Run the full sync cycle if not already running.
  Future<void> runSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _hydrateIfNeeded();
      await _pushOutbox();
      await _pullHot();
      await _pullReviewHistory();
    } finally {
      _syncing = false;
    }
  }

  Future<SyncStateTableData> _state() => local.syncState(workspaceId);

  Future<void> _hydrateIfNeeded() async {
    final state = await _state();
    if (state.hasHydratedHotState) return;

    // Bootstrap pull (paged until hasMore=false).
    String? cursor;
    var bootstrapHotChangeId = 0;
    while (true) {
      final res = await api.post(
        '/workspaces/$workspaceId/sync/bootstrap',
        body: {
          'mode': 'pull',
          'cursor': cursor,
          'limit': 1000,
          'installationId': _installationId,
          'platform': syncPlatform,
        },
      );
      bootstrapHotChangeId =
          (res['bootstrapHotChangeId'] as num?)?.toInt() ?? 0;

      for (final entry in (res['entries'] as List<dynamic>?) ?? const []) {
        final e = entry as Map<String, dynamic>;
        await _applyEntity(
          entityType: e['entityType'] as String,
          entityId: e['entityId'] as String,
          payloadJson: jsonEncode(e['payload']),
        );
      }
      if (res['hasMore'] != true || res['nextCursor'] == null) break;
      cursor = res['nextCursor'] as String;
    }

    // Hydrate content cache (senses + workspace settings).
    await _cacheContent();

    await local.setHotCursor(workspaceId, bootstrapHotChangeId);
    await local.setHydrated(workspaceId, hot: true);
  }

  Future<void> _cacheContent() async {
    final sensesRes = await api.get('/content/senses');
    await local.cacheSenses(
      ((sensesRes['senses'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>(),
    );
    final settings = await api.post('/workspaces/$workspaceId/sync/bootstrap', body: {
      'mode': 'pull',
      'limit': 1,
      'installationId': _installationId,
      'platform': syncPlatform,
    });
    final entries = (settings['entries'] as List<dynamic>?) ?? const [];
    for (final entry in entries) {
      final e = entry as Map<String, dynamic>;
      if (e['entityType'] == 'workspace_scheduler_settings') {
        await local.cacheWorkspaceSettings(
            workspaceId, e['payload'] as Map<String, dynamic>);
      }
    }
  }

  Future<void> _pushOutbox() async {
    final pending = await local.pendingOperations(workspaceId);
    if (pending.isEmpty) return;

    const batchSize = 100;
    for (var i = 0; i < pending.length; i += batchSize) {
      final batch = pending.skip(i).take(batchSize).toList();
      final res = await api.post(
        '/workspaces/$workspaceId/sync/push',
        body: {
          'installationId': _installationId,
          'platform': syncPlatform,
          'operations': [
            for (final op in batch)
              {
                'operationId': op.operationId,
                'entityType': op.entityType,
                'entityId': op.entityId,
                'action': op.action,
                'clientUpdatedAt': op.clientUpdatedAt,
                'payload': jsonDecode(op.payloadJson),
              },
          ],
        },
      );

      final outcomes = (res['operations'] as List<dynamic>?) ?? const [];
      final outcomeByOp = <String, String>{
        for (final o in outcomes)
          (o as Map<String, dynamic>)['operationId'] as String:
              o['status'] as String,
      };

      for (final op in batch) {
        final status = outcomeByOp[op.operationId];
        if (status == 'applied' ||
            status == 'ignored' ||
            status == 'duplicate') {
          await local.removeOutboxOperation(op.operationId);
        } else if (status == 'rejected') {
          await local.markOutboxFailure(op.operationId, 'rejected by server');
        }
      }

      // Any rejection aborts the whole sync run: later batches and the pull
      // phases must not execute (reference CloudSyncPush throws after
      // marking the failed operations). The exception propagates through
      // runSync to the syncTriggerProvider catch, surfacing as offline.
      final rejected = batch
          .where((op) => outcomeByOp[op.operationId] == 'rejected')
          .toList();
      if (rejected.isNotEmpty) {
        final message = rejected
            .map((op) =>
                '${op.operationId} (${op.entityType}/${op.entityId})')
            .join('; ');
        throw StateError('Cloud sync rejected one or more operations: $message');
      }
    }
  }

  Future<void> _pullHot() async {
    final state = await _state();
    var after = state.lastAppliedHotChangeId;
    while (true) {
      final res = await api.post(
        '/workspaces/$workspaceId/sync/pull',
        body: {
          'afterHotChangeId': after,
          'limit': 500,
          'installationId': _installationId,
          'platform': syncPlatform,
        },
      );
      for (final change in (res['changes'] as List<dynamic>?) ?? const []) {
        final c = change as Map<String, dynamic>;
        await _applyEntity(
          entityType: c['entityType'] as String,
          entityId: c['entityId'] as String,
          payloadJson: jsonEncode(c['payload']),
        );
      }
      after = (res['nextHotChangeId'] as num?)?.toInt() ?? after;
      await local.setHotCursor(workspaceId, after);
      if (res['hasMore'] != true) break;
    }
  }

  Future<void> _pullReviewHistory() async {
    final state = await _state();
    var after = state.lastAppliedReviewSequenceId;
    while (true) {
      final res = await api.post(
        '/workspaces/$workspaceId/sync/review-history/pull',
        body: {
          'afterReviewSequenceId': after,
          'limit': 500,
          'installationId': _installationId,
          'platform': syncPlatform,
        },
      );
      for (final event in (res['reviewEvents'] as List<dynamic>?) ?? const []) {
        final e = event as Map<String, dynamic>;
        await local.db.into(local.db.localReviewEvents).insertOnConflictUpdate(
              LocalReviewEventsCompanion.insert(
                reviewEventId: e['reviewEventId'] as String,
                wordSenseId: e['wordSenseId'] as String,
                programVersion: (e['programVersion'] as num?)?.toInt() ?? 1,
                experienceUnitId: e['experienceUnitId'] as String,
                rating: (e['rating'] as num).toInt(),
                reviewedAtClient:
                    DateTime.parse(e['reviewedAtClient'] as String).toUtc(),
                reviewedTimeZone: Value(e['reviewedTimeZone'] as String?),
                reviewedLocalDate: Value(e['reviewedLocalDate'] as String?),
              ),
            );
      }
      after = (res['nextReviewSequenceId'] as num?)?.toInt() ?? after;
      await local.db.into(local.db.syncStateTable).insertOnConflictUpdate(
            SyncStateTableCompanion.insert(
              workspaceId: workspaceId,
              lastAppliedReviewSequenceId: Value(after),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      if (res['hasMore'] != true) break;
    }
  }

  Future<void> _applyEntity({
    required String entityType,
    required String entityId,
    required String payloadJson,
  }) async {
    switch (entityType) {
      case 'learning_state':
        await local.applyLearningState(
            wordSenseId: entityId, payloadJson: payloadJson);
      case 'workspace_scheduler_settings':
        await local.cacheWorkspaceSettings(
            workspaceId, jsonDecode(payloadJson) as Map<String, dynamic>);
      case 'list':
        await local.applyList(listId: entityId, payloadJson: payloadJson);
    }
  }

  String? _installationId;
  set installationId(String id) => _installationId = id;
}
