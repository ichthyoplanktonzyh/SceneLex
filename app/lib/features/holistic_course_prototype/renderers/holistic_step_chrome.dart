/// Shared chrome for Holistic Course step renderers (incl. the six
/// Teaching Archetype MVP renderers). Pure layout — no teaching content.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';

/// Scrollable step body used by every renderer.
class HolisticStepScroll extends StatelessWidget {
  const HolisticStepScroll({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Neutral note card (learner-facing instruction or explanation).
class HolisticNote extends StatelessWidget {
  const HolisticNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Color(0xFF3D3D47),
        ),
      ),
    );
  }
}

/// Small uppercase section label.
class HolisticLabel extends StatelessWidget {
  const HolisticLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF8B8B96),
      ),
    );
  }
}

/// Feedback card shown after answering.
class HolisticFeedbackCard extends StatelessWidget {
  const HolisticFeedbackCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSignalSuccessBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.55, color: kColorInk),
      ),
    );
  }
}

/// Bullet evidence list (same visual as the original _EvidenceList).
class HolisticEvidenceList extends StatelessWidget {
  const HolisticEvidenceList({super.key, required this.evidence});

  final List<String> evidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '可观察的证据',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· ', style: TextStyle(color: kColorEmber)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Color(0xFF3D3D47),
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

/// Small tinted gloss card (used by symbol reveal / recall).
class HolisticGlossCard extends StatelessWidget {
  const HolisticGlossCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kColorEmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: kColorInk,
        ),
      ),
    );
  }
}
