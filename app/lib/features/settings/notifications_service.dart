import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local review reminders (mobile clients only). Web/Linux/Windows surface
/// this as an unsupported note in settings.
///
/// Modes mirror the reference:
/// - Once daily: one reminder at a fixed time.
/// - Inactivity: reminders inside a time window, spaced by an interval
///   (30-240 min), first one after the configured idle time from the last
///   activity.
/// - Streak (strict) reminders: 4/3/2 hours before midnight when the user
///   has not reviewed today.
/// - App icon badge on delivered reminders (iOS; Android channel badge).
class NotificationsService {
  static const _dailyId = 1;
  static const _inactivityIdBase = 101;
  static const _strictIdBase = 201;

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  String _title = 'SceneLex';
  String _body = '';
  bool _showBadge = false;

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
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  NotificationDetails _details() => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_review_reminder',
      'daily_review_reminder',
      channelDescription: 'Daily review reminder',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      channelShowBadge: _showBadge,
    ),
    iOS: DarwinNotificationDetails(badgeNumber: _showBadge ? 1 : null),
    macOS: DarwinNotificationDetails(badgeNumber: _showBadge ? 1 : null),
  );

  Future<void> _scheduleOneShot(
    int id,
    DateTime localTime, {
    required bool repeatDaily,
  }) async {
    if (!localTime.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: _title,
      body: _body,
      scheduledDate: tz.TZDateTime.from(localTime, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  /// Schedules all reminders for the current settings.
  Future<bool> scheduleAll({
    required NotificationSettings settings,
    required String title,
    required String body,
  }) async {
    await initialize();
    final granted = await _requestPermissions();
    if (!granted) return false;
    _title = title;
    _body = body;
    _showBadge = settings.showBadge;
    await cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final localDate = _localDateString(now);
    final lastReviewedDate = prefs.getString('last_reviewed_local_date');
    final lastActivityRaw = prefs.getString('last_activity_at');
    final lastActivity = lastActivityRaw == null
        ? null
        : DateTime.tryParse(lastActivityRaw)?.toLocal();

    if (settings.mode == 'daily') {
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        settings.dailyHour,
        settings.dailyMinute,
      );
      await _scheduleOneShot(_dailyId, time, repeatDaily: true);
    } else {
      // Inactivity: candidates within the window, spaced by the interval,
      // skipping anything before max(now, lastActivity + idle).
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        settings.inactivityStartHour,
        settings.inactivityStartMinute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        settings.inactivityEndHour,
        settings.inactivityEndMinute,
      );
      if (start.isBefore(end)) {
        final earliest = <DateTime>[
          start,
          now.add(const Duration(minutes: 1)),
          if (lastActivity != null)
            lastActivity.add(Duration(minutes: settings.idleMinutes)),
        ].reduce((a, b) => a.isAfter(b) ? a : b);
        var candidate = start;
        var index = 0;
        while (candidate.isBefore(end) && index < 12) {
          if (!candidate.isBefore(earliest)) {
            await _scheduleOneShot(
              _inactivityIdBase + index,
              candidate,
              repeatDaily: false,
            );
          }
          candidate = candidate.add(Duration(minutes: settings.idleMinutes));
          index++;
        }
      }
    }

    // Streak reminders: 4/3/2 hours before midnight when not reviewed today.
    if (settings.strictRemindersEnabled && lastReviewedDate != localDate) {
      final midnight = DateTime(now.year, now.month, now.day + 1);
      for (var i = 0; i < 3; i++) {
        final time = midnight.subtract(Duration(hours: 4 - i));
        await _scheduleOneShot(_strictIdBase + i, time, repeatDaily: false);
      }
    }

    return true;
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancel(id: _dailyId);
    for (var i = 0; i < 12; i++) {
      await _plugin.cancel(id: _inactivityIdBase + i);
    }
    for (var i = 0; i < 3; i++) {
      await _plugin.cancel(id: _strictIdBase + i);
    }
  }

  /// Clears the app icon badge (opened app / reviewed today).
  Future<void> clearBadge() async {
    if (!isSupported) return;
    await initialize();
    await BadgeService.clear();
  }
}

/// Minimal app-badge bridge (iOS only; Android badges follow the channel).
class BadgeService {
  static const _channel = MethodChannel('scenelex/app_badge');

  static Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear');
    } catch (_) {
      // Native side missing — nothing to clear.
    }
  }
}

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    this.mode = 'daily',
    this.dailyHour = 19,
    this.dailyMinute = 0,
    this.inactivityStartHour = 9,
    this.inactivityStartMinute = 0,
    this.inactivityEndHour = 21,
    this.inactivityEndMinute = 0,
    this.idleMinutes = 60,
    this.showBadge = false,
    this.strictRemindersEnabled = false,
  });

  final bool enabled;
  final String mode;
  final int dailyHour;
  final int dailyMinute;
  final int inactivityStartHour;
  final int inactivityStartMinute;
  final int inactivityEndHour;
  final int inactivityEndMinute;
  final int idleMinutes;
  final bool showBadge;
  final bool strictRemindersEnabled;

  NotificationSettings copyWith({
    bool? enabled,
    String? mode,
    int? dailyHour,
    int? dailyMinute,
    int? inactivityStartHour,
    int? inactivityStartMinute,
    int? inactivityEndHour,
    int? inactivityEndMinute,
    int? idleMinutes,
    bool? showBadge,
    bool? strictRemindersEnabled,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    dailyHour: dailyHour ?? this.dailyHour,
    dailyMinute: dailyMinute ?? this.dailyMinute,
    inactivityStartHour: inactivityStartHour ?? this.inactivityStartHour,
    inactivityStartMinute: inactivityStartMinute ?? this.inactivityStartMinute,
    inactivityEndHour: inactivityEndHour ?? this.inactivityEndHour,
    inactivityEndMinute: inactivityEndMinute ?? this.inactivityEndMinute,
    idleMinutes: idleMinutes ?? this.idleMinutes,
    showBadge: showBadge ?? this.showBadge,
    strictRemindersEnabled:
        strictRemindersEnabled ?? this.strictRemindersEnabled,
  );
}

class NotificationsController extends Notifier<NotificationSettings> {
  static const _enabledKey = 'notifications_enabled';
  static const _modeKey = 'notifications_mode';
  static const _hourKey = 'notifications_hour';
  static const _minuteKey = 'notifications_minute';
  static const _inStartHourKey = 'notifications_in_start_hour';
  static const _inStartMinuteKey = 'notifications_in_start_minute';
  static const _inEndHourKey = 'notifications_in_end_hour';
  static const _inEndMinuteKey = 'notifications_in_end_minute';
  static const _idleKey = 'notifications_idle_minutes';
  static const _badgeKey = 'notifications_badge';
  static const _strictKey = 'notifications_strict';

  @override
  NotificationSettings build() {
    _restore();
    return const NotificationSettings(enabled: false);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = NotificationSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      mode: prefs.getString(_modeKey) ?? 'daily',
      dailyHour: prefs.getInt(_hourKey) ?? 19,
      dailyMinute: prefs.getInt(_minuteKey) ?? 0,
      inactivityStartHour: prefs.getInt(_inStartHourKey) ?? 9,
      inactivityStartMinute: prefs.getInt(_inStartMinuteKey) ?? 0,
      inactivityEndHour: prefs.getInt(_inEndHourKey) ?? 21,
      inactivityEndMinute: prefs.getInt(_inEndMinuteKey) ?? 0,
      idleMinutes: prefs.getInt(_idleKey) ?? 60,
      showBadge: prefs.getBool(_badgeKey) ?? false,
      strictRemindersEnabled: prefs.getBool(_strictKey) ?? false,
    );
    state = settings;
    if (settings.enabled && NotificationsService.isSupported) {
      await _apply(settings);
    }
  }

  /// Persists + reschedules. Returns false when permission was denied.
  Future<bool> update(
    NotificationSettings Function(NotificationSettings) transform, {
    required String title,
    required String body,
  }) async {
    final next = transform(state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, next.enabled);
    await prefs.setString(_modeKey, next.mode);
    await prefs.setInt(_hourKey, next.dailyHour);
    await prefs.setInt(_minuteKey, next.dailyMinute);
    await prefs.setInt(_inStartHourKey, next.inactivityStartHour);
    await prefs.setInt(_inStartMinuteKey, next.inactivityStartMinute);
    await prefs.setInt(_inEndHourKey, next.inactivityEndHour);
    await prefs.setInt(_inEndMinuteKey, next.inactivityEndMinute);
    await prefs.setInt(_idleKey, next.idleMinutes);
    await prefs.setBool(_badgeKey, next.showBadge);
    await prefs.setBool(_strictKey, next.strictRemindersEnabled);

    if (!next.enabled || !NotificationsService.isSupported) {
      await NotificationsService().cancelAll();
      state = next;
      return true;
    }
    final ok = await _apply(next, title: title, body: body);
    if (ok) state = next;
    return ok;
  }

  Future<bool> _apply(
    NotificationSettings settings, {
    String? title,
    String? body,
  }) => NotificationsService().scheduleAll(
    settings: settings,
    title: title ?? 'SceneLex',
    body: body ?? '',
  );
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationSettings>(
      NotificationsController.new,
    );

/// YYYY-MM-DD in the device-local timezone.
String _localDateString(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';
