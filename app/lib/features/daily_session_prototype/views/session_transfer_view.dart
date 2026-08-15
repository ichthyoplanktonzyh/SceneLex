/// Session transfer task view — thin adapter over the Journey prototype's
/// [TransferTaskView]. The unit is a domain type (ExperienceUnit), so no
/// Journey types cross this boundary.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/experience_unit.dart';
import '../../journey_prototype/views/transfer_task_view.dart'
    show TransferTaskView;

class SessionTransferView extends StatelessWidget {
  const SessionTransferView({
    super.key,
    required this.unit,
    required this.revealed,
    required this.choiceAnswerId,
    required this.onChoose,
  });

  final ExperienceUnit unit;
  final bool revealed;
  final String? choiceAnswerId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    return TransferTaskView(
      unit: unit,
      revealed: revealed,
      choiceAnswerId: choiceAnswerId,
      onChoose: onChoose,
    );
  }
}
