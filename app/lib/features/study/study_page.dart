/// 我的学习: plan, overview statistics and the check-in calendar — every
/// number from real local data. 学习偏好 lives on the second tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../data/product_providers.dart';
import '../../domain/learning/study_stats.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../preferences/preferences_page.dart';

class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key});

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider).value;
    final states = ref.watch(learningStatesProvider).value ?? const {};
    final prefs = ref.watch(preferencesProvider);

    final header = Row(
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.studyTitle)),
            ButtonSegment(value: 1, label: Text(l10n.studyPreferences)),
          ],
          selected: {_tab},
          onSelectionChanged: (selection) =>
              setState(() => _tab = selection.first),
          showSelectedIcon: false,
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: header,
                ),
                Expanded(
                  child: _tab == 0
                      ? _StudyTab(
                          catalogSize: catalog?.senses.length ?? 0,
                          learnedCount: states.length,
                          dailyGoal: prefs.newGroupSize,
                        )
                      : PreferencesBody(
                          onChanged: (next) {
                            ref.read(preferencesProvider.notifier).set(next);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyTab extends ConsumerWidget {
  const _StudyTab({
    required this.catalogSize,
    required this.learnedCount,
    required this.dailyGoal,
  });

  final int catalogSize;
  final int learnedCount;
  final int dailyGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<StudyStats>(
      future: _stats(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.studyLoadError(snapshot.error ?? '')));
        }
        final stats = snapshot.data!;
        final progress = learnedCount == 0
            ? 0.0
            : learnedCount / catalogSize.clamp(1, 1 << 31);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            // 计划
            Row(
              children: [
                Text(
                  l10n.studyPlan,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/content/lists'),
                  child: Text(l10n.studyLists),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.studyScope,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l10n.studyBySense,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF9A9AA4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFEEEFF2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.studyLearned(learnedCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6D6D76),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.studyCatalogSize(catalogSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6D6D76),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.studyDailyNew,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.studyDailyGoal(dailyGoal),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: kColorEmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 概览
            Text(
              l10n.studyStats,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusCard),
              ),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.9,
                children: [
                  _Stat(
                    icon: Icons.bar_chart,
                    color: const Color(0xFFF5C23A),
                    label: l10n.studyTodayLearnReview,
                    value: '${stats.todayLearnedCount}',
                    unit: l10n.studySenses,
                  ),
                  _Stat(
                    icon: Icons.trending_up,
                    color: const Color(0xFFEF4E63),
                    label: l10n.studyCumulativeLearned,
                    value: '${stats.totalLearnedCount}',
                    unit: l10n.studySenses,
                  ),
                  _Stat(
                    icon: Icons.timer_outlined,
                    color: const Color(0xFFF5C23A),
                    label: l10n.studyTodayMinutes,
                    value: _minutes(stats.todayDurationSeconds),
                    unit: l10n.studyMinutes,
                  ),
                  _Stat(
                    icon: Icons.schedule,
                    color: const Color(0xFFEF4E63),
                    label: l10n.studyCumulativeMinutes,
                    value: _minutes(stats.totalDurationSeconds),
                    unit: l10n.studyMinutes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 签到日历
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadiusCard),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.studyCheckinCalendar,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l10n.studyStreak(stats.streakDays),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFA2A2AA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final day in stats.week)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _weekday(day.date),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: day.isToday
                                      ? kColorEmber
                                      : const Color(0xFFB0B0B8),
                                ),
                              ),
                              const SizedBox(height: 10),
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: day.checkedIn
                                    ? kColorEmber
                                    : Colors.transparent,
                                child: day.isToday
                                    ? Text(
                                        l10n.studyTodayCol,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kColorEmber,
                                        ),
                                      )
                                    : Text(
                                        '${day.date.day}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2A2A30),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<StudyStats> _stats(WidgetRef ref) async {
    final local = ref.watch(localRepositoryProvider);
    final checkins = await local.allCheckins();
    final checkinKeys = checkins.map((c) => c.dayKey).toSet();
    final events = await local.allReviewEvents();
    final sessions = await local.allSessions();
    final stats = deriveStudyStats(
      checkinDayKeys: checkinKeys,
      reviewEventTimes: events.map((e) => e.reviewedAtClient.toLocal()),
      sessions: sessions.map(
        (s) => (
          startedAt: s.startedAt,
          endedAt: s.endedAt,
          durationSeconds: s.durationSeconds,
        ),
      ),
      learnedCount: learnedCount,
    );
    return stats;
  }

  String _minutes(int seconds) =>
      (seconds / 60).round().clamp(0, 999999).toString();

  String _weekday(DateTime date) =>
      DateFormat('EEE', 'en').format(date).toUpperCase();
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF4B4B53),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: kColorInk,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFA2A2AA),
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
