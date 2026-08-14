/// Concept map: WordSense catalog rendered with its real semantic content —
/// invariant, L1 confusables and (currently not collected) boundary
/// relations. Never renders compiler debug fields; boundary targets show an
/// explicit 待收录 state until content provides relations data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/product_providers.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';

class ConceptMapPage extends ConsumerStatefulWidget {
  const ConceptMapPage({super.key});

  @override
  ConsumerState<ConceptMapPage> createState() => _ConceptMapPageState();
}

class _ConceptMapPageState extends ConsumerState<ConceptMapPage> {
  bool _learnedOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider);
    final states = ref.watch(learningStatesProvider);
    final header = Row(
      children: [
        Text(
          l10n.mapTitle,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l10n.mapAll)),
            ButtonSegment(value: true, label: Text(l10n.mapLearned)),
          ],
          selected: {_learnedOnly},
          onSelectionChanged: (selection) =>
              setState(() => _learnedOnly = selection.first),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: header,
                ),
                Expanded(
                  child: catalog.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Center(child: Text(l10n.mapLoadError(error))),
                    data: (data) {
                      final learned = states.value ?? const {};
                      final entries = data.ordered
                          .where(
                            (e) =>
                                !_learnedOnly || learned.containsKey(e.senseId),
                          )
                          .toList();
                      if (entries.isEmpty) {
                        return Center(child: Text(l10n.mapEmpty));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _SenseMapCard(entry: entries[index]),
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
}

class _SenseMapCard extends StatelessWidget {
  const _SenseMapCard({required this.entry});

  final WordSenseCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 10),
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
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${entry.pos} · ${entry.semanticType}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9AA4)),
              ),
            ],
          ),
          if (entry.invariant.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.invariant,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6E6E79),
                height: 1.55,
              ),
            ),
          ],
          if (entry.boundariesStatus == 'not_collected') ...[
            const Divider(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kSignalWarnBg,
                borderRadius: BorderRadius.circular(kRadiusSm),
              ),
              child: Text(
                l10n.mapBoundariesNotCollected,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF7A6A52)),
              ),
            ),
          ] else
            for (final boundary in entry.boundaries)
              _BoundaryRow(boundary: boundary),
          for (final confusable in entry.l1Confusables) ...[
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.translate,
                    size: 15,
                    color: Color(0xFF9A7C2E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confusable,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B6B76),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _BoundaryRow extends StatelessWidget {
  const _BoundaryRow({required this.boundary});

  final WordSenseBoundary boundary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                size: 16,
                color: Color(0xFF9A7C2E),
              ),
              const SizedBox(width: 9),
              Text(
                boundary.targetSenseId,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: boundary.relationType == 'different_dimension'
                      ? const Color(0xFFE8EFFB)
                      : const Color(0xFFFDF3DC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  boundary.relationType == 'different_dimension'
                      ? l10n.mapDiffDim
                      : l10n.mapOverlap,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: boundary.relationType == 'different_dimension'
                        ? const Color(0xFF3F6FB5)
                        : const Color(0xFF9A7C2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            boundary.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B6B76),
              height: 1.6,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.only(left: 11),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFECECF1))),
            ),
            child: Text(
              l10n.mapBoundaryCriterion(boundary.diagnostic),
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B8B96)),
            ),
          ),
        ],
      ),
    );
  }
}
