import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/providers.dart';
import 'experience_player.dart';

/// Today queue: due/new learning states, played through the Experience Player.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('今日学习')),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (lib) {
          final queue = _buildQueue(lib);
          if (queue.isEmpty) {
            return _EmptyQueue(senseCount: lib.states.length);
          }
          final sense = queue.first;
          return ExperiencePlayer(
            key: ValueKey('${sense.wordSenseId}-${lib.states[sense.wordSenseId]?.reps}'),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(senseCount == 0 ? '还没有学习中的词义' : '今天没有到期内容'),
          const SizedBox(height: 8),
          Text(
            senseCount == 0 ? '去「词表」添加要学的词义' : '全部完成,明天再来',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
