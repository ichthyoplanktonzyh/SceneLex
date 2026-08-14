/// Learn session page: a whole learn group, one sense after another.
///
/// Drives [GroupSessionViewModel] and renders the Vertical Slice views
/// (ConceptUnitView / SymbolBindingView / GroundingView) plus the group-level
/// chrome: exit, per-sense progress, undo, favorite, 熟 (Known Check), more
/// menu (note / preferences), segmented progress bar, learner-facing stage
/// label, fixed bottom action, interrupted-session recovery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/product_providers.dart';
import '../../data/providers.dart' show workspaceProvider;
import '../../domain/experience_program/experience_unit.dart';
import '../../domain/learning/learning_progress.dart';
import '../../domain/learning/preferences.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../experience_runtime/experience_runtime_view_model.dart';
import '../experience_runtime/views/concept_unit_view.dart';
import '../experience_runtime/views/grounding_view.dart';
import '../experience_runtime/views/symbol_binding_view.dart';
import '../review/speech/tts_service.dart';
import 'group_session_view_model.dart';

/// Result handed to the group complete page.
class GroupResult {
  const GroupResult({
    required this.senseIds,
    required this.outcomes,
    required this.durationSeconds,
    required this.transferTiming,
  });

  final List<String> senseIds;
  final Map<String, SenseOutcome> outcomes;
  final int durationSeconds;
  final TransferTiming transferTiming;
}

final groupResultProvider =
    NotifierProvider<GroupResultController, GroupResult?>(
      GroupResultController.new,
    );

class GroupResultController extends Notifier<GroupResult?> {
  @override
  GroupResult? build() => null;

  void set(GroupResult? result) => state = result;
}

class LearnSessionPage extends ConsumerStatefulWidget {
  const LearnSessionPage({super.key});

  @override
  ConsumerState<LearnSessionPage> createState() => _LearnSessionPageState();
}

class _LearnSessionPageState extends ConsumerState<LearnSessionPage> {
  GroupSessionViewModel? _viewModel;
  String? _error;
  final Stopwatch _elapsed = Stopwatch()..start();
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final prefs = ref.read(preferencesProvider);
    final repository = ref.read(programRepositoryProvider);
    final catalog = await ref.read(catalogProvider.future);
    final states = await ref.read(learningStatesProvider.future);

    List<String> senseIds;
    Map<String, dynamic>? draft;
    final savedDraft = await loadLearnSessionDraft();
    // 预习入口：从指定义项开始一组。
    final previewSense = mounted
        ? GoRouterState.of(context).uri.queryParameters['preview']
        : null;
    if (previewSense != null && previewSense.isNotEmpty) {
      final anchor = [previewSense];
      final rest = nextLearnGroup(
        catalog: catalog,
        learnedSenseIds: states.keys.toSet().union({previewSense}),
        maxGroupSize: prefs.newGroupSize - 1,
      );
      senseIds = [...anchor, ...rest];
    } else if (savedDraft != null &&
        savedDraft['senseIds'] is List &&
        (savedDraft['senseIds'] as List).isNotEmpty) {
      senseIds = (savedDraft['senseIds'] as List)
          .map((e) => e.toString())
          .toList();
      draft = savedDraft;
    } else {
      senseIds = nextLearnGroup(
        catalog: catalog,
        learnedSenseIds: states.keys.toSet(),
        maxGroupSize: prefs.newGroupSize,
      );
    }
    if (senseIds.isEmpty) {
      setState(() => _error = 'empty');
      return;
    }
    final vm = GroupSessionViewModel(
      repository: repository,
      senseIds: senseIds,
      preferences: prefs,
    );
    _viewModel = vm;
    vm.addListener(_onVmChange);
    await vm.load(restoreState: draft);
  }

  void _onVmChange() {
    if (mounted) setState(() {});
  }

  Future<void> _saveDraft() async {
    final vm = _viewModel;
    if (vm == null) return;
    await saveLearnSessionDraft({
      'senseIds': vm.senseIds,
      'session': vm.toJson(),
    });
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onVmChange);
    super.dispose();
  }

  Future<void> _confirmExit() async {
    if (_exiting) return;
    _exiting = true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.learnExitTitle),
        content: Text(l10n.learnExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.learnResume),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.learnQuit),
          ),
        ],
      ),
    );
    _exiting = false;
    if (confirmed == true) {
      await _saveDraft();
      if (mounted) context.pop();
    }
  }

  Future<void> _toggleFavorite() async {
    final vm = _viewModel;
    final currentVm = vm?.currentVm;
    final unitId = currentVm?.currentUnit?.id;
    if (currentVm == null || unitId == null) return;
    final local = ref.read(localRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final programId = currentVm.program?.programId ?? '';
    final key = '$programId:$unitId';
    final fav = await local.isFavorite(key);
    if (fav) {
      await local.removeFavorite(key);
    } else {
      await local.addFavorite(programId: programId, experienceUnitId: unitId);
    }
    ref.invalidate(favoritesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fav ? l10n.learnRemovedFavorite : l10n.learnAddedFavorite,
        ),
      ),
    );
  }

  Future<void> _writeNote() async {
    final senseId = _viewModel?.currentSenseId;
    if (senseId == null) return;
    final local = ref.read(localRepositoryProvider);
    final existing = await local.noteFor(senseId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final text = existing?.noteText ?? '';
    final controller = TextEditingController(text: text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noteTitle(senseId)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(hintText: l10n.noteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.noteDelete),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.noteSave),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      await local.deleteNote(senseId);
    } else {
      await local.saveNote(senseId, result);
    }
    ref.invalidate(notesProvider);
  }

  Future<void> _finishGroup() async {
    final vm = _viewModel;
    if (vm == null) return;
    _elapsed.stop();
    await saveLearnSessionDraft(null);
    // 真实学习状态：每个义项进入 FSRS（无状态则创建）。
    final local = ref.read(localRepositoryProvider);
    final ws = await _workspaceId();
    for (final senseId in vm.senseIds) {
      final existing = await local.stateFor(senseId);
      if (existing == null) {
        await local.createLearningState(
          workspaceId: ws,
          wordSenseId: senseId,
          nowIso: DateTime.now().toUtc().toIso8601String(),
        );
      }
    }
    final elapsedSeconds = _elapsed.elapsed.inSeconds;
    await recordSession(
      local: local,
      kind: 'learn',
      startedAt: DateTime.now().subtract(
        Duration(seconds: elapsedSeconds.clamp(0, 1 << 31)),
      ),
      endedAt: DateTime.now(),
    );
    ref.invalidate(homeProgressProvider);
    ref.invalidate(learningStatesProvider);
    ref
        .read(groupResultProvider.notifier)
        .set(
          GroupResult(
            senseIds: vm.senseIds,
            outcomes: vm.outcomes,
            durationSeconds: elapsedSeconds,
            transferTiming: vm.preferences.transferTiming,
          ),
        );
    if (mounted) context.go('/finish');
  }

  Future<String> _workspaceId() async {
    try {
      final ws = await ref.read(workspaceProvider.future);
      return ws;
    } catch (_) {
      return ''; // 未登录/离线：本地先落库，登录后再同步。
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = _viewModel;
    if (_error == 'empty') return _EmptyCatalog();
    if (vm == null || !vm.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (vm.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.learnLoadError(vm.errorMessage ?? ''))),
      );
    }
    final currentVm = vm.currentVm;
    if (currentVm == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final phase = currentVm.phase;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7E8CA),
        body: SafeArea(
          child: Column(
            children: [
              _LearnHeader(
                senseLabel: l10n.learnWordProgress(
                  vm.senseIndex + 1,
                  vm.senseCount,
                ),
                canUndo: currentVm.canGoBack,
                onExit: _confirmExit,
                onUndo: currentVm.canGoBack ? currentVm.back : null,
                onFavorite: _toggleFavorite,
                onKnownCheck: vm.canOfferKnownCheck ? vm.startKnownCheck : null,
                onMore: _showMoreMenu,
              ),
              _SegmentedBar(
                segments: (currentVm.program?.units.length ?? 0) + 2,
                progress: _senseProgress(currentVm),
              ),
              _StepRow(
                label: _stepLabel(l10n, currentVm),
                modePill: _modePill(l10n, currentVm),
                isL2:
                    phase == ExperienceRuntimePhase.symbolBinding ||
                    phase == ExperienceRuntimePhase.grounding,
              ),
              Expanded(child: _buildBody(currentVm, vm)),
              _buildFooter(vm, currentVm),
            ],
          ),
        ),
      ),
    );
  }

  int _senseProgress(ExperienceRuntimeViewModel currentVm) {
    final program = currentVm.program;
    if (program == null) return 0;
    if (currentVm.phase == ExperienceRuntimePhase.symbolBinding) {
      return program.units.length + 1;
    }
    if (currentVm.phase == ExperienceRuntimePhase.grounding) {
      return program.units.length + 2;
    }
    return currentVm.unitIndex + (currentVm.isCurrentUnitAnswered ? 1 : 0);
  }

  String _stepLabel(
    AppLocalizations l10n,
    ExperienceRuntimeViewModel currentVm,
  ) {
    switch (currentVm.phase) {
      case ExperienceRuntimePhase.symbolBinding:
        return l10n.phaseSymbolReveal;
      case ExperienceRuntimePhase.grounding:
        return l10n.phaseSymbolRevealSub;
      case ExperienceRuntimePhase.conceptUnit:
        final unit = currentVm.currentUnit;
        if (unit != null) return roleLabel(l10n, unit.role);
      default:
        return '';
    }
    return '';
  }

  String _modePill(
    AppLocalizations l10n,
    ExperienceRuntimeViewModel currentVm,
  ) {
    switch (currentVm.phase) {
      case ExperienceRuntimePhase.symbolBinding:
        return l10n.phaseSymbolBinding;
      case ExperienceRuntimePhase.grounding:
        return l10n.phaseL2Usage;
      case ExperienceRuntimePhase.conceptUnit:
        final unit = currentVm.currentUnit;
        if (unit != null && unit.role == UnitRole.transfer) {
          return l10n.phaseTransfer;
        }
        return l10n.phaseFormation;
      default:
        return '';
    }
  }

  Widget _buildBody(
    ExperienceRuntimeViewModel currentVm,
    GroupSessionViewModel groupVm,
  ) {
    if (groupVm.knownCheckActive) {
      return _KnownCheckView(
        unit: groupVm.knownCheckUnit,
        onResult: (passed) => groupVm.completeKnownCheck(passed: passed),
      );
    }
    switch (currentVm.phase) {
      case ExperienceRuntimePhase.loading:
      case ExperienceRuntimePhase.loadError:
        return const SizedBox.shrink();
      case ExperienceRuntimePhase.conceptUnit:
        final unit = currentVm.currentUnit;
        if (unit == null) return const SizedBox.shrink();
        return ConceptUnitView(
          unit: unit,
          selectedAnswerId: _selectedAnswerId(currentVm),
          onAnswerSelected: currentVm.answer,
        );
      case ExperienceRuntimePhase.symbolBinding:
        final program = currentVm.program!;
        return SymbolBindingView(
          reveal: program.symbolBinding.reveal,
          minimalL1Gloss: program.symbolBinding.minimalL1Gloss,
          onPronounce: _pronounce(program.symbolBinding.reveal.l2Word),
        );
      case ExperienceRuntimePhase.grounding:
        final program = currentVm.program!;
        final source =
            program.units
                .where((u) => u.id == program.grounding.sourceExperienceId)
                .firstOrNull ??
            program.units.firstOrNull;
        if (source == null) return const SizedBox.shrink();
        return GroundingView(
          grounding: program.grounding,
          sourceUnit: source,
        );
      case ExperienceRuntimePhase.complete:
        return const SizedBox.shrink();
    }
  }

  static String? _selectedAnswerId(ExperienceRuntimeViewModel viewModel) {
    final unit = viewModel.currentUnit;
    if (unit == null) return null;
    return viewModel.recordFor(unit.id)?.answer.id;
  }

  Widget _buildFooter(
    GroupSessionViewModel groupVm,
    ExperienceRuntimeViewModel currentVm,
  ) {
    if (groupVm.knownCheckActive) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final isLastSense = groupVm.senseIndex == groupVm.senseCount - 1;
    String label;
    VoidCallback? action;
    if (currentVm.phase == ExperienceRuntimePhase.grounding ||
        currentVm.phase == ExperienceRuntimePhase.complete) {
      label = isLastSense ? l10n.learnFinishGroup : l10n.learnNextWord;
      action = () {
        groupVm.proceed();
        if (groupVm.finished) _finishGroup();
      };
    } else {
      label = currentVm.canProceed ? l10n.learnContinue : l10n.learnAnswerFirst;
      action = currentVm.canProceed ? currentVm.proceed : null;
    }
    return _BottomAction(
      label: label,
      accent:
          currentVm.phase == ExperienceRuntimePhase.symbolBinding ||
              currentVm.phase == ExperienceRuntimePhase.grounding
          ? kColorTealSignal
          : kColorEmber,
      onTap: action,
    );
  }

  /// TTS from symbol binding onward only (policy: pronunciation never before
  /// the reveal; the accent follows the learning preference).
  Future<void> Function()? _pronounce(String word) {
    return () async {
      final tts = ref.read(ttsServiceProvider);
      final accent = ref.read(preferencesProvider).accent;
      final tag = accent == Accent.us ? 'en-US' : 'en-GB';
      await tts.speak(word, fallbackLanguageTag: tag);
    };
  }

  void _showMoreMenu() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.learnWriteNote),
              onTap: () {
                Navigator.pop(context);
                _writeNote();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.learnPreferences),
              onTap: () {
                Navigator.pop(context);
                context.push('/preferences');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnHeader extends StatelessWidget {
  const _LearnHeader({
    required this.senseLabel,
    required this.canUndo,
    required this.onExit,
    required this.onUndo,
    required this.onFavorite,
    required this.onKnownCheck,
    required this.onMore,
  });

  final String senseLabel;
  final bool canUndo;
  final VoidCallback onExit;
  final VoidCallback? onUndo;
  final VoidCallback onFavorite;
  final VoidCallback? onKnownCheck;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.learnQuit,
            icon: const Icon(Icons.arrow_back),
            onPressed: onExit,
          ),
          Expanded(
            child: Text(
              senseLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A4A54),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.learnRetreat,
            icon: const Icon(Icons.undo_outlined),
            onPressed: onUndo,
          ),
          IconButton(
            tooltip: l10n.learnFavorite,
            icon: const Icon(Icons.favorite_border),
            onPressed: onFavorite,
          ),
          if (onKnownCheck != null)
            IconButton(
              tooltip: l10n.learnKnown,
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: onKnownCheck,
            ),
          IconButton(
            tooltip: l10n.learnMore,
            icon: const Icon(Icons.more_horiz),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.segments, required this.progress});

  final int segments;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: List.generate(segments, (i) {
          final on = i < progress;
          final half = i == progress && progress > 0;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              height: 3.5,
              decoration: BoxDecoration(
                color: on || half
                    ? kColorDusk
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.modePill,
    required this.isL2,
  });

  final String label;
  final String modePill;
  final bool isL2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFF6D6D78),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isL2 ? kColorDusk : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              modePill,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isL2 ? Colors.white : const Color(0xFF5C5C68),
              ),
            ),
          ),
        ],
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
      width: double.infinity,
      child: Column(
        children: [
          Opacity(
            opacity: disabled ? 0.35 : 1,
            child: TextButton(
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

class _KnownCheckView extends StatelessWidget {
  const _KnownCheckView({required this.unit, required this.onResult});

  final ExperienceUnit? unit;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (unit == null) {
      return Center(child: Text(l10n.knownCheckUnavailable));
    }
    return _KnownCheckBody(unit: unit!, onResult: onResult);
  }
}

class _KnownCheckBody extends StatefulWidget {
  const _KnownCheckBody({required this.unit, required this.onResult});

  final ExperienceUnit unit;
  final ValueChanged<bool> onResult;

  @override
  State<_KnownCheckBody> createState() => _KnownCheckBodyState();
}

class _KnownCheckBodyState extends State<_KnownCheckBody> {
  Answer? _picked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = widget.unit;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Kicker(text: l10n.knownCheckTitle),
          _SceneCard(text: unit.experience.episode),
          const SizedBox(height: 22),
          Text(
            unit.interaction.question,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final answer in unit.interaction.answers)
            _Choice(
              text: answer.text,
              state: _picked == null
                  ? _ChoiceState.idle
                  : answer.isCorrect
                  ? _ChoiceState.correct
                  : _picked!.id == answer.id
                  ? _ChoiceState.wrong
                  : _ChoiceState.muted,
              onTap: _picked == null
                  ? () => setState(() => _picked = answer)
                  : null,
            ),
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _picked!.isCorrect
                    ? l10n.knownCheckPassHint
                    : l10n.knownCheckFailHint,
                style: TextStyle(
                  fontSize: 15,
                  color: _picked!.isCorrect ? kSignalSuccess : kSignalError,
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_picked != null)
            Center(
              child: _BottomAction(
                label: _picked!.isCorrect
                    ? l10n.knownCheckSkip
                    : l10n.knownCheckAnchor,
                accent: kColorEmber,
                onTap: () => widget.onResult(_picked!.isCorrect),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small components (also reused by review/other pages)
// ---------------------------------------------------------------------------

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
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF7B7B86)),
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

enum _ChoiceState { idle, correct, wrong, muted }

class _Choice extends StatelessWidget {
  const _Choice({required this.text, required this.state, required this.onTap});

  final String text;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = switch (state) {
      _ChoiceState.correct => kSignalSuccessBg,
      _ChoiceState.wrong => kSignalErrorBg,
      _ => Colors.white.withValues(alpha: 0.52),
    };
    final border = switch (state) {
      _ChoiceState.correct => kSignalCorrectBorder,
      _ChoiceState.wrong => kSignalWrongBorder,
      _ => Colors.transparent,
    };
    final foreground = switch (state) {
      _ChoiceState.correct => kSignalSuccess,
      _ChoiceState.wrong => kSignalError,
      _ => const Color(0xFF26262C),
    };
    return Opacity(
      opacity: state == _ChoiceState.muted ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusMd),
            side: BorderSide(color: border, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(kRadiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: foreground,
                  fontWeight:
                      state == _ChoiceState.correct ||
                          state == _ChoiceState.wrong
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 48,
                color: kSignalSuccess,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.learnEmptyTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.learnEmptyBody,
                style: const TextStyle(color: Color(0xFF6E6E79)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: Text(l10n.learnBackHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
