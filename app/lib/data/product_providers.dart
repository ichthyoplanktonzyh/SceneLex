/// Product-level providers for the v1 App (home / learn / review / study /
/// profile / content library).
///
/// These are the new-IA data layer: catalog + learning states + preferences +
/// personal content, all offline-first. Legacy providers (libraryProvider etc.)
/// remain for legacy screens that are being retired.
library;

import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../domain/learning/learning_progress.dart';
import '../../domain/learning/preferences.dart';
import '../api/api_client.dart';
import 'content/content_catalog_repository.dart';
import 'content/content_service.dart';
import 'content/experience_program_repository.dart';
import 'fsrs.dart' show SchedulerSettings;
import 'local/database.dart';
import 'local/local_repository.dart';
import 'providers.dart' show schedulerSettingsFromJson, workspaceProvider;
import 'sync/sync_providers.dart';

export 'sync/sync_providers.dart' show localRepositoryProvider;

// ---------------------------------------------------------------------------
// Content (offline-first)
// ---------------------------------------------------------------------------

final contentServiceProvider = Provider<ContentService>((ref) {
  final api = ref.watch(apiClientProvider);
  return ContentService(
    bundleCatalog: BundledContentCatalogRepository(),
    bundlePrograms: BundledExperienceProgramRepository(),
    local: ref.watch(localRepositoryProvider),
    api: api,
  );
});

/// The content catalog. Loads from the local server snapshot (if any) or the
/// bundle, and refreshes from the server in the background (best effort —
/// never fails the page).
final catalogProvider = FutureProvider<WordSenseCatalog>((ref) async {
  final service = ref.watch(contentServiceProvider);
  final catalog = await service.loadCatalog();
  // background refresh (fire and forget)
  service.refreshFromServer();
  return catalog;
});

/// Program loader with the full bundle → cache → server chain.
final programRepositoryProvider = Provider<ExperienceProgramRepository>((ref) {
  return _ServiceProgramRepository(ref.watch(contentServiceProvider));
});

class _ServiceProgramRepository implements ExperienceProgramRepository {
  _ServiceProgramRepository(this._service);
  final ContentService _service;

  @override
  Future<ExperienceProgram> load(String senseId) =>
      _service.loadProgram(senseId);
}

// ---------------------------------------------------------------------------
// Learning states (local)
// ---------------------------------------------------------------------------

/// Active learning states as [LearningStateView]s, keyed by sense id.
final learningStatesProvider = FutureProvider<Map<String, LearningStateView>>((
  ref,
) async {
  final local = ref.watch(localRepositoryProvider);
  final rows = await local.allStates('');
  return {
    for (final row in rows)
      if (row.deletedAt == null)
        row.wordSenseId: LearningStateView(
          wordSenseId: row.wordSenseId,
          dueAt: row.dueAt,
          fsrsCardState: row.fsrsCardState,
          reps: row.reps,
          lapses: row.lapses,
          stability: row.fsrsStability,
          difficulty: row.fsrsDifficulty,
          scheduledDays: row.fsrsScheduledDays,
          lastReviewedAt: row.fsrsLastReviewedAt,
          fsrsStepIndex: row.fsrsStepIndex,
        ),
  };
});

/// Home numbers (Learn / Review counts, mastery distribution).
final homeProgressProvider = FutureProvider<LearningProgress>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  final states = await ref.watch(learningStatesProvider.future);
  return deriveLearningProgress(catalog: catalog, states: states.values);
});

// ---------------------------------------------------------------------------
// Learning preferences (typed, persisted)
// ---------------------------------------------------------------------------

/// Workspace scheduler settings for FSRS (offline default on failure).
final schedulerSettingsProvider = FutureProvider<SchedulerSettings>((
  ref,
) async {
  final local = ref.watch(localRepositoryProvider);
  String ws;
  try {
    ws = await ref.watch(workspaceProvider.future);
  } catch (_) {
    ws = '';
  }
  return schedulerSettingsFromJson(await local.cachedWorkspaceSettings(ws));
});

class PreferencesController extends Notifier<LearningPreferences> {
  static const _key = 'learning_preferences';

  @override
  LearningPreferences build() {
    _restore();
    return const LearningPreferences();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    try {
      state = LearningPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(stored) as Map),
      );
    } catch (_) {}
  }

  Future<void> set(LearningPreferences next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.toJson()));
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesController, LearningPreferences>(
      PreferencesController.new,
    );

/// The scaffold policy seam (capability-aware).
final scaffoldPolicyProvider = Provider<ScaffoldPolicy>((ref) {
  return const ScaffoldPolicy(ContentSurfaceCapability());
});

// ---------------------------------------------------------------------------
// Check-in (签到)
// ---------------------------------------------------------------------------

/// Whether today is checked in (read-only; the page refreshes it after an
/// action or on entry).
final todayCheckedInProvider = FutureProvider<bool>((ref) async {
  final local = ref.watch(localRepositoryProvider);
  return local.checkedInOn(LocalRepository.dayKeyOf(DateTime.now()));
});

/// Check in for today; returns false when already checked in.
Future<bool> performCheckIn(LocalRepository local) async {
  final now = DateTime.now();
  final key = LocalRepository.dayKeyOf(now);
  final already = await local.checkedInOn(key);
  if (already) return false;
  await local.checkIn(now);
  return true;
}

// ---------------------------------------------------------------------------
// Personal content (favorites / notes / sessions)
// ---------------------------------------------------------------------------

/// Favorited experience keys (programId:experienceUnitId).
final favoritesProvider = FutureProvider<Set<String>>((ref) async {
  final rows = await ref.watch(localRepositoryProvider).allFavorites();
  return rows.map((r) => r.experienceKey).toSet();
});

final notesProvider = FutureProvider<List<LocalNote>>((ref) async {
  return ref.watch(localRepositoryProvider).allNotes();
});

// ---------------------------------------------------------------------------
// Appearance (深色模式)
// ---------------------------------------------------------------------------

final appearanceThemeModeProvider =
    NotifierProvider<AppearanceThemeModeController, ThemeMode>(
      AppearanceThemeModeController.new,
    );

class AppearanceThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) => state = mode;
}

final _appearanceStorageKey = 'appearance_theme_mode';

Future<void> persistThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_appearanceStorageKey, mode.name);
}

Future<ThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_appearanceStorageKey);
  return ThemeMode.values.firstWhere(
    (m) => m.name == stored,
    orElse: () => ThemeMode.system,
  );
}

// ---------------------------------------------------------------------------
// Interrupted learn session draft
// ---------------------------------------------------------------------------

const kLearnSessionDraftKey = 'learn_session_draft_v1';

Future<Map<String, dynamic>?> loadLearnSessionDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(kLearnSessionDraftKey);
  if (stored == null) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(stored) as Map);
  } catch (_) {
    return null;
  }
}

Future<void> saveLearnSessionDraft(Map<String, dynamic>? draft) async {
  final prefs = await SharedPreferences.getInstance();
  if (draft == null) {
    await prefs.remove(kLearnSessionDraftKey);
  } else {
    await prefs.setString(kLearnSessionDraftKey, jsonEncode(draft));
  }
}

// ---------------------------------------------------------------------------
// Session time recording (今日/累计时长)
// ---------------------------------------------------------------------------

const _uuidGen = Uuid();

/// Record a completed session (learn/review) for time statistics.
Future<void> recordSession({
  required LocalRepository local,
  required String kind,
  required DateTime startedAt,
  required DateTime endedAt,
}) async {
  await local.recordSession(
    sessionId: _uuidGen.v4(),
    kind: kind,
    startedAt: startedAt,
    endedAt: endedAt,
  );
}
