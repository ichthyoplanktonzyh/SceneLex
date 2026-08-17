/// Dev-only overview: course & archetype coverage, per-course phase,
/// primitive usage and the honest identity/bundle status. Never shown to
/// ordinary learners.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import 'archetype_mvp_models.dart';
import 'learner_state.dart';

class ArchetypeMvpDevOverview extends StatelessWidget {
  const ArchetypeMvpDevOverview({super.key, required this.state});

  final LearnerState state;

  @override
  Widget build(BuildContext context) {
    final bundle = state.bundle;
    return Scaffold(
      appBar: AppBar(title: const Text('课程/类别覆盖总览（仅开发者）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text(
            '这不是七种用户模式——archetype 只影响 Course Author 的输入建议。',
            style: TextStyle(fontSize: 13, color: Color(0xFF8B8B96)),
          ),
          const SizedBox(height: 14),
          Text(
            'bundle v${bundle.bundleVersion} · capability v${bundle.capabilityVersion}'
            ' · ${bundle.courses.length}/14 门课程',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 16),
          for (final archetype in bundle.archetypes) ...[
            _ArchetypeCard(archetype: archetype, state: state),
            const SizedBox(height: 12),
          ],
          const Divider(height: 28),
          const Text(
            '课程进度',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final courseId in bundle.orderedCourseIds)
            _CourseRow(state: state, senseId: courseId),
        ],
      ),
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({required this.archetype, required this.state});

  final MvpArchetype archetype;
  final LearnerState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                archetype.id,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kColorInk,
                ),
              ),
              const Spacer(),
              Text(
                archetype.semanticTypes.join(', '),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF8B8B96),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            archetype.experienceMechanism,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFF5C5C68),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final pair in archetype.pairs)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${pair.pairId} · allowed=${pair.allowed}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final cap in archetype.suggestedCapabilities)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kColorDusk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    cap,
                    style: const TextStyle(fontSize: 10.5, color: kColorDusk),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.state, required this.senseId});

  final LearnerState state;
  final String senseId;

  @override
  Widget build(BuildContext context) {
    final course = state.bundle.courseFor(senseId);
    final p = state.progressFor(senseId);
    final lemma = (course?.target['lemma'] as String?) ?? senseId;
    final archetype = state.bundle.archetypeFor(senseId) ?? '?';
    final day = state.bundle.curriculumDayFor(senseId);
    final primitives = course == null
        ? <String>[]
        : course.steps.map((s) => s.primitive.name).toSet().toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFECECF2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$senseId · $lemma',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kColorInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'archetype=$archetype  day=$day  phase=${p.phase.name}'
                    '  step=${p.nextStepIndex}/${course?.steps.length ?? 0}'
                    '${p.bindingDay != null ? '  bound@day${p.bindingDay}' : ''}'
                    '${p.errorCount > 0 ? '  errors=${p.errorCount}' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF8B8B96),
                    ),
                  ),
                  if (primitives.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        primitives.join(' · '),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFB0B0BC),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
