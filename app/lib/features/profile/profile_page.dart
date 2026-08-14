/// 个人中心: real account info, real counts, real FSRS mastery overview,
/// appearance, preferences and settings entry. Nothing fake — no VIP, no
/// fake message counts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/content/experience_program_repository.dart';
import '../../data/product_providers.dart';
import '../../domain/content_catalog/word_sense_catalog.dart';
import '../../ui/theme/scenelex_tokens.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<int>? _experienceCountFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(homeProgressProvider).value;
    final states = ref.watch(learningStatesProvider).value ?? const {};
    final catalog = ref.watch(catalogProvider).value;
    final themeMode = ref.watch(appearanceThemeModeProvider);

    final learnedCount = progress?.learnedCount ?? 0;
    final emailFuture = _emailFuture();
    _experienceCountFuture ??= catalog == null
        ? Future.value(0)
        : _loadExperienceCount(
            catalog: catalog,
            learned: states.keys.toSet(),
            repository: ref.read(programRepositoryProvider),
          );

    final distribution = [
      (
        label: l10n.profileLearning,
        count: progress?.learningCount ?? 0,
        color: kColorEmber,
      ),
      (
        label: l10n.profileReviewing,
        count: progress?.reviewingCount ?? 0,
        color: kColorTealSignalBright,
      ),
      (
        label: l10n.profileRelearning,
        count: progress?.relearningCount ?? 0,
        color: const Color(0xFFE0A021),
      ),
      (
        label: l10n.profileNewCards,
        count: progress?.newCount ?? 0,
        color: const Color(0xFF9A9AA4),
      ),
    ];
    final maxCount = distribution.fold<int>(
      1,
      (m, d) => d.count > m ? d.count : m,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEEF0EF),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.profileBack,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF6B7488),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person, size: 42),
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<String?>(
                      future: emailFuture,
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? l10n.profileLearner,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profileNoMember,
                      style: TextStyle(fontSize: 14, color: Color(0xFF8B8B93)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _AssetTile(
                        title: l10n.profileLearnedSenses,
                        value: '$learnedCount',
                        subtitleWidget: FutureBuilder<int>(
                          future: _experienceCountFuture,
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Text(
                              snapshot.hasError || snapshot.data == null
                                  ? l10n.profileExperiencesLoading
                                  : l10n.profileExperienceCount(count),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF9A9AA4),
                              ),
                            );
                          },
                        ),
                        onTap: () => context.push('/content/learned'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AssetTile(
                        title: l10n.profileMastery,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final d in distribution)
                              Expanded(
                                child: Container(
                                  height: 16 + (d.count / maxCount) * 26,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: d.color,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: _masterySummary(l10n, distribution),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Group([
                  _Row(
                    icon: Icons.palette_outlined,
                    iconBg: const Color(0xFFDFF5EC),
                    iconColor: const Color(0xFF17A97F),
                    title: l10n.profileAppearance,
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (dark) async {
                        final mode = dark ? ThemeMode.dark : ThemeMode.light;
                        ref
                            .read(appearanceThemeModeProvider.notifier)
                            .setThemeMode(mode);
                        await persistThemeMode(mode);
                      },
                      activeThumbColor: kColorEmber,
                    ),
                  ),
                  _Row(
                    icon: Icons.tune,
                    iconBg: const Color(0xFFF6E9FB),
                    iconColor: const Color(0xFFB053D8),
                    title: l10n.profilePreferences,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFC2C2CA),
                    ),
                    onTap: () => context.push('/preferences'),
                  ),
                  _Row(
                    icon: Icons.settings_outlined,
                    iconBg: const Color(0xFFE7EDFD),
                    iconColor: const Color(0xFF4A76E8),
                    title: l10n.profileMoreSettings,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFC2C2CA),
                    ),
                    onTap: () => context.push('/settings'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<int> _loadExperienceCount({
    required WordSenseCatalog catalog,
    required Set<String> learned,
    required ExperienceProgramRepository repository,
  }) async {
    var total = 0;
    for (final entry in catalog.ordered) {
      if (!learned.contains(entry.senseId)) continue;
      try {
        final program = await repository.load(entry.senseId);
        total += program.units.length;
      } catch (_) {}
    }
    return total;
  }

  String _masterySummary(
    AppLocalizations l10n,
    List<({String label, int count, Color color})> d,
  ) {
    final total = d.fold<int>(0, (s, x) => s + x.count);
    if (total == 0) return l10n.profileNoRecords;
    return l10n.profileFsrsSummary(total);
  }

  Future<String?> _emailFuture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_email');
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.title,
    this.subtitle,
    this.value,
    this.subtitleWidget,
    this.child,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? subtitleWidget;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (value != null)
                Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              if (child != null) child!,
              const SizedBox(height: 6),
              if (subtitleWidget != null)
                subtitleWidget!
              else if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF9A9AA4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(kRadiusSm),
          ),
          child: Icon(icon, size: 21, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
        ),
        trailing: trailing,
      ),
    );
  }
}
