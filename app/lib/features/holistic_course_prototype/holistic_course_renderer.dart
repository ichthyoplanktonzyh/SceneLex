/// Holistic Course renderer — maps each App Teaching Capabilities primitive
/// to a thin adapter widget.
///
/// Reuses existing prototype chrome where a direct match exists
/// (JourneySceneCard / JourneyChoiceTile / JourneyFooterButton from the
/// Journey prototype); anything without a direct match gets a small local
/// adapter. No teaching content is added here — only capability fields are
/// laid out, in the Author's order.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import '../journey_prototype/views/journey_shell.dart';
import 'holistic_course_models.dart';
import 'renderers/holistic_renderer_registry.dart';

/// Callbacks the page wires into a step view.
class StepActions {
  const StepActions({
    required this.onChoose,
    required this.onReveal,
    required this.onGrade,
  });

  final ValueChanged<String> onChoose;
  final VoidCallback onReveal;
  final ValueChanged<String> onGrade;
}

/// Learner-visible state of the current step.
class StepViewState {
  const StepViewState({this.choiceId, this.revealed = false, this.gradeId});

  final String? choiceId;
  final bool revealed;
  final String? gradeId;
}

/// Renders the current step strictly from its content; nothing else.
Widget buildStepView(
  HolisticStep step,
  StepViewState state,
  StepActions actions,
) {
  switch (step.primitive) {
    case HolisticPrimitive.sceneObservation:
      return _SceneStep(
        step: step,
        revealed: state.revealed,
        onProceed: actions.onReveal,
      );
    case HolisticPrimitive.evidenceHighlight:
      return _SceneStep(
        step: step,
        revealed: state.revealed,
        onProceed: actions.onReveal,
      );
    case HolisticPrimitive.singleChoice:
    case HolisticPrimitive.binaryJudgment:
    case HolisticPrimitive.transferJudgment:
      return _ChoiceStep(step: step, state: state, onChoose: actions.onChoose);
    case HolisticPrimitive.symbolReveal:
      return _SymbolRevealStep(step: step);
    case HolisticPrimitive.pronunciation:
      return _PronunciationStep(step: step, onPronounce: actions.onReveal);
    case HolisticPrimitive.l1Confirmation:
      return _ConfirmationStep(step: step);
    case HolisticPrimitive.l2Grounding:
      return _GroundingStep(step: step);
    case HolisticPrimitive.boundaryChoice:
      return _BoundaryStep(
        step: step,
        state: state,
        onChoose: actions.onChoose,
      );
    case HolisticPrimitive.recallReveal:
      return _RecallRevealStep(
        step: step,
        revealed: state.revealed,
        onReveal: actions.onReveal,
      );
    case HolisticPrimitive.recallSelfGrade:
      return _SelfGradeStep(
        step: step,
        gradeId: state.gradeId,
        onGrade: actions.onGrade,
      );
    case HolisticPrimitive.multiLabelChoice:
    case HolisticPrimitive.objectInspection:
    case HolisticPrimitive.spatialStage:
    case HolisticPrimitive.participantMap:
    case HolisticPrimitive.scalarThreshold:
    case HolisticPrimitive.informationState:
      // Teaching Archetype MVP 六组新能力：由 Renderer Registry 分发。
      return HolisticRendererRegistry.build(step, state, actions)!;
  }
}

// --------------------------------------------------------------------------- //
// 场景 / 证据
// --------------------------------------------------------------------------- //

class _SceneStep extends StatelessWidget {
  const _SceneStep({
    required this.step,
    required this.revealed,
    required this.onProceed,
  });

  final HolisticStep step;
  final bool revealed;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    final episode = content['episode'] as String?;
    final evidence = [
      for (final e in (content['evidence'] as List?) ?? const []) e as String,
    ];
    return _StepScroll(
      children: [
        if (episode != null) JourneySceneCard(text: episode),
        if (evidence.isNotEmpty) _EvidenceList(evidence: evidence),
        const SizedBox(height: 14),
        _Note(revealed ? '已观察。' : '观察场景中的线索。'),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// 单选 / 二选一 / 迁移判断
// --------------------------------------------------------------------------- //

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    final episode = content['episode'] as String?;
    final question = content['question'] as String? ?? '';
    final evidence = [
      for (final e in (content['evidence'] as List?) ?? const []) e as String,
    ];
    final options = (content['options'] as List?) ?? const [];
    final answered = state.choiceId != null;
    final correctId = step.correctOptionId;
    return _StepScroll(
      children: [
        if (episode != null) JourneySceneCard(text: episode),
        if (evidence.isNotEmpty) _EvidenceList(evidence: evidence),
        if (question.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            question,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: JourneyChoiceTile(
              key: ValueKey('option-${option['id']}'),
              label: option['text'] as String? ?? '',
              state: _choiceState(option['id'], correctId, state.choiceId),
              onTap: answered ? null : () => onChoose(option['id'] as String),
            ),
          ),
        if (answered)
          _FeedbackCard(text: _feedbackFor(options, state.choiceId)),
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

// --------------------------------------------------------------------------- //
// Symbol binding / 发音
// --------------------------------------------------------------------------- //

class _SymbolRevealStep extends StatelessWidget {
  const _SymbolRevealStep({required this.step});

  final HolisticStep step;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    return _StepScroll(
      children: [
        const SizedBox(height: 26),
        Icon(Icons.motion_photos_on, size: 40, color: kColorEmber),
        const SizedBox(height: 14),
        Text(
          content['l2_word'] as String? ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: kColorInk,
          ),
        ),
        if ((content['ipa'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '/${content['ipa']}/',
              style: const TextStyle(fontSize: 17, color: Color(0xFF4A4A54)),
            ),
          ),
        if (content['presentation'] is String)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Text(
              content['presentation'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.6,
                color: kColorInk,
              ),
            ),
          ),
        if (content['minimal_l1_gloss'] is String)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _GlossCard(text: content['minimal_l1_gloss'] as String),
          ),
      ],
    );
  }
}

class _PronunciationStep extends StatelessWidget {
  const _PronunciationStep({required this.step, required this.onPronounce});

  final HolisticStep step;
  final VoidCallback onPronounce;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    return _StepScroll(
      children: [
        const SizedBox(height: 26),
        Text(
          content['l2_word'] as String? ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: kColorInk,
          ),
        ),
        if ((content['ipa'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '/${content['ipa']}/',
              style: const TextStyle(fontSize: 17, color: Color(0xFF4A4A54)),
            ),
          ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onPronounce,
          icon: const Icon(Icons.volume_up),
          label: const Text('听发音'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// L1 确认 / Grounding
// --------------------------------------------------------------------------- //

class _ConfirmationStep extends StatelessWidget {
  const _ConfirmationStep({required this.step});

  final HolisticStep step;

  @override
  Widget build(BuildContext context) {
    final text = step.content['prompt_text'] as String? ?? '';
    return _StepScroll(children: [const SizedBox(height: 26), _Note(text)]);
  }
}

class _GroundingStep extends StatelessWidget {
  const _GroundingStep({required this.step});

  final HolisticStep step;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    final realization = content['l2_realization'] as String? ?? '';
    final constructions = [
      for (final c in (content['constructions'] as List?) ?? const [])
        c as String,
    ];
    final collocations = [
      for (final c in (content['collocations'] as List?) ?? const [])
        c as String,
    ];
    return _StepScroll(
      children: [
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
            realization,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ),
        if (constructions.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Label('句型'),
          ...constructions.map(
            (c) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Note(c),
            ),
          ),
        ],
        if (collocations.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Label('搭配'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in collocations) JourneyChip(label: c)],
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// Boundary
// --------------------------------------------------------------------------- //

class _BoundaryStep extends StatelessWidget {
  const _BoundaryStep({
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    final episode = content['episode'] as String? ?? '';
    final options = (content['options'] as List?) ?? const [];
    final correctSenseId = step.correctSenseId;
    // explanation 可以是数组（对象/字符串条目）或单个字符串（整段解释）
    final rawExplanation = content['explanation'];
    final explanation = rawExplanation is List
        ? rawExplanation
        : [if (rawExplanation is String) rawExplanation];
    final answered = state.choiceId != null;
    return _StepScroll(
      children: [
        JourneySceneCard(text: episode),
        const SizedBox(height: 20),
        Text(
          '这个场景更符合哪个词？',
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: kColorInk,
          ),
        ),
        const SizedBox(height: 12),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: JourneyChoiceTile(
              key: ValueKey('boundary-${option['sense_id']}'),
              label: (option['lemma'] ?? option['text']) as String? ?? '',
              state: _senseState(
                option['sense_id'],
                correctSenseId,
                state.choiceId,
              ),
              onTap: answered
                  ? null
                  : () => onChoose(option['sense_id'] as String),
            ),
          ),
        if (answered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in explanation)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry is Map) ...[
                            Text(
                              entry['sense_id'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: kColorInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            entry is Map
                                ? (entry['note'] as String? ?? '')
                                : entry as String? ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Color(0xFF5C5C68),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  JourneyChoiceState _senseState(Object? id, String? correct, String? chosen) {
    if (chosen == null) return JourneyChoiceState.idle;
    if (id == correct) return JourneyChoiceState.correct;
    if (id == chosen) return JourneyChoiceState.wrong;
    return JourneyChoiceState.muted;
  }
}

// --------------------------------------------------------------------------- //
// Recall
// --------------------------------------------------------------------------- //

class _RecallRevealStep extends StatelessWidget {
  const _RecallRevealStep({
    required this.step,
    required this.revealed,
    required this.onReveal,
  });

  final HolisticStep step;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    final episode = content['episode'] as String? ?? '';
    return _StepScroll(
      children: [
        JourneySceneCard(text: episode),
        const SizedBox(height: 24),
        if (!revealed)
          _Note('先在心里回想这个词，然后查看答案。')
        else ...[
          Text(
            content['l2_word'] as String? ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: kColorInk,
            ),
          ),
          if ((content['ipa'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '/${content['ipa']}/',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: Color(0xFF4A4A54)),
              ),
            ),
          if (content['minimal_gloss'] is String)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _GlossCard(text: content['minimal_gloss'] as String),
            ),
        ],
      ],
    );
  }
}

class _SelfGradeStep extends StatelessWidget {
  const _SelfGradeStep({
    required this.step,
    required this.gradeId,
    required this.onGrade,
  });

  final HolisticStep step;
  final String? gradeId;
  final ValueChanged<String> onGrade;

  static const _grades = [
    ('forgot', '忘了', kSignalError),
    ('hard', '勉强', Color(0xFFE0A021)),
    ('gotIt', '记住了', kSignalSuccess),
  ];

  @override
  Widget build(BuildContext context) {
    final content = step.content;
    return _StepScroll(
      children: [
        const SizedBox(height: 26),
        Text(
          content['l2_word'] as String? ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: kColorInk,
          ),
        ),
        if ((content['ipa'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '/${content['ipa']}/',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: Color(0xFF4A4A54)),
            ),
          ),
        const SizedBox(height: 28),
        _Label('这次回忆得怎么样？'),
        const SizedBox(height: 10),
        for (final (id, label, color) in _grades)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: gradeId == id
                  ? color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: color.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: () => onGrade(id),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kColorInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
// 小部件
// --------------------------------------------------------------------------- //

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

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

class _EvidenceList extends StatelessWidget {
  const _EvidenceList({required this.evidence});

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

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.text});

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

class _Note extends StatelessWidget {
  const _Note(this.text);

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

class _GlossCard extends StatelessWidget {
  const _GlossCard({required this.text});

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

class _Label extends StatelessWidget {
  const _Label(this.text);

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
