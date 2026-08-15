/// Daily Session Home: the "unified entry" landing surface.
///
/// One strong primary entry — today's session (with estimated time and task
/// composition) — and quiet secondary actions (adjust session, semantic map,
/// free exploration). There is deliberately no Learn / Review split here:
/// the system plans the session from the learner's state, and the learner
/// can adjust the mode instead of picking a separate tool.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../home/home_sky.dart';
import 'daily_session_models.dart';
import 'daily_session_page.dart';
import 'daily_session_store.dart';
import 'daily_session_view_model.dart';
import 'session_empty_page.dart';
import 'session_explore_page.dart';
import 'session_mode_sheet.dart';
import 'session_semantic_map_page.dart';

class DailySessionHomePage extends StatefulWidget {
  const DailySessionHomePage({
    super.key,
    required this.store,
    required this.repository,
  });

  final DailySessionStore store;
  final ExperienceProgramRepository repository;

  @override
  State<DailySessionHomePage> createState() => _DailySessionHomePageState();
}

class _DailySessionHomePageState extends State<DailySessionHomePage> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        backgroundColor: kHomeNightGradient.first,
        body: Stack(
          children: [
            const HomeSky(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HomeHeader(),
                    const SizedBox(height: 28),
                    _SessionCard(
                      store: store,
                      onPrimary: () => _openSession(context),
                      onAdjust: () => showSessionModeSheet(context, store),
                    ),
                    const SizedBox(height: 18),
                    _SecondaryActions(
                      onSemanticMap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionSemanticMapPage(store: store),
                        ),
                      ),
                      onExplore: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionExplorePage(store: store),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _FooterNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The primary CTA: resume an active session, start a fresh one, or show
  /// the empty state when the current mode has nothing to do.
  void _openSession(BuildContext context) {
    final store = widget.store;
    if (store.hasActiveSession) {
      _enterSession(context);
      return;
    }
    if (!store.startSession()) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionEmptyPage(mode: store.mode),
        ),
      );
      return;
    }
    _enterSession(context);
  }

  void _enterSession(BuildContext context) {
    final vm = DailySessionViewModel(
      store: widget.store,
      catalog: widget.store.catalog,
      repository: widget.repository,
    );
    vm.load();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailySessionPage(
          viewModel: vm,
          store: widget.store,
          repository: widget.repository,
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionHomeKicker,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
                color: Color(0xFFCFC7E6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SCENELEX',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: Color(0xFFF0DCEE),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.store,
    required this.onPrimary,
    required this.onAdjust,
  });

  final DailySessionStore store;
  final VoidCallback onPrimary;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = store.plan;
    final state = store.runState;
    final completed = state == SessionRunState.completed;
    final resume = state == SessionRunState.active;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.26),
          ],
        ),
        borderRadius: BorderRadius.circular(kRadiusCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x335A3C78),
            blurRadius: 34,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: kColorEmber),
              const SizedBox(width: 8),
              Text(
                l10n.sessionHomeTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kColorInk,
                ),
              ),
              const Spacer(),
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kSignalSuccessBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.sessionHomeDone,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kSignalSuccess,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.sessionHomeMinutes(plan.estimatedMinutes),
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6470)),
          ),
          const SizedBox(height: 14),
          Text(
            plan.isEmpty ? l10n.sessionHomeEmptyHint : _summaryLine(l10n, plan),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D3D47),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.sessionHomeExplanation,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B6470),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPrimary,
              icon: Icon(
                resume ? Icons.play_circle_outline : Icons.arrow_forward,
              ),
              label: Text(
                completed
                    ? l10n.sessionHomeRedo
                    : (resume ? l10n.sessionHomeResume : l10n.sessionHomeStart),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onAdjust,
              icon: const Icon(Icons.tune, size: 17),
              label: Text(l10n.sessionHomeAdjust),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5A5470),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _summaryLine(AppLocalizations l10n, DailySessionPlan plan) {
    final parts = <String>[
      if (plan.countOf(DailySessionTaskType.recall) > 0)
        l10n.sessionSummaryRecall(plan.countOf(DailySessionTaskType.recall)),
      if (plan.countOf(DailySessionTaskType.discover) > 0)
        l10n.sessionSummaryDiscover(
          plan.countOf(DailySessionTaskType.discover),
        ),
      if (plan.countOf(DailySessionTaskType.boundary) > 0)
        l10n.sessionSummaryBoundary(
          plan.countOf(DailySessionTaskType.boundary),
        ),
      if (plan.countOf(DailySessionTaskType.transfer) > 0)
        l10n.sessionSummaryTransfer(
          plan.countOf(DailySessionTaskType.transfer),
        ),
    ];
    return parts.join(' · ');
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.onSemanticMap,
    required this.onExplore,
  });

  final VoidCallback onSemanticMap;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _QuietAction(
            icon: Icons.hub_outlined,
            label: l10n.sessionHomeSemanticMap,
            onTap: onSemanticMap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuietAction(
            icon: Icons.explore_outlined,
            label: l10n.sessionHomeExplore,
            onTap: onExplore,
          ),
        ),
      ],
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFE8E2F2), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8E2F2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.sessionHomeFooterHint,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: Color(0x996E7A9E)),
    );
  }
}
