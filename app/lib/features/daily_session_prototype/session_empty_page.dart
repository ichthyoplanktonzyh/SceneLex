/// Session empty state: shown instead of a broken session when the plan for
/// the current mode is empty (nothing due / nothing unseen).
library;

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_models.dart';

class SessionEmptyPage extends StatelessWidget {
  const SessionEmptyPage({super.key, required this.mode});

  final DailySessionMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = mode == DailySessionMode.reviewOnly
        ? l10n.sessionEmptyReviewBody
        : l10n.sessionEmptyLearnBody;
    return Scaffold(
      backgroundColor: kHomeNightGradient.first,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      size: 40,
                      color: Color(0xFFCFC7E6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.sessionEmptyTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF0DCEE),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFB9B2CC),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(l10n.sessionEmptyBackHome),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
