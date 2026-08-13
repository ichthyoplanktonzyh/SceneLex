/// Grounding view: the L2 word anchored in a real experience the learner
/// already saw (grounding.source_experience_id → its unit).
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/symbol_binding.dart';
import '../../../domain/experience_program/experience_unit.dart';
import '../../../l10n/gen/app_localizations.dart';

class GroundingView extends StatelessWidget {
  const GroundingView({
    super.key,
    required this.grounding,
    required this.sourceUnit,
  });

  final Grounding grounding;
  final ExperienceUnit sourceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                icon: Icons.replay,
                color: Colors.teal.shade700,
                title: l10n.experienceRuntimeGroundingBackToExperience,
                child: Text(
                  sourceUnit.experience.episode,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade50,
                      Colors.teal.shade100.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  grounding.l2Realization,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                icon: Icons.format_list_bulleted,
                color: Colors.teal.shade700,
                title: l10n.experienceRuntimeConstructions,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final construction in grounding.constructions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '· ',
                              style: TextStyle(color: Colors.teal.shade700),
                            ),
                            Expanded(
                              child: Text(
                                construction,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.link,
                color: Colors.teal.shade700,
                title: l10n.experienceRuntimeCollocations,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final collocation in grounding.collocations)
                      Chip(
                        label: Text(collocation),
                        backgroundColor: Colors.teal.shade50.withValues(
                          alpha: 0.7,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
