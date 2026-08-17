/// Session mode picker: the "adjust this session" bottom sheet.
///
/// Three mutually exclusive modes. The choice is fed into the planner via
/// [DailySessionStore.setMode] — the UI never hides tasks itself. Switching
/// while an unfinished session exists requires an explicit confirmation
/// (the unfinished session is discarded).
library;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_models.dart';
import 'daily_session_store.dart';

/// Opens the mode sheet; the store's mode is updated on selection.
Future<void> showSessionModeSheet(
  BuildContext context,
  DailySessionStore store,
) async {
  final mode = await showModalBottomSheet<DailySessionMode>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFDF3E4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SessionModeSheet(store: store),
  );
  if (mode == null || mode == store.mode) return;
  if (!context.mounted) return;

  // Switching drops an unfinished session — ask first.
  var confirmed = true;
  if (store.hasActiveSession) {
    confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              AppLocalizations.of(dialogContext).sessionModeConfirmTitle,
            ),
            content: Text(
              AppLocalizations.of(dialogContext).sessionModeConfirmBody,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  AppLocalizations.of(dialogContext).sessionModeCancel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  AppLocalizations.of(dialogContext).sessionModeConfirmSwitch,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
  if (!confirmed || !context.mounted) return;
  store.setMode(mode);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).sessionModeChanged)),
  );
}

class _SessionModeSheet extends StatelessWidget {
  const _SessionModeSheet({required this.store});

  final DailySessionStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionModeTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kColorInk,
              ),
            ),
            const SizedBox(height: 14),
            _ModeOption(
              mode: DailySessionMode.standard,
              selected: store.mode,
              title: l10n.sessionModeStandard,
              description: l10n.sessionModeStandardDesc,
              onTap: () => Navigator.of(context).pop(DailySessionMode.standard),
            ),
            _ModeOption(
              mode: DailySessionMode.reviewOnly,
              selected: store.mode,
              title: l10n.sessionModeReviewOnly,
              description: l10n.sessionModeReviewOnlyDesc,
              onTap: () =>
                  Navigator.of(context).pop(DailySessionMode.reviewOnly),
            ),
            _ModeOption(
              mode: DailySessionMode.learnOnly,
              selected: store.mode,
              title: l10n.sessionModeLearnOnly,
              description: l10n.sessionModeLearnOnlyDesc,
              onTap: () =>
                  Navigator.of(context).pop(DailySessionMode.learnOnly),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final DailySessionMode mode;
  final DailySessionMode selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected
            ? kColorEmber.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          side: isSelected
              ? BorderSide(
                  color: kColorEmber.withValues(alpha: 0.55),
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected ? kColorEmber : const Color(0xFF9A9AA4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: kColorInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F6F79),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
