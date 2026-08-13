/// Symbol binding and grounding of a Contract v1 ExperienceProgram.
///
/// Per the contract, `symbol_binding` carries the reveal plus the minimal L1
/// gloss; `grounding` and `review_pool` live at the program's top level. The
/// learner first meets the L2 word here, strictly after all concept units
/// have been answered.
library;

import 'parsing.dart';

/// The binding stage: the reveal and its minimal L1 gloss.
class SymbolBinding {
  const SymbolBinding({required this.reveal, this.minimalL1Gloss});

  factory SymbolBinding.fromJson(Map<String, dynamic> json) => SymbolBinding(
    reveal: Reveal.fromJson(jsonMap(json, 'reveal')),
    minimalL1Gloss: json['minimal_l1_gloss'] is String
        ? json['minimal_l1_gloss'] as String
        : null,
  );

  final Reveal reveal;

  /// Confirmation-only L1 gloss; rendered only when present.
  final String? minimalL1Gloss;
}

/// The first moment the target word is shown to the learner.
class Reveal {
  const Reveal({
    required this.l2Word,
    required this.ipa,
    required this.presentation,
  });

  factory Reveal.fromJson(Map<String, dynamic> json) => Reveal(
    l2Word: jsonString(json, 'l2_word'),
    ipa: jsonString(json, 'ipa'),
    presentation: jsonString(json, 'presentation'),
  );

  final String l2Word;
  final String ipa;
  final String presentation;
}

/// Grounds the L2 word in a real experience already seen by the learner.
class Grounding {
  const Grounding({
    required this.sourceExperienceId,
    required this.l2Realization,
    required this.constructions,
    required this.collocations,
  });

  factory Grounding.fromJson(Map<String, dynamic> json) => Grounding(
    sourceExperienceId: jsonString(json, 'source_experience_id'),
    l2Realization: jsonString(json, 'l2_realization'),
    constructions: jsonStringList(json, 'constructions'),
    collocations: jsonStringList(json, 'collocations'),
  );

  final String sourceExperienceId;
  final String l2Realization;
  final List<String> constructions;
  final List<String> collocations;
}

/// One review-pool item. Not consumed by this round's first-run Runtime;
/// kept as a typed placeholder for the future review flow.
class ReviewItem {
  const ReviewItem({required this.raw});

  factory ReviewItem.fromJson(Map<String, dynamic> json) =>
      ReviewItem(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;
}
