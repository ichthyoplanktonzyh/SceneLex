import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/progress/progress_aggregation.dart';
import '../../l10n/gen/app_localizations.dart';

/// Review Schedule card: donut ring of due-date buckets + tappable legend.
class ScheduleCard extends StatefulWidget {
  const ScheduleCard({super.key, required this.schedule});

  final List<ScheduleBucketView> schedule;

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  ScheduleBucket? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = widget.schedule.fold<int>(0, (sum, b) => sum + b.count);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reviewScheduleTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(l10n.scheduleEmpty,
                      style: theme.textTheme.bodySmall),
                ),
              )
            else ...[
              _Donut(
                schedule: widget.schedule,
                selected: _selected,
                onSegmentTap: (bucket) => setState(() {
                  _selected = _selected == bucket ? null : bucket;
                }),
              ),
              const SizedBox(height: 12),
              for (final view in widget.schedule)
                if (view.count > 0)
                  _BucketRow(
                    view: view,
                    total: total,
                    selected: _selected == view.bucket,
                    onTap: () => setState(() {
                      _selected = _selected == view.bucket ? null : view.bucket;
                    }),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({
    required this.schedule,
    required this.selected,
    required this.onSegmentTap,
  });

  final List<ScheduleBucketView> schedule;
  final ScheduleBucket? selected;
  final ValueChanged<ScheduleBucket> onSegmentTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final bucket = _hitTestBucket(details.localPosition);
        if (bucket != null) onSegmentTap(bucket);
      },
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Center(
          child: CustomPaint(
            size: const Size(180, 180),
            painter: _DonutPainter(
              schedule: schedule,
              selected: selected,
              labelColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  ScheduleBucket? _hitTestBucket(Offset position) {
    const size = 180.0;
    const center = Offset(size / 2, size / 2);
    const outer = 88.0;
    const inner = 54.0;
    final d = position - center;
    final dist = d.distance;
    if (dist < inner || dist > outer) return null;

    final total = schedule.fold<int>(0, (sum, b) => sum + b.count);
    if (total <= 0) return null;

    // Angle clockwise from 12 o'clock.
    var angle = (math.atan2(d.dy, d.dx) * 180 / math.pi + 90) % 360;
    if (angle < 0) angle += 360;

    var current = 0.0;
    for (final view in schedule) {
      if (view.count == 0) continue;
      final start = current;
      final end = current + view.count / total * 360;
      if (angle >= start && angle < end) return view.bucket;
      current = end;
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.schedule,
    required this.selected,
    required this.labelColor,
  });

  final List<ScheduleBucketView> schedule;
  final ScheduleBucket? selected;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = schedule.fold<int>(0, (sum, b) => sum + b.count);
    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.62;

    var start = -math.pi / 2;
    for (final view in schedule) {
      if (view.count == 0) continue;
      final sweep = view.count / total * 2 * math.pi;
      final isSelected = view.bucket == selected;
      final rect = Rect.fromCircle(center: center, radius: outer - 1);

      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer - inner
          ..strokeCap = StrokeCap.butt
          ..color = Color(scheduleBucketColors[view.bucket]!)
              .withValues(alpha: isSelected ? 1.0 : (selected == null ? 0.95 : 0.35)),
      );
      start += sweep;
    }

    // Center label: selected bucket count, or total.
    final selectedView = selected == null
        ? null
        : schedule.where((b) => b.bucket == selected).firstOrNull;
    final label = selectedView?.count ?? total;
    final labelStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: labelColor,
    );
    final tp = TextPainter(
      text: TextSpan(text: '$label', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.schedule != schedule ||
      oldDelegate.labelColor != labelColor;
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.view,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final ScheduleBucketView view;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(scheduleBucketColors[view.bucket]!);
    final percentage = total <= 0
        ? '0%'
        : '${((view.count / total) * 100).toStringAsFixed(1)}%';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _bucketLabel(context, view.bucket),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
            Text(
              '${view.count} ($percentage)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _bucketLabel(BuildContext context, ScheduleBucket bucket) {
    final l10n = AppLocalizations.of(context);
    return switch (bucket) {
      ScheduleBucket.new_ => l10n.bucketNew,
      ScheduleBucket.today => l10n.bucketToday,
      ScheduleBucket.days1To7 => l10n.bucket1to7,
      ScheduleBucket.days8To30 => l10n.bucket8to30,
      ScheduleBucket.days31To90 => l10n.bucket31to90,
      ScheduleBucket.days91To360 => l10n.bucket91to360,
      ScheduleBucket.years1To2 => l10n.bucket1to2y,
      ScheduleBucket.later => l10n.bucketLater,
    };
  }
}
