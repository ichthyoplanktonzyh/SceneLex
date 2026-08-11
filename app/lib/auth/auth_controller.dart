import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../data/sync/sync_providers.dart';

/// Session state machine: unknown (loading) -> signedOut / signedIn.
enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState({required this.status, this.email});

  final AuthStatus status;
  final String? email;

  bool get isSignedIn => status == AuthStatus.signedIn;
}

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _tokenExpiresAtKey = 'auth_token_expires_at';

  /// Re-entrancy guard: sign-out itself performs network calls (revoke)
  /// that can fail and re-enter the session-expired callback. The callback
  /// must stay registered across sign-in cycles (build() runs once per
  /// provider lifetime, not per sign-out), so it is guarded with this flag
  /// instead of being nulled out.
  bool _signingOut = false;

  @override
  AuthState build() {
    // Session renewal failures anywhere in the app sign the user out.
    ref.read(apiClientProvider).onSessionExpired = () {
      if (_signingOut) return;
      Future(() => signOut());
    };
    _restore().then((email) {
      state = email == null
          ? const AuthState(status: AuthStatus.signedOut)
          : AuthState(status: AuthStatus.signedIn, email: email);
    });
    return const AuthState(status: AuthStatus.loading);
  }

  Future<String?> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return null;
    final client = ref.read(apiClientProvider);
    client.token = token;
    client.refreshToken = prefs.getString(_refreshTokenKey);
    final expiresAt = prefs.getString(_tokenExpiresAtKey);
    client.tokenExpiresAt =
        expiresAt == null ? null : DateTime.tryParse(expiresAt)?.toUtc();
    return prefs.getString('auth_email');
  }

  Future<void> sendCode(String email) async {
    await ref.read(apiClientProvider).post('/auth/send-code', body: {'email': email});
  }

  Future<void> verifyCode(String email, String code) async {
    final res = await ref
        .read(apiClientProvider)
        .post('/auth/verify-code', body: {'email': email, 'code': code});
    final session = AuthSession.fromJson(res);
    final client = ref.read(apiClientProvider);
    client.token = session.idToken;
    client.refreshToken = session.refreshToken;
    client.tokenExpiresAt = DateTime.now()
        .toUtc()
        .add(Duration(seconds: session.expiresIn));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.idToken);
    await prefs.setString(_refreshTokenKey, session.refreshToken);
    await prefs.setString(
        _tokenExpiresAtKey, client.tokenExpiresAt!.toIso8601String());
    await prefs.setString('auth_email', session.email);

    state = AuthState(status: AuthStatus.signedIn, email: session.email);
  }

  /// Signs out: revokes the refresh token on the server (best effort, never
  /// blocks local cleanup), then clears all local workspaces and sync data
  /// (spec §6); the installation identity is kept. Re-entrant safe: the
  /// session-expired callback stays registered (see [_signingOut]).
  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      final client = ref.read(apiClientProvider);
      final refreshToken = client.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await client.post('/auth/revoke-token',
              body: {'refreshToken': refreshToken});
        } catch (_) {
          // Revocation is best effort; local cleanup proceeds regardless.
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await ref.read(localRepositoryProvider).wipeStudyData();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiresAtKey);
      await prefs.remove('auth_email');
      client.token = null;
      client.refreshToken = null;
      client.tokenExpiresAt = null;
      state = const AuthState(status: AuthStatus.signedOut);
    } finally {
      _signingOut = false;
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
