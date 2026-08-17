/// spatial_stage renderer — 2D stage (regions/containers, start & end,
/// candidate paths) where the learner picks a path and watches it play.
/// Path selection is the answer (evaluation.correct_path_id). No physics.
library;

import 'package:flutter/material.dart';

import '../../../../ui/theme/scenelex_tokens.dart';
import '../holistic_course_models.dart';
import '../holistic_course_renderer.dart';
import 'holistic_step_chrome.dart';

class SpatialStageRenderer extends StatefulWidget {
  const SpatialStageRenderer({
    super.key,
    required this.step,
    required this.state,
    required this.onChoose,
  });

  final HolisticStep step;
  final StepViewState state;
  final ValueChanged<String> onChoose;

  @override
  State<SpatialStageRenderer> createState() => _SpatialStageState();
}

class _SpatialStageState extends State<SpatialStageRenderer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  String? _selectedPathId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.step.content;
    final title = content['stage_title'] as String? ?? '';
    final width = (content['stage_width'] as num?)?.toDouble() ?? 100;
    final height = (content['stage_height'] as num?)?.toDouble() ?? 60;
    final start = _point(content['start']);
    final end = _point(content['end']);
    final regions = [
      for (final r in (content['regions'] as List?) ?? const [])
        if (r is Map) r.cast<String, dynamic>(),
    ];
    final paths = [
      for (final p in (content['paths'] as List?) ?? const [])
        if (p is Map) p.cast<String, dynamic>(),
    ];
    final answered = widget.state.choiceId != null;
    final correctPathId = widget.step.correctPathId;
    final selected = _selectedPathId ?? widget.state.choiceId;
    final feedback = content['feedback'] as String? ?? '';

    return HolisticStepScroll(
      children: [
        if (title.isNotEmpty) HolisticNote(title),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F1EA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0DCD2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: width / height,
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _StagePainter(
                    start: start,
                    end: end,
                    regions: regions,
                    paths: paths,
                    selectedPathId: selected,
                    correctPathId: correctPathId,
                    answered: answered,
                    progress: _controller.value,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const HolisticLabel('选择一条路径'),
        const SizedBox(height: 8),
        for (final path in paths)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              key: ValueKey('path-${path['id']}'),
              color: _pathColor(
                path['id'],
                answered,
                correctPathId,
                selected,
              ).withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _pathColor(
                    path['id'],
                    answered,
                    correctPathId,
                    selected,
                  ),
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: answered
                    ? null
                    : () {
                        widget.onChoose(path['id'] as String);
                        setState(() {
                          _selectedPathId = path['id'] as String;
                          _controller.forward(from: 0);
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    path['label'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: kColorInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (answered && feedback.isNotEmpty) ...[
          const SizedBox(height: 6),
          HolisticFeedbackCard(text: feedback),
        ],
      ],
    );
  }

  Color _pathColor(
    Object? id,
    bool answered,
    String? correctId,
    String? selected,
  ) {
    if (!answered) {
      return id == selected ? kColorDusk : const Color(0xFFB9B9C4);
    }
    if (id == correctId) return kSignalSuccess;
    if (id == selected) return kSignalError;
    return const Color(0xFFD5D5DE);
  }

  Offset? _point(Object? raw) {
    if (raw is! Map) return null;
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    if (x == null || y == null) return null;
    return Offset(x, y);
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.start,
    required this.end,
    required this.regions,
    required this.paths,
    required this.selectedPathId,
    required this.correctPathId,
    required this.answered,
    required this.progress,
  });

  final Offset? start;
  final Offset? end;
  final List<Map<String, dynamic>> regions;
  final List<Map<String, dynamic>> paths;
  final String? selectedPathId;
  final String? correctPathId;
  final bool answered;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    Offset map(Offset p) =>
        Offset(p.dx / 100 * size.width, p.dy / 100 * size.height);

    // regions (containers / surfaces)
    for (final region in regions) {
      final paint = Paint()..color = const Color(0xFFE4E0D4);
      final rect = Rect.fromLTWH(
        size.width * 0.30,
        size.height * 0.30,
        size.width * 0.40,
        size.height * 0.40,
      );
      switch (region['shape']) {
        case 'circle':
          canvas.drawOval(rect, paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            paint,
          );
      }
      final label = region['label'] as String? ?? '';
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7A746A)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            size.width / 2 - tp.width / 2,
            size.height / 2 - tp.height / 2,
          ),
        );
      }
    }

    // path polylines (non-selected, dimmed)
    for (final path in paths) {
      final isSelected = path['id'] == selectedPathId;
      final isCorrect = path['id'] == correctPathId;
      final points = [
        for (final p in (path['points'] as List?) ?? const [])
          if (p is List && p.length == 2)
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ].map(map).toList();
      if (points.length < 2) continue;
      final paint = Paint()
        ..color = isSelected
            ? (answered && !isCorrect ? kSignalError : kColorDusk)
            : const Color(0xFFC9C4B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.2 : 1.6;
      final pathObj = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        pathObj.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(pathObj, paint);
    }

    // animated playhead on the selected path
    final selected = paths.where((p) => p['id'] == selectedPathId).toList();
    if (selected.isNotEmpty && progress > 0 && progress < 1) {
      final points = [
        for (final p in (selected.first['points'] as List?) ?? const [])
          if (p is List && p.length == 2)
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ].map(map).toList();
      final pos = _pointAlong(points, progress);
      if (pos != null) {
        canvas.drawCircle(pos, 5, Paint()..color = kColorEmber);
      }
    }

    // start / end markers
    if (start != null) {
      final s = map(start!);
      canvas.drawCircle(s, 7, Paint()..color = kSignalSuccess);
      final tp = TextPainter(
        text: const TextSpan(
          text: '起点',
          style: TextStyle(fontSize: 10, color: kSignalSuccess),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(s.dx - tp.width / 2, s.dy + 9));
    }
    if (end != null) {
      final e = map(end!);
      canvas.drawCircle(e, 7, Paint()..color = kColorEmber);
      final tp = TextPainter(
        text: const TextSpan(
          text: '终点',
          style: TextStyle(fontSize: 10, color: kColorEmber),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(e.dx - tp.width / 2, e.dy + 9));
    }
  }

  Offset? _pointAlong(List<Offset> points, double t) {
    if (points.length < 2) return null;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    if (total == 0) return points.first;
    var target = total * t;
    for (var i = 0; i < points.length - 1; i++) {
      final segment = (points[i + 1] - points[i]).distance;
      if (target <= segment) {
        return Offset.lerp(
          points[i],
          points[i + 1],
          segment == 0 ? 0 : target / segment,
        );
      }
      target -= segment;
    }
    return points.last;
  }

  @override
  bool shouldRepaint(covariant _StagePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selectedPathId != selectedPathId ||
      oldDelegate.answered != answered ||
      oldDelegate.correctPathId != correctPathId;
}
