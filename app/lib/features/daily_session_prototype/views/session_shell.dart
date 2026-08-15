/// Daily Session chrome: the shell every task lives inside.
///
/// Reuses the Journey prototype's generic scene/choice/footer widgets by
/// re-export (those are generic, model-free chrome); the session-specific
/// header (block chip + progress) lives here. The shell shows only
/// block/task progress and never reveals a target lemma.
library;

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/scenelex_tokens.dart';
import '../../journey_prototype/views/journey_shell.dart'
    show JourneyFooterButton;

/// Reusable generic chrome from the Journey prototype (scene card, choice
/// tile, chip, footer button). Kept as thin re-exports/wrappers so session
/// views read as one vocabulary without owning duplicated widgets.

export '../../journey_prototype/views/journey_shell.dart'
    show JourneyChip, JourneyChoiceState, JourneyChoiceTile, JourneySceneCard;

/// The fixed bottom action of the session shell — thin wrapper over the
/// Journey prototype's generic footer button (same widget, session name).
class SessionFooterButton extends StatelessWidget {
  const SessionFooterButton({
    super.key,
    required this.label,
    required this.accent,
    this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return JourneyFooterButton(label: label, accent: accent, onTap: onTap);
  }
}

/// The unified session header: back, title, overall task progress, bar.
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.title,
    required this.current,
    required this.total,
    required this.onBack,
  });

  final String title;
  final int current;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.sessionQuitTooltip,
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A54),
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  l10n.sessionProgress(current, total),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D6D78),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Row(
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: kMotionFeedback,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: i < current
                            ? kColorDusk
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Block kicker shown above the task body: which block we are in, plus the
/// task position inside this block (e.g. "Quick wake-up · 1/4").
class SessionBlockKicker extends StatelessWidget {
  const SessionBlockKicker({super.key, required this.label, this.progressText});

  final String label;
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kColorEmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF6D6D78),
            ),
          ),
          if (progressText != null) ...[
            const Spacer(),
            Text(
              progressText!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B8B96),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The safe-exit note shown above the footer.
class SessionSafeExitNote extends StatelessWidget {
  const SessionSafeExitNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Text(
        l10n.sessionSafeExitNote,
        style: const TextStyle(fontSize: 12, color: Color(0xFF9A9AA4)),
      ),
    );
  }
}

/// The task-unavailable state (missing program / unit — graceful skip).
class SessionTaskUnavailable extends StatelessWidget {
  const SessionTaskUnavailable({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF9A9AA4), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6D6D78)),
            ),
          ],
        ),
      ),
    );
  }
}
