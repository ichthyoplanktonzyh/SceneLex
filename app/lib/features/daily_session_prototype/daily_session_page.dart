/// Unified Daily Session page: every task of the active session runs inside
/// one continuous shell — Recall / Discover / Boundary / Transfer switch
/// without ever returning to Home. Progress (block, task, overall) is shown
/// at all times, and exiting is always safe (the store keeps the session).
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../../domain/experience_program/experience_unit.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import '../experience_runtime/experience_runtime_view_model.dart';
import '../experience_runtime/views/concept_unit_view.dart';
import '../experience_runtime/views/grounding_view.dart';
import '../experience_runtime/views/symbol_binding_view.dart';
import 'daily_session_models.dart';
import 'daily_session_store.dart';
import 'daily_session_view_model.dart';
import 'session_complete_page.dart';
import 'views/session_boundary_view.dart';
import 'views/session_recall_view.dart';
import 'views/session_shell.dart';
import 'views/session_transfer_view.dart';

class DailySessionPage extends StatefulWidget {
  const DailySessionPage({
    super.key,
    required this.viewModel,
    required this.store,
    required this.repository,
  });

  final DailySessionViewModel viewModel;
  final DailySessionStore store;
  final ExperienceProgramRepository repository;

  @override
  State<DailySessionPage> createState() => _DailySessionPageState();
}

class _DailySessionPageState extends State<DailySessionPage> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onVmChange);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onVmChange);
    super.dispose();
  }

  void _onVmChange() {
    if (!mounted) return;
    setState(() {});
    if (widget.viewModel.isComplete) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SessionCompletePage(
            store: widget.store,
            repository: widget.repository,
          ),
        ),
      );
    }
  }

  /// Safe exit: the store keeps the plan, the task index and the results;
  /// an interrupted discover is snapshotted so it resumes at the same
  /// question. The home CTA becomes "Continue this session".
  void _quit() {
    widget.viewModel.saveCurrentDiscoverSnapshot();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    if (vm.phase == DailySessionPhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final store = widget.store;
    final plan = store.activePlan;
    final task = store.currentTask;
    // Transient frame between the last task and the completion navigation:
    // the session is over, currentTask is already null.
    if (plan == null || task == null || vm.isComplete) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final blockProgress = _blockProgress(plan, store.currentTaskIndex);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7E8CA),
        body: SafeArea(
          child: Column(
            children: [
              SessionHeader(
                title: l10n.sessionHomeTitle,
                current: store.currentTaskIndex + 1,
                total: plan.tasks.length,
                onBack: _quit,
              ),
              SessionBlockKicker(
                label: _blockLabel(l10n, task.block),
                progressText: blockProgress,
              ),
              Expanded(child: _buildBody(vm)),
              const SessionSafeExitNote(),
              _buildFooter(vm),
            ],
          ),
        ),
      ),
    );
  }

  String _blockLabel(AppLocalizations l10n, DailySessionBlock block) =>
      switch (block) {
        DailySessionBlock.warmup => l10n.sessionBlockWarmup,
        DailySessionBlock.core => l10n.sessionBlockCore,
        DailySessionBlock.boundary => l10n.sessionBlockBoundary,
        DailySessionBlock.transfer => l10n.sessionBlockTransfer,
        DailySessionBlock.completion => l10n.sessionBlockCompletion,
      };

  /// "1/2" style position of the current task inside its block.
  String _blockProgress(DailySessionPlan plan, int taskIndex) {
    final block = plan.tasks[taskIndex].block;
    final firstInBlock = plan.tasks
        .indexWhere((t) => t.block == block)
        .clamp(0, taskIndex);
    final totalInBlock = plan.tasks.where((t) => t.block == block).length;
    final within = taskIndex - firstInBlock + 1;
    return '$within/$totalInBlock';
  }

  Widget _buildBody(DailySessionViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final task = vm.currentTask;
    if (vm.currentTaskHasError) {
      return SessionTaskUnavailable(message: l10n.sessionTaskUnavailable);
    }
    switch (task.type) {
      case DailySessionTaskType.recall:
        final episode = vm.recallItem?.experience;
        final reveal = vm.recallReveal;
        if (episode == null || reveal == null) {
          return SessionTaskUnavailable(message: l10n.sessionTaskUnavailable);
        }
        return SessionRecallView(
          episode: Experience.fromJson(episode).episode,
          revealed: vm.recallRevealed,
          reveal: reveal,
          minimalGloss: vm.recallMinimalGloss,
          onReveal: vm.proceedTask,
          onGrade: vm.gradeRecall,
        );
      case DailySessionTaskType.discover:
        return _buildDiscoverBody(vm);
      case DailySessionTaskType.boundary:
        final scene = vm.boundarySceneEpisode;
        if (scene == null) {
          return SessionTaskUnavailable(message: l10n.sessionTaskUnavailable);
        }
        return SessionBoundaryView(
          sceneEpisode: scene,
          options: vm.boundaryOptions,
          revealed: vm.boundaryRevealed,
          choiceSenseId: vm.boundaryChoiceId,
          correctSenseId: task.primarySenseId,
          onChoose: vm.chooseBoundary,
        );
      case DailySessionTaskType.transfer:
        final unit = vm.transferUnit;
        if (unit == null) {
          return SessionTaskUnavailable(message: l10n.sessionTaskUnavailable);
        }
        return SessionTransferView(
          unit: unit,
          revealed: vm.transferRevealed,
          choiceAnswerId: vm.transferChoiceId,
          onChoose: vm.chooseTransfer,
        );
    }
  }

  Widget _buildDiscoverBody(DailySessionViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final discover = vm.discoverVm;
    if (discover == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (discover.phase) {
      case ExperienceRuntimePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case ExperienceRuntimePhase.loadError:
        return SessionTaskUnavailable(
          message: discover.errorMessage ?? l10n.sessionTaskUnavailable,
        );
      case ExperienceRuntimePhase.conceptUnit:
        final unit = discover.currentUnit;
        if (unit == null) return const SizedBox.shrink();
        return ConceptUnitView(
          unit: unit,
          selectedAnswerId: _selectedAnswerId(discover),
          onAnswerSelected: discover.answer,
        );
      case ExperienceRuntimePhase.symbolBinding:
        final program = discover.program!;
        return SymbolBindingView(
          reveal: program.symbolBinding.reveal,
          minimalL1Gloss: program.symbolBinding.minimalL1Gloss,
        );
      case ExperienceRuntimePhase.grounding:
        final program = discover.program!;
        final source =
            program.units
                .where((u) => u.id == program.grounding.sourceExperienceId)
                .firstOrNull ??
            program.units.firstOrNull;
        if (source == null) return const SizedBox.shrink();
        return GroundingView(grounding: program.grounding, sourceUnit: source);
      case ExperienceRuntimePhase.complete:
        return _TaskCompleteNote(label: l10n.sessionTaskDiscover);
    }
  }

  static String? _selectedAnswerId(ExperienceRuntimeViewModel discover) {
    final unit = discover.currentUnit;
    if (unit == null) return null;
    return discover.recordFor(unit.id)?.answer.id;
  }

  Widget _buildFooter(DailySessionViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final task = vm.currentTask;
    if (vm.currentTaskHasError) {
      return SessionFooterButton(
        label: l10n.sessionSkipTask,
        accent: kColorEmber,
        onTap: vm.proceedTask,
      );
    }
    switch (task.type) {
      case DailySessionTaskType.recall:
        return const SizedBox.shrink();
      case DailySessionTaskType.discover:
        final discover = vm.discoverVm;
        if (discover == null) return const SizedBox.shrink();
        if (discover.phase == ExperienceRuntimePhase.complete ||
            discover.phase == ExperienceRuntimePhase.loadError) {
          return SessionFooterButton(
            label: vm.isLastTask
                ? l10n.sessionFinishSession
                : l10n.sessionNextTask,
            accent: kColorTealSignal,
            onTap: vm.proceedTask,
          );
        }
        return SessionFooterButton(
          label: l10n.sessionContinue,
          accent: kColorEmber,
          onTap: discover.canProceed ? vm.proceedTask : null,
        );
      case DailySessionTaskType.boundary:
      case DailySessionTaskType.transfer:
        final revealed = task.type == DailySessionTaskType.boundary
            ? vm.boundaryRevealed
            : vm.transferRevealed;
        return SessionFooterButton(
          label: revealed
              ? (vm.isLastTask
                    ? l10n.sessionFinishSession
                    : l10n.sessionNextTask)
              : l10n.sessionContinue,
          accent: kColorTealSignal,
          onTap: revealed ? vm.proceedTask : null,
        );
    }
  }
}

class _TaskCompleteNote extends StatelessWidget {
  const _TaskCompleteNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 44, color: kSignalSuccess),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kColorInk,
            ),
          ),
        ],
      ),
    );
  }
}
