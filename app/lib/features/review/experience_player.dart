import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'markdown/content_text.dart';
import 'rating_interval.dart';
import 'reactions/review_reactions_controller.dart';
import 'speech/tts_service.dart';

/// Plays the Experience Program for one word sense, then rates the review.
class ExperiencePlayer extends ConsumerStatefulWidget {
  const ExperiencePlayer({
    super.key,
    this.active = true,
    required this.sense,
    required this.state,
    required this.onCompleted,
  });

  /// Whether the hosting tab is visible (web/desktop keyboard shortcuts).
  final bool active;
  final Sense sense;
  final LearningState state;
  final VoidCallback onCompleted;

  @override
  ConsumerState<ExperiencePlayer> createState() => _ExperiencePlayerState();
}

class _ExperiencePlayerState extends ConsumerState<ExperiencePlayer> {
  final _focusNode = FocusNode(debugLabel: 'experience-player');
  late final Future<ExperienceProgram> _programFuture;
  int _unitIndex = 0;
  bool _ratingMode = false;
  bool _submitting = false;
  String? _error;
  bool _speaking = false;
  List<RatingOption>? _ratingOptions;
  bool _ratingOptionsFailed = false;

  /// Cached in initState: dispose() must not touch `ref` (the provider
  /// container is already disposed by then), so the TTS service is held in
  /// a field instead of a `ref.read` getter.
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    _programFuture = _loadProgram();
    _tts.isSpeaking.addListener(_onSpeakingChanged);
  }

  void _onSpeakingChanged() {
    if (!mounted) return;
    final speaking = _tts.isSpeaking.value;
    if (speaking != _speaking) {
      setState(() => _speaking = speaking);
    }
  }

  @override
  void didUpdateWidget(covariant ExperiencePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _tts.isSpeaking.removeListener(_onSpeakingChanged);
    _tts.stop();
    _focusNode.dispose();
    super.dispose();
  }

  /// Space advances (next unit / enter rating); 1-4 rate (rating view only).
  /// Only on web/desktop; the focus node stays primary only while this page
  /// is active and no text field or dialog holds the focus.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.active) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!(kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (!_ratingMode && !_submitting && _program != null &&
          _program!.units.isNotEmpty) {
        _advance();
      }
      return KeyEventResult.handled;
    }
    final int? rating;
    if (key == LogicalKeyboardKey.digit1) {
      rating = 0;
    } else if (key == LogicalKeyboardKey.digit2) {
      rating = 1;
    } else if (key == LogicalKeyboardKey.digit3) {
      rating = 2;
    } else if (key == LogicalKeyboardKey.digit4) {
      rating = 3;
    } else {
      rating = null;
    }
    if (rating != null) {
      if (_ratingMode && !_submitting) {
        _submitRating(rating);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _advance() {
    final program = _program;
    if (program == null) return;
    _tts.stop();
    setState(() {
      if (_unitIndex < program.units.length - 1) {
        _unitIndex++;
      } else {
        _ratingMode = true;
      }
    });
    if (_ratingMode) _prepareRatingOptions();
  }

  /// Computes the four rating-button schedules once, at the moment the rating
  /// view is entered. The preview and the actual submission share the same
  /// inputs (schedule state from the drift row, scheduler settings from the
  /// cached workspace settings) so the shown intervals match the written
  /// dueAt. `now` is captured here on purpose: the fuzz seed contains
  /// now.getTime(), and recomputing in build() would make numbers jump.
  Future<void> _prepareRatingOptions() async {
    try {
      final local = ref.read(localRepositoryProvider);
      final ws = await ref.read(workspaceProvider.future);
      final stateRow = await local.stateFor(widget.sense.wordSenseId);
      final settingsJson = await local.cachedWorkspaceSettings(ws);
      if (!mounted) return;
      setState(() {
        _ratingOptions = buildRatingOptions(
          state: scheduleStateFromRow(stateRow),
          settings: schedulerSettingsFromJson(settingsJson),
          now: DateTime.now(),
          l10n: AppLocalizations.of(context),
        );
        _ratingOptionsFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ratingOptionsFailed = true);
    }
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

  Future<void> _toggleSpeech(String text) async {
    if (_speaking) {
      await _tts.stop();
      return;
    }
    final errorKey = await _tts.speak(
      text,
      fallbackLanguageTag: Localizations.localeOf(context).toLanguageTag(),
    );
    if (errorKey != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).speechUnavailable)),
      );
    }
  }

  Future<void> _submitRating(int rating) async {
    // Reference behavior: emit the rating reaction, then submit.
    ref.read(reviewReactionsControllerProvider.notifier).emit(
          rating,
          reducedMotion: MediaQuery.disableAnimationsOf(context),
        );
    _tts.stop();
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
      if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).reviewSubmitError);
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  ExperienceUnit get _currentUnit => _program!.units[_unitIndex];

  ExperienceProgram? _program;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.active,
      onKeyEvent: _onKeyEvent,
      child: FutureBuilder<ExperienceProgram>(
      future: _programFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(l10n.playerLoadFailed('${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        _program = snapshot.data;
        final program = snapshot.data!;
        if (program.units.isEmpty) {
          return Center(child: Text(l10n.playerNoUnits));
        }
        return _ratingMode
            ? _RatingView(
                sense: widget.sense,
                speaking: _speaking,
                onToggleSpeech: () => _toggleSpeech(widget.sense.lemma),
                submitting: _submitting,
                error: _error,
                options: _ratingOptions,
                optionsFailed: _ratingOptionsFailed,
                onRate: _submitRating,
              )
            : _UnitView(
                sense: widget.sense,
                unit: program.units[_unitIndex],
                isFirst: _unitIndex == 0,
                isLast: _unitIndex == program.units.length - 1,
                speaking: _speaking,
                onToggleSpeech: _toggleSpeech,
                onNext: _advance,
              );
      },
      ),
    );
  }
}

class _SpeechButton extends StatelessWidget {
  const _SpeechButton({required this.speaking, required this.onTap});

  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: speaking ? l10n.speechStop : l10n.speechListen,
      icon: Icon(speaking ? Icons.volume_up : Icons.volume_up_outlined),
      color: Theme.of(context).colorScheme.primary,
      onPressed: onTap,
    );
  }
}

class _UnitView extends StatelessWidget {
  const _UnitView({
    required this.sense,
    required this.unit,
    required this.isFirst,
    required this.isLast,
    required this.speaking,
    required this.onToggleSpeech,
    required this.onNext,
  });

  final Sense sense;
  final ExperienceUnit unit;
  final bool isFirst;
  final bool isLast;
  final bool speaking;
  final void Function(String text) onToggleSpeech;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = _stageLabel(l10n, unit.stage);

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
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$label · ${_stageHint(l10n, unit.stage)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                if (unit.synopsis.isNotEmpty || unit.title.isNotEmpty)
                  _SpeechButton(
                    speaking: speaking,
                    onTap: () => onToggleSpeech(
                      [unit.title, unit.synopsis].join('\n\n'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (unit.title.isNotEmpty)
              Text(unit.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (unit.synopsis.isNotEmpty)
              ContentText(unit.synopsis)
            else
              Text(l10n.playerNoSynopsis),
            if (unit.learningTasks.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...unit.learningTasks.map((task) => _TaskView(task)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onNext,
              child: Text(isLast ? l10n.playerFinish : l10n.playerContinue),
            ),
          ],
        ),
      ),
    );
  }
}

String _stageLabel(AppLocalizations l10n, String stage) => switch (stage) {
      'anchor' => l10n.stageAnchor,
      'variation' => l10n.stageVariation,
      'perturbation' => l10n.stagePerturbation,
      'discrimination' => l10n.stageDiscrimination,
      'symbol_binding' => l10n.stageSymbolBinding,
      'l2_grounding' => l10n.stageL2Grounding,
      'transfer' => l10n.stageTransfer,
      _ => stage,
    };

String _stageHint(AppLocalizations l10n, String stage) => switch (stage) {
      'anchor' => l10n.hintAnchor,
      'variation' => l10n.hintVariation,
      'perturbation' => l10n.hintPerturbation,
      'discrimination' => l10n.hintDiscrimination,
      'symbol_binding' => l10n.hintSymbolBinding,
      'l2_grounding' => l10n.hintL2Grounding,
      'transfer' => l10n.hintTransfer,
      _ => '',
    };

class _TaskView extends StatelessWidget {
  const _TaskView(this.task);

  final dynamic task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final map = task is Map<String, dynamic> ? task as Map<String, dynamic> : const <String, dynamic>{};
    final prompt = map['prompt']?.toString() ?? '';
    final options = (map['options'] as List<dynamic>?) ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.playerTaskJudge,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (prompt.isEmpty)
              Text(l10n.playerTaskPlaceholder)
            else
              ContentText(prompt),
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
    required this.speaking,
    required this.onToggleSpeech,
    required this.submitting,
    required this.error,
    required this.options,
    required this.optionsFailed,
    required this.onRate,
  });

  final Sense sense;
  final bool speaking;
  final VoidCallback onToggleSpeech;
  final bool submitting;
  final String? error;
  final List<RatingOption>? options;
  final bool optionsFailed;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Spacer(),
                _SpeechButton(speaking: speaking, onTap: onToggleSpeech),
              ],
            ),
            Text(
              sense.lemma,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.playerRatingQuestion,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (error != null) ...[
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            if (optionsFailed)
              Text(
                l10n.reviewSubmitError,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (options == null)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 76,
                children: [
                  for (final option in options!)
                    _RatingButton(
                      option: option,
                      color: _ratingColor(option.rating),
                      onTap: () => onRate(option.rating),
                      enabled: !submitting,
                    ),
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

Color _ratingColor(int rating) => switch (rating) {
      0 => Colors.red,
      1 => Colors.orange,
      2 => Colors.green,
      _ => Colors.teal,
    };

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.option,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  final RatingOption option;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            option.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            option.interval,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
