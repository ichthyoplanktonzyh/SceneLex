/// Home: the immersive SceneLex landing surface. Every number is real
/// (catalog − learned = Learn, FSRS due = Review, local check-in), and the
/// entry points navigate to real pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/product_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'home_sky.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(homeProgressProvider);
    final checkedIn = ref.watch(todayCheckedInProvider);

    return Scaffold(
      backgroundColor: kHomeNightGradient.first,
      body: Stack(
        children: [
          const HomeSky(),
          SafeArea(
            child: progress.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
              error: (error, _) => _HomeError(error: error.toString()),
              data: (data) => _HomeContent(
                progress: data,
                checkedIn: checkedIn.value ?? false,
                onCheckIn: () async {
                  final local = ref.read(localRepositoryProvider);
                  await performCheckIn(local);
                  ref.invalidate(todayCheckedInProvider);
                  ref.invalidate(homeProgressProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.progress,
    required this.checkedIn,
    required this.onCheckIn,
  });

  final dynamic progress;
  final bool checkedIn;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final dateLabel = DateFormat('MM/dd EEE.').format(now);
    return Stack(
      children: [
        // Avatar → profile
        Positioned(
          top: 12,
          left: 20,
          child: IconButton(
            tooltip: l10n.homeProfile,
            onPressed: () => context.push('/profile'),
            icon: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF9AA6BD),
              foregroundColor: Colors.white,
              child: Icon(Icons.person, size: 26),
            ),
          ),
        ),
        const Positioned(
          top: 20,
          right: 22,
          child: Text(
            'SCENELEX',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: Color(0xB8402A3A),
            ),
          ),
        ),
        // Check-in card
        Positioned(
          top: 176,
          left: 0,
          right: 0,
          child: Center(
            child: _GlassCard(
              onTap: checkedIn ? null : onCheckIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    checkedIn ? Icons.calendar_today : Icons.calendar_month,
                    size: 34,
                    color: kColorInk,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    checkedIn ? l10n.homeCheckedIn : l10n.homeCheckin,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kColorInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF3D3D45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Learn / Review actions
        Positioned(
          left: 16,
          right: 16,
          bottom: 96,
          child: Row(
            children: [
              Expanded(
                child: _ActionCard(
                  label: l10n.homeLearnCta,
                  value: '${progress.learnCount}',
                  caption: l10n.homeNewSensesLabel,
                  onTap: progress.learnCount > 0
                      ? () => context.push('/learn')
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionCard(
                  label: l10n.homeReviewCta,
                  value: '${progress.reviewCount}',
                  caption: l10n.homeDueLabel,
                  onTap: progress.reviewCount > 0
                      ? () => context.push('/review')
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 172,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(kRadiusPill),
        boxShadow: const [
          BoxShadow(
            color: Color(0x245A3C78),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusPill),
      child: content,
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.44),
                Colors.white.withValues(alpha: 0.22),
              ],
            ),
            borderRadius: BorderRadius.circular(kRadiusLg),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F5A3C78),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: kColorEmber,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6470)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white70, size: 44),
            const SizedBox(height: 12),
            Text(
              l10n.homeLoadError,
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
