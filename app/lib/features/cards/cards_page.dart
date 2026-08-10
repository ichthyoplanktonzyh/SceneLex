import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../data/providers.dart';

/// Vocabulary surface: senses catalog + add-to-study.
class CardsPage extends ConsumerWidget {
  const CardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('词表')),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (lib) {
          if (lib.senses.isEmpty) {
            return const Center(child: Text('词义库为空,先运行 import_content.py'));
          }
          return ListView.separated(
            itemCount: lib.senses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sense = lib.senses[index];
              final state = lib.states[sense.wordSenseId];
              return ListTile(
                title: Text(sense.lemma),
                subtitle: Text(
                  '${sense.pos} · ${sense.semanticType}\n${_stateLabel(state)}',
                ),
                trailing: state == null
                    ? FilledButton.tonal(
                        onPressed: () async {
                          await addSenseToStudy(ref, sense.wordSenseId);
                          ref.invalidate(libraryProvider);
                        },
                        child: const Text('学习'),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
                onTap: state == null
                    ? null
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('${sense.lemma}: ${_stateLabel(state)}')),
                        ),
              );
            },
          );
        },
      ),
    );
  }

  String _stateLabel(LearningState? state) {
    if (state == null) return '未添加';
    return switch (state.fsrsCardState) {
      'new' => '新词 · 等待学习',
      'learning' => '学习中 · 下一步 ${state.dueAt?.toLocal()}',
      'relearning' => '复习中 · 下一步 ${state.dueAt?.toLocal()}',
      _ => '复习 · 下次 ${state.dueAt?.toLocal()}',
    };
  }
}
