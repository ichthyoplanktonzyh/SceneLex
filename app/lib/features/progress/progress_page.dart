import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/progress/progress_providers.dart';
import '../../data/progress/progress_aggregation.dart';
import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'reviews_chart_card.dart';
import 'schedule_card.dart';
import 'streak_card.dart';

/// Progress surface: streak (with freezes), reviews chart, review schedule.
/// All data is aggregated locally; pull-to-refresh runs a sync first.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  final _streakKey = GlobalKey();
  final _reviewsKey = GlobalKey();
  final _scheduleKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(progressDataProvider);

    // Scroll-to-section jump (e.g. Review streak badge -> streak card).
    ref.listen(progressScrollTargetProvider, (previous, target) {
      if (target == null) return;
      final key = switch (target) {
        ProgressScrollTarget.streak => _streakKey,
        ProgressScrollTarget.reviews => _reviewsKey,
        ProgressScrollTarget.schedule => _scheduleKey,
      };
      final targetContext = key.currentContext;
      if (targetContext != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
      ref.read(progressScrollTargetProvider.notifier).consume();
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressDataProvider);
          await ref.read(progressDataProvider.future);
        },
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
          data: (d) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              StreakCard(key: _streakKey, streak: d.streak, weeks: d.weeks),
              const SizedBox(height: 12),
              ReviewsChartCard(
                key: _reviewsKey,
                dailyReviews: d.dailyReviews,
                today: todayLocalDate(),
              ),
              const SizedBox(height: 12),
              ScheduleCard(key: _scheduleKey, schedule: d.schedule),
            ],
          ),
        ),
      ),
    );
  }
}
