import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../l10n/gen/app_localizations.dart';

const defaultSchedulingSettings = {
  'desiredRetention': 0.90,
  'learningStepsMinutes': [1, 10],
  'relearningStepsMinutes': [10],
  'maximumIntervalDays': 36500,
  'enableFuzz': true,
};

/// FSRS scheduling settings editor (local write + outbox upsert).
class SchedulingSettingsPage extends ConsumerStatefulWidget {
  const SchedulingSettingsPage({super.key});

  @override
  ConsumerState<SchedulingSettingsPage> createState() =>
      _SchedulingSettingsPageState();
}

class _SchedulingSettingsPageState
    extends ConsumerState<SchedulingSettingsPage> {
  final _retentionController = TextEditingController();
  final _learningStepsController = TextEditingController();
  final _relearningStepsController = TextEditingController();
  final _maxIntervalController = TextEditingController();
  bool _enableFuzz = true;
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _retentionController.dispose();
    _learningStepsController.dispose();
    _relearningStepsController.dispose();
    _maxIntervalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = ref.read(localRepositoryProvider);
    final ws = await ref.read(workspaceProvider.future);
    final json = await local.cachedWorkspaceSettings(ws);
    final s = json ?? defaultSchedulingSettings;
    _retentionController.text = _formatRetention(s['desiredRetention']);
    _learningStepsController.text = _formatSteps(s['learningStepsMinutes']);
    _relearningStepsController.text = _formatSteps(s['relearningStepsMinutes']);
    _maxIntervalController.text = '${s['maximumIntervalDays'] ?? 36500}';
    _enableFuzz = s['enableFuzz'] as bool? ?? true;
    setState(() => _loaded = true);
  }

  String _formatRetention(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0.90;
    return d.toStringAsFixed(2);
  }

  String _formatSteps(dynamic v) {
    final list = (v as List<dynamic>?) ?? const [];
    return list.map((e) => (e as num).toInt().toString()).join(', ');
  }

  List<int>? _parseSteps(String text) {
    final parts = text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final steps = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n <= 0) return null;
      steps.add(n);
    }
    return steps;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final retention = double.tryParse(_retentionController.text.trim());
    final learningSteps = _parseSteps(_learningStepsController.text);
    final relearningSteps = _parseSteps(_relearningStepsController.text);
    final maxInterval = int.tryParse(_maxIntervalController.text.trim());

    if (retention == null ||
        retention <= 0 ||
        retention >= 1 ||
        learningSteps == null ||
        relearningSteps == null ||
        maxInterval == null ||
        maxInterval <= 0) {
      setState(() => _error = l10n.settingsInvalidValue);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsSave),
        content: Text(l10n.settingsSaveHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.signOutCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final local = ref.read(localRepositoryProvider);
    final ws = await ref.read(workspaceProvider.future);
    await local.updateWorkspaceSettings(
      workspaceId: ws,
      settings: {
        'desiredRetention': retention,
        'learningStepsMinutes': learningSteps,
        'relearningStepsMinutes': relearningSteps,
        'maximumIntervalDays': maxInterval,
        'enableFuzz': _enableFuzz,
      },
    );
    ref.read(syncTriggerProvider)();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
      Navigator.pop(context);
    }
  }

  Future<void> _resetDefaults() async {
    final local = ref.read(localRepositoryProvider);
    final ws = await ref.read(workspaceProvider.future);
    await local.updateWorkspaceSettings(
      workspaceId: ws,
      settings: Map<String, dynamic>.from(defaultSchedulingSettings),
    );
    ref.read(syncTriggerProvider)();
    setState(() => _error = null);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsSchedulingSection)),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NumberField(
                  controller: _retentionController,
                  label: l10n.settingsDesiredRetention,
                  hint: '0.90',
                ),
                _NumberField(
                  controller: _learningStepsController,
                  label: l10n.settingsLearningSteps,
                  hint: '1, 10',
                ),
                _NumberField(
                  controller: _relearningStepsController,
                  label: l10n.settingsRelearningSteps,
                  hint: '10',
                ),
                _NumberField(
                  controller: _maxIntervalController,
                  label: l10n.settingsMaxInterval,
                  hint: '36500',
                ),
                SwitchListTile(
                  title: Text(l10n.settingsEnableFuzz),
                  value: _enableFuzz,
                  onChanged: (v) => setState(() => _enableFuzz = v),
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
                TextButton(
                  onPressed: _resetDefaults,
                  child: Text(l10n.settingsResetDefaults),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          signed: false,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
