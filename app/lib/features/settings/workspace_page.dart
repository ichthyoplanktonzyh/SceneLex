import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';

/// Workspace management: list, create, switch, rename.
class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspaces = ref.watch(workspacesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWorkspaceSection)),
      body: workspaces.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
        data: (items) => ListView(
          children: [
            for (final ws in items)
              ListTile(
                leading: Icon(
                  ws.isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: ws.isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(ws.name),
                subtitle: Text(
                  ws.isSelected ? l10n.settingsWorkspaceSelected : '',
                ),
                onTap: ws.isSelected
                    ? null
                    : () => _switchTo(context, ref, ws),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.settingsWorkspaceRename,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _rename(context, ref, ws),
                    ),
                    if (ws.isSelected)
                      const Icon(Icons.check, color: Colors.green),
                  ],
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.settingsWorkspaceCreate),
              onTap: () => _create(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchTo(
      BuildContext context, WidgetRef ref, Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(apiClientProvider).post(
            '/workspaces/${workspace.workspaceId}/select',
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

  Future<void> _rename(
      BuildContext context, WidgetRef ref, Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: workspace.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsWorkspaceRename),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.listsNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.signOutCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
            '/workspaces/${workspace.workspaceId}/rename',
            body: {'name': name},
          );
      ref.invalidate(workspacesProvider);
    } catch (_) {
      // Keep the dialog result surface; failure surfaces on next refresh.
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsWorkspaceCreate),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.listsNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.signOutCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/workspaces', body: {'name': name});
      final newWs = Workspace.fromJson(res);
      await reloadWorkspaceData(ref);
      ref.invalidate(workspacesProvider);
      if (context.mounted && newWs.workspaceId.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsWorkspaceCreated(name))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loadingFailed(''))),
        );
      }
    }
  }
}
