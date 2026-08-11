import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'experience_player.dart';
import 'reactions/power_mode_service.dart';
import 'reactions/review_reaction_layer.dart';
import 'reactions/review_reactions_controller.dart';

/// Today queue: due/new learning states, played through the Experience Player.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, this.active = true});

  /// Whether this tab is currently visible (drives keyboard focus on
  /// web/desktop when returning to the tab).
  final bool active;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
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
                final queue = _buildQueue(lib);
                if (queue.isEmpty) {
                  return _EmptyQueue(senseCount: lib.states.length);
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

  /// Queue order mirrors the reference: recently reviewed due -> due -> new.
  List<Sense> _buildQueue(Library lib) {
    final due = <(Sense, DateTime?)>[];
    final newItems = <Sense>[];
    for (final sense in lib.senses) {
      final state = lib.states[sense.wordSenseId];
      if (state == null) continue;
      if (state.isNew) {
        newItems.add(sense);
      } else if (state.isDue) {
        due.add((sense, state.dueAt));
      }
    }
    due.sort((a, b) {
      final da = a.$2?.millisecondsSinceEpoch ?? 0;
      final db = b.$2?.millisecondsSinceEpoch ?? 0;
      return da.compareTo(db);
    });
    return [...due.map((e) => e.$1), ...newItems];
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.senseCount});

  final int senseCount;

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
        ],
      ),
    );
  }
}
