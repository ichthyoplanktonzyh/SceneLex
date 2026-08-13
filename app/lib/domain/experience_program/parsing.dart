/// Shared strict JSON field readers for Contract v1 parsing.
///
/// Public so the three model files can share them; they are internal to the
/// experience_program domain and not part of its public API surface.
library;

import 'experience_program.dart';

String jsonString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw ExperienceProgramFormatException(
    '$key 必须是字符串，实际是 ${value.runtimeType}',
  );
}

int jsonInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw ExperienceProgramFormatException('$key 必须是整数，实际是 ${value.runtimeType}');
}

bool jsonBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw ExperienceProgramFormatException(
    '$key 必须是布尔值，实际是 ${value.runtimeType}',
  );
}

Map<String, dynamic> jsonMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw ExperienceProgramFormatException('$key 必须是对象，实际是 ${value.runtimeType}');
}

List<dynamic> jsonList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw ExperienceProgramFormatException('$key 必须是数组，实际是 ${value.runtimeType}');
}

List<String> jsonStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((e) => e is! String)) {
    throw ExperienceProgramFormatException('$key 必须是字符串数组');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
