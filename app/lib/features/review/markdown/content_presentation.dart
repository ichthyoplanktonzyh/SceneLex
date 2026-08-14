// Content presentation heuristics and LaTeX degradation.
// Classification ported from the flashcards reference
// (reviewContentPresentation.ts); LaTeX renders as monospace text (v1
// degradation — no KaTeX on Flutter yet).
library;

enum ContentPresentationMode { shortPlain, paragraphPlain, markdown }

final _markdownHeadingPattern = RegExp(r'^\s{0,3}#{1,6}\s+\S', multiLine: true);
final _markdownBlockquotePattern = RegExp(r'^\s{0,3}>\s+\S', multiLine: true);
final _markdownUnorderedListPattern = RegExp(
  r'^\s{0,3}[-*+]\s+\S',
  multiLine: true,
);
final _markdownOrderedListPattern = RegExp(
  r'^\s{0,3}\d+\.\s+\S',
  multiLine: true,
);
final _markdownFencedCodePattern = RegExp(
  r'^\s{0,3}(?:```|~~~)',
  multiLine: true,
);
final _markdownLinkOrMediaPattern = RegExp(r'!?\[[^\]]*]\([^)]+\)');
final _markdownReferenceLinkOrMediaPattern = RegExp(r'!?\[[^\]]+]\[[^\]]*]');
final _markdownReferenceDefinitionPattern = RegExp(
  r'^\s{0,3}\[(?:\\.|[^\\\]])+]:\s+\S',
  multiLine: true,
);
final _markdownThematicBreakPattern = RegExp(
  r'^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$',
  multiLine: true,
);
final _markdownTableSeparatorPattern = RegExp(
  r'^\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$',
  multiLine: true,
);
final _displayMathPattern = RegExp(r'\$\$[\s\S]+?\$\$');
final _inlineMathPattern = RegExp(r'\$[^$\s][^$\n\r]*\$');

const _shortPlainWordLimit = 4;
const _shortPlainVisibleCharacterLimit = 48;

bool _hasStrongMarkdownCue(String text) {
  return _markdownHeadingPattern.hasMatch(text) ||
      _markdownBlockquotePattern.hasMatch(text) ||
      _markdownUnorderedListPattern.hasMatch(text) ||
      _markdownOrderedListPattern.hasMatch(text) ||
      _markdownFencedCodePattern.hasMatch(text) ||
      _markdownLinkOrMediaPattern.hasMatch(text) ||
      _markdownReferenceLinkOrMediaPattern.hasMatch(text) ||
      _markdownReferenceDefinitionPattern.hasMatch(text) ||
      _markdownThematicBreakPattern.hasMatch(text) ||
      _markdownTableSeparatorPattern.hasMatch(text);
}

/// Whether the text contains eligible math (`$$...$$` or `$...$`).
bool hasEligibleMath(String text) {
  if (_displayMathPattern.hasMatch(text)) return true;
  return _inlineMathPattern.hasMatch(text);
}

ContentPresentationMode classifyContentPresentation(String text) {
  final trimmed = text.trim();

  if (trimmed.contains('`')) return ContentPresentationMode.markdown;
  if (_hasStrongMarkdownCue(trimmed)) return ContentPresentationMode.markdown;
  if (text.contains(r'$') && hasEligibleMath(text)) {
    return ContentPresentationMode.markdown;
  }
  if (trimmed.isEmpty) return ContentPresentationMode.paragraphPlain;
  if (RegExp(r'[\r\n]').hasMatch(trimmed)) {
    return ContentPresentationMode.paragraphPlain;
  }
  final wordCount = trimmed.split(RegExp(r'\s+')).length;
  if (wordCount < 1 || wordCount > _shortPlainWordLimit) {
    return ContentPresentationMode.paragraphPlain;
  }
  if (trimmed.length > _shortPlainVisibleCharacterLimit) {
    return ContentPresentationMode.paragraphPlain;
  }
  return ContentPresentationMode.shortPlain;
}

/// v1 LaTeX degradation: display math becomes a fenced code block, inline
/// math becomes inline code, so formulas render as monospace text.
String downgradeLatex(String text) {
  var out = text.replaceAllMapped(_displayMathPattern, (match) {
    final formula = match
        .group(0)!
        .substring(2, match.group(0)!.length - 2)
        .trim();
    return formula.isEmpty ? match.group(0)! : '```\n$formula\n```';
  });
  out = out.replaceAllMapped(_inlineMathPattern, (match) {
    final formula = match
        .group(0)!
        .substring(1, match.group(0)!.length - 1)
        .trim();
    return formula.isEmpty ? match.group(0)! : '`$formula`';
  });
  return out;
}
