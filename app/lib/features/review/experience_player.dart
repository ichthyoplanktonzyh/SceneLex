import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';

const _stageLabels = {
  'anchor': '经验原型',
  'variation': '变式',
  'perturbation': '边界扰动',
  'discrimination': '区分',
  'symbol_binding': '词义揭示',
  'l2_grounding': '语言用法',
  'transfer': '迁移判断',
};

const _stageHints = {
  'anchor': '先经历:这是这个词生长的典型经验。',
  'variation': '情境变了,经验结构不变——找到不变的东西。',
  'perturbation': '只改变一个变量:它还是同一个词吗?',
  'discrimination': '两种心理状态,是同一种吗?',
  'symbol_binding': '你反复识别的这种经验,英语里这样说。',
  'l2_grounding': '这个词在真实语言里怎么用。',
  'transfer': '一个全新的经验:这个词成立吗?',
};

/// Plays the Experience Program for one word sense, then rates the review.
class ExperiencePlayer extends ConsumerStatefulWidget {
  const ExperiencePlayer({
    super.key,
    required this.sense,
    required this.state,
    required this.onCompleted,
  });

  final Sense sense;
  final LearningState state;
  final VoidCallback onCompleted;

  @override
  ConsumerState<ExperiencePlayer> createState() => _ExperiencePlayerState();
}

class _ExperiencePlayerState extends ConsumerState<ExperiencePlayer> {
  late final Future<ExperienceProgram> _programFuture;
  int _unitIndex = 0;
  bool _ratingMode = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _programFuture = _loadProgram();
  }

  Future<ExperienceProgram> _loadProgram() async {
    final programId = widget.sense.programId;
    if (programId == null) {
      throw ApiException(0, 'sense ${widget.sense.senseKey} has no program');
    }
    // Offline-first: local program cache first, then network + cache.
    final local = ref.read(localRepositoryProvider);
    final cached = await local.cachedProgram(programId);
    if (cached != null) return ExperienceProgram.fromJson(cached);

    final api = ref.read(apiClientProvider);
    final res = await api.get('/content/programs/$programId');
    await local.cacheProgram(programId, res);
    return ExperienceProgram.fromJson(res);
  }

  Future<void> _submitRating(int rating) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await submitReview(
        ref,
        wordSenseId: widget.sense.wordSenseId,
        learningStateId: widget.state.learningStateId ?? widget.sense.wordSenseId,
        experienceUnitId: _currentUnit.experienceUnitId,
        programVersion: widget.sense.programVersion ?? 1,
        rating: rating,
        reviewedAtClient: DateTime.now(),
      );
      if (mounted) widget.onCompleted();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  ExperienceUnit get _currentUnit => _program!.units[_unitIndex];

  ExperienceProgram? _program;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExperienceProgram>(
      future: _programFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Program 加载失败: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        _program = snapshot.data;
        final program = snapshot.data!;
        if (program.units.isEmpty) {
          return const Center(child: Text('这个词义还没有可播放的经验。'));
        }
        return _ratingMode
            ? _RatingView(
                sense: widget.sense,
                submitting: _submitting,
                error: _error,
                onRate: _submitRating,
              )
            : _UnitView(
                sense: widget.sense,
                unit: program.units[_unitIndex],
                isFirst: _unitIndex == 0,
                isLast: _unitIndex == program.units.length - 1,
                onNext: () {
                  setState(() {
                    if (_unitIndex < program.units.length - 1) {
                      _unitIndex++;
                    } else {
                      _ratingMode = true;
                    }
                  });
                },
              );
      },
    );
  }
}

class _UnitView extends StatelessWidget {
  const _UnitView({
    required this.sense,
    required this.unit,
    required this.isFirst,
    required this.isLast,
    required this.onNext,
  });

  final Sense sense;
  final ExperienceUnit unit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _stageLabels[unit.stage] ?? unit.stage;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFirst) ...[
              Text(
                sense.lemma,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (sense.pos.isNotEmpty)
                Text(sense.pos, style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('$label · ${_stageHints[unit.stage] ?? ''}'),
            ),
            const SizedBox(height: 24),
            if (unit.title.isNotEmpty)
              Text(unit.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              unit.synopsis.isEmpty ? '(无叙事内容)' : unit.synopsis,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            if (unit.learningTasks.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...unit.learningTasks.map((task) => _TaskView(task)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onNext,
              child: Text(isLast ? '完成经验之旅' : '继续'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskView extends StatelessWidget {
  const _TaskView(this.task);

  final dynamic task;

  @override
  Widget build(BuildContext context) {
    final map = task is Map<String, dynamic> ? task as Map<String, dynamic> : const <String, dynamic>{};
    final prompt = map['prompt']?.toString() ?? '';
    final options = (map['options'] as List<dynamic>?) ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('判断', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(prompt.isEmpty ? '(任务)' : prompt),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option.toString()),
                      selected: false,
                      onSelected: (_) {},
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingView extends StatelessWidget {
  const _RatingView({
    required this.sense,
    required this.submitting,
    required this.error,
    required this.onRate,
  });

  final Sense sense;
  final bool submitting;
  final String? error;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sense.lemma,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '刚才的经历,你记得多牢?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (error != null) ...[
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _RatingButton(label: 'Again', color: Colors.red, onTap: () => onRate(0), enabled: !submitting),
                _RatingButton(label: 'Hard', color: Colors.orange, onTap: () => onRate(1), enabled: !submitting),
                _RatingButton(label: 'Good', color: Colors.green, onTap: () => onRate(2), enabled: !submitting),
                _RatingButton(label: 'Easy', color: Colors.teal, onTap: () => onRate(3), enabled: !submitting),
              ],
            ),
            const SizedBox(height: 16),
            if (submitting) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: enabled ? onTap : null,
      child: Text(label),
    );
  }
}
