import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import 'local/database.dart';
import 'sync/sync_providers.dart';
import 'fsrs.dart';
import 'tags.dart';

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

/// Offline-first library: senses + learning states + lists from the local DB.
/// Refresh = run sync first, then re-read.
class Library {
  const Library({
    required this.senses,
    required this.states,
    required this.lists,
    required this.tagCounts,
  });

  final List<Sense> senses;
  final Map<String, LearningState> states;
  final List<WordList> lists;
  final Map<String, int> tagCounts;

  /// Preset tags of a sense (empty when the sense is unknown).
  Set<String> tagsOf(String wordSenseId) {
    final sense = senses.where((s) => s.wordSenseId == wordSenseId).firstOrNull;
    return sense == null ? const {} : presetTagsForSense(sense).toSet();
  }

  /// Whether a sense carries at least one of [tags] (match-any rule).
  bool senseHasAnyTag(String wordSenseId, Iterable<String> tags) {
    if (tags.isEmpty) return false;
    return matchesAnyTag(tagsOf(wordSenseId), tags);
  }

  /// Number of studied senses matching any of [tags].
  int countSensesWithTags(Iterable<String> tags) {
    if (tags.isEmpty) return 0;
    return senses
        .where((s) => states.containsKey(s.wordSenseId))
        .where((s) => matchesAnyTag(presetTagsForSense(s), tags))
        .length;
  }

  /// Number of studied senses matching a list's rule.
  int matchedCount(WordList list) => countSensesWithTags(list.tags);
}

final libraryProvider = FutureProvider<Library>((ref) async {
  final local = ref.watch(localRepositoryProvider);
  final ws = await ref.watch(workspaceProvider.future);

  // Best effort sync (offline-safe).
  final engine = await ref.watch(syncEngineProvider.future);
  try {
    await engine.runSync();
  } catch (e) {
    // Offline: proceed with local data. Account deleted: clear the session.
    if (isAccountDeletedError(e)) {
      await handleAccountDeleted(ref.container);
    }
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

  final listRows = await local.allLists();
  final lists = [
    for (final row in listRows)
      WordList.fromJson({
        'listId': row.listId,
        'name': row.name,
        'filterDefinition':
            jsonDecode(row.filterDefinitionJson) as Map<String, dynamic>,
      }),
  ];

  final tagCounts = <String, int>{};
  for (final sense in senses) {
    if (!states.containsKey(sense.wordSenseId)) continue;
    for (final tag in presetTagsForSense(sense)) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  return Library(
    senses: senses,
    states: states,
    lists: lists,
    tagCounts: tagCounts,
  );
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

  await recordActivity();
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

/// Selected bottom-tab index (lets the lists page jump to the Review tab).
class SelectedTabController extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final selectedTabProvider =
    NotifierProvider<SelectedTabController, int>(SelectedTabController.new);

/// Review queue filter: All Cards / a word list / a tag set (persisted).
sealed class ReviewFilter {
  const ReviewFilter();

  const factory ReviewFilter.all() = ReviewFilterAll;
  const factory ReviewFilter.list(String listId) = ReviewFilterList;
  const factory ReviewFilter.tags(Set<String> tags) = ReviewFilterTags;

  String get persistenceKey => jsonEncode(_toJson());

  Map<String, dynamic> _toJson() => switch (this) {
        ReviewFilterAll() => {'kind': 'all'},
        ReviewFilterList(:final listId) => {'kind': 'list', 'listId': listId},
        ReviewFilterTags(:final tags) => {'kind': 'tags', 'tags': tags.toList()},
      };

  static ReviewFilter fromPersistenceKey(String stored) {
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      return switch (json['kind']) {
        'list' => ReviewFilter.list(json['listId'] as String),
        'tags' => ReviewFilter.tags(
            ((json['tags'] as List<dynamic>?) ?? const [])
                .map((t) => t.toString())
                .toSet(),
          ),
        _ => const ReviewFilter.all(),
      };
    } catch (_) {
      return const ReviewFilter.all();
    }
  }
}

class ReviewFilterAll extends ReviewFilter {
  const ReviewFilterAll();
}

class ReviewFilterList extends ReviewFilter {
  const ReviewFilterList(this.listId);
  final String listId;
}

class ReviewFilterTags extends ReviewFilter {
  const ReviewFilterTags(this.tags);
  final Set<String> tags;
}

final reviewFilterProvider = NotifierProvider<ReviewFilterController, ReviewFilter>(
    ReviewFilterController.new);

class ReviewFilterController extends Notifier<ReviewFilter> {
  static const _key = 'review_filter';

  @override
  ReviewFilter build() {
    _restore();
    return const ReviewFilter.all();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final restored = ReviewFilter.fromPersistenceKey(stored);
    if (restored is ReviewFilterAll || restored is ReviewFilterList || restored is ReviewFilterTags) {
      state = restored;
    }
  }

  Future<void> set(ReviewFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, filter.persistenceKey);
    state = filter;
  }
}

/// All workspaces of the signed-in user (from GET /workspaces).
final workspacesProvider = FutureProvider<List<Workspace>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get('/workspaces');
  return ((res['workspaces'] as List<dynamic>?) ?? const [])
      .map((w) => Workspace.fromJson(w as Map<String, dynamic>))
      .toList();
});

/// Records a study-activity heartbeat (notifications "inactivity" mode and
/// streak reminders).
Future<void> recordActivity() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'last_activity_at',
    DateTime.now().toUtc().toIso8601String(),
  );
  await prefs.setString('last_reviewed_local_date', _localDate(DateTime.now()));
}

String _localDate(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

/// Clears local study data and re-syncs from the selected workspace
/// (workspace switch / delete / reset-progress).
Future<void> reloadWorkspaceData(WidgetRef ref) async {
  final local = ref.read(localRepositoryProvider);
  await local.wipeStudyData();
  ref.invalidate(workspaceProvider);
  ref.invalidate(syncEngineProvider);
  ref.invalidate(libraryProvider);
}

/// Handles 410 ACCOUNT_DELETED: wipe local study data, clear the session.
Future<void> handleAccountDeleted(ProviderContainer container) async {
  final local = container.read(localRepositoryProvider);
  await local.wipeStudyData();
  await container.read(authControllerProvider.notifier).signOut();
  container.invalidate(libraryProvider);
}

bool isAccountDeletedError(Object error) =>
    error is ApiException && error.statusCode == 410;
