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

  @override
  AuthState build() {
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
    ref.read(apiClientProvider).token = token;
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
    ref.read(apiClientProvider).token = session.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString('auth_email', session.email);

    state = AuthState(status: AuthStatus.signedIn, email: session.email);
  }

  /// Signs out and clears all local workspaces and sync data (spec §6);
  /// the installation identity is kept.
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await ref.read(localRepositoryProvider).wipeStudyData();
    await prefs.remove(_tokenKey);
    await prefs.remove('auth_email');
    ref.read(apiClientProvider).token = null;
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
