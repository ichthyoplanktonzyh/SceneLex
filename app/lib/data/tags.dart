// Preset read-only tag system (user decision: no user-generated tags in v1).
// Tags derive from the word sense metadata (semantic type + part of speech),
// are normalized (trim + lowercase), and power list rules and review filters.
library;

import '../api/models.dart';

/// Normalizes a tag: trimmed, lowercased.
String normalizeTag(String tag) => tag.trim().toLowerCase();

/// Preset tags for a sense: `type:<semanticType>` and `pos:<pos>`.
/// Empty metadata produces no tag. Returns normalized tags.
List<String> presetTagsForSense(Sense sense) {
  final tags = <String>[];
  final semanticType = normalizeTag(sense.semanticType);
  if (semanticType.isNotEmpty) {
    tags.add('type:$semanticType');
  }
  final pos = normalizeTag(sense.pos);
  if (pos.isNotEmpty) {
    tags.add('pos:$pos');
  }
  return tags;
}

/// Matches any-tag rule: the sense matches the rule when at least one of its
/// tags is in the selected tag set.
bool matchesAnyTag(Iterable<String> senseTags, Iterable<String> selectedTags) {
  final selected = selectedTags.toSet();
  return senseTags.any(selected.contains);
}
