/// 学习偏好: strongly typed, persisted learning preferences. Everything
/// the Runtime can honor is wired; the L1 scaffold level is capability-aware
/// via [ScaffoldPolicy] (never pretends the content switched languages).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../domain/learning/preferences.dart';
import '../../ui/theme/scenelex_tokens.dart';

/// Preferences body reused inside the study tab (学习偏好 segment) and the
/// dedicated page.
class PreferencesBody extends ConsumerWidget {
  const PreferencesBody({super.key, this.onChanged});

  final ValueChanged<LearningPreferences>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(preferencesProvider);
    final policy = ref.watch(scaffoldPolicyProvider);

    void update(LearningPreferences next) {
      if (onChanged != null) {
        onChanged!(next);
      } else {
        ref.read(preferencesProvider.notifier).set(next);
      }
    }

    final capabilityNote = policy.capabilityNote();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (capabilityNote != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSignalWarnBg,
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: Text(
              capabilityNote,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A6A52),
                height: 1.6,
              ),
            ),
          ),
        _SectionLabel(l10n.prefSectionUnderstanding),
        _Group(
          children: [
            _CycleRow(
              title: l10n.prefTransferTiming,
              subtitle: l10n.prefTransferTimingHint,
              value: _transferLabel(l10n, prefs.transferTiming),
              onTap: () => update(
                prefs.copyWith(transferTiming: _next(prefs.transferTiming)),
              ),
            ),
            _SwitchRow(
              title: l10n.prefBoundaryPerturbation,
              subtitle: l10n.prefBoundaryPerturbationHint,
              value: prefs.boundaryPerturbationEnabled,
              onChanged: (v) =>
                  update(prefs.copyWith(boundaryPerturbationEnabled: v)),
            ),
            _SwitchRow(
              title: l10n.prefSymbolRecall,
              subtitle: l10n.prefSymbolRecallHint,
              value: prefs.symbolRecallEnabled,
              onChanged: (v) => update(prefs.copyWith(symbolRecallEnabled: v)),
            ),
          ],
        ),
        _SectionLabel(l10n.prefScaffold),
        _Group(
          children: [
            _CycleRow(
              title: l10n.prefScaffoldLevel,
              subtitle: l10n.prefScaffoldCurrent,
              value: _scaffoldLabel(l10n, prefs.scaffoldLevel),
              onTap: () => update(
                prefs.copyWith(scaffoldLevel: _next(prefs.scaffoldLevel)),
              ),
            ),
            _SwitchRow(
              title: l10n.prefAutoScaffoldRemoval,
              subtitle: l10n.prefAutoScaffoldRemovalHint,
              value: prefs.autoScaffoldRemoval,
              onChanged: (v) => update(prefs.copyWith(autoScaffoldRemoval: v)),
            ),
            _SwitchRow(
              title: l10n.prefZhLabelBeforeReveal,
              subtitle: l10n.prefZhLabelBeforeRevealHint,
              value: prefs.zhLabelBeforeReveal,
              onChanged: (v) => update(prefs.copyWith(zhLabelBeforeReveal: v)),
            ),
          ],
        ),
        _SectionLabel(l10n.prefSectionRhythm),
        _Group(
          children: [
            _CycleRow(
              title: l10n.prefNewGroup,
              subtitle: l10n.prefNewGroupHint,
              value: l10n.prefNewGroupSize(prefs.newGroupSize),
              onTap: () => update(
                prefs.copyWith(
                  newGroupSize: _cycle(
                    prefs.newGroupSize,
                    LearningPreferences.supportedNewGroupSizes,
                  ),
                ),
              ),
            ),
            _CycleRow(
              title: l10n.prefReviewGroup,
              value: l10n.prefReviewGroupSize(prefs.reviewGroupSize),
              onTap: () => update(
                prefs.copyWith(
                  reviewGroupSize: _cycle(
                    prefs.reviewGroupSize,
                    LearningPreferences.supportedReviewGroupSizes,
                  ),
                ),
              ),
            ),
          ],
        ),
        _SectionLabel(l10n.prefSectionVoice),
        _Group(
          children: [
            _CycleRow(
              title: l10n.prefAccent,
              value: prefs.accent == Accent.us
                  ? l10n.prefAccentUs
                  : l10n.prefAccentUk,
              onTap: () => update(
                prefs.copyWith(
                  accent: prefs.accent == Accent.us ? Accent.uk : Accent.us,
                ),
              ),
            ),
            _CycleRow(
              title: l10n.prefAutoPronounce,
              value: _pronounceLabel(l10n, prefs.autoPronounce),
              onTap: () => update(
                prefs.copyWith(autoPronounce: _next(prefs.autoPronounce)),
              ),
            ),
            _CycleRow(
              title: l10n.prefReminder,
              subtitle: l10n.prefReminderHint,
              value: _reminderLabel(l10n, prefs.reminderMode),
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ],
    );
  }

  String _transferLabel(AppLocalizations l10n, TransferTiming t) => switch (t) {
    TransferTiming.endOfDay => l10n.prefTransferEndOfDay,
    TransferTiming.endOfFirstLearning => l10n.prefTransferEndOfFirstLearning,
    TransferTiming.firstReview => l10n.prefTransferFirstReview,
  };

  String _scaffoldLabel(AppLocalizations l10n, ScaffoldLevel level) =>
      switch (level) {
        ScaffoldLevel.zh => l10n.prefScaffoldZh,
        ScaffoldLevel.zhEn => l10n.prefScaffoldMixed,
        ScaffoldLevel.en => l10n.prefScaffoldEn,
      };

  String _pronounceLabel(AppLocalizations l10n, AutoPronounce p) => switch (p) {
    AutoPronounce.onReveal => l10n.prefReminderReveal,
    AutoPronounce.revealAndExamples => l10n.prefReminderRevealExample,
    AutoPronounce.off => l10n.prefReminderOff,
  };

  String _reminderLabel(AppLocalizations l10n, ReminderMode m) => switch (m) {
    ReminderMode.smart => l10n.prefReminderSmart,
    ReminderMode.fixed => l10n.prefReminderFixed,
    ReminderMode.off => l10n.prefReminderOff,
  };

  T _next<T extends Enum>(T current) {
    final values = current is TransferTiming
        ? TransferTiming.values
        : current is ScaffoldLevel
        ? ScaffoldLevel.values
        : current is AutoPronounce
        ? AutoPronounce.values
        : current is ReminderMode
        ? ReminderMode.values
        : null;
    if (values == null) return current;
    return values[(current.index + 1) % values.length] as T;
  }

  int _cycle(int current, List<int> options) {
    final index = options.indexOf(current);
    return options[(index + 1) % options.length];
  }
}

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.prefTitle)),
      body: const PreferencesBody(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 9),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: Color(0xFFA0A0AA),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Column(children: children),
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFA4A4AC),
                height: 1.5,
              ),
            ),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 15, color: Color(0xFF9A9AA2)),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFA4A4AC),
                height: 1.5,
              ),
            ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: kColorEmber,
    );
  }
}
