import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// Stable per-install id (mirrors the sync installation identity).
final installationIdProvider = FutureProvider<String>((ref) async {
  const key = 'installation_id';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null) return existing;
  final id = _uuid();
  await prefs.setString(key, id);
  return id;
});

String _uuid() {
  final rng = DateTime.now().microsecondsSinceEpoch;
  return '${rng.toRadixString(16).padLeft(8, '0')}-0000-4000-8000-${rng.toRadixString(16).padLeft(12, '0')}';
}

/// Selected workspace (from /v1/me).
final workspaceProvider = FutureProvider<String>((ref) async {
  final api = ref.watch(apiClientProvider);
  final me = await api.get('/me');
  return me['selectedWorkspaceId'] as String;
});

/// Senses catalog + local learning states (bootstrap hydration).
class Library {
  const Library({required this.senses, required this.states});

  final List<Sense> senses;
  final Map<String, LearningState> states; // key: wordSenseId
}

final libraryProvider = FutureProvider<Library>((ref) async {
  final api = ref.watch(apiClientProvider);
  final ws = await ref.watch(workspaceProvider.future);
  final installId = await ref.watch(installationIdProvider.future);

  final sensesRes = await api.get('/content/senses');
  final senses = ((sensesRes['senses'] as List<dynamic>?) ?? const [])
      .map((s) => Sense.fromJson(s as Map<String, dynamic>))
      .toList();

  final bootstrap = await api.post('/workspaces/$ws/sync/bootstrap', body: {
    'mode': 'pull',
    'installationId': installId,
    'platform': 'web',
  });
  final entries = (bootstrap['entries'] as List<dynamic>?) ?? const [];
  final states = <String, LearningState>{};
  for (final entry in entries) {
    final e = entry as Map<String, dynamic>;
    if (e['entityType'] == 'learning_state') {
      final ls = LearningState.fromJson(e);
      states[ls.wordSenseId] = ls;
    }
  }

  return Library(senses: senses, states: states);
});

/// Add a word sense to study: push a new learning_state via the sync protocol.
Future<void> addSenseToStudy(
  WidgetRef ref,
  String wordSenseId,
) async {
  final api = ref.read(apiClientProvider);
  final ws = await ref.read(workspaceProvider.future);
  final installId = await ref.read(installationIdProvider.future);
  final now = DateTime.now().toUtc().toIso8601String();
  final opId = _uuid();
  final replicaId = _uuid();
  final stateId = _uuid();

  await api.post('/workspaces/$ws/sync/push', body: {
    'installationId': installId,
    'platform': 'web',
    'operations': [
      {
        'operationId': opId,
        'entityType': 'learning_state',
        'entityId': wordSenseId,
        'action': 'upsert',
        'clientUpdatedAt': now,
        'payload': {
          'learningStateId': stateId,
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
          'clientUpdatedAt': now,
          'lastModifiedByReplicaId': replicaId,
          'lastOperationId': opId,
          'deletedAt': null,
        },
      }
    ],
  });
}

/// Submit a review (online mode: server computes FSRS).
Future<void> submitReview(
  WidgetRef ref, {
  required String wordSenseId,
  required String experienceUnitId,
  required int programVersion,
  required int rating,
  required DateTime reviewedAtClient,
}) async {
  final api = ref.read(apiClientProvider);
  final ws = await ref.read(workspaceProvider.future);
  final installId = await ref.read(installationIdProvider.future);
  await api.post('/workspaces/$ws/review', body: {
    'installationId': installId,
    'platform': 'web',
    'wordSenseId': wordSenseId,
    'experienceUnitId': experienceUnitId,
    'programVersion': programVersion,
    'rating': rating,
    'reviewedAtClient': reviewedAtClient.toUtc().toIso8601String(),
    'reviewedTimeZone': 'Asia/Shanghai',
  });
}
