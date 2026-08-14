import 'package:flutter/material.dart';

import '../../data/progress/progress_aggregation.dart';
import '../../l10n/gen/app_localizations.dart';

/// Streak card: streak badge, freeze credits chip, and a 5-week calendar grid
/// (reviewed = flame, frozen = snowflake, today outlined).
class StreakCard extends StatefulWidget {
  const StreakCard({super.key, required this.streak, required this.weeks});

  final StreakEvaluation streak;
  final List<List<StreakWeekDay>> weeks;

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  bool _infoVisible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final freeze = widget.streak.streakFreeze;
    final hasReviewedToday = widget.weeks.any(
      (week) =>
          week.any((d) => d.isToday && d.state == StreakDayState.reviewed),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.streakCardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _Badge(
                  icon: Icons.local_fire_department,
                  color: hasReviewedToday
                      ? const Color(0xFFFF6B35)
                      : theme.colorScheme.outline,
                  label: l10n.streakDaysLabel(widget.streak.currentStreakDays),
                ),
                const SizedBox(width: 12),
                _Badge(
                  icon: Icons.ac_unit,
                  color: freeze.availableCredits > 0
                      ? const Color(0xFF4FC3F7)
                      : theme.colorScheme.outline,
                  label: l10n.streakFreezeCount(
                    freeze.availableCredits,
                    freeze.capacity,
                  ),
                  onTap: () => setState(() => _infoVisible = !_infoVisible),
                  trailing: const Icon(Icons.info_outline, size: 14),
                ),
              ],
            ),
            if (_infoVisible) ...[
              const SizedBox(height: 12),
              Text(
                freeze.availableCredits >= freeze.capacity
                    ? l10n.streakFreezeFull
                    : l10n.streakFreezeInfo(freeze.unitsUntilNextCredit),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              children: [
                _WeekdayHeader(label: 'M'),
                _WeekdayHeader(label: 'T'),
                _WeekdayHeader(label: 'W'),
                _WeekdayHeader(label: 'T'),
                _WeekdayHeader(label: 'F'),
                _WeekdayHeader(label: 'S'),
                _WeekdayHeader(label: 'S'),
              ],
            ),
            for (final week in widget.weeks)
              Row(
                children: [
                  for (final day in week)
                    Expanded(child: _StreakDayCell(day: day)),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              l10n.streakLongest(widget.streak.longestStreakDays),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: color),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _StreakDayCell extends StatelessWidget {
  const _StreakDayCell({required this.day});

  final StreakWeekDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bg;
    IconData? icon;
    switch (day.state) {
      case StreakDayState.reviewed:
        bg = const Color(0xFFFF6B35);
        icon = Icons.local_fire_department;
      case StreakDayState.frozen:
        bg = const Color(0xFF4FC3F7);
        icon = Icons.ac_unit;
      default:
        bg = null;
    }
    final todayBorder = day.isToday
        ? Border.all(color: theme.colorScheme.primary, width: 2)
        : null;

    // The caller wraps this cell in Expanded; nesting another one here would
    // trigger "Incorrect use of ParentDataWidget" at runtime.
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color:
              bg?.withValues(alpha: 0.25) ??
              (day.isFuture
                  ? null
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    )),
          borderRadius: BorderRadius.circular(8),
          border: todayBorder,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 16, color: bg)
            : Text(
                day.dayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: day.isFuture
                      ? theme.colorScheme.outline.withValues(alpha: 0.4)
                      : theme.colorScheme.outline,
                ),
              ),
      ),
    );
  }
}
