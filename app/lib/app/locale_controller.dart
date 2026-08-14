import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App locale preference: null = follow the system; set = explicit choice.
/// The web client exposes an in-app picker; mobile clients follow the system
/// (the preference is still honored if one was ever persisted).
class AppLocale {
  const AppLocale(this.locale);

  final Locale? locale;

  bool get isAuto => locale == null;

  static const auto = AppLocale(null);
}

class LocaleController extends Notifier<AppLocale> {
  static const _key = 'locale_preference';
  static const supportedCodes = ['en', 'zh'];

  @override
  AppLocale build() {
    _restore();
    return AppLocale.auto;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final code = saved == null || saved.isEmpty ? null : saved;
    if (!supportedCodes.contains(code)) {
      await prefs.remove(_key);
      if (!state.isAuto) state = AppLocale.auto;
      return;
    }
    final locale = code == null ? null : Locale(code);
    if (state.locale != locale) state = AppLocale(locale);
  }

  Future<void> setLocale(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
    state = AppLocale(code == null ? null : Locale(code));
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);
