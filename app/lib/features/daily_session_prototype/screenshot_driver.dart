/// Screenshot driver — prototype-only helper that renders fixed page states
/// for the `?shot=<name>` URL parameter (used with a headless browser at
/// 1200×870; see docs/prototypes/daily-session/README.md).
///
/// Each shot builds the exact store / view-model state the screenshot
/// documents. The driver never runs in production: it is only reachable
/// through the SESSION_PREVIEW preview entry.
library;

import 'package:flutter/material.dart';

import '../../data/content/experience_program_repository.dart';
import '../experience_runtime/experience_runtime_view_model.dart';
import 'daily_session_home_page.dart';
import 'daily_session_models.dart';
import 'daily_session_page.dart';
import 'daily_session_store.dart';
import 'daily_session_view_model.dart';
import 'session_complete_page.dart';
import 'session_mode_sheet.dart';

class ScreenshotDriver extends StatelessWidget {
  const ScreenshotDriver({
    super.key,
    required this.store,
    required this.repository,
    required this.shot,
  });

  final DailySessionStore store;
  final ExperienceProgramRepository repository;
  final String shot;

  @override
  Widget build(BuildContext context) {
    switch (shot) {
      case 'home':
        return DailySessionHomePage(store: store, repository: repository);
      case 'mode':
        return _AutoModeSheet(store: store, repository: repository);
      case 'continue':
        store.startSession();
        return DailySessionHomePage(store: store, repository: repository);
      case 'recall':
      case 'discover':
      case 'boundary':
      case 'transfer':
      case 'completion':
        return _SessionShot(store: store, repository: repository, shot: shot);
    }
    return DailySessionHomePage(store: store, repository: repository);
  }
}

/// Opens the mode sheet right after the first frame.
class _AutoModeSheet extends StatefulWidget {
  const _AutoModeSheet({required this.store, required this.repository});

  final DailySessionStore store;
  final ExperienceProgramRepository repository;

  @override
  State<_AutoModeSheet> createState() => _AutoModeSheetState();
}

class _AutoModeSheetState extends State<_AutoModeSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSessionModeSheet(context, widget.store);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DailySessionHomePage(
      store: widget.store,
      repository: widget.repository,
    );
  }
}

/// Runs a session forward to the requested state, then renders the page.
class _SessionShot extends StatefulWidget {
  const _SessionShot({
    required this.store,
    required this.repository,
    required this.shot,
  });

  final DailySessionStore store;
  final ExperienceProgramRepository repository;
  final String shot;

  @override
  State<_SessionShot> createState() => _SessionShotState();
}

class _SessionShotState extends State<_SessionShot> {
  late final Future<Widget> _future;

  @override
  void initState() {
    super.initState();
    _future = _prepare();
  }

  Future<Widget> _prepare() async {
    final store = widget.store;
    final repository = widget.repository;
    if (!store.startSession()) {
      return DailySessionHomePage(store: store, repository: repository);
    }
    final vm = DailySessionViewModel(
      store: store,
      catalog: store.catalog,
      repository: repository,
    );
    await vm.load();

    switch (widget.shot) {
      case 'recall':
        return DailySessionPage(
          viewModel: vm,
          store: store,
          repository: repository,
        );
      case 'discover':
        vm.proceedTask(); // reveal the recalled sense
        vm.gradeRecall(DailySessionRecallGrade.gotIt);
        return DailySessionPage(
          viewModel: vm,
          store: store,
          repository: repository,
        );
      case 'transfer':
        // Forgot → the planner inserts a remedial transfer for this sense.
        vm.proceedTask();
        vm.gradeRecall(DailySessionRecallGrade.forgot);
        return DailySessionPage(
          viewModel: vm,
          store: store,
          repository: repository,
        );
      case 'boundary':
        vm.proceedTask();
        vm.gradeRecall(DailySessionRecallGrade.gotIt);
        await _completeCurrentDiscover(vm);
        return DailySessionPage(
          viewModel: vm,
          store: store,
          repository: repository,
        );
      case 'completion':
        vm.proceedTask();
        vm.gradeRecall(DailySessionRecallGrade.gotIt);
        await _completeCurrentDiscover(vm);
        vm.chooseBoundary(vm.currentTask.primarySenseId);
        vm.proceedTask();
        return SessionCompletePage(store: store, repository: repository);
    }
    return DailySessionHomePage(store: store, repository: repository);
  }

  Future<void> _completeCurrentDiscover(DailySessionViewModel vm) async {
    for (var guard = 0; guard < 60; guard++) {
      final discover = vm.discoverVm;
      if (discover == null) return;
      if (discover.phase == ExperienceRuntimePhase.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        continue;
      }
      if (discover.phase == ExperienceRuntimePhase.loadError) {
        vm.proceedTask();
        return;
      }
      if (discover.phase == ExperienceRuntimePhase.complete) {
        vm.proceedTask();
        return;
      }
      if (discover.phase == ExperienceRuntimePhase.conceptUnit &&
          !discover.isCurrentUnitAnswered) {
        final unit = discover.currentUnit;
        if (unit != null) {
          discover.answer(unit.interaction.correctAnswer.id);
        }
      }
      vm.proceedTask();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }
}
