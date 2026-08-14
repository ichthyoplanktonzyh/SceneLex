import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import 'notifications_service.dart';

/// Notification settings: mode (Once daily / Inactivity), time window +
/// repeat interval, app icon badge, streak reminders.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const idleOptions = [30, 60, 90, 120, 180, 240];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(notificationsControllerProvider);
    final supported = NotificationsService.isSupported;
    final controller = ref.read(notificationsControllerProvider.notifier);

    Future<void> update(
      NotificationSettings Function(NotificationSettings) transform,
    ) async {
      final ok = await controller.update(
        transform,
        title: l10n.appTitle,
        body: l10n.notificationDailyBody,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsNotificationsDenied)),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotificationsSection)),
      body: ListView(
        children: [
          if (!supported)
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.settingsNotificationsUnsupported),
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.settingsEnableNotifications),
              value: settings.enabled,
              onChanged: (enabled) =>
                  update((s) => s.copyWith(enabled: enabled)),
            ),
            if (settings.enabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.settingsNotificationsMode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'daily',
                    label: Text(l10n.settingsNotificationsModeDaily),
                  ),
                  ButtonSegment(
                    value: 'inactivity',
                    label: Text(l10n.settingsNotificationsModeInactivity),
                  ),
                ],
                selected: {settings.mode},
                onSelectionChanged: (selection) =>
                    update((s) => s.copyWith(mode: selection.first)),
              ),
              const SizedBox(height: 8),
              if (settings.mode == 'daily')
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.settingsNotificationTime),
                  trailing: Text(
                    '${settings.dailyHour.toString().padLeft(2, '0')}:'
                    '${settings.dailyMinute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.dailyHour,
                        minute: settings.dailyMinute,
                      ),
                    );
                    if (picked != null) {
                      await update(
                        (s) => s.copyWith(
                          dailyHour: picked.hour,
                          dailyMinute: picked.minute,
                        ),
                      );
                    }
                  },
                )
              else ...[
                Text(
                  l10n.settingsNotificationsInactivityBody,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                _TimeRow(
                  icon: Icons.wb_sunny_outlined,
                  label: l10n.settingsNotificationsFrom,
                  hour: settings.inactivityStartHour,
                  minute: settings.inactivityStartMinute,
                  onPick: (h, m) => update(
                    (s) => s.copyWith(
                      inactivityStartHour: h,
                      inactivityStartMinute: m,
                    ),
                  ),
                ),
                _TimeRow(
                  icon: Icons.nights_stay_outlined,
                  label: l10n.settingsNotificationsTo,
                  hour: settings.inactivityEndHour,
                  minute: settings.inactivityEndMinute,
                  onPick: (h, m) => update(
                    (s) => s.copyWith(
                      inactivityEndHour: h,
                      inactivityEndMinute: m,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: Text(l10n.settingsNotificationsRepeatEvery),
                  trailing: DropdownButton<int>(
                    value: settings.idleMinutes,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final minutes in idleOptions)
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(_formatIdle(l10n, minutes)),
                        ),
                    ],
                    onChanged: (minutes) {
                      if (minutes != null) {
                        update((s) => s.copyWith(idleMinutes: minutes));
                      }
                    },
                  ),
                ),
              ],
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.badge_outlined),
                title: Text(l10n.settingsNotificationsBadge),
                subtitle: Text(l10n.settingsNotificationsBadgeBody),
                value: settings.showBadge,
                onChanged: (value) =>
                    update((s) => s.copyWith(showBadge: value)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.local_fire_department_outlined),
                title: Text(l10n.settingsNotificationsStrict),
                subtitle: Text(l10n.settingsNotificationsStrictBody),
                value: settings.strictRemindersEnabled,
                onChanged: (value) =>
                    update((s) => s.copyWith(strictRemindersEnabled: value)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  l10n.settingsNotificationsFooter,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatIdle(AppLocalizations l10n, int minutes) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1
          ? l10n.settingsNotificationsOneHour
          : l10n.settingsNotificationsHours(hours);
    }
    return l10n.settingsNotificationsMinutes(minutes);
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.hour,
    required this.minute,
    required this.onPick,
  });

  final IconData icon;
  final String label;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          onPick(picked.hour, picked.minute);
        }
      },
    );
  }
}
