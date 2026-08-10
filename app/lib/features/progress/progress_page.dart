import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress surface: streak, charts, schedule. Phase 5.
class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('进度')),
      body: Center(
        child: Text(
          '进度(Phase 5)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
