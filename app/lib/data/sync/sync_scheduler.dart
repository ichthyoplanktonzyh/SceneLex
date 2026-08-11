import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_providers.dart';

/// Foreground sync scheduler: runs the sync cycle on lifecycle resume, on a
/// 60s foreground timer (reference: useWorkspaceLifecycle.ts — periodic tick
/// only while visible, plus focus/visibilitychange to visible), and with
/// exponential backoff after failures (30s start, capped at 5 minutes,
/// reset on success). No connectivity listener: failed cycles retry via the
/// backoff timer. Mounted with the signed-in shell, so it lives and dies
/// with the session.
class SyncScheduler extends ConsumerStatefulWidget {
  const SyncScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncScheduler> createState() => _SyncSchedulerState();
}

class _SyncSchedulerState extends ConsumerState<SyncScheduler> {
  static const _period = Duration(seconds: 60);
  static const _backoffInitial = Duration(seconds: 30);
  static const _backoffMax = Duration(minutes: 5);

  Timer? _periodicTimer;
  Timer? _retryTimer;
  bool _retrying = false;
  int _retryCount = 0;
  AppLifecycleListener? _lifecycleListener;
  ProviderSubscription<SyncStateInfo>? _statusSubscription;
  // lifecycleState can be null before the first lifecycle message arrives;
  // the app is by definition in the foreground at that point, so null means
  // foreground (otherwise the 60s poll and the backoff retry would never run).
  bool _foreground =
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        // Foreground resume triggers an immediate sync (reference behavior
        // on visibilitychange -> visible and scenePhase -> active).
        _triggerSync();
      },
      onHide: () => _foreground = false,
      onPause: () => _foreground = false,
      onDetach: () => _foreground = false,
    );
    _periodicTimer = Timer.periodic(_period, (_) {
      if (_foreground) _triggerSync();
    });

    // Backoff retry: any sync cycle ending in the offline state schedules
    // the next attempt (exponential, capped at 5 minutes); success cancels
    // it and resets the backoff window. ref.listen is not allowed in
    // initState, so use listenManual and close the subscription on dispose.
    _statusSubscription = ref.listenManual<SyncStateInfo>(syncStatusProvider,
        (previous, next) {
      switch (next.status) {
        case SyncStateStatus.synced:
          _retrying = false;
          _retryCount = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
        case SyncStateStatus.syncing:
          break;
        case SyncStateStatus.offline:
          if (_retrying || !mounted) return;
          _retrying = true;
          _retryTimer?.cancel();
          _retryTimer = Timer(_nextBackoffDelay(), () {
            if (!mounted) return;
            _retrying = false;
            _triggerSync();
          });
      }
    });
  }

  /// 30s, 60s, 120s, 240s, then capped at 300s.
  Duration _nextBackoffDelay() {
    final shift = math.min(_retryCount++, 4);
    final ms = math.min(
      _backoffInitial.inMilliseconds * (1 << shift),
      _backoffMax.inMilliseconds,
    );
    return Duration(milliseconds: ms);
  }

  void _triggerSync() {
    // Backed-off retries are intentionally dropped while in the background
    // (no re-arming): coming back to the foreground re-triggers via onResume.
    if (!_foreground) return;
    ref.read(syncTriggerProvider)();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _retryTimer?.cancel();
    _statusSubscription?.close();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
