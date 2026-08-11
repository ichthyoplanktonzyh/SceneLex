import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'local/database.dart';
import 'sync/sync_providers.dart';
import 'fsrs.dart';

const _uuidGen = Uuid();

/// Stable per-install id (mirrors the sync installation identity).
final installationIdProvider = FutureProvider<String>((ref) async {
  const key = 'installation_id';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null) return existing;
  final id = _uuidGen.v4();
  await prefs.setString(key, id);
  return id;
});

/// Selected workspace (from /v1/me).
final workspaceProvider = FutureProvider<String>((ref) async {
  final api = ref.watch(apiClientProvider);
  final me = await api.get('/me');
  return me['selectedWorkspaceId'] as String;
});

/// Offline-first library: senses + learning states from the local DB.
/// Refresh = run sync first, then re-read.
class Library {
  const Library({required this.senses, required this.states});

  final List<Sense> senses;
  final Map<String, LearningState> states;
}

final libraryProvider = FutureProvider<Library>((ref) async {
  final local = ref.watch(localRepositoryProvider);
  final ws = await ref.watch(workspaceProvider.future);

  // Best effort sync (offline-safe).
  final engine = await ref.watch(syncEngineProvider.future);
  try {
    await engine.runSync();
  } catch (_) {
    // Offline: proceed with local data.
  }

  final senseRows = await local.cachedSenses();
  final senses = [for (final s in senseRows) Sense.fromJson({
        'wordSenseId': s.wordSenseId,
        'senseKey': s.senseKey,
        'lemma': s.lemma,
        'pos': s.pos,
        'semanticType': s.semanticType,
        'localeL1': s.localeL1,
        'programVersion': s.programVersion,
        'programId': s.programId,
      })];

  final stateRows = await local.allStates(ws);
  final states = <String, LearningState>{};
  for (final row in stateRows) {
    states[row.wordSenseId] = LearningState(
      wordSenseId: row.wordSenseId,
      learningStateId: row.learningStateId,
      dueAt: row.dueAt,
      reps: row.reps,
      lapses: row.lapses,
      fsrsCardState: row.fsrsCardState,
      fsrsStepIndex: row.fsrsStepIndex,
      fsrsStability: row.fsrsStability,
      fsrsDifficulty: row.fsrsDifficulty,
      fsrsScheduledDays: row.fsrsScheduledDays,
    );
  }

  return Library(senses: senses, states: states);
});

/// Add a word sense locally (outbox), then trigger sync.
Future<void> addSenseToStudy(WidgetRef ref, String wordSenseId) async {
  final local = ref.read(localRepositoryProvider);
  final ws = await ref.read(workspaceProvider.future);
  final now = DateTime.now().toUtc().toIso8601String();
  await local.createLearningState(
      workspaceId: ws, wordSenseId: wordSenseId, nowIso: now);
  final trigger = ref.read(syncTriggerProvider);
  trigger();
}

/// Local review submission: compute FSRS with the Dart port, write locally
/// (event + state + two outbox records), then trigger sync.
Future<void> submitReview(
  WidgetRef ref, {
  required String wordSenseId,
  required String learningStateId,
  required String experienceUnitId,
  required int programVersion,
  required int rating,
  required DateTime reviewedAtClient,
}) async {
  final local = ref.read(localRepositoryProvider);
  final ws = await ref.read(workspaceProvider.future);

  final stateRow = await local.stateFor(wordSenseId);
  final settingsJson = await local.cachedWorkspaceSettings(ws);
  final settings = settingsJson == null
      ? const SchedulerSettings()
      : SchedulerSettings(
          desiredRetention:
              (settingsJson['desiredRetention'] as num?)?.toDouble() ?? 0.90,
          learningStepsMinutes: ((settingsJson['learningStepsMinutes']
                      as List<dynamic>?) ??
                  const [])
              .map((e) => (e as num).toInt())
              .toList(),
          relearningStepsMinutes: ((settingsJson['relearningStepsMinutes']
                      as List<dynamic>?) ??
                  const [10])
              .map((e) => (e as num).toInt())
              .toList(),
          maximumIntervalDays:
              (settingsJson['maximumIntervalDays'] as num?)?.toInt() ?? 36500,
          enableFuzz: settingsJson['enableFuzz'] as bool? ?? true,
        );

  final scheduleState = _toScheduleState(stateRow);
  final next = computeReviewSchedule(
      scheduleState, settings, _ratingOf(rating), reviewedAtClient.toUtc());

  final newState = {
    'dueAt': next.dueAt.toIso8601String(),
    'reps': next.reps,
    'lapses': next.lapses,
    'fsrsStability': next.stability,
    'fsrsDifficulty': next.difficulty,
    'fsrsLastReviewedAt': next.lastReviewedAt.toIso8601String(),
    'fsrsScheduledDays': next.scheduledDays,
    'fsrsCardState': _stateName(next.state),
    'fsrsStepIndex': next.stepIndex,
  };

  await local.commitReviewLocally(
    workspaceId: ws,
    wordSenseId: wordSenseId,
    learningStateId: learningStateId,
    programVersion: programVersion,
    experienceUnitId: experienceUnitId,
    rating: rating,
    reviewedAtClientIso: reviewedAtClient.toUtc().toIso8601String(),
    newStateJson: jsonEncode(newState),
  );

  final trigger = ref.read(syncTriggerProvider);
  trigger();
}

ScheduleState _toScheduleState(LocalLearningState? row) {
  if (row == null) return const ScheduleState();
  return ScheduleState(
    reps: row.reps,
    lapses: row.lapses,
    state: _stateOf(row.fsrsCardState),
    stepIndex: row.fsrsStepIndex,
    stability: row.fsrsStability,
    difficulty: row.fsrsDifficulty,
    lastReviewedAt: row.fsrsLastReviewedAt,
    scheduledDays: row.fsrsScheduledDays,
  );
}

FsrsCardState _stateOf(String name) => switch (name) {
      'learning' => FsrsCardState.learning,
      'review' => FsrsCardState.review,
      'relearning' => FsrsCardState.relearning,
      _ => FsrsCardState.new_,
    };

String _stateName(FsrsCardState state) => switch (state) {
      FsrsCardState.learning => 'learning',
      FsrsCardState.review => 'review',
      FsrsCardState.relearning => 'relearning',
      FsrsCardState.new_ => 'new',
    };

ReviewRating _ratingOf(int rating) => switch (rating) {
      0 => ReviewRating.again,
      1 => ReviewRating.hard,
      2 => ReviewRating.good,
      _ => ReviewRating.easy,
    };
