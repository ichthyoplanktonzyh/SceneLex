import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local daily review reminder (mobile clients only). Web/Linux/Windows
/// surface this as an unsupported note in settings.
class NotificationsService {
  static const _notificationId = 1;

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Last localized strings used to schedule (reused on background restore).
  String _title = 'SceneLex';
  String _body = '';

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> _requestPermissions() async {
    await initialize();
    if (Platform.isIOS || Platform.isMacOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  /// Schedules the daily reminder; returns false if permission was denied.
  Future<bool> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await initialize();
    final granted = await _requestPermissions();
    if (!granted) return false;
    _title = title;
    _body = body;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: _title,
      body: _body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review_reminder',
          'daily_review_reminder',
          channelDescription: 'Daily review reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  /// Re-schedules with the previously used strings (settings restore path).
  Future<bool> reschedule({required int hour, required int minute}) {
    return scheduleDaily(hour: hour, minute: minute, title: _title, body: _body);
  }

  Future<void> cancelDaily() async {
    await initialize();
    await _plugin.cancel(id: _notificationId);
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}

class NotificationsController extends Notifier<NotificationSettings> {
  static const _enabledKey = 'notifications_enabled';
  static const _hourKey = 'notifications_hour';
  static const _minuteKey = 'notifications_minute';

  @override
  NotificationSettings build() {
    _restore();
    return const NotificationSettings(enabled: false, hour: 19, minute: 0);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final hour = prefs.getInt(_hourKey) ?? 19;
    final minute = prefs.getInt(_minuteKey) ?? 0;
    if (state.enabled != enabled || state.hour != hour || state.minute != minute) {
      state = NotificationSettings(enabled: enabled, hour: hour, minute: minute);
    }
    if (enabled && NotificationsService.isSupported) {
      await NotificationsService().reschedule(hour: hour, minute: minute);
    }
  }

  /// Enables/disables the reminder. Returns false when permission is denied.
  Future<bool> setEnabled(
    bool enabled, {
    required String title,
    required String body,
  }) async {
    if (!NotificationsService.isSupported) return false;
    if (enabled == state.enabled) return true;

    if (enabled) {
      final ok = await NotificationsService().scheduleDaily(
        hour: state.hour,
        minute: state.minute,
        title: title,
        body: body,
      );
      if (!ok) return false;
    } else {
      await NotificationsService().cancelDaily();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    state = NotificationSettings(
      enabled: enabled,
      hour: state.hour,
      minute: state.minute,
    );
    return true;
  }

  Future<void> setTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    state = NotificationSettings(enabled: state.enabled, hour: hour, minute: minute);
    if (state.enabled) {
      await NotificationsService().reschedule(hour: hour, minute: minute);
    }
  }
}

final notificationsControllerProvider = NotifierProvider<NotificationsController,
    NotificationSettings>(NotificationsController.new);
