/// Session boundary task view — thin adapter over the Journey prototype's
/// [BoundaryTaskView]. No Journey types cross this boundary; the view model
/// drives it directly.
library;

import 'package:flutter/material.dart';

import '../../../domain/content_catalog/word_sense_catalog.dart';
import '../../journey_prototype/views/boundary_task_view.dart'
    show BoundaryTaskView;

class SessionBoundaryView extends StatelessWidget {
  const SessionBoundaryView({
    super.key,
    required this.sceneEpisode,
    required this.options,
    required this.revealed,
    required this.choiceSenseId,
    required this.correctSenseId,
    required this.onChoose,
  });

  /// A real scene from the "new" side's review pool.
  final String sceneEpisode;

  /// [secondary (learned), primary (just discovered)] in that order.
  final List<WordSenseCatalogEntry> options;

  final bool revealed;
  final String? choiceSenseId;
  final String correctSenseId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    return BoundaryTaskView(
      sceneEpisode: sceneEpisode,
      options: options,
      revealed: revealed,
      choiceSenseId: choiceSenseId,
      correctSenseId: correctSenseId,
      onChoose: onChoose,
    );
  }
}
