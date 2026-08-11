import 'package:flutter/material.dart';

import '../../data/progress/progress_aggregation.dart';
import '../../l10n/gen/app_localizations.dart';

/// Reviews card: stacked daily bar chart with week paging, day selection and
/// rating legend filtering (mirrors the flashcards chart model).
class ReviewsChartCard extends StatefulWidget {
  const ReviewsChartCard({super.key, required this.dailyReviews, required this.today});

  final List<DailyReviewPoint> dailyReviews;
  final String today;

  @override
  State<ReviewsChartCard> createState() => _ReviewsChartCardState();
}

class _ReviewsChartCardState extends State<ReviewsChartCard> {
  late List<ChartPage> _pages;
  int _pageIndex = 0;
  ChartSelection _selection = const ChartSelection.none();

  @override
  void initState() {
    super.initState();
    _rebuildPages();
  }

  @override
  void didUpdateWidget(covariant ReviewsChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildPages();
  }

  void _rebuildPages() {
    _pages = buildChartPages(widget.dailyReviews, widget.today, _selection.rating);
    if (_pages.isNotEmpty) {
      _pageIndex = _pages.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.reviewsCardTitle,
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _pageIndex > 0
                      ? () => setState(() {
                            _pageIndex--;
                            _selection = const ChartSelection.none();
                          })
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _pageIndex < _pages.length - 1
                      ? () => setState(() {
                            _pageIndex++;
                            _selection = const ChartSelection.none();
                          })
                      : null,
                ),
              ],
            ),
            if (_pages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(l10n.progressNoData,
                      style: theme.textTheme.bodySmall),
                ),
              )
            else
              _ChartView(
                page: _pages[_pageIndex],
                selection: _selection,
                onDayTap: (date) => setState(() {
                  _selection = _selection.day == date
                      ? const ChartSelection.none()
                      : ChartSelection.day(date);
                }),
                onRatingTap: (rating) => setState(() {
                  _selection = _selection.rating == rating
                      ? const ChartSelection.none()
                      : ChartSelection.rating(rating);
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({
    required this.page,
    required this.selection,
    required this.onDayTap,
    required this.onRatingTap,
  });

  final ChartPage page;
  final ChartSelection selection;
  final ValueChanged<String> onDayTap;
  final ValueChanged<ChartRatingKey> onRatingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final legend = buildChartLegendItems(page, selection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in page.days)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDayTap(day.date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (day.showMonthLabel)
                            Text(day.monthLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline)),
                          const SizedBox(height: 2),
                          Container(
                            width: double.infinity,
                            height: 110,
                            alignment: Alignment.bottomCenter,
                            child: _DayBar(day: day, selected: selection.day == day.date),
                          ),
                          const SizedBox(height: 2),
                          Text(day.weekdayLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline)),
                          Text(day.dayLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: day.isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in legend)
              _LegendChip(
                item: item,
                onTap: item.isDisabled ? null : () => onRatingTap(item.rating),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.selected});

  final ChartDay day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final height = day.barHeightPercentage.clamp(0, 100) / 100 * 100;
    return Opacity(
      opacity: selected ? 1.0 : 0.75,
      child: Container(
        width: double.infinity,
        height: height == 0 ? 2 : height,
        decoration: BoxDecoration(
          color: height == 0
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
        ),
        child: height == 0
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final segment in day.segments)
                    Expanded(
                      flex: (segment.heightPercentage * 100).round().clamp(1, 1000000),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(chartRatingColors[segment.rating]!),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.item, required this.onTap});

  final ChartLegendItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(chartRatingColors[item.rating]!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: item.isDimmed ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: item.isSelected ? 0.25 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: item.isSelected
                ? Border.all(color: color, width: 1.5)
                : null,
          ),
          child: Text(
            '${_ratingLabel(context, item.rating)} · ${item.count} (${item.percentageLabel})',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(BuildContext context, ChartRatingKey rating) {
    final l10n = AppLocalizations.of(context);
    return switch (rating) {
      ChartRatingKey.again => l10n.ratingAgain,
      ChartRatingKey.hard => l10n.ratingHard,
      ChartRatingKey.good => l10n.ratingGood,
      ChartRatingKey.easy => l10n.ratingEasy,
    };
  }
}
