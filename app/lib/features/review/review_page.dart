import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/progress/progress_aggregation.dart';
import '../../data/progress/progress_providers.dart';
import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../lists/lists_page.dart';
import 'experience_player.dart';
import 'reactions/power_mode_service.dart';
import 'reactions/review_reaction_layer.dart';
import 'reactions/review_reactions_controller.dart';

/// Today queue: due/new learning states, played through the Experience Player.
/// The queue can be filtered (All Cards / a word list / tags), persisted.
///
/// Queue shape mirrors the reference: it starts seeded with up to 8 cards,
/// cards reviewed in this session are excluded from the queue, and when the
/// queue drops to 4 or fewer cards it is silently replenished back to 8.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, this.active = true});

  /// Whether this tab is currently visible (drives keyboard focus on
  /// web/desktop when returning to the tab).
  final bool active;

  static const queueSeedSize = 8;
  static const queueReplenishBelow = 4;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  /// Session queue of wordSenseIds (capped at [ReviewPage.queueSeedSize]).
  final List<String> _queue = [];

  /// wordSenseIds already reviewed in this session; they never re-enter the
  /// queue until the next session (mirrors the reference excluded-card set).
  final Set<String> _reviewedThisSession = {};

  @override
  void initState() {
    super.initState();
    PowerModeService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);
    final reactions = ref.watch(reviewReactionsControllerProvider);
    final filter = ref.watch(reviewFilterProvider);
    final hardReminder = ref.watch(reviewHardReminderProvider);

    if (hardReminder) {
      // Non-blocking reminder after repeated Hard answers; shown once per
      // 3-day cooldown (reference "Quick reminder" dialog).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reviewHardReminderProvider.notifier).dismiss();
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.reviewHardReminderTitle),
            content: Text(l10n.reviewHardReminderBody),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.reviewHardReminderDismiss),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: _FilterMenuButton(
          filter: filter,
          onPressed: () => showReviewFilterSheet(context, ref),
        ),
        title: Text(l10n.reviewTitle),
        actions: const [_ReviewStreakBadge()],
      ),
      // Touch to cancel: any touch on the review surface dismisses the
      // active rating reactions (reference behavior).
      body: Listener(
        onPointerDown: (_) =>
            ref.read(reviewReactionsControllerProvider.notifier).dismissAll(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            library.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.loadingFailed('$e'))),
              data: (lib) {
                final queue = _buildQueue(lib, filter);
                if (queue.isEmpty) {
                  return _EmptyQueue(
                    senseCount: lib.states.length,
                    filtered: filter is! ReviewFilterAll,
                    onSwitchToAll: filter is ReviewFilterAll
                        ? null
                        : () => ref
                            .read(reviewFilterProvider.notifier)
                            .set(const ReviewFilter.all()),
                  );
                }
                final sense = queue.first;
                return ExperiencePlayer(
                  key: ValueKey('${sense.wordSenseId}-${lib.states[sense.wordSenseId]?.reps}'),
                  active: widget.active,
                  sense: sense,
                  state: lib.states[sense.wordSenseId] ?? const LearningState(
                    wordSenseId: '',
                    reps: 0,
                    lapses: 0,
                    fsrsCardState: 'new',
                  ),
                  onCompleted: () {
                    _reviewedThisSession.add(sense.wordSenseId);
                    ref.invalidate(libraryProvider);
                  },
                );
              },
            ),
            ReviewReactionLayer(
              events: reactions.events,
              reducedMotion: MediaQuery.disableAnimationsOf(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Queue order mirrors the reference: recently reviewed due -> due -> new,
  /// restricted to the active filter. Maintains the session queue: up to 8
  /// seeded cards, replenished (silently) once it drops to 4 or fewer.
  List<Sense> _buildQueue(Library lib, ReviewFilter filter) {
    final candidates = _orderedCandidates(lib, filter)
        .where((sense) => !_reviewedThisSession.contains(sense.wordSenseId))
        .toList();
    final candidateIds = {for (final s in candidates) s.wordSenseId};

    // Drop cards that left the candidates (reviewed / state changed).
    _queue.removeWhere((id) => !candidateIds.contains(id));

    // Seed or replenish back to 8 (replenish triggers below 4, matching the
    // reference "seed 8, top up when the queue runs low" behavior).
    if (_queue.isEmpty || _queue.length < ReviewPage.queueReplenishBelow) {
      final need = ReviewPage.queueSeedSize - _queue.length;
      _queue.addAll(candidates
          .where((s) => !_queue.contains(s.wordSenseId))
          .take(need)
          .map((s) => s.wordSenseId));
    }

    return [
      for (final id in _queue)
        if (candidateIds.contains(id))
          lib.senses.firstWhere((s) => s.wordSenseId == id),
    ];
  }

  /// Rank mirrors behavior spec §10: due cards reviewed within the last hour
  /// -> other due cards -> new cards; tie-break: dueAt ASC -> createdAt
  /// (clientUpdatedAt) DESC -> id ASC.
  List<Sense> _orderedCandidates(Library lib, ReviewFilter filter) {
    final filtered = lib.senses.where((sense) {
      if (!lib.states.containsKey(sense.wordSenseId)) return false;
      return switch (filter) {
        ReviewFilterAll() => true,
        ReviewFilterList(:final listId) => lib.lists
            .where((l) => l.listId == listId)
            .map((l) => lib.senseHasAnyTag(sense.wordSenseId, l.tags))
            .firstOrNull ??
            false,
        ReviewFilterTags(:final tags) =>
          lib.senseHasAnyTag(sense.wordSenseId, tags),
      };
    }).toList();

    final recentDue = <(Sense, DateTime)>[];
    final due = <(Sense, DateTime)>[];
    final newItems = <Sense>[];
    final hourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));

    for (final sense in filtered) {
      final state = lib.states[sense.wordSenseId]!;
      if (state.isNew) {
        newItems.add(sense);
      } else if (state.isDue && state.dueAt != null) {
        final lastReviewed = state.fsrsLastReviewedAt;
        final reviewedRecently =
            lastReviewed != null && lastReviewed.isAfter(hourAgo);
        (reviewedRecently ? recentDue : due).add((sense, state.dueAt!));
      }
    }

    // createdAt proxy: the state's clientUpdatedAt (when it joined study).
    String createdKey(Sense s) =>
        lib.states[s.wordSenseId]?.clientUpdatedAt ?? '';

    int compare((Sense, DateTime) a, (Sense, DateTime) b) {
      final byDue = a.$2.compareTo(b.$2);
      if (byDue != 0) return byDue;
      final byCreated = createdKey(b.$1).compareTo(createdKey(a.$1));
      if (byCreated != 0) return byCreated;
      return a.$1.wordSenseId.compareTo(b.$1.wordSenseId);
    }

    recentDue.sort(compare);
    due.sort(compare);
    newItems.sort((a, b) {
      final byCreated = createdKey(b).compareTo(createdKey(a));
      if (byCreated != 0) return byCreated;
      return a.wordSenseId.compareTo(b.wordSenseId);
    });

    return [
      ...recentDue.map((e) => e.$1),
      ...due.map((e) => e.$1),
      ...newItems,
    ];
  }
}

/// Streak badge in the Review app bar: flame icon + current streak days.
/// Highlighted when reviewed today; tapping jumps to the Progress streak card.
class _ReviewStreakBadge extends ConsumerWidget {
  const _ReviewStreakBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final data = ref.watch(progressDataProvider);
    final streak = data.value?.streak;
    final days = streak?.currentStreakDays ?? 0;
    final hasReviewedToday = streak != null &&
        streak.statesByDate[todayLocalDate()] == StreakDayState.reviewed;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: hasReviewedToday
            ? l10n.reviewBadgeTooltipReviewed(days)
            : l10n.reviewBadgeTooltip(days),
        child: Material(
          color: hasReviewedToday
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              ref
                  .read(progressScrollTargetProvider.notifier)
                  .set(ProgressScrollTarget.streak);
              ref.read(selectedTabProvider.notifier).setTab(1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: hasReviewedToday
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$days',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: hasReviewedToday
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AppBar menu button: current filter title; opens the filter sheet.
class _FilterMenuButton extends ConsumerWidget {
  const _FilterMenuButton({required this.filter, required this.onPressed});

  final ReviewFilter filter;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);

    final title = library.when(
      data: (lib) => switch (filter) {
        ReviewFilterAll() => l10n.listsAllCards,
        ReviewFilterList(:final listId) => lib.lists
            .where((l) => l.listId == listId)
            .map((l) => l.name)
            .firstOrNull ??
            l10n.listsAllCards,
        ReviewFilterTags(:final tags) => tags.isEmpty
            ? l10n.listsAllCards
            : tags.join(', '),
      },
      loading: () => l10n.listsAllCards,
      error: (_, _) => l10n.listsAllCards,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Opens the filter bottom sheet (All Cards / lists / multi-select tags).
void showReviewFilterSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final library = ref.read(libraryProvider);
  final lib = library.value;
  if (lib == null) return;

  final current = ref.read(reviewFilterProvider);
  var draft = current;
  var draftTags = current is ReviewFilterTags
      ? {...current.tags}
      : <String>{};

  Object radioValue(ReviewFilter filter) => switch (filter) {
        ReviewFilterAll() => 'all',
        ReviewFilterList(:final listId) => 'list-$listId',
        ReviewFilterTags() => 'tags',
      };

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.reviewFilterTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              RadioGroup<Object>(
                groupValue: radioValue(draft),
                onChanged: (value) => setSheetState(() {
                  if (value == 'all') {
                    draft = const ReviewFilter.all();
                    draftTags = {};
                  } else if (value is String && value.startsWith('list-')) {
                    draft = ReviewFilter.list(value.substring(5));
                    draftTags = {};
                  }
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioListTile<Object>(
                      value: 'all',
                      title: Text(l10n.listsAllCards),
                      subtitle: Text(l10n.listsAllCardsBody(lib.states.length)),
                    ),
                    if (lib.lists.isNotEmpty) ...[
                      const Divider(height: 8),
                      Text(l10n.reviewFilterLists,
                          style: Theme.of(context).textTheme.labelLarge),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final list in lib.lists)
                              RadioListTile<Object>(
                                value: 'list-${list.listId}',
                                dense: true,
                                title: Text(list.name),
                                subtitle: Text(l10n.listsMatchedCount(
                                    lib.matchedCount(list))),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 8),
              Text(l10n.reviewFilterTags,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (lib.tagCounts.isEmpty)
                Text(
                  l10n.listsNoTags,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in lib.tagCounts.entries)
                      FilterChip(
                        label: Text('${entry.key} (${entry.value})'),
                        selected: draftTags.contains(entry.key),
                        onSelected: (selected) => setSheetState(() {
                          if (selected) {
                            draftTags.add(entry.key);
                          } else {
                            draftTags.remove(entry.key);
                          }
                          draft = draftTags.isEmpty
                              ? const ReviewFilter.all()
                              : ReviewFilter.tags({...draftTags});
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ListsPage(),
                        ),
                      );
                    },
                    child: Text(l10n.reviewFilterManage),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      ref.read(reviewFilterProvider.notifier).set(draft);
                      Navigator.pop(sheetContext);
                    },
                    child: Text(l10n.reviewFilterDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({
    required this.senseCount,
    required this.filtered,
    this.onSwitchToAll,
  });

  final int senseCount;
  final bool filtered;
  final VoidCallback? onSwitchToAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(senseCount == 0 ? l10n.reviewEmptyNoSenses : l10n.reviewEmptyNoDue),
          const SizedBox(height: 8),
          Text(
            senseCount == 0 ? l10n.reviewEmptyGoAdd : l10n.reviewEmptyAllDone,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (filtered && onSwitchToAll != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onSwitchToAll,
              icon: const Icon(Icons.style),
              label: Text(l10n.reviewEmptySwitchToAll),
            ),
          ],
        ],
      ),
    );
  }
}
