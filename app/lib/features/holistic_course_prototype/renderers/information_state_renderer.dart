/// information_state renderer — timeline beats revealing facts and which
/// agents know them; the learner advances beats, then judges whether the
/// agent noticed (perception) or realized (inference). No reasoning engine.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import '../../journey_prototype/views/journey_shell.dart';
import 'holistic_step_chrome.dart';

class InformationStateRenderer extends StatefulWidget {
  const InformationStateRenderer({
    super.key,
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  State<InformationStateRenderer> createState() => _InformationStateState();
}

class _InformationStateState extends State<InformationStateRenderer> {
  int _beatIndex = 0;
  final Set<String> _revealedFactIds = {};

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final episode = content['episode'] as String? ?? '';
    final agents = [
      for (final a in (content['agents'] as List?) ?? const [])
        if (a is Map) a.cast<String, dynamic>(),
    ];
    final facts = [
      for (final f in (content['facts'] as List?) ?? const [])
        if (f is Map) f.cast<String, dynamic>(),
    ];
    final beats = [
      for (final b in (content['beats'] as List?) ?? const [])
        if (b is Map) b.cast<String, dynamic>(),
    ];
    final question = content['question'] as String? ?? '';
    final options = (content['options'] as List?) ?? const [];
    final answered = widget.state.choiceId != null;
    final correctId = widget.step.correctOptionId;
    final allRevealed = _beatIndex >= beats.length;

    return HolisticStepScroll(
      children: [
        if (episode.isNotEmpty) JourneySceneCard(text: episode),
        const SizedBox(height: 16),
        const HolisticLabel('时间线'),
        const SizedBox(height: 8),
        for (final (i, beat) in beats.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _BeatCard(
              key: ValueKey('beat-$i'),
              index: i,
              beat: beat,
              revealed: i <= _beatIndex,
              facts: facts,
              agents: agents,
            ),
          ),
        if (!allRevealed)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('beat-next'),
              onPressed: () => setState(() {
                final beat = beats[_beatIndex];
                _beatIndex += 1;
                for (final fid in (beat['reveals'] as List?) ?? const []) {
                  _revealedFactIds.add(fid as String);
                }
              }),
              icon: const Icon(Icons.skip_next),
              label: Text('继续（${_beatIndex + 1} / ${beats.length}）'),
            ),
          ),
        if (allRevealed && question.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ],
        if (allRevealed) ...[
          const SizedBox(height: 12),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoOptionTile(
                key: ValueKey('info-option-${option['id']}'),
                label: option['text'] as String? ?? '',
                state: _choiceState(
                  option['id'],
                  correctId,
                  widget.state.choiceId,
                ),
                onTap: answered
                    ? null
                    : () => widget.onChoose(option['id'] as String),
              ),
            ),
          if (answered)
            HolisticFeedbackCard(
              text: _feedbackFor(options, widget.state.choiceId),
            ),
        ],
      ],
    );
  }

  JourneyChoiceState _choiceState(
    Object? id,
    String? correctId,
    String? chosen,
  ) {
    if (chosen == null) return JourneyChoiceState.idle;
    if (id == correctId) return JourneyChoiceState.correct;
    if (id == chosen) return JourneyChoiceState.wrong;
    return JourneyChoiceState.muted;
  }

  String _feedbackFor(List<dynamic> options, String? chosen) {
    for (final option in options) {
      if (option['id'] == chosen) {
        return option['feedback'] as String? ?? '';
      }
    }
    return '';
  }
}

class _BeatCard extends StatelessWidget {
  const _BeatCard({
    super.key,
    required this.index,
    required this.beat,
    required this.revealed,
    required this.facts,
    required this.agents,
  });

  final int index;
  final Map<String, dynamic> beat;
  final bool revealed;
  final List<Map<String, dynamic>> facts;
  final List<Map<String, dynamic>> agents;

  @override
  Widget build(BuildContext context) {
    final label = beat['label'] as String? ?? '';
    final evidence = [
      for (final e in (beat['visible_evidence'] as List?) ?? const [])
        e as String,
    ];
    final revealIds = [
      for (final id in (beat['reveals'] as List?) ?? const []) id as String,
    ];
    final knownIds = [
      for (final id in (beat['known_by'] as List?) ?? const []) id as String,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: revealed
            ? Colors.white.withValues(alpha: 0.72)
            : const Color(0xFFE9E7E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: revealed
              ? kColorDusk.withValues(alpha: 0.3)
              : const Color(0xFFDDD9D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: revealed
                    ? kColorDusk
                    : const Color(0xFFB9B4A8),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kColorInk,
                  ),
                ),
              ),
            ],
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final item in evidence)
              Text(
                '· $item',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF5C5C68),
                ),
              ),
          ],
          if (revealed && revealIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final fid in revealIds)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kColorEmber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '得知：${_factText(facts, fid)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kColorInk,
                  ),
                ),
              ),
          ],
          if (revealed && knownIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final aid in knownIds)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${_agentLabel(agents, aid)} 知道',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _factText(List<Map<String, dynamic>> facts, String id) {
    for (final f in facts) {
      if (f['id'] == id) return f['text'] as String? ?? id;
    }
    return id;
  }

  String _agentLabel(List<Map<String, dynamic>> agents, String id) {
    for (final a in agents) {
      if (a['id'] == id) return a['label'] as String? ?? id;
    }
    return id;
  }
}

class _InfoOptionTile extends StatelessWidget {
  const _InfoOptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final JourneyChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: switch (state) {
        JourneyChoiceState.correct => kSignalSuccessBg,
        JourneyChoiceState.wrong => kSignalErrorBg,
        _ => Colors.white.withValues(alpha: 0.62),
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: switch (state) {
            JourneyChoiceState.correct => kSignalSuccess,
            JourneyChoiceState.wrong => kSignalError,
            _ => const Color(0xFFD9D9E2),
          },
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: kColorInk,
            ),
          ),
        ),
      ),
    );
  }
}
