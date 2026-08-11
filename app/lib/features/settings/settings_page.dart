import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/locale_controller.dart';
import '../../api/api_client.dart';
import '../../auth/auth_controller.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../lists/lists_page.dart';
import '../review/reactions/review_reactions_controller.dart';
import 'notifications_page.dart';
import 'notifications_service.dart';
import 'scheduling_settings_page.dart';
import 'workspace_page.dart';

/// Settings surface: account, workspace, notifications, review, scheduling,
/// language, information items, danger zone.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _appVersion = '0.1.0';

  static String _formatSyncTime(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} '
        '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final syncStatusText = switch (syncStatus.status) {
      SyncStateStatus.synced => l10n.syncStatusSynced,
      SyncStateStatus.syncing => l10n.syncStatusSyncing,
      SyncStateStatus.offline => l10n.syncStatusOffline,
    };
    final lastSyncText = syncStatus.lastSyncAt == null
        ? l10n.settingsLastSyncNever
        : l10n.settingsLastSyncValue(_formatSyncTime(syncStatus.lastSyncAt!));

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
            leading: const Icon(Icons.link),
            title: Text(l10n.settingsAccountStatus),
            subtitle: Text(l10n.settingsAccountStatusLinked),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(l10n.settingsSyncStatus),
            subtitle: Text(syncStatusText),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l10n.settingsLastSync),
            subtitle: Text(lastSyncText),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.settingsSyncNow),
            onTap: () => ref.read(syncTriggerProvider)(),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settingsSignOut),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsWorkspaceSection),
          ListTile(
            leading: const Icon(Icons.workspaces_outlined),
            title: Text(l10n.settingsWorkspaceCurrent),
            subtitle: Text(l10n.settingsWorkspaceSwitch),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const WorkspacePage(),
              ),
            ),
          ),
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
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.settingsNotificationsSection),
            subtitle: notifications.enabled
                ? Text(
                    notifications.mode == 'daily'
                        ? l10n.settingsNotificationsModeDaily
                        : l10n.settingsNotificationsModeInactivity,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Text(
                    l10n.settingsNotificationsOff,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
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
          _SectionHeader(l10n.settingsAboutSection),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.settingsOpenSource),
            onTap: () => _showInfoDialog(
              context,
              title: l10n.settingsOpenSource,
              body: l10n.settingsOpenSourceBody,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLegal),
            onTap: () => _showInfoDialog(
              context,
              title: l10n.settingsLegal,
              body: l10n.settingsLegalBody,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.settingsSupport),
            onTap: () => _showInfoDialog(
              context,
              title: l10n.settingsSupport,
              body: l10n.settingsSupportBody,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.settingsServerInfo),
            onTap: () => _showInfoDialog(
              context,
              title: l10n.settingsServerInfo,
              body: '${l10n.settingsServerInfoApi}: '
                  '${ref.read(apiClientProvider).baseUrl}\n'
                  '${l10n.settingsServerInfoAccount}: ${auth.email ?? '-'}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(l10n.settingsDeviceInfo),
            onTap: () => _showInfoDialog(
              context,
              title: l10n.settingsDeviceInfo,
              body: '${l10n.settingsDevicePlatform}: '
                  '${kIsWeb ? 'web' : Platform.operatingSystem} '
                  '${kIsWeb ? '' : Platform.operatingSystemVersion}\n'
                  '${l10n.settingsVersion}: $_appVersion',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l10n.settingsShareApp),
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: '${l10n.appTitle} — ${l10n.appTagline}',
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsDangerSection),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.settingsResetProgress),
            onTap: () => _confirmDangerAction(
              context,
              title: l10n.settingsResetProgress,
              description: l10n.settingsResetProgressBody,
              confirmPhrase: 'reset all progress for all cards in this workspace',
              confirmLabel: l10n.settingsReset,
              onConfirm: () => _resetProgress(context, ref),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: Text(l10n.settingsDeleteWorkspace),
            onTap: () => _confirmDangerAction(
              context,
              title: l10n.settingsDeleteWorkspace,
              description: l10n.settingsDeleteWorkspaceBody,
              confirmPhrase: 'delete workspace',
              confirmLabel: l10n.settingsDelete,
              onConfirm: () => _deleteWorkspace(context, ref),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: Text(l10n.settingsDeleteAccount),
            subtitle: Text(l10n.settingsDeleteAccountBody,
                style: Theme.of(context).textTheme.bodySmall),
            onTap: () => _confirmDangerAction(
              context,
              title: l10n.settingsDeleteAccount,
              description: l10n.settingsDeleteAccountPhrase,
              confirmPhrase: 'delete my account',
              confirmLabel: l10n.settingsDeleteAccountConfirm,
              onConfirm: () => _deleteAccount(context, ref),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            trailing: const Text(_appVersion),
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

  /// Danger-zone confirm dialog: the user must type the phrase exactly.
  Future<void> _confirmDangerAction(
    BuildContext context, {
    required String title,
    required String description,
    required String confirmPhrase,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.settingsTypeToConfirm(confirmPhrase),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.signOutCancel),
            ),
            FilledButton(
              onPressed: controller.text.trim() == confirmPhrase
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await onConfirm();
  }

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ws = await ref.read(workspaceProvider.future);
      await ref.read(apiClientProvider).post(
            '/workspaces/$ws/reset-progress',
            body: {
              'confirmationText':
                  'reset all progress for all cards in this workspace',
            },
          );
      await reloadWorkspaceData(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadingFailed(''))),
        );
      }
    }
  }

  Future<void> _deleteWorkspace(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final ws = await ref.read(workspaceProvider.future);
      await ref.read(apiClientProvider).post(
            '/workspaces/$ws/delete',
            body: {'confirmationText': 'delete workspace'},
          );
      await reloadWorkspaceData(ref);
      ref.invalidate(workspacesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadingFailed(''))),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).post(
            '/account/delete',
            body: {'confirmationText': 'delete my account'},
          );
      await handleAccountDeleted(ref.container);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadingFailed(''))),
        );
      }
    }
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).reviewFilterDone),
          ),
        ],
      ),
    );
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
