/// Unified journey session page: every task of today's journey runs inside
/// one continuous shell — Recall / Discover / Boundary / Transfer switch
/// without ever returning to Home.
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
import 'journey_complete_page.dart';
import 'journey_preview_store.dart';
import 'journey_session_view_model.dart';
import 'prototype_journey_plan.dart';
import 'views/boundary_task_view.dart';
import 'views/journey_shell.dart';
import 'views/recall_task_view.dart';
import 'views/transfer_task_view.dart';

class JourneySessionPage extends StatefulWidget {
  const JourneySessionPage({
    super.key,
    required this.viewModel,
    required this.store,
    required this.repository,
  });

  final JourneySessionViewModel viewModel;
  final JourneyPreviewStore store;
  final ExperienceProgramRepository repository;

  @override
  State<JourneySessionPage> createState() => _JourneySessionPageState();
}

class _JourneySessionPageState extends State<JourneySessionPage> {
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
          builder: (_) => JourneyCompletePage(
            store: widget.store,
            repository: widget.repository,
          ),
        ),
      );
    }
  }

  void _quit() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    if (vm.phase == JourneySessionPhase.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = vm.currentTask;
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
              JourneyHeader(
                title: l10n.journeySessionTitle,
                current: vm.taskIndex + 1,
                total: vm.taskCount,
                onBack: _quit,
              ),
              JourneyTaskKicker(label: _taskKicker(l10n, task.type)),
              Expanded(child: _buildBody()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  String _taskKicker(AppLocalizations l10n, JourneyTaskType type) =>
      switch (type) {
        JourneyTaskType.recall => l10n.journeyTaskRecall,
        JourneyTaskType.newConcept => l10n.journeyTaskDiscover,
        JourneyTaskType.discrimination => l10n.journeyTaskBoundary,
        JourneyTaskType.transfer => l10n.journeyTaskTransfer,
      };

  Widget _buildBody() {
    final vm = widget.viewModel;
    final task = vm.currentTask;
    if (vm.currentTaskHasError) {
      return _TaskUnavailable(
        message: AppLocalizations.of(context).journeyTaskUnavailable,
      );
    }
    switch (task.type) {
      case JourneyTaskType.recall:
        final episode = vm.recallItem?.experience;
        final reveal = vm.recallReveal;
        if (episode == null || reveal == null) {
          return _TaskUnavailable(
            message: AppLocalizations.of(context).journeyTaskUnavailable,
          );
        }
        return RecallTaskView(
          episode: Experience.fromJson(episode).episode,
          revealed: vm.recallRevealed,
          reveal: reveal,
          minimalGloss: vm.recallMinimalGloss,
          onReveal: vm.proceedTask,
          onGrade: (index) => vm.gradeRecall(
            JourneyRecallGrade.values[index],
          ),
        );
      case JourneyTaskType.newConcept:
        return _buildDiscoverBody(vm);
      case JourneyTaskType.discrimination:
        final scene = vm.boundarySceneEpisode;
        if (scene == null) {
          return _TaskUnavailable(
            message: AppLocalizations.of(context).journeyTaskUnavailable,
          );
        }
        return BoundaryTaskView(
          sceneEpisode: scene,
          options: vm.boundaryOptions,
          revealed: vm.boundaryRevealed,
          choiceSenseId: vm.boundaryChoiceId,
          correctSenseId: task.primarySenseId,
          onChoose: vm.chooseBoundary,
        );
      case JourneyTaskType.transfer:
        final unit = vm.transferUnit;
        if (unit == null) {
          return _TaskUnavailable(
            message: AppLocalizations.of(context).journeyTaskUnavailable,
          );
        }
        return TransferTaskView(
          unit: unit,
          revealed: vm.transferRevealed,
          choiceAnswerId: vm.transferChoiceId,
          onChoose: vm.chooseTransfer,
        );
    }
  }

  Widget _buildDiscoverBody(JourneySessionViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final discover = vm.discoverVm;
    if (discover == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (discover.phase) {
      case ExperienceRuntimePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case ExperienceRuntimePhase.loadError:
        return _TaskUnavailable(message: discover.errorMessage ?? '');
      case ExperienceRuntimePhase.conceptUnit:
        final unit = discover.currentUnit;
        if (unit == null) {
          return const SizedBox.shrink();
        }
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
        return _TaskCompleteNote(label: l10n.journeyTaskDiscover);
    }
  }

  static String? _selectedAnswerId(ExperienceRuntimeViewModel discover) {
    final unit = discover.currentUnit;
    if (unit == null) return null;
    return discover.recordFor(unit.id)?.answer.id;
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context);
    final vm = widget.viewModel;
    final task = vm.currentTask;
    if (task.type == JourneyTaskType.recall && !vm.currentTaskHasError) {
      return const SizedBox.shrink();
    }
    if (vm.currentTaskHasError) {
      return JourneyFooterButton(
        label: l10n.journeySkipTask,
        accent: kColorEmber,
        onTap: vm.proceedTask,
      );
    }
    switch (task.type) {
      case JourneyTaskType.recall:
        return const SizedBox.shrink();
      case JourneyTaskType.newConcept:
        final discover = vm.discoverVm;
        if (discover == null) return const SizedBox.shrink();
        if (discover.phase == ExperienceRuntimePhase.complete ||
            discover.phase == ExperienceRuntimePhase.loadError) {
          return JourneyFooterButton(
            label: vm.isLastTask
                ? l10n.journeyFinishJourney
                : l10n.journeyNextTask,
            accent: kColorTealSignal,
            onTap: vm.proceedTask,
          );
        }
        return JourneyFooterButton(
          label: l10n.journeyContinue,
          accent: kColorEmber,
          onTap: discover.canProceed ? vm.proceedTask : null,
        );
      case JourneyTaskType.discrimination:
      case JourneyTaskType.transfer:
        final revealed = task.type == JourneyTaskType.discrimination
            ? vm.boundaryRevealed
            : vm.transferRevealed;
        return JourneyFooterButton(
          label: revealed
              ? (vm.isLastTask
                    ? l10n.journeyFinishJourney
                    : l10n.journeyNextTask)
              : l10n.journeyContinue,
          accent: kColorTealSignal,
          onTap: revealed ? vm.proceedTask : null,
        );
    }
  }
}

class _TaskUnavailable extends StatelessWidget {
  const _TaskUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF9A9AA4), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6D6D78)),
            ),
          ],
        ),
      ),
    );
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
