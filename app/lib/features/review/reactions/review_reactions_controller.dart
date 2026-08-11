import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'power_mode_service.dart';
import 'review_reaction.dart';

class ReviewReactionsState {
  const ReviewReactionsState({
    required this.enabled,
    this.events = const [],
  });

  final bool enabled;
  final List<ReviewReactionEvent> events;
}

final powerModeStreamProvider = StreamProvider<bool>((ref) =>
    PowerModeService.instance.changes);

/// Owns the active rating-reaction events and the "Review Animations"
/// preference. Mirrors the reference: max 3 events on screen, random
/// weighted variants, touch-to-dismiss, and auto-disable while the OS is in
/// low power / power saver mode (without changing the preference).
class ReviewReactionsController extends Notifier<ReviewReactionsState> {
  static const _enabledKey = 'review_animations_enabled';

  final Map<String, Timer> _cleanupTimers = {};

  bool get _lowPowerEnabled =>
      ref.read(powerModeStreamProvider).value ?? false;

  @override
  ReviewReactionsState build() {
    _restoreEnabled();
    ref.listen(powerModeStreamProvider, (previous, next) {
      if (next.value == true) {
        dismissAll();
      }
    });
    ref.onDispose(() {
      for (final timer in _cleanupTimers.values) {
        timer.cancel();
      }
      _cleanupTimers.clear();
    });
    return const ReviewReactionsState(enabled: true);
  }

  Future<void> _restoreEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;
    if (enabled != state.enabled) {
      state = ReviewReactionsState(enabled: enabled);
      if (!enabled) dismissAll();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    state = ReviewReactionsState(enabled: enabled);
    if (!enabled) dismissAll();
  }

  bool get _animationsEnabled =>
      state.enabled && !_lowPowerEnabled;

  /// Emits a reaction for a rating (0=Again … 3=Easy). No-op when the
  /// setting is off or the OS is in low power mode.
  void emit(int rating, {required bool reducedMotion}) {
    if (!_animationsEnabled) return;
    final reactionRating = makeReviewReactionRating(rating);
    final totalWeight = reviewReactionVariantTotalWeight(reactionRating);
    final variant =
        selectReviewReactionVariant(reactionRating, _randomRoll(totalWeight));
    final event = ReviewReactionEvent(
      id: _newEventId(),
      rating: reactionRating,
      variant: variant,
    );

    final previousEvents = state.events;
    final nextEvents = appendReviewReactionEvent(
      previousEvents,
      event,
      reviewReactionMaximumActiveEvents,
    );
    for (final previousEvent in previousEvents) {
      if (!nextEvents.any((e) => e.id == previousEvent.id)) {
        _cancelCleanup(previousEvent.id);
      }
    }
    state = ReviewReactionsState(enabled: state.enabled, events: nextEvents);

    _cleanupTimers[event.id] = Timer(
      reviewReactionCleanupDelay(event.variant, reducedMotion: reducedMotion),
      () => removeEvent(event.id),
    );
  }

  void removeEvent(String eventId) {
    _cancelCleanup(eventId);
    final events = state.events.where((event) => event.id != eventId).toList();
    state = ReviewReactionsState(enabled: state.enabled, events: events);
  }

  /// Touch-to-dismiss: clears every active reaction immediately.
  void dismissAll() {
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
    if (state.events.isNotEmpty) {
      state = ReviewReactionsState(enabled: state.enabled);
    }
  }

  void _cancelCleanup(String eventId) {
    _cleanupTimers.remove(eventId)?.cancel();
  }

  final _random = Random();

  int _randomRoll(int totalWeight) => _random.nextInt(totalWeight);

  String _newEventId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
}

final reviewReactionsControllerProvider =
    NotifierProvider<ReviewReactionsController, ReviewReactionsState>(
        ReviewReactionsController.new);
