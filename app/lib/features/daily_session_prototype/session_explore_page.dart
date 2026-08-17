/// Session free exploration: browse the real catalog — every sense below
/// comes from the bundled content, with the prototype learner's status.
library;

import 'package:flutter/material.dart';

import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'daily_session_store.dart';
import 'session_learner_state.dart';

class SessionExplorePage extends StatelessWidget {
  const SessionExplorePage({super.key, required this.store});

  final DailySessionStore store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = store.catalog.ordered;
    return Scaffold(
      backgroundColor: const Color(0xFFF7E8CA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.sessionExploreTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kColorInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                l10n.sessionExploreSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F79)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                itemCount: entries.length,
                itemBuilder: (context, index) =>
                    _SenseTile(store: store, entry: entries[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({required this.store, required this.entry});

  final DailySessionStore store;
  final WordSenseCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final senseId = entry.senseId;
    final status = store.learnerState.statusFor(senseId);
    final (label, color) = switch (status) {
      SessionSenseStatus.learning => (l10n.sessionStatusDue, kSignalWarn),
      SessionSenseStatus.mastered => (l10n.sessionStatusStable, kSignalSuccess),
      SessionSenseStatus.unseen => (l10n.sessionStatusNew, kColorEmber),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(kRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.lemma,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kColorInk,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            entry.invariant,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF5C5C68),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
