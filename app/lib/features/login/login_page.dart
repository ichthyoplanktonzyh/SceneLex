import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/gen/app_localizations.dart';

/// Email + OTP sign-in, mirroring the reference two-step flow
/// (reference: CloudOtpVerificationSheet.swift): 8-digit numeric code,
/// resend with a 60s countdown, "use a different email" back step, and
/// localized messages keyed by the server's structured error codes.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _resendCooldownSeconds = 60;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  /// Structured error code from the server; an empty string means an error
  /// without a code (falls back to the generic message). Never shows raw
  /// exceptions on screen.
  String? _errorCode;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _errorMessage(AppLocalizations l10n, String? code) {
    return switch (code) {
      'RATE_LIMITED' => l10n.loginErrorRateLimited,
      'ACCOUNT_DELETED' => l10n.loginErrorAccountDeleted,
      'CODE_EXPIRED' => l10n.loginErrorCodeExpired,
      'CODE_ALREADY_USED' => l10n.loginErrorCodeAlreadyUsed,
      'TOO_MANY_ATTEMPTS' => l10n.loginErrorTooManyAttempts,
      'INVALID_CODE' => l10n.loginErrorInvalidCode,
      'INTERNAL_ERROR' => l10n.loginErrorInternalError,
      _ => l10n.loginErrorUnknown,
    };
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  /// Whether the challenge is broken server-side (expired, used, or locked
  /// after too many attempts): the resend action is offered immediately.
  bool _challengeBroken(String? code) {
    return code == 'CODE_EXPIRED' ||
        code == 'CODE_ALREADY_USED' ||
        code == 'TOO_MANY_ATTEMPTS';
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendCode(_emailController.text);
      _startResendTimer();
      _codeController.clear();
      setState(() => _codeSent = true);
    } catch (e) {
      setState(() => _errorCode = e is ApiException ? (e.code ?? '') : '');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyCode(_emailController.text, _codeController.text);
      _codeController.clear();
    } catch (e) {
      setState(() => _errorCode = e is ApiException ? (e.code ?? '') : '');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendSeconds = 0;
      _errorCode = null;
    });
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resendDisabled = _busy || _resendSeconds > 0;
    final error = _errorCode;
    final resendNow = error != null && _challengeBroken(error);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.loginEmailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_codeSent) ...[
                  Text(
                    l10n.loginCodePrompt,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.loginOtpLabel,
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy || (resendDisabled && !resendNow)
                            ? null
                            : _sendCode,
                        child: Text(
                          resendDisabled && !resendNow
                              ? l10n.loginResendIn(_resendSeconds)
                              : l10n.loginResendCode,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _changeEmail,
                        child: Text(l10n.loginChangeEmail),
                      ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  Text(
                    _errorMessage(l10n, error),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_codeSent ? l10n.loginSignIn : l10n.loginSendCode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
