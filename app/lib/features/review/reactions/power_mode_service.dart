import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Low power / power saver state from the OS.
/// iOS: Low Power Mode (NSProcessInfo); Android: Power Save Mode
/// (PowerManager). Web and desktop always report false.
class PowerModeService {
  static const _methodChannel = MethodChannel('scenelex/power_mode');
  static const _eventChannel = EventChannel('scenelex/power_mode/events');

  static final PowerModeService instance = PowerModeService();

  final ValueNotifier<bool> _isLowPower = ValueNotifier(false);
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  /// Current low-power state (synchronous read).
  ValueNotifier<bool> get isLowPower => _isLowPower;

  /// Emits whenever the OS low-power state changes (and the current value
  /// on subscribe after [start] has run).
  Stream<bool> get changes => _changes.stream;

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> start() async {
    if (!isSupported) return;
    try {
      final current = await _methodChannel.invokeMethod<bool>(
        'isLowPowerEnabled',
      );
      _setLowPower(current ?? false);
    } catch (_) {
      // Native side missing (e.g. tests) — default to false.
    }
    _subscription ??= _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is bool) {
        _setLowPower(event);
      }
    });
  }

  void _setLowPower(bool value) {
    if (_isLowPower.value != value) {
      _isLowPower.value = value;
    }
    if (!_changes.isClosed) {
      _changes.add(value);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _changes.close();
    _isLowPower.dispose();
  }
}
