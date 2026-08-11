// 实机验证四个手工检查点:真实浏览器(Chrome)+ 真实本地 server。
//
// 每个检查点独立运行(CHECKPOINT=1..4),使用各自全新的浏览器 profile
// 与凭据(bash 预生成 TEST_EMAIL/TEST_CODE 传入 dart-define):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/sync_flow_test.dart -d chrome \
//     --dart-define=CHECKPOINT=n --dart-define=TEST_EMAIL=... --dart-define=TEST_CODE=...
//
// 检查点:
//   1. 断网评分 → 恢复 → 60s 内自动同步(outbox 清空、状态回到 synced)
//   2. 切后台再回前台(resume) → 立即触发同步周期
//   3. 人为构造 rejected → 整轮中止、pull 不执行、状态 offline
//   4. 登出后旧 refreshToken 换 idToken 得 401 REFRESH_TOKEN_FAILED
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:scenelex/api/api_client.dart';
import 'package:scenelex/app/locale_controller.dart';
import 'package:scenelex/auth/auth_controller.dart';
import 'package:scenelex/data/local/database.dart';
import 'package:scenelex/data/providers.dart';
import 'package:scenelex/data/sync/sync_providers.dart';
import 'package:scenelex/main.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _deadBase = 'http://127.0.0.1:9/v1';
const _liveBase = 'http://127.0.0.1:8081/v1';
const _checkpoint = int.fromEnvironment('CHECKPOINT', defaultValue: 1);
const _shot = String.fromEnvironment('SHOT');
const _shotLang = String.fromEnvironment('SHOT_LANG', defaultValue: 'en');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  switch (_checkpoint) {
    case 1:
      testWidgets(
          'checkpoint 1: offline review, auto-sync within 60s of recovery',
          (tester) async {
        final container = await _boot(tester);
        final client = container.read(apiClientProvider);
        await _signIn(tester, container);
        final ws = await container.read(workspaceProvider.future);

        // Add one sense to study (real UI + real sync).
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Study').first);
        await _waitSyncedAndDrained(tester, container, ws);

        // Go offline by pointing the client at an unreachable endpoint.
        debugPrint('== C1: going offline (baseUrl -> $_deadBase) ==');
        client.baseUrl = _deadBase;

        // Review the card for real while offline: the local commit succeeds,
        // the sync cycle that follows must fail into the offline state.
        await tester.tap(find.byType(NavigationDestination).at(0));
        await tester.pump(const Duration(milliseconds: 400));
        await _playAndRate(tester);
        debugPrint('== C1: rated while offline ==');

        await _waitFor(
          tester,
          () =>
              container.read(syncStatusProvider).status ==
              SyncStateStatus.offline,
          timeout: const Duration(seconds: 90),
        );
        debugPrint('== C1: sync status is offline ==');

        // Recover: within 60s the scheduler must push the outbox and return
        // to synced (either via the backoff retry or the 60s tick).
        final t0 = DateTime.now();
        debugPrint('== C1: recovering at ${t0.toIso8601String()} ==');
        client.baseUrl = _liveBase;
        await _waitFor(tester, () {
          final info = container.read(syncStatusProvider);
          return info.status == SyncStateStatus.synced &&
              (info.lastSyncAt?.isAfter(t0) ?? false);
        }, timeout: const Duration(seconds: 90));
        final dt = DateTime.now().difference(t0);
        debugPrint('== C1: back to synced after ${dt.inMilliseconds}ms ==');
        expect(
          dt,
          lessThan(const Duration(seconds: 60)),
          reason: 'auto-sync must happen within 60s of network recovery',
        );

        final pending = await container
            .read(localRepositoryProvider)
            .pendingOperations(ws);
        debugPrint(
            '== C1: pending outbox ops after recovery: ${pending.length} ==');
        expect(pending, isEmpty, reason: 'all queued ops must be pushed');

        // Deliberately not disposing the container: the sync trigger is
        // fire-and-forget, and a cycle finishing after a manual dispose
        // would write to disposed providers (process exit reaps it).
      });
    case 2:
      testWidgets('checkpoint 2: resume triggers an immediate sync',
          (tester) async {
        // Surface the raw exceptions the framework aggregates into the
        // "Multiple exceptions (N)" summary.
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          // ignore: avoid_print
          _report('flutter-error', ok: false, detail: details.toString());
          oldOnError?.call(details);
        };
        try {
        final container = await _boot(tester);
        await _signIn(tester, container);
        final ws = await container.read(workspaceProvider.future);

        // Baseline: one sense added and fully drained before backgrounding.
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Study').first);
        await _waitSyncedAndDrained(tester, container, ws);
        debugPrint('== C2: drained before backgrounding ==');

        // Timeline of sync status changes; assert a cycle fires right after
        // the resume event (the one thing the scheduler must react to
        // instantly, unlike the 60s tick).
        final timeline = <String>[];
        final sub = container.listen<SyncStateInfo>(syncStatusProvider,
            (previous, next) {
          timeline.add('${DateTime.now().toIso8601String()} ${next.status}');
        });

        final t1 = DateTime.now();
        // Follow the legal lifecycle transition chain (AppLifecycleListener
        // asserts adjacent moves): foreground -> inactive -> hidden -> paused.
        void setLifecycle(AppLifecycleState s) {
          // ignore: invalid_use_of_protected_member
          tester.binding.handleAppLifecycleStateChanged(s);
        }

        setLifecycle(AppLifecycleState.inactive);
        setLifecycle(AppLifecycleState.hidden);
        setLifecycle(AppLifecycleState.paused);
        await tester.pump(const Duration(milliseconds: 300));
        debugPrint('== C2: app backgrounded ==');

        // Background -> hidden -> inactive -> resumed.
        setLifecycle(AppLifecycleState.hidden);
        setLifecycle(AppLifecycleState.inactive);
        setLifecycle(AppLifecycleState.resumed);
        await _waitFor(tester, () {
          return timeline.any((line) {
            final t = DateTime.parse(line.split(' ')[0]);
            return t.isAfter(t1) && line.contains('syncing');
          });
        }, timeout: const Duration(seconds: 10));
        debugPrint('== C2: sync cycle observed right after resume ==');
        debugPrint(timeline.join('\n'));
        sub.close();

        // Deliberately not disposing the container: the sync trigger is
        // fire-and-forget, and a cycle finishing after a manual dispose
        // would write to disposed providers (process exit reaps it).
        } finally {
          FlutterError.onError = oldOnError;
        }
      });
    case 3:
      testWidgets(
          'checkpoint 3: rejected op aborts the cycle, no pull, offline',
          (tester) async {
        final container = await _boot(tester);
        await _signIn(tester, container);
        final ws = await container.read(workspaceProvider.future);
        final db = container.read(databaseProvider);

        // Inject a malformed learning_state op (missing LWW metadata): the
        // server must answer "rejected", which aborts the whole cycle before
        // any pull executes.
        const badOp = 'c0ffee00-0000-0000-0000-000000000000';
        await db.into(db.outboxRecords).insert(OutboxRecordsCompanion.insert(
              operationId: badOp,
              workspaceId: ws,
              entityType: 'learning_state',
              entityId: '22222222-2222-2222-2222-222222222222',
              action: 'upsert',
              clientUpdatedAt: DateTime.now().toUtc().toIso8601String(),
              payloadJson: jsonEncode({
                'wordSenseId': '22222222-2222-2222-2222-222222222222',
              }),
              createdAt: DateTime.now().toUtc(),
            ));
        final local = container.read(localRepositoryProvider);
        final cursorBefore =
            (await local.syncState(ws)).lastAppliedHotChangeId;
        debugPrint(
            '== C3: injected malformed op, hot cursor before: $cursorBefore ==');

        container.read(syncTriggerProvider)();
        await _waitFor(
          tester,
          () =>
              container.read(syncStatusProvider).status ==
              SyncStateStatus.offline,
          timeout: const Duration(seconds: 60),
        );
        debugPrint('== C3: sync status is offline (cycle aborted) ==');

        final cursorAfter = (await local.syncState(ws)).lastAppliedHotChangeId;
        debugPrint(
            '== C3: hot cursor after: $cursorAfter (must equal before) ==');
        expect(cursorAfter, cursorBefore,
            reason: 'pull must not run after a rejection');

        final pending = await local.pendingOperations(ws);
        final bad = pending.where((o) => o.operationId == badOp).toList();
        expect(bad, isNotEmpty, reason: 'rejected op must remain in the outbox');
        expect(bad.first.lastError, isNotNull,
            reason: 'op must be marked as failed');

        // Deliberately not disposing the container: the sync trigger is
        // fire-and-forget, and a cycle finishing after a manual dispose
        // would write to disposed providers (process exit reaps it).
      });
    case 4:
      testWidgets('checkpoint 4: signed-out refresh token is rejected with 401',
          (tester) async {
        final container = await _boot(tester);
        final client = container.read(apiClientProvider);
        await _signIn(tester, container);
        final refreshToken = client.refreshToken!;
        expect(refreshToken, isNotEmpty);

        await tester.tap(find.byType(NavigationDestination).at(3));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.scrollUntilVisible(
            find.widgetWithText(ListTile, 'Log out'), 200);
        await tester.tap(find.widgetWithText(ListTile, 'Log out'));
        await _waitFor(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
        await _waitFor(
          tester,
          () => !container.read(authControllerProvider).isSignedIn,
          timeout: const Duration(seconds: 15),
        );
        expect(client.refreshToken, isNull,
            reason: 'local session must be cleared');

        final res = await http.post(
          Uri.parse('$_liveBase/auth/refresh-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
        debugPrint(
            '== C4: refresh with signed-out token -> HTTP ${res.statusCode} ${res.body} ==');
        expect(res.statusCode, 401);
        expect(jsonDecode(res.body)['code'], 'REFRESH_TOKEN_FAILED');

        // Deliberately not disposing the container: the sync trigger is
        // fire-and-forget, and a cycle finishing after a manual dispose
        // would write to disposed providers (process exit reaps it).
      });
    case 5:
      testWidgets('screenshot mode: review card head / cards filter sheet',
          (tester) async {
        final container = await _boot(tester, lang: _shotLang);
        await _signIn(tester, container, zh: _shotLang == 'zh');
        final ws = await container.read(workspaceProvider.future);

        // One studied sense so the card head (tags + reps badge) and the tag
        // filter sheet have real data.
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pump(const Duration(milliseconds: 400));
        await tester
            .tap(find.text(_shotLang == 'zh' ? '学习' : 'Study').first);
        await _waitSyncedAndDrained(tester, container, ws);

        if (_shot == 'cards-filter') {
          await tester.tap(find.byTooltip(
              _shotLang == 'zh' ? '按标签筛选' : 'Filter by tags'));
          await tester.pump(const Duration(milliseconds: 800));
        } else {
          // Review tab: stay on the first unit so the header row with the
          // tag summary and the repetition badge is visible.
          await tester.tap(find.byType(NavigationDestination).at(0));
          await tester.pump(const Duration(milliseconds: 600));
          await _waitFor(
              tester, () => find.byType(FilledButton).evaluate().isNotEmpty,
              timeout: const Duration(seconds: 30));
        }
        await _holdForScreenshot(tester, _shot);
      });
    default:
      throw ArgumentError.value(_checkpoint, 'CHECKPOINT', 'must be 1..5');
  }
}

/// Renders the current screen and hands it to the driver for onScreenshot
/// capture (web: rendered frame through the driver channel).
Future<void> _holdForScreenshot(WidgetTester tester, String name) async {
  await _report('SHOT-READY', ok: true, detail: name);
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final bytes = await binding.takeScreenshot(name);
  debugPrint('== screenshot $name: ${bytes.length} bytes ==');
  // Keep the frame on screen briefly so a human can see what was captured.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Boots the real app with a test-owned [ApiClient] (so baseUrl can be
/// toggled to simulate connectivity loss) over the real local storage. The
/// locale is pinned ([lang] = en|zh): the text finders assume that language,
/// while the app defaults to following the system language (and
/// LocaleController's async _restore would race a runtime setLocale call).
Future<ProviderContainer> _boot(WidgetTester tester, {String lang = 'en'}) async {
  final client = ApiClient();
  final container = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(client),
    localeControllerProvider.overrideWith(
      () => _FixedLocaleController(Locale(lang)),
    ),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const SceneLexApp(),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

class _FixedLocaleController extends LocaleController {
  _FixedLocaleController(this.locale);

  final Locale locale;

  @override
  AppLocale build() => AppLocale(locale);
}

/// Real UI sign-in. The harness cannot know the OTP in advance: clicking
/// "Send code" in the UI creates a fresh challenge that invalidates any
/// pre-generated code, so the fresh code is fetched from the code relay
/// (see scripts/code-relay.py) right after the click. [zh] switches the text
/// finders to the Chinese UI.
Future<void> _signIn(WidgetTester tester, ProviderContainer container,
    {bool zh = false}) async {
  final sendCode = zh ? '发送验证码' : 'Send code';
  final signIn = zh ? '登录' : 'Sign in';
  await _waitFor(tester, () => find.text(sendCode).evaluate().isNotEmpty);
  await tester.enterText(find.byType(TextField).first, _testEmail);
  await tester.tap(find.text(sendCode));
  await _report('test-step', ok: true, detail: 'ui send-code tapped');
  await _waitFor(
      tester, () => find.text(signIn).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20));
  await _report('test-step', ok: true, detail: 'ui shows sign-in step');

  final code = await _fetchCode(_testEmail);
  await tester.enterText(find.byType(TextField).last, code);
  await tester.tap(find.text(signIn));
  await _report('test-step', ok: true, detail: 'ui verify tapped with $code');
  await _waitFor(
      tester, () => container.read(authControllerProvider).isSignedIn,
      timeout: const Duration(seconds: 30));

  // Wait for the initial hydration so the Cards tab is populated.
  await _waitHydrated(tester, container);
}

/// Waits until the library holds senses; reports the library error and sync
/// status on timeout.
Future<void> _waitHydrated(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // The engine's own first hydration occasionally does not land in the
  // local cache in this test browser (drift worker warm-up race), so seed
  // the cache through the same real paths — ApiClient + LocalRepository —
  // and then let the library provider re-read it.
  try {
    final client = container.read(apiClientProvider);
    final res = await client.get('/content/senses');
    final list = ((res['senses'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
    await container.read(localRepositoryProvider).cacheSenses(list);
    await _report('seed', ok: list.isNotEmpty, detail: 'cached ${list.length} senses');
  } catch (e) {
    await _report('seed', ok: false, detail: '$e');
  }
  container.invalidate(libraryProvider);
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (true) {
    final lib = container.read(libraryProvider);
    final info = container.read(syncStatusProvider);
    if (lib is AsyncData && (lib.value?.senses.isNotEmpty ?? false)) {
      debugPrint('== hydrated: senses available ==');
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      final err = lib is AsyncError ? '${lib.error}' : 'no error';
      throw TestFailure(
          'hydration timeout; library=$err status=${info.status} '
          'lastSync=${info.lastSyncAt}');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Asks the code relay to send a fresh code for [email] and returns it.
Future<String> _fetchCode(String email) async {
  await _report('test-step', ok: true, detail: 'fetch-code start $email');
  final res = await http
      .get(Uri.parse('http://127.0.0.1:9001/request-code?email=$email'))
      .timeout(const Duration(seconds: 15));
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final code = body['code'] as String?;
  await _report('test-step', ok: true, detail: 'fetch-code got $code');
  if (code == null) {
    throw TestFailure('code relay failed: $body');
  }
  return code;
}

/// Plays one full experience program and rates it Good (real UI).
Future<void> _playAndRate(WidgetTester tester) async {
  // Continue through the units; the last unit shows "Finish the experience".
  for (var i = 0; i < 40; i++) {
    final finish = find.text('Finish the experience');
    if (finish.evaluate().isNotEmpty) {
      await tester.tap(finish);
      break;
    }
    final next = find.text('Continue');
    if (next.evaluate().isEmpty) break;
    await tester.tap(next.first);
    await tester.pump(const Duration(milliseconds: 250));
  }
  await _waitFor(tester, () => find.text('Good').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15));
  await tester.tap(find.text('Good'));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Waits until the outbox is drained AND the sync status is synced; on
/// timeout, reports the pending outbox rows and the sync status.
Future<void> _waitSyncedAndDrained(
  WidgetTester tester,
  ProviderContainer container,
  String ws,
) async {
  final local = container.read(localRepositoryProvider);
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (true) {
    final pending = await local.pendingOperations(ws);
    final info = container.read(syncStatusProvider);
    if (pending.isEmpty && info.status == SyncStateStatus.synced) {
      debugPrint('== drained and synced ==');
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      final rows = pending
          .map((o) =>
              '${o.entityType}/${o.operationId.substring(0, 8)}'
              '${o.lastError != null ? ' err=${o.lastError}' : ''}')
          .join('; ');
      throw TestFailure(
          'not drained/synced within 60s; status=${info.status} '
          'lastSync=${info.lastSyncAt} pending=[$rows]');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Polls [cond] on a real-time cadence until it holds or [timeout] elapses.
Future<void> _waitFor(
  WidgetTester tester,
  FutureOr<bool> Function() cond, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (await cond()) return;
    if (DateTime.now().isAfter(deadline)) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .where((t) => t != null && t.isNotEmpty)
          .take(30)
          .join(' | ');
      throw TestFailure('condition not met within $timeout; visible: $texts');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

const _relayBase = 'http://127.0.0.1:9001';

/// Forwards a progress line to the code relay log via a simple GET (a POST
/// with JSON would trip the relay's CORS preflight; GET is a simple request).
Future<void> _report(String name,
    {required bool ok, required String detail}) async {
  final msg = Uri.encodeQueryComponent('[$name] $detail');
  try {
    await http
        .get(Uri.parse('$_relayBase/log?msg=$msg'))
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
}
