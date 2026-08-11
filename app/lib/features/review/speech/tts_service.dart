import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'review_speech.dart';

/// Cross-platform TTS backed by flutter_tts (native voices on iOS/Android,
/// browser SpeechSynthesis on web). One in-flight utterance at a time; the
/// host surface shows a transient banner when speaking fails.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  /// Whether an utterance is currently playing (drives the toggle button).
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) {
      isSpeaking.value = false;
      _lastError = true;
    });
    _initialized = true;
  }

  bool _lastError = false;

  /// Speaks [text] (markdown-stripped, language auto-detected).
  /// Returns an error message on failure, null on success.
  Future<String?> speak(String text, {required String fallbackLanguageTag}) async {
    await _ensureInitialized();
    final speakable = makeSpeakableText(text);
    if (speakable.isEmpty) return null;
    final languageTag = detectSpeechLanguage(speakable, fallbackLanguageTag);
    _lastError = false;
    try {
      await _tts.stop();
      await _tts.setLanguage(languageTag);
      await _tts.speak(speakable);
      if (_lastError) {
        return 'speechUnavailable';
      }
      return null;
    } catch (_) {
      isSpeaking.value = false;
      return 'speechUnavailable';
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    await _tts.stop();
    isSpeaking.value = false;
  }

  void dispose() {
    stop();
    isSpeaking.dispose();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});
