/// Daily Session widget tests: home summary, mode adjustment, session
/// entry / exit / resume, result-based completion and empty states.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenelex/data/content/content_catalog_repository.dart';
import 'package:scenelex/data/content/experience_program_repository.dart';
import 'package:scenelex/domain/content_catalog/word_sense_catalog.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_home_page.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_models.dart';
import 'package:scenelex/features/daily_session_prototype/daily_session_store.dart';
import 'package:scenelex/features/daily_session_prototype/session_learner_state.dart';
import 'package:scenelex/l10n/gen/app_localizations.dart';

String? _bundleText;

Future<WordSenseCatalog> loadCatalog() async {
  return BundledContentCatalogRepository(
    bundleLoader: () async => _bundleText!,
  ).load();
}

BundledExperienceProgramRepository buildRepository() =>
    BundledExperienceProgramRepository(bundleLoader: () async => _bundleText!);

Future<DailySessionStore> pumpHome(
  WidgetTester tester, {
  Map<String, SessionSenseStatus> byLemma = const {
    'reluctant': SessionSenseStatus.learning,
    'dirty': SessionSenseStatus.mastered,
    'messy': SessionSenseStatus.unseen,
    'almost': SessionSenseStatus.unseen,
  },
  DailySessionMode mode = DailySessionMode.standard,
}) async {
  final catalog = await loadCatalog();
  final store = DailySessionStore.standard(
    catalog: catalog,
    repository: buildRepository(),
    byLemma: byLemma,
    mode: mode,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DailySessionHomePage(store: store, repository: buildRepository()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return store;
}

/// Pumps fake time until [finder] matches (or [maxPumps] frames elapsed).
/// Used because the session VM loads the real program asynchronously after
/// the route push.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 30,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('never found $finder on screen');
}

/// Reveals the recall task and grades it, then pumps.
Future<void> finishRecall(WidgetTester tester, int grade) async {
  await tester.tap(find.text('Reveal'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(
    find.text(grade == 0 ? 'Forgot' : (grade == 1 ? 'Hard' : 'Got it')),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Drives the current discover task to completion through the real UI.
/// Correct answers are derived from the real program (same source the
/// ConceptUnitView renders from).
Future<void> completeDiscover(
  WidgetTester tester,
  DailySessionStore store,
) async {
  final task = store.currentTask;
  if (task == null) return;
  final program = await store.repository.load(task.primarySenseId);
  final correctIds = program.units
      .map((u) => u.interaction.correctAnswer.id)
      .toList();
  var unitIndex = 0;
  for (var guard = 0; guard < 40; guard++) {
    // Discover finished → the shell shows "Next task".
    if (find.text('Next task').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next task'));
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    final continueFinder = find.ancestor(
      of: find.text('Continue'),
      matching: find.byType(TextButton),
    );
    final continueEnabled =
        continueFinder.evaluate().isNotEmpty &&
        tester.widget<TextButton>(continueFinder).onPressed != null;
    // The current unit is unanswered while Continue is gated; answer it.
    if (!continueEnabled && unitIndex < correctIds.length) {
      final answer = find.byKey(ValueKey('answer-${correctIds[unitIndex]}'));
      if (answer.evaluate().isNotEmpty) {
        await tester.ensureVisible(answer);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(answer);
        unitIndex += 1;
        await tester.pump(const Duration(milliseconds: 300));
        continue;
      }
    }
    // Otherwise advance through binding / grounding / next unit.
    if (continueEnabled) {
      await tester.ensureVisible(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      continue;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('discover did not finish');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _bundleText = await rootBundle.loadString(
      'assets/content/experience-programs.v1.json',
    );
  });

  testWidgets('home shows estimated time and task composition', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);

    expect(find.text("Today's Study"), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    expect(find.text('1 recall · 1 new sense · 1 boundary'), findsOneWidget);
    expect(find.text('Start Learning'), findsOneWidget);
    expect(find.text('Semantic Map'), findsOneWidget);
    expect(find.text('Explore freely'), findsOneWidget);
  });

  testWidgets('adjusting the mode changes the home summary', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await pumpHome(tester);

    await tester.tap(find.text('Adjust this session'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Review only'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.mode, DailySessionMode.reviewOnly);
    // Summary now reflects the review-only plan.
    expect(find.text('1 recall'), findsOneWidget);
    expect(find.text('1 recall · 1 new sense · 1 boundary'), findsNothing);
    expect(find.text('1 min'), findsOneWidget);
  });

  testWidgets('primary CTA enters the session', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);
    await tester.tap(find.text('Start Learning'));
    await pumpUntilFound(tester, find.text('Quick wake-up'));

    // The session shell: block label, overall progress, safe-exit note.
    expect(find.text('Quick wake-up'), findsOneWidget);
    expect(find.text('Task 1 of 3'), findsOneWidget);
    expect(
      find.text('You can safely exit — this session resumes from here.'),
      findsOneWidget,
    );
  });

  testWidgets('exiting mid-session shows the resume CTA on home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);
    await tester.tap(find.text('Start Learning'));
    await pumpUntilFound(tester, find.text('Quick wake-up'));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilFound(tester, find.text('Continue this session'));

    expect(find.text('Continue this session'), findsOneWidget);
    expect(find.text('Start Learning'), findsNothing);
  });

  testWidgets('re-entering resumes at the same task', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);
    await tester.tap(find.text('Start Learning'));
    await pumpUntilFound(tester, find.text('Quick wake-up'));

    // Finish the recall task (task 1 of 3).
    await finishRecall(tester, 2); // Got it
    expect(find.text('Core sense'), findsOneWidget);

    // Quit mid-session and re-enter.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpUntilFound(tester, find.text('Continue this session'));
    expect(find.text('Continue this session'), findsOneWidget);

    await tester.tap(find.text('Continue this session'));
    await pumpUntilFound(tester, find.text('Core sense'));
    // Still on task 2 (the discover), not back at task 1.
    expect(find.text('Core sense'), findsOneWidget);
    expect(find.text('Task 2 of 3'), findsOneWidget);
    expect(find.text('Reveal'), findsNothing);
  });

  testWidgets('completion page reports the real session results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await pumpHome(tester);
    await tester.tap(find.text('Start Learning'));
    await pumpUntilFound(tester, find.text('Quick wake-up'));

    // Recall → discover → boundary.
    await finishRecall(tester, 2); // Got it
    expect(find.text('Core sense'), findsOneWidget);
    await completeDiscover(tester, store);
    await pumpUntilFound(tester, find.text('Boundary check'));

    // Choose the just-discovered sense (messy) in the boundary.
    await tester.tap(find.byKey(const ValueKey('boundary-messy-01')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Finish session'));
    await pumpUntilFound(tester, find.text('Session complete'));

    // The completion ledger is built from real results.
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Woke up reluctant'), findsOneWidget);
    expect(find.text('Established messy'), findsOneWidget);
    expect(find.text('Distinguished messy / dirty'), findsOneWidget);
    expect(
      find.text(
        'Prototype summary — no long-term memory score is computed or stored.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty plan shows a clear page instead of a broken session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(
      tester,
      byLemma: {
        'reluctant': SessionSenseStatus.mastered,
        'dirty': SessionSenseStatus.mastered,
        'messy': SessionSenseStatus.mastered,
        'almost': SessionSenseStatus.mastered,
      },
      mode: DailySessionMode.reviewOnly,
    );

    // No task summary; CTA still present.
    expect(find.text('Start Learning'), findsOneWidget);
    await tester.tap(find.text('Start Learning'));
    await pumpUntilFound(tester, find.text('Nothing to do today'));

    // A dedicated empty page with an explanation, never a spinner crash.
    expect(find.text('Nothing to do today'), findsOneWidget);
    expect(find.textContaining('No senses are due today'), findsOneWidget);
    expect(find.text('Back Home'), findsOneWidget);
  });
}
