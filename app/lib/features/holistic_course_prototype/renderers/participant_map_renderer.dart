/// participant_map renderer — same event from different participant
/// perspectives: participants, transferable object, direction arrows and
/// a perspective switch; then the Author's question (single choice).
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import '../../journey_prototype/views/journey_shell.dart';
import 'holistic_step_chrome.dart';

class ParticipantMapRenderer extends StatefulWidget {
  const ParticipantMapRenderer({
    super.key,
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  State<ParticipantMapRenderer> createState() => _ParticipantMapState();
}

class _ParticipantMapState extends State<ParticipantMapRenderer> {
  late String _currentRole = _authoredCurrentRole ?? _firstRole ?? '';

  String? get _authoredCurrentRole =>
      (widget.step.content['perspective'] as Map?)?['current_role'] as String?;

  String? get _firstRole {
    final roles =
        (widget.step.content['perspective'] as Map?)?['roles'] as List?;
    return roles == null || roles.isEmpty ? null : roles.first as String;
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final episode = content['episode'] as String? ?? '';
    final participants = [
      for (final p in (content['participants'] as List?) ?? const [])
        if (p is Map) p.cast<String, dynamic>(),
    ];
    final transferable = content['transferable'] is Map
        ? (content['transferable'] as Map).cast<String, dynamic>()
        : null;
    final arrows = [
      for (final a in (content['arrows'] as List?) ?? const [])
        if (a is Map) a.cast<String, dynamic>(),
    ];
    final perspective = content['perspective'] is Map
        ? (content['perspective'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final roles = [
      for (final r in (perspective['roles'] as List?) ?? const []) r as String,
    ];
    final question = content['question'] as String? ?? '';
    final options = (content['options'] as List?) ?? const [];
    final answered = widget.state.choiceId != null;
    final correctId = widget.step.correctOptionId;

    return HolisticStepScroll(
      children: [
        if (episode.isNotEmpty) JourneySceneCard(text: episode),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F0EC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2DED4)),
          ),
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              size: Size(constraints.maxWidth, 120),
              painter: _ParticipantMapPainter(
                participants: participants,
                arrows: arrows,
                currentRole: _currentRole,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final participant in participants)
                    Expanded(
                      child: _ParticipantNode(
                        participant: participant,
                        highlighted: participant['id'] == _currentRole,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (transferable != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '流动物：${transferable['label'] ?? ''}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF7A746A),
                ),
              ),
            ),
          ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 14),
          const HolisticLabel('切换视角'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in roles)
                ChoiceChip(
                  key: ValueKey('perspective-$role'),
                  label: Text(_labelFor(participants, role)),
                  selected: _currentRole == role,
                  onSelected: (_) => setState(() => _currentRole = role),
                ),
            ],
          ),
        ],
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
            child: _OptionTile(
              key: ValueKey('participant-option-${option['id']}'),
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
    );
  }

  String _labelFor(List<Map<String, dynamic>> participants, String role) {
    for (final p in participants) {
      if (p['id'] == role) return p['label'] as String? ?? role;
    }
    return role;
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

class _ParticipantNode extends StatelessWidget {
  const _ParticipantNode({
    required this.participant,
    required this.highlighted,
  });

  final Map<String, dynamic> participant;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final label = participant['label'] as String? ?? '';
    final role = participant['role'] as String? ?? '';
    final roleZh = switch (role) {
      'giver' => '提供者',
      'receiver' => '接收者',
      _ => '观察者',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted
                ? kColorEmber.withValues(alpha: 0.9)
                : kColorDusk.withValues(alpha: 0.25),
          ),
          child: Icon(
            Icons.person,
            color: highlighted ? Colors.white : kColorDusk,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: highlighted ? kColorEmber : kColorInk,
          ),
        ),
        Text(
          roleZh,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8B8B96)),
        ),
      ],
    );
  }
}

class _ParticipantMapPainter extends CustomPainter {
  _ParticipantMapPainter({
    required this.participants,
    required this.arrows,
    required this.currentRole,
  });

  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> arrows;
  final String currentRole;

  @override
  void paint(Canvas canvas, Size size) {
    if (participants.isEmpty) return;
    final xs = <String, double>{};
    final count = participants.length;
    for (final (i, p) in participants.indexed) {
      xs[p['id'] as String] = count == 1
          ? size.width / 2
          : size.width * (i / (count - 1));
    }
    const y = 22.0;
    for (final arrow in arrows) {
      final from = xs[arrow['from']];
      final to = xs[arrow['to']];
      if (from == null || to == null) continue;
      final paint = Paint()
        ..color = arrow['from'] == currentRole
            ? kColorEmber
            : const Color(0xFFB0AFAF)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(from, y)
        ..quadraticBezierTo((from + to) / 2, y - 26, to, y);
      canvas.drawPath(path, paint);
      // arrow head
      final dx = to > from ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(to, y)
          ..lineTo(to - 9 * dx, y - 6)
          ..moveTo(to, y)
          ..lineTo(to - 9 * dx, y + 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticipantMapPainter oldDelegate) =>
      oldDelegate.currentRole != currentRole || oldDelegate.arrows != arrows;
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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
