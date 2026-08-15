/// Journey session page widget tests: the learner-facing no-leak rule.
///
/// The journey shell must never expose the target lemma before its symbol
/// binding — the same rule the experience runtime enforces, now under the
/// unified journey chrome.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/features/experience_runtime/experience_runtime_view_model.dart';
import 'package:scenelex/features/journey_prototype/journey_home_page.dart';
import 'package:scenelex/features/journey_prototype/journey_preview_store.dart';
import 'package:scenelex/features/journey_prototype/journey_session_page.dart';
import 'package:scenelex/features/journey_prototype/journey_session_view_model.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_plan.dart';
import 'package:scenelex/features/journey_prototype/prototype_journey_planner.dart';
import 'package:scenelex/features/journey_prototype/prototype_learner_state.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';

String? _bundleText;

String allVisibleText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' ');
  final semantics = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .join(' ');
  return '$texts $semantics'.toLowerCase();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  testWidgets('new concept: target lemma is invisible until symbol binding',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = await BundledContentCatalogRepository(
      bundleLoader: () async => _bundleText!,
    ).load();
    final repository = BundledExperienceProgramRepository(
      bundleLoader: () async => _bundleText!,
    );
    final store = JourneyPreviewStore.standard(catalog: catalog);
    final learner = PrototypeLearnerState.resolve(
      catalog: catalog,
      byLemma: PrototypeLearnerState.defaultByLemma,
    );
    final plan = const PrototypeJourneyPlanner().plan(
      catalog: catalog,
      learnerState: learner,
    );
    expect(plan.tasks.length, 5);

    final vm = JourneySessionViewModel(
      plan: plan,
      catalog: catalog,
      repository: repository,
      onComplete: (_) {},
    );
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JourneySessionPage(
          viewModel: vm,
          store: store,
          repository: repository,
        ),
      ),
    );
    await tester.pump();

    // Task 1: recall — the reveal happens only after the learner asks.
    final revealButton = find.text('Reveal');
    expect(revealButton, findsOneWidget);
    expect(allVisibleText(tester), isNot(contains('reluctant')));
    await tester.tap(revealButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(allVisibleText(tester), contains('reluctant'));
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 400));

    // Task 2: discover messy — through every concept unit the word "messy"
    // must stay out of the learner-facing UI.
    expect(vm.currentTask.type, JourneyTaskType.newConcept);
    expect(vm.currentTask.primarySenseId, 'messy-01');
    expect(allVisibleText(tester), isNot(contains('messy')));

    var guarded = 0;
    while (guarded < 12) {
      guarded += 1;
      final discover = vm.discoverVm!;
      if (discover.phase == ExperienceRuntimePhase.symbolBinding) break;
      if (discover.phase == ExperienceRuntimePhase.conceptUnit &&
          !discover.isCurrentUnitAnswered) {
        final unit = discover.currentUnit!;
        final correctId = unit.interaction.correctAnswer.id;
        await tester.ensureVisible(find.byKey(ValueKey('answer-$correctId')));
        await tester.tap(find.byKey(ValueKey('answer-$correctId')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(allVisibleText(tester), isNot(contains('messy')),
          reason: 'leak before binding at phase ${discover.phase}');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(guarded, lessThan(12));

    // Symbol binding: the word finally appears.
    expect(vm.discoverVm!.phase, ExperienceRuntimePhase.symbolBinding);
    expect(allVisibleText(tester), contains('messy'));
  });

  testWidgets('journey home renders the journey as the only strong CTA',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = await BundledContentCatalogRepository(
      bundleLoader: () async => _bundleText!,
    ).load();
    final store = JourneyPreviewStore.standard(catalog: catalog);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JourneyHomePage(
          store: store,
          repository: BundledExperienceProgramRepository(
            bundleLoader: () async => _bundleText!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The primary CTA and the two quiet secondary actions are present.
    expect(find.text('Today\'s Journey'), findsOneWidget);
    expect(find.text('Continue Journey'), findsOneWidget);
    expect(find.text('Semantic Map'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    // No Learn / Review tool entries on the journey home.
    expect(find.text('Learn'), findsNothing);
    expect(find.text('Review'), findsNothing);

    // Completing the journey marks today done.
    store.completeJourney(
      JourneyCompletion(results: const [], completedAt: DateTime(2026)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Journey complete'), findsOneWidget);
  });
}
