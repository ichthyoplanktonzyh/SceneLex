/// Content repositories: load Contract v1 ExperiencePrograms for the
/// Experience Runtime.
///
/// Repositories are pure data access — no Widgets, no BuildContext, no page
/// state. Errors are distinguishable by type.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/experience_program/experience_program.dart';

/// Base error for experience content loading.
sealed class ExperienceProgramLoadException implements Exception {
  const ExperienceProgramLoadException(this.senseId, {this.message = ''});

  final String senseId;
  final String message;

  @override
  String toString() => '$runtimeType($senseId): $message';
}

/// The requested sense id is not present in the bundle.
class SenseNotFoundException extends ExperienceProgramLoadException {
  const SenseNotFoundException(super.senseId)
    : super(message: 'bundle 中不存在 sense "$senseId"');
}

/// The bundle JSON is missing or unparseable, or a program failed Contract
/// v1 runtime checks.
class ExperienceProgramCorruptException extends ExperienceProgramLoadException {
  const ExperienceProgramCorruptException(super.senseId, {super.message});
}

/// The program exists but is not in a runnable release state.
class ExperienceProgramNotReviewableException
    extends ExperienceProgramLoadException {
  const ExperienceProgramNotReviewableException(super.senseId)
    : super(message: 'status 不是 reviewed 或 published');
}

/// Loads an [ExperienceProgram] by sense id.
abstract interface class ExperienceProgramRepository {
  Future<ExperienceProgram> load(String senseId);
}

/// Repository backed by the generated asset bundle
/// `assets/content/experience-programs.v1.json`.
///
/// The bundle is parsed exactly once and cached; every subsequent [load]
/// serves from memory.
class BundledExperienceProgramRepository
    implements ExperienceProgramRepository {
  BundledExperienceProgramRepository({Future<String> Function()? bundleLoader})
    : _bundleLoader = bundleLoader ?? _defaultBundleLoader;

  static const String _bundleAsset =
      'assets/content/experience-programs.v1.json';

  static Future<String> _defaultBundleLoader() =>
      rootBundle.loadString(_bundleAsset);

  final Future<String> Function() _bundleLoader;

  Map<String, dynamic>? _programs;
  bool _loadFailed = false;
  String? _loadErrorMessage;

  Future<Map<String, dynamic>> _ensurePrograms() async {
    if (_programs != null) return _programs!;
    if (_loadFailed) {
      throw ExperienceProgramCorruptException('', message: _loadErrorMessage!);
    }
    Map<String, dynamic> root;
    try {
      final text = await _bundleLoader();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('bundle 根节点必须是对象');
      }
      root = Map<String, dynamic>.from(decoded);
    } catch (error) {
      _loadFailed = true;
      _loadErrorMessage = 'bundle JSON 损坏: $error';
      throw const ExperienceProgramCorruptException(
        '',
        message: 'bundle JSON 损坏',
      );
    }
    final programs = root['programs'];
    if (programs is! Map) {
      _loadFailed = true;
      _loadErrorMessage = 'bundle 缺少 programs 对象';
      throw const ExperienceProgramCorruptException(
        '',
        message: '缺少 programs 对象',
      );
    }
    _programs = Map<String, dynamic>.from(programs);
    return _programs!;
  }

  @override
  Future<ExperienceProgram> load(String senseId) async {
    final programs = await _ensurePrograms();
    final raw = programs[senseId];
    if (raw == null) {
      throw SenseNotFoundException(senseId);
    }
    if (raw is! Map) {
      throw ExperienceProgramCorruptException(senseId, message: 'program 不是对象');
    }
    final program = Map<String, dynamic>.from(raw);
    final status = program['status'];
    if (status is! String || !kProgramStatusWireNames.contains(status)) {
      throw ExperienceProgramNotReviewableException(senseId);
    }
    try {
      return ExperienceProgram.fromJson(program);
    } on ExperienceProgramFormatException catch (error) {
      throw ExperienceProgramCorruptException(senseId, message: error.message);
    }
  }
}
