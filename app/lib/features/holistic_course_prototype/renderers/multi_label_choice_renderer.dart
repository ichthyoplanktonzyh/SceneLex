/// multi_label_choice renderer — checkbox multi-select with unified
/// post-submit feedback and lock. The correct set is
/// evaluation.correct_option_ids (single authority); `both` /
/// insufficient-evidence are ordinary options — no special casing here.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import '../../journey_prototype/views/journey_shell.dart';
import 'holistic_step_chrome.dart';

/// Answer encoding: selected option ids joined with ',' (the page stores it
/// as the step's single answer string).
String encodeMultiChoice(List<String> ids) => ids.join(',');

List<String> decodeMultiChoice(String? raw) =>
    raw == null || raw.isEmpty ? const [] : raw.split(',');

class MultiLabelChoiceRenderer extends StatefulWidget {
  const MultiLabelChoiceRenderer({
    super.key,
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  State<MultiLabelChoiceRenderer> createState() => _MultiLabelChoiceState();
}

class _MultiLabelChoiceState extends State<MultiLabelChoiceRenderer> {
  late final Set<String> _selected = {
    ...decodeMultiChoice(widget.state.choiceId),
  };

  bool get _answered => widget.state.choiceId != null;

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final episode = content['episode'] as String?;
    final evidence = [
      for (final e in (content['evidence'] as List?) ?? const []) e as String,
    ];
    final question = content['question'] as String? ?? '';
    final options = (content['options'] as List?) ?? const [];
    final correct = widget.step.correctOptionIds;
    return HolisticStepScroll(
      children: [
        if (episode != null) JourneySceneCard(text: episode),
        if (evidence.isNotEmpty) HolisticEvidenceList(evidence: evidence),
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
        const SizedBox(height: 8),
        if (!_answered) const HolisticNote('可以选择多个答案；提交前可修改，提交后锁定。'),
        const SizedBox(height: 12),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MultiOptionTile(
              key: ValueKey('multi-option-${option['id']}'),
              label: option['text'] as String? ?? '',
              selected: _selected.contains(option['id']),
              isCorrect: correct.contains(option['id']),
              answered: _answered,
              onTap: _answered
                  ? null
                  : () => setState(() {
                      final id = option['id'] as String;
                      if (!_selected.add(id)) _selected.remove(id);
                    }),
            ),
          ),
        if (!_answered)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('multi-submit'),
              onPressed: _selected.isEmpty
                  ? null
                  : () =>
                        widget.onChoose(encodeMultiChoice(_selected.toList())),
              style: FilledButton.styleFrom(
                backgroundColor: kColorDusk,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('提交'),
            ),
          ),
        if (_answered) ...[
          HolisticFeedbackCard(
            text: _selectedSetEquals(correct)
                ? '回答正确。'
                : '未完全正确——正确集合是：${_correctLabels(options, correct).join('、')}。',
          ),
          const SizedBox(height: 10),
          for (final option in options)
            if (option['feedback'] is String)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HolisticNote(option['feedback'] as String),
              ),
        ],
      ],
    );
  }

  bool _selectedSetEquals(List<String> correct) {
    final chosen = decodeMultiChoice(widget.state.choiceId).toSet();
    return chosen.length == correct.length && chosen.containsAll(correct);
  }

  List<String> _correctLabels(List<dynamic> options, List<String> correct) {
    return [
      for (final option in options)
        if (correct.contains(option['id'])) option['text'] as String? ?? '',
    ].where((label) => label.isNotEmpty).toList();
  }
}

class _MultiOptionTile extends StatelessWidget {
  const _MultiOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color border = const Color(0xFFD9D9E2);
    Color fill = Colors.white.withValues(alpha: 0.62);
    IconData icon = Icons.check_box_outline_blank;
    Color? iconColor;
    if (answered) {
      if (selected && isCorrect) {
        border = kSignalSuccess;
        fill = kSignalSuccessBg;
        icon = Icons.check_circle;
        iconColor = kSignalSuccess;
      } else if (selected && !isCorrect) {
        border = kSignalError;
        fill = kSignalErrorBg;
        icon = Icons.cancel;
        iconColor = kSignalError;
      } else if (!selected && isCorrect) {
        border = kSignalSuccess.withValues(alpha: 0.7);
        fill = kSignalSuccessBg.withValues(alpha: 0.4);
        icon = Icons.add_circle_outline;
        iconColor = kSignalSuccess;
      } else {
        icon = Icons.check_box_outline_blank;
      }
    } else if (selected) {
      border = kColorDusk;
      fill = kColorDusk.withValues(alpha: 0.08);
      icon = Icons.check_box;
      iconColor = kColorDusk;
    }
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: kColorInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
