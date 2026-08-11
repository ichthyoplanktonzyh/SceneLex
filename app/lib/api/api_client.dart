import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Global API client (session fields injected by the auth controller).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Thin JSON API client for the SceneLex server, with session renewal
/// handled centrally (reference: CloudSupport.swift refreshes when the id
/// token has <= 300s left; CloudSessionRuntime swaps only the id token):
///  - proactive refresh before any request when the id token is about to
///    expire;
///  - reactive refresh on a 401, then exactly one replay of the request;
///  - when a refresh fails, [onSessionExpired] is invoked (sign-out flow).
class ApiClient {
  ApiClient({String? baseUrl, this.onSessionExpired})
      : baseUrl = baseUrl ?? 'http://127.0.0.1:8081/v1';

  /// Mutable so the integration harness can simulate connectivity loss by
  /// pointing it at an unreachable endpoint.
  String baseUrl;

  /// Invoked when the session can no longer be renewed (refresh rejected,
  /// revoked, expired, or the account was deleted). Set by the auth
  /// controller; sign-out is the only response.
  void Function()? onSessionExpired;

  String? token;
  String? refreshToken;
  DateTime? tokenExpiresAt;

  /// Refresh threshold: remaining lifetime <= 300s triggers a refresh
  /// (reference CloudSupport.swift).
  static const _refreshLeadSeconds = 300;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path) async {
    await _ensureFreshToken();
    var res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401 && await _refreshAndRetry()) {
      res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body}) async {
    await _ensureFreshToken();
    final uri = Uri.parse('$baseUrl$path');
    var res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode == 401 && await _refreshAndRetry()) {
      res = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body ?? {}),
      );
    }
    return _decode(res);
  }

  /// Proactive refresh: skip when there is no session, no expiry, or still
  /// more than the lead time left.
  Future<void> _ensureFreshToken() async {
    if (token == null || refreshToken == null) return;
    final expiresAt = tokenExpiresAt;
    if (expiresAt == null) return;
    if (expiresAt.difference(DateTime.now().toUtc()) >
        const Duration(seconds: _refreshLeadSeconds)) {
      return;
    }
    await _refresh();
  }

  Future<bool> _refreshAndRetry() async {
    try {
      await _refresh();
      return true;
    } catch (_) {
      onSessionExpired?.call();
      return false;
    }
  }

  /// Exchange of the refresh token for a fresh id token, deduplicated: any
  /// concurrent callers share the single in-flight request instead of
  /// issuing parallel refreshes (reference: CloudSessionRuntime serializes
  /// refreshes). Only [token] and [tokenExpiresAt] are updated; the refresh
  /// token itself never rotates (reference: refreshToken.ts returns
  /// {idToken, expiresIn}).
  Future<void> _refresh() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight;
    final run = _doRefresh().whenComplete(() => _inFlightRefresh = null);
    _inFlightRefresh = run;
    return run;
  }

  Future<void>? _inFlightRefresh;

  Future<void> _doRefresh() async {
    final rt = refreshToken;
    if (rt == null) throw ApiException(401, 'no refresh token');
    final res = await http.post(
      Uri.parse('$baseUrl/auth/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': rt}),
    );
    if (res.statusCode != 200) {
      final info = _errorInfo(res);
      throw ApiException(
        res.statusCode,
        info.message ?? 'refresh failed',
        code: info.code,
      );
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    token = decoded['idToken'] as String;
    final expiresIn = (decoded['expiresIn'] as num).toInt();
    tokenExpiresAt =
        DateTime.now().toUtc().add(Duration(seconds: expiresIn));
  }

  /// Best-effort extraction of the structured error fields
  /// ({code, message}) used by the auth endpoints.
  ({String? code, String? message}) _errorInfo(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return (
          code: decoded['code']?.toString(),
          message: decoded['message']?.toString(),
        );
      }
    } catch (_) {}
    return (code: null, message: null);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    final info = _errorInfo(res);
    final message = info.message?.isNotEmpty == true
        ? info.message!
        : 'HTTP ${res.statusCode}';
    throw ApiException(res.statusCode, message, code: info.code);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code});

  final int statusCode;
  final String message;

  /// Structured error code from the server (e.g. INVALID_CODE), used for
  /// localized messages; null for legacy/plain errors.
  final String? code;

  @override
  String toString() => message;
}
