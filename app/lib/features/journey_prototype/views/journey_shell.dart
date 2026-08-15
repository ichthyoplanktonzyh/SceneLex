/// Journey session chrome: the unified shell every task lives inside.
///
/// One continuous session — no jumping between Learn and Review pages. The
/// shell shows only task-type labels (Recall / Discover / Boundary /
/// Transfer) and progress; it never reveals a target lemma.
library;

import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/scenelex_tokens.dart';

/// The unified journey header: back, title, progress, segmented bar.
class JourneyHeader extends StatelessWidget {
  const JourneyHeader({
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
                tooltip: l10n.journeySessionQuit,
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
                width: 48,
                child: Text(
                  l10n.experienceRuntimeProgress(current, total),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13.5,
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

/// Task-type kicker shown above the task body.
class JourneyTaskKicker extends StatelessWidget {
  const JourneyTaskKicker({super.key, required this.label});

  final String label;

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
        ],
      ),
    );
  }
}

/// The fixed bottom action of the journey shell.
class JourneyFooterButton extends StatelessWidget {
  const JourneyFooterButton({
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
    final disabled = onTap == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
      width: double.infinity,
      child: Column(
        children: [
          Opacity(
            opacity: disabled ? 0.35 : 1,
            child: TextButton(
              onPressed: onTap,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: kMotionFeedback,
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scene card used across recall / boundary / transfer tasks.
class JourneySceneCard extends StatelessWidget {
  const JourneySceneCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          height: 1.78,
          color: Color(0xFF1E1E26),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// A tappable choice tile (boundary / transfer answers).
class JourneyChoiceTile extends StatelessWidget {
  const JourneyChoiceTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  /// `idle` before picking; `correct` / `wrong` after reveal.
  final JourneyChoiceState state;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = switch (state) {
      JourneyChoiceState.correct => kSignalSuccessBg,
      JourneyChoiceState.wrong => kSignalErrorBg,
      JourneyChoiceState.muted => Colors.white.withValues(alpha: 0.4),
      JourneyChoiceState.idle => Colors.white.withValues(alpha: 0.52),
    };
    final border = switch (state) {
      JourneyChoiceState.correct => kSignalCorrectBorder,
      JourneyChoiceState.wrong => kSignalWrongBorder,
      _ => Colors.transparent,
    };
    final foreground = switch (state) {
      JourneyChoiceState.correct => kSignalSuccess,
      JourneyChoiceState.wrong => kSignalError,
      JourneyChoiceState.muted => const Color(0xFF9A9AA4),
      JourneyChoiceState.idle => const Color(0xFF26262C),
    };
    return Opacity(
      opacity: state == JourneyChoiceState.muted ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            side: BorderSide(color: border, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: foreground,
                  fontWeight: state == JourneyChoiceState.correct ||
                          state == JourneyChoiceState.wrong
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum JourneyChoiceState { idle, correct, wrong, muted }

/// Small labeled chip (e.g. "NEW", status pills).
class JourneyChip extends StatelessWidget {
  const JourneyChip({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? kColorEmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: foreground ?? kColorEmber,
        ),
      ),
    );
  }
}
