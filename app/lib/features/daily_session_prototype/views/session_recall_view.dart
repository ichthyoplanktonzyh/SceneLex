/// Session recall task view — thin adapter over the Journey prototype's
/// [RecallTaskView].
///
/// The only Journey type crossing this boundary is the recall grade enum;
/// it is converted here (adapter), never in the planner or the view model.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/symbol_binding.dart';
import '../daily_session_models.dart';
import '../../journey_prototype/views/recall_task_view.dart'
    show RecallTaskView;

class SessionRecallView extends StatelessWidget {
  const SessionRecallView({
    super.key,
    required this.episode,
    required this.revealed,
    required this.reveal,
    this.minimalGloss,
    required this.onReveal,
    required this.onGrade,
  });

  final String episode;
  final bool revealed;
  final Reveal reveal;
  final String? minimalGloss;
  final VoidCallback onReveal;
  final ValueChanged<DailySessionRecallGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    return RecallTaskView(
      episode: episode,
      revealed: revealed,
      reveal: reveal,
      minimalGloss: minimalGloss,
      onReveal: onReveal,
      // Both enums declare the same order (forgot, hard, gotIt); this is the
      // single enum bridge between the session domain and the journey chrome.
      onGrade: (index) => onGrade(DailySessionRecallGrade.values[index]),
    );
  }
}
