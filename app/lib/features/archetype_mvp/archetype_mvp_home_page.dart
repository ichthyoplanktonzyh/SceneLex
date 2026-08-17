/// MVP home — one primary entry ("继续今日学习") plus secondary actions.
///
/// The home never leaks the target L2 lemma of a course that has not been
/// symbol-bound: the continue card only shows counts and minutes. There are
/// no seven "category mode" buttons — archetypes are invisible to the user.
library;

import 'package:flutter/material.dart';

import '../../../ui/theme/scenelex_tokens.dart';
import 'archetype_mvp_models.dart';
import 'archetype_mvp_session_page.dart';
import 'learner_state.dart';

class ArchetypeMvpHomePage extends StatelessWidget {
  const ArchetypeMvpHomePage({
    super.key,
    required this.state,
    required this.onOpenDevOverview,
    this.autoOpenSession,
    this.autoOpenOverview = false,
  });

  final LearnerState state;
  final VoidCallback onOpenDevOverview;

  /// Dev-only: auto-open today's session at the given plan item index
  /// (null = first item); index == plan length shows the completion page.
  final int? autoOpenSession;

  /// Dev-only: auto-open the dev overview sheet (screenshot driver).
  final bool autoOpenOverview;

  @override
  Widget build(BuildContext context) {
    if (autoOpenOverview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onOpenDevOverview();
      });
    }
    if (autoOpenSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final plan = state.plan();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ArchetypeMvpSessionPage(
                state: state,
                plan: plan,
                initialStepIndex: autoOpenSession!.clamp(0, plan.items.length),
              ),
            ),
          );
        }
      });
    }
    final dayPlan = state.plan();
    final minutes = (dayPlan.estimatedSeconds / 60).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('原型首页'),
        actions: [
          IconButton(
            key: const ValueKey('dev-overview-button'),
            tooltip: '开发者：课程/类别总览',
            icon: const Icon(Icons.science_outlined),
            onPressed: onOpenDevOverview,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            '第 ${state.day} 天',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '今天学什么',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kColorInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '到期复习优先，然后继续你的义项课程。',
            style: const TextStyle(fontSize: 14, color: Color(0xFF5C5C68)),
          ),
          const SizedBox(height: 22),
          // 主入口：继续今日学习
          Material(
            key: const ValueKey('continue-card'),
            color: kColorDusk,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => _startSession(context),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '继续今日学习',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '约 $minutes 分钟',
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (dayPlan.reviewCount > 0)
                          _CountChip(label: '${dayPlan.reviewCount} 次回想'),
                        if (dayPlan.newCourseCount > 0)
                          _CountChip(label: '${dayPlan.newCourseCount} 门新义项课'),
                        if (dayPlan.transferCount > 0)
                          _CountChip(label: '${dayPlan.transferCount} 次迁移'),
                        if (dayPlan.remedialCount > 0)
                          _CountChip(label: '${dayPlan.remedialCount} 次补救'),
                      ],
                    ),
                    if (dayPlan.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          '今天没有到期内容，可以休息或查看课程库。',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (dayPlan.deferred.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final reason in dayPlan.deferred)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: kColorEmber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF8A4B1D),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '本次学习',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF8B8B96),
            ),
          ),
          const SizedBox(height: 10),
          _SecondaryAction(
            key: const ValueKey('adjust-mode'),
            icon: Icons.tune,
            label: '调整本次学习',
            subtitle: '当前：${_modeLabel(state.mode)}',
            onTap: () => _pickMode(context),
          ),
          _SecondaryAction(
            key: const ValueKey('review-only'),
            icon: Icons.refresh,
            label: '只复习',
            subtitle: '只做今天到期的复习与补救',
            onTap: () {
              state.setMode(SessionMode.reviewOnly);
              _startSession(context);
            },
          ),
          _SecondaryAction(
            key: const ValueKey('new-only'),
            icon: Icons.auto_stories,
            label: '只学新内容',
            subtitle: '只开始/继续新义项课程',
            onTap: () {
              state.setMode(SessionMode.newOnly);
              _startSession(context);
            },
          ),
          _SecondaryAction(
            key: const ValueKey('course-library'),
            icon: Icons.grid_view,
            label: '课程库 / 开发者课程总览',
            subtitle: '查看 14 门课程与类别覆盖（开发者可见）',
            onTap: onOpenDevOverview,
          ),
          _SecondaryAction(
            key: const ValueKey('switch-day'),
            icon: Icons.calendar_month,
            label: '切换模拟日期',
            subtitle: '当前第 ${state.day} 天（1–14）',
            onTap: () => _pickDay(context),
          ),
        ],
      ),
    );
  }

  void _startSession(BuildContext context) {
    final plan = state.plan();
    if (plan.items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArchetypeMvpSessionPage(state: state, plan: plan),
      ),
    );
  }

  void _pickMode(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '调整本次学习',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (final (mode, label, desc) in [
              (SessionMode.normal, '正常', '复习 + 继续课程 + 新义项课'),
              (SessionMode.reviewOnly, '只复习', '只做到期复习与补救'),
              (SessionMode.newOnly, '只学新内容', '只开始/继续新义项课程'),
            ])
              ListTile(
                key: ValueKey('mode-${mode.name}'),
                leading: Icon(
                  mode == state.mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(label),
                subtitle: Text(desc),
                onTap: () {
                  state.setMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _pickDay(BuildContext context) {
    showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('切换模拟日期'),
        children: [
          for (var d = 1; d <= 14; d++)
            SimpleDialogOption(
              key: ValueKey('day-$d'),
              onPressed: () => Navigator.of(dialogContext).pop(d),
              child: Text(d == state.day ? '第 $d 天（当前）' : '第 $d 天'),
            ),
        ],
      ),
    ).then((day) {
      if (day != null) state.setDay(day);
    });
  }

  static String _modeLabel(SessionMode mode) => switch (mode) {
    SessionMode.normal => '正常',
    SessionMode.reviewOnly => '只复习',
    SessionMode.newOnly => '只学新内容',
  };
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE4E4EC)),
        ),
        child: ListTile(
          leading: Icon(icon, color: kColorDusk),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF8B8B96)),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFFB9B9C4)),
          onTap: onTap,
        ),
      ),
    );
  }
}
