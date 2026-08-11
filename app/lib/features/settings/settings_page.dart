import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_controller.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../lists/lists_page.dart';
import '../review/reactions/review_reactions_controller.dart';
import 'notifications_service.dart';
import 'scheduling_settings_page.dart';

/// Settings surface: account, notifications, scheduling, language, danger zone.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final notificationsSupported = NotificationsService.isSupported;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsAccountSection),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(l10n.settingsAccountEmail),
            subtitle: Text(auth.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settingsSignOut),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsWorkspaceSection),
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: Text(l10n.settingsWorkspaceLists),
            subtitle: Text(l10n.settingsWorkspaceListsBody),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ListsPage(),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsNotificationsSection),
          if (!notificationsSupported)
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.settingsNotificationsUnsupported),
              enabled: false,
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.settingsEnableNotifications),
              value: notifications.enabled,
              onChanged: (enabled) async {
                final ok = await ref
                    .read(notificationsControllerProvider.notifier)
                    .setEnabled(
                      enabled,
                      title: l10n.appTitle,
                      body: l10n.notificationDailyBody,
                    );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.settingsNotificationsDenied)),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.settingsNotificationTime),
              trailing: Text(
                '${notifications.hour.toString().padLeft(2, '0')}:'
                '${notifications.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: notifications.hour,
                    minute: notifications.minute,
                  ),
                );
                if (picked != null) {
                  await ref
                      .read(notificationsControllerProvider.notifier)
                      .setTime(hour: picked.hour, minute: picked.minute);
                }
              },
            ),
          ],
          const Divider(),
          _SectionHeader(l10n.settingsReviewSection),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: Text(l10n.settingsReviewAnimations),
            subtitle: Text(l10n.settingsReviewAnimationsBody),
            value: ref.watch(reviewReactionsControllerProvider).enabled,
            onChanged: (enabled) => ref
                .read(reviewReactionsControllerProvider.notifier)
                .setEnabled(enabled),
          ),
          if (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.settingsReviewAnimationsLowPowerHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          const Divider(),
          _SectionHeader(l10n.settingsSchedulingSection),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.settingsSchedulingSection),
            subtitle: Text(l10n.settingsSaveHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SchedulingSettingsPage(),
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsLanguageSection),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settingsLanguageSection),
              trailing: DropdownButton<String>(
                value: locale.isAuto ? 'auto' : locale.locale!.languageCode,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text(l10n.settingsLanguageAuto),
                  ),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'zh', child: Text('中文')),
                ],
                onChanged: (code) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(code == 'auto' ? null : code),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settingsLanguageSection),
              subtitle: Text(l10n.settingsLanguageFollowsSystem),
            ),
          const Divider(),
          _SectionHeader(l10n.settingsDangerSection),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.settingsResetProgress),
            enabled: false,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: Text(l10n.settingsDeleteWorkspace),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            trailing: const Text('0.1.0'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.signOutCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.signOutConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
