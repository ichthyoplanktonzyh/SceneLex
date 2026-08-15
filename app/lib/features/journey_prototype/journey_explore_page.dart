/// Journey Explore: the quiet side path of the prototype.
///
/// Everything shown here is real bundled content — catalog senses and their
/// actual anchor experiences. It demonstrates "free exploration" as a
/// secondary loop next to the system-guided journey.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../domain/experience_program/experience_program.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'journey_preview_store.dart';
import 'prototype_semantic_graph.dart';

class JourneyExplorePage extends StatefulWidget {
  const JourneyExplorePage({
    super.key,
    required this.store,
    required this.repository,
  });

  final JourneyPreviewStore store;
  final ExperienceProgramRepository repository;

  @override
  State<JourneyExplorePage> createState() => _JourneyExplorePageState();
}

class _JourneyExplorePageState extends State<JourneyExplorePage> {
  final Map<String, ExperienceProgram> _programs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final entry in widget.store.catalog.senses.values) {
      try {
        _programs[entry.senseId] = await widget.repository.load(entry.senseId);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = widget.store.catalog.ordered;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.journeyExploreTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    l10n.journeyExploreSubtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF8B8B96),
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _SenseCard(
                              entry: entry,
                              status: widget.store.graph.nodeFor(entry.senseId)?.status,
                              anchorEpisode: _anchorEpisode(entry.senseId),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _anchorEpisode(String senseId) {
    final program = _programs[senseId];
    if (program == null || program.units.isEmpty) return null;
    return program.units.first.experience.episode;
  }
}

class _SenseCard extends StatelessWidget {
  const _SenseCard({
    required this.entry,
    required this.status,
    required this.anchorEpisode,
  });

  final WordSenseCatalogEntry entry;
  final PrototypeNodeStatus? status;
  final String? anchorEpisode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                entry.lemma,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kColorInk,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${entry.pos} · ${entry.semanticType}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9AA4)),
              ),
              const Spacer(),
              Text(
                _statusLabel(l10n, status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: status == PrototypeNodeStatus.unseen
                      ? const Color(0xFF9A9AA4)
                      : kSignalSuccess,
                ),
              ),
            ],
          ),
          if (anchorEpisode != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1E8),
                borderRadius: BorderRadius.circular(kRadiusSm),
              ),
              child: Text(
                anchorEpisode!,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4A4A54),
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PrototypeNodeStatus? status) =>
      switch (status) {
        PrototypeNodeStatus.mastered => l10n.journeyMapStatusMastered,
        PrototypeNodeStatus.learning => l10n.journeyMapStatusLearning,
        PrototypeNodeStatus.newlyLearned => l10n.journeyMapStatusNewlyLearned,
        PrototypeNodeStatus.unseen || null => l10n.journeyMapStatusUnseen,
      };
}
