/// Review session page: new-experience reverse retrieval with real FSRS
/// grading, offline-safe review events and a real completion view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/product_providers.dart';
import '../../data/providers.dart' show submitReview;
import '../../domain/experience_program/experience_program.dart';
import '../../data/fsrs.dart'
    show ScheduleState, SchedulerSettings, FsrsCardState;
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../review/rating_interval.dart' show RatingOption, buildRatingOptions;
import 'review_session_view_model.dart';

class ReviewSessionPage extends ConsumerStatefulWidget {
  const ReviewSessionPage({super.key, this.transferMode = false});

  final bool transferMode;

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  ReviewSessionViewModel? _viewModel;
  final Stopwatch _elapsed = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final repository = ref.read(programRepositoryProvider);
    final catalog = await ref.read(catalogProvider.future);
    final states = await ref.read(learningStatesProvider.future);

    // Load programs for senses that can enter the queue.
    final programs = <String, ExperienceProgram>{};
    final due = states.values.where((s) => widget.transferMode || s.isDue);
    for (final state in due) {
      if (!catalog.contains(state.wordSenseId)) continue;
      try {
        programs[state.wordSenseId] = await repository.load(state.wordSenseId);
      } catch (_) {}
    }

    final local = ref.read(localRepositoryProvider);
    final events = await local.allReviewEvents();
    final usedCounts = <String, int>{};
    for (final e in events) {
      if (e.experienceUnitId.isEmpty) continue;
      usedCounts[e.experienceUnitId] =
          (usedCounts[e.experienceUnitId] ?? 0) + 1;
    }

    final vm = ReviewSessionViewModel(
      transferMode: widget.transferMode,
      submitReview: _submit,
    );
    _viewModel = vm;
    vm.addListener(_onVmChange);
    await vm.load(
      catalog: catalog,
      states: states,
      programs: programs,
      usedItemCounts: usedCounts,
    );
  }

  Future<void> _submit({
    required String wordSenseId,
    required String learningStateId,
    required String experienceUnitId,
    required int programVersion,
    required int rating,
    required DateTime reviewedAtClient,
  }) async {
    final local = ref.read(localRepositoryProvider);
    final existing = await local.stateFor(wordSenseId);
    final effectiveStateId = existing?.learningStateId ?? learningStateId;
    await submitReview(
      ref,
      wordSenseId: wordSenseId,
      learningStateId: effectiveStateId,
      experienceUnitId: experienceUnitId,
      programVersion: programVersion,
      rating: rating,
      reviewedAtClient: reviewedAtClient,
    );
  }

  void _onVmChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onVmChange);
    super.dispose();
  }

  Future<void> _finishReview() async {
    _elapsed.stop();
    final local = ref.read(localRepositoryProvider);
    final elapsedSeconds = _elapsed.elapsed.inSeconds;
    await recordSession(
      local: local,
      kind: 'review',
      startedAt: DateTime.now().subtract(
        Duration(seconds: elapsedSeconds.clamp(0, 1 << 31)),
      ),
      endedAt: DateTime.now(),
    );
    ref.invalidate(homeProgressProvider);
    ref.invalidate(learningStatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = _viewModel;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && vm != null && vm.phase != ReviewPhase.done) {
          await _finishReview();
          if (context.mounted) context.pop();
        } else if (!didPop) {
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7E8CA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7E8CA),
          leading: IconButton(
            tooltip: l10n.reviewQuit,
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _finishReview();
              if (context.mounted) context.pop();
            },
          ),
          title: Text(
            vm == null
                ? ''
                : '${widget.transferMode ? l10n.reviewTransferTitle : l10n.reviewTitle} '
                      '${(vm.index + 1).clamp(1, vm.cards.length)} / '
                      '${vm.cards.length}',
          ),
        ),
        body: switch (vm?.phase) {
          null || ReviewPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          ReviewPhase.loadError => Center(
            child: Text(vm!.errorMessage ?? l10n.reviewLoadError),
          ),
          ReviewPhase.done => _DoneView(
            transferMode: widget.transferMode,
            gradedCount: vm!.gradedCount,
            onExit: () async {
              await _finishReview();
              if (context.mounted) context.go('/');
            },
          ),
          ReviewPhase.recalling ||
          ReviewPhase.revealed ||
          ReviewPhase.grading => _ReviewBody(
            vm: vm!,
            options: _ratingOptions(context, ref, vm.currentCard!.senseId),
            onReveal: vm.reveal,
            onGrade: (rating) async {
              final local = ref.read(localRepositoryProvider);
              final existing = await local.stateFor(vm.currentCard!.senseId);
              final stateId = existing?.learningStateId ?? '';
              final ok = await vm.grade(
                rating,
                learningStateId: stateId,
                reviewedAtClient: DateTime.now(),
              );
              if (ok) {
                ref.invalidate(homeProgressProvider);
                ref.invalidate(learningStatesProvider);
              }
            },
          ),
        },
      ),
    );
  }

  /// Real FSRS predicted intervals for the current card's sense.
  List<RatingOption> _ratingOptions(
    BuildContext context,
    WidgetRef ref,
    String senseId,
  ) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(schedulerSettingsProvider).value ?? const SchedulerSettings();
    final state = ref.watch(learningStatesProvider).value?[senseId];
    return buildRatingOptions(
      state: ScheduleState(
        reps: state?.reps ?? 0,
        lapses: state?.lapses ?? 0,
        state: switch (state?.fsrsCardState) {
          'learning' => FsrsCardState.learning,
          'review' => FsrsCardState.review,
          'relearning' => FsrsCardState.relearning,
          _ => FsrsCardState.new_,
        },
        stepIndex: state?.fsrsStepIndex,
        stability: state?.stability,
        difficulty: state?.difficulty,
        lastReviewedAt: state?.lastReviewedAt,
        scheduledDays: state?.scheduledDays,
      ),
      settings: settings,
      now: DateTime.now(),
      l10n: l10n,
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.vm,
    required this.options,
    required this.onReveal,
    required this.onGrade,
  });

  final ReviewSessionViewModel vm;
  final List<RatingOption> options;
  final VoidCallback onReveal;
  final ValueChanged<int> onGrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = vm.currentCard!;
    final revealed = vm.revealed;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (card.isTransfer)
                    _Kicker(text: l10n.recallDelayedRetrieval)
                  else
                    _L1Badge(
                      label: card.isNewItem
                          ? l10n.recallNewExperience
                          : l10n.recallRevisit,
                    ),
                  _SceneCard(text: card.episode),
                  if (!revealed)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          Text(
                            l10n.recallPrompt,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: kColorInk,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            l10n.recallHint,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF84848F),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _AnswerBox(
                      lemma: card.lemma,
                      ipa: card.ipa,
                      minimalHint: card.minimalHint,
                    ),
                ],
              ),
            ),
          ),
          if (!revealed)
            _BottomAction(
              label: l10n.revealShowAnswer,
              accent: kColorDusk,
              onTap: onReveal,
            )
          else
            _GradeGrid(options: options, onGrade: onGrade),
        ],
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({required this.lemma, this.ipa, this.minimalHint});

  final String lemma;
  final String? ipa;
  final String? minimalHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Text(
              lemma,
              key: ValueKey(lemma),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: Color(0xFF131318),
              ),
            ),
          ),
          if (ipa != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                ipa!,
                style: const TextStyle(fontSize: 17, color: Color(0xFF4A4A54)),
              ),
            ),
          if (minimalHint != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                minimalHint!,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: Color(0xFF3D3D47),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GradeGrid extends StatelessWidget {
  const _GradeGrid({required this.options, required this.onGrade});

  final List<RatingOption> options;
  final ValueChanged<int> onGrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = const [
      kSignalError,
      Color(0xFFE0A021),
      kSignalSuccess,
      Color(0xFF3C78DC),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: _GradeButton(
                    label: options[i].title,
                    hint: options[i].interval,
                    borderColor: colors[i],
                    onTap: () => onGrade(i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 2; i < 4; i++)
                Expanded(
                  child: _GradeButton(
                    label: options[i].title,
                    hint: options[i].interval,
                    borderColor: colors[i],
                    onTap: () => onGrade(i),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.gradeNextUsesNewExperience,
              style: TextStyle(fontSize: 12, color: Color(0xFF8B8B96)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.hint,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final String hint;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kColorInk,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF83838F),
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

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.transferMode,
    required this.gradedCount,
    required this.onExit,
  });

  final bool transferMode;
  final int gradedCount;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              transferMode ? Icons.track_changes : Icons.task_alt,
              size: 52,
              color: kSignalSuccess,
            ),
            const SizedBox(height: 14),
            Text(
              transferMode ? l10n.reviewTransferDone : l10n.reviewDone,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              transferMode
                  ? l10n.reviewTransferDoneBody
                  : l10n.reviewDoneBody(gradedCount),
              style: const TextStyle(fontSize: 15, color: Color(0xFF6F6F79)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              width: 160,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '$gradedCount',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    transferMode ? l10n.reviewRetrieved : l10n.reviewReviewed,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A84),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            FilledButton(onPressed: onExit, child: Text(l10n.reviewBackHome)),
          ],
        ),
      ),
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kColorEmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF7B7B86)),
          ),
        ],
      ),
    );
  }
}

class _L1Badge extends StatelessWidget {
  const _L1Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: kColorEmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C5C68),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            Colors.white.withValues(alpha: 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          height: 1.78,
          color: Color(0xFF1E1E26),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
      width: double.infinity,
      child: Column(
        children: [
          TextButton(
            onPressed: onTap,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
                color: kColorInk,
              ),
            ),
          ),
          AnimatedContainer(
            duration: kMotionFeedback,
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}
