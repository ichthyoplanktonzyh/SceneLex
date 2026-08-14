/// Content service: catalog + program loading with bundle-first, server-update
/// sourcing and offline fallback.
///
/// Data flow (product policy):
///   1. Bundled catalog/program — production App works offline from first
///      install, draft content can never appear (bundle gate).
///   2. Local Drift cache — server-fresh snapshots written during a previous
///      successful server check.
///   3. Server check — best effort; network failure silently keeps the
///      bundle/cache state.
///
/// Every program path re-validates the release status (reviewed/published);
/// drafts are never reachable from the production App.
library;

import 'dart:convert';

import '../../api/api_client.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../local/local_repository.dart';
import 'content_catalog_repository.dart';
import 'experience_program_repository.dart';

/// ContentService combines the bundled catalog/programs with the local cache
/// and the server channel. Pure data access — no Widgets, no BuildContext.
class ContentService {
  ContentService({
    required BundledContentCatalogRepository bundleCatalog,
    required BundledExperienceProgramRepository bundlePrograms,
    required LocalRepository local,
    ApiClient? api,
  }) : _bundleCatalog = bundleCatalog,
       _bundlePrograms = bundlePrograms,
       _local = local,
       _api = api;

  final BundledContentCatalogRepository _bundleCatalog;
  final BundledExperienceProgramRepository _bundlePrograms;
  final LocalRepository _local;
  final ApiClient? _api;

  /// Load the catalog: local server snapshot first (freshest), then bundle.
  Future<WordSenseCatalog> loadCatalog() async {
    final cached = await _local.cachedCatalogJson();
    if (cached != null) {
      try {
        return WordSenseCatalog.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      } catch (_) {
        // corrupted cache: fall through to the bundle
      }
    }
    return _bundleCatalog.load();
  }

  /// Best-effort server refresh: merge server catalog entries that are newer
  /// than the bundle into a local snapshot and prefetch newer programs.
  /// Never throws on network failure — the product stays on bundle/cache.
  Future<void> refreshFromServer() async {
    final api = _api;
    if (api == null || api.token == null) return;
    try {
      final res = await api.get('/content/senses');
      final rawSenses = (res['senses'] as List<dynamic>?) ?? const [];
      final bundled = await _bundleCatalog.load();
      final merged = Map<String, WordSenseCatalogEntry>.of(bundled.senses);

      for (final raw in rawSenses) {
        if (raw is! Map) continue;
        try {
          final entry = WordSenseCatalogEntry.fromJson(
            Map<String, dynamic>.from(raw).cast<String, dynamic>(),
          );
          final existing = merged[entry.senseId];
          if (existing == null ||
              entry.programVersion > existing.programVersion) {
            merged[entry.senseId] = entry;
          }
        } catch (_) {
          // skip malformed entries; bundle stays authoritative
        }
      }

      final root = {
        'bundle_version': bundled.bundleVersion,
        'schema_version': bundled.schemaVersion,
        'catalog': {
          for (final entry in merged.values) entry.senseId: _entryToJson(entry),
        },
      };
      await _local.cacheCatalogJson(jsonEncode(root));
      // Prefetch programs that are newer than the bundle's.
      for (final entry in merged.values) {
        final bundledEntry = bundled.senses[entry.senseId];
        if (bundledEntry != null &&
            entry.programVersion <= bundledEntry.programVersion) {
          continue;
        }
        try {
          final program = await _fetchProgramFromServer(entry.programId);
          await _local.cacheProgram(entry.programId, program);
        } catch (_) {
          // program prefetch is best effort
        }
      }
    } catch (_) {
      // offline / server error: keep bundle/cache
    }
  }

  static Map<String, dynamic> _entryToJson(WordSenseCatalogEntry e) => {
    'sense_id': e.senseId,
    'sense_key': e.senseKey,
    'lemma': e.lemma,
    'pos': e.pos,
    'ipa': e.ipa,
    'semantic_type': e.semanticType,
    'locale_l1': e.localeL1,
    'invariant': e.invariant,
    'l1_confusables': e.l1Confusables,
    'boundaries': [
      for (final b in e.boundaries)
        {
          'target_sense_id': b.targetSenseId,
          'relation_type': b.relationType,
          'description': b.description,
          'diagnostic': b.diagnostic,
        },
    ],
    'boundaries_status': e.boundariesStatus,
    'program_id': e.programId,
    'program_version': e.programVersion,
  };

  /// Load a program with the full source chain:
  /// local cache → bundle → server (fetch + cache).
  Future<ExperienceProgram> loadProgram(String senseId) async {
    final catalog = await loadCatalog();
    if (!catalog.contains(senseId)) {
      throw SenseNotFoundException(senseId);
    }
    final entry = catalog.entryFor(senseId);

    final cached = await _local.cachedProgram(entry.programId);
    if (cached != null) {
      final program = _parseProgram(entry.programId, senseId, cached);
      if (program != null) return program;
    }

    try {
      return await _bundlePrograms.load(senseId);
    } on ExperienceProgramLoadException {
      // not in bundle (or corrupt): try the server
    }

    final raw = await _fetchProgramFromServer(entry.programId);
    await _local.cacheProgram(entry.programId, raw);
    final parsed = _parseProgram(entry.programId, senseId, raw);
    if (parsed != null) return parsed;
    throw ExperienceProgramCorruptException(senseId, message: 'server 程序解析失败');
  }

  Future<Map<String, dynamic>> _fetchProgramFromServer(String programId) async {
    final api = _api;
    if (api == null) {
      throw const ExperienceProgramCorruptException('', message: '无 server 通道');
    }
    return Map<String, dynamic>.from(
      await api.get('/content/programs/$programId'),
    );
  }

  ExperienceProgram? _parseProgram(
    String programId,
    String senseId,
    Map<String, dynamic> raw,
  ) {
    final status = raw['status'];
    if (status is! String || !kProgramStatusWireNames.contains(status)) {
      return null;
    }
    if (raw['program_id'] != programId) return null;
    try {
      return ExperienceProgram.fromJson(raw);
    } on ExperienceProgramFormatException {
      return null;
    }
  }
}
