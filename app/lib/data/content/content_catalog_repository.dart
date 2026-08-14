/// Content catalog repositories: load the WordSense catalog for the App.
///
/// The catalog is the formal content directory. The bundled catalog makes the
/// production App usable offline from first install; a sourcing layer checks
/// the server for newer programs and falls back to bundle/cache on failure.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';

/// Catalog loading error (bundle missing/corrupt, parse failure).
class ContentCatalogLoadException implements Exception {
  const ContentCatalogLoadException(this.message);
  final String message;

  @override
  String toString() => 'ContentCatalogLoadException: $message';
}

/// Loads the [WordSenseCatalog].
abstract interface class ContentCatalogRepository {
  Future<WordSenseCatalog> load();
}

/// Repository backed by the generated asset bundle
/// `assets/content/experience-programs.v1.json` (catalog section).
///
/// Parsed exactly once and cached; safe for the production App without
/// network.
class BundledContentCatalogRepository implements ContentCatalogRepository {
  BundledContentCatalogRepository({Future<String> Function()? bundleLoader})
    : _bundleLoader = bundleLoader ?? _defaultBundleLoader;

  static const String _bundleAsset =
      'assets/content/experience-programs.v1.json';

  static Future<String> _defaultBundleLoader() =>
      rootBundle.loadString(_bundleAsset);

  final Future<String> Function() _bundleLoader;

  WordSenseCatalog? _catalog;
  bool _loadFailed = false;
  String? _loadErrorMessage;

  @override
  Future<WordSenseCatalog> load() async {
    if (_catalog != null) return _catalog!;
    if (_loadFailed) {
      throw ContentCatalogLoadException(_loadErrorMessage!);
    }
    try {
      final text = await _bundleLoader();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('bundle 根节点必须是对象');
      }
      _catalog = WordSenseCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } on ExperienceProgramFormatException catch (error) {
      _loadFailed = true;
      _loadErrorMessage = error.message;
      throw ContentCatalogLoadException(error.message);
    } catch (error) {
      _loadFailed = true;
      _loadErrorMessage = 'bundle JSON 损坏: $error';
      throw const ContentCatalogLoadException('bundle JSON 损坏');
    }
    return _catalog!;
  }
}
