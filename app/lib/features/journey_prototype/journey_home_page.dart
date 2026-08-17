/// Journey Home: the future-facing landing surface of the prototype.
///
/// One strong CTA — Today's Journey — with Semantic Map / Explore as quiet
/// secondary actions. No "Learn" / "Review" / check-in numbers: today is a
/// single journey, not two tool entries.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../home/home_sky.dart';
import 'journey_explore_page.dart';
import 'journey_preview_store.dart';
import 'journey_semantic_map_page.dart';
import 'journey_session_page.dart';
import 'journey_session_view_model.dart';
import 'prototype_journey_plan.dart';

class JourneyHomePage extends StatefulWidget {
  const JourneyHomePage({
    super.key,
    required this.store,
    required this.repository,
  });

  final JourneyPreviewStore store;
  final ExperienceProgramRepository repository;

  @override
  State<JourneyHomePage> createState() => _JourneyHomePageState();
}

class _JourneyHomePageState extends State<JourneyHomePage> {
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
                    _JourneyCard(
                      store: store,
                      onContinue: () => _openSession(context),
                    ),
                    const SizedBox(height: 18),
                    _SecondaryActions(
                      onSemanticMap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JourneySemanticMapPage(
                            store: store,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                      onExplore: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JourneyExplorePage(
                            store: store,
                            repository: widget.repository,
                          ),
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

  void _openSession(BuildContext context) {
    final vm = JourneySessionViewModel(
      plan: widget.store.plan,
      catalog: widget.store.catalog,
      repository: widget.repository,
      onComplete: widget.store.completeJourney,
    );
    vm.load();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JourneySessionPage(
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
              l10n.journeyHomeGreeting,
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

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.store, required this.onContinue});

  final JourneyPreviewStore store;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = store.plan;
    final done = store.journeyCompletedToday;
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
                l10n.journeyHomeJourneyTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: kColorInk,
                ),
              ),
              const Spacer(),
              if (done)
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
                    l10n.journeyHomeDone,
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
            l10n.journeyHomeMinutes(plan.estimatedMinutes),
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B6470)),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.journeyHomeTaskSummary(
              plan.countOf(JourneyTaskType.recall),
              plan.countOf(JourneyTaskType.newConcept),
              plan.countOf(JourneyTaskType.discrimination),
              plan.countOf(JourneyTaskType.transfer),
            ),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D3D47),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.journeyHomeExplanation,
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
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                done ? l10n.journeyHomeContinueAgain : l10n.journeyHomeContinue,
              ),
            ),
          ),
        ],
      ),
    );
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
            label: l10n.journeyHomeSemanticMap,
            onTap: onSemanticMap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuietAction(
            icon: Icons.explore_outlined,
            label: l10n.journeyHomeExplore,
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
      l10n.journeyHomeSecondaryHint,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0x996E7A9E),
      ),
    );
  }
}
