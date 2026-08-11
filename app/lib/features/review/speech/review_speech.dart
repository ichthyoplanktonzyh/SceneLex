// Pure speech helpers (no platform code): markdown-aware speakable text
// extraction and language detection. Ported from the flashcards reference
// (apps/web/src/screens/review/speech/reviewSpeech.ts).
library;

final RegExp _fencePattern = RegExp(r'^\s{0,3}(`{3,}|~{3,})');
final RegExp _headingPattern = RegExp(r'^\s{0,3}#{1,6}\s+');
final RegExp _blockquotePattern = RegExp(r'^\s{0,3}>\s?');
final RegExp _unorderedListPattern = RegExp(r'^\s{0,3}[-*+]\s+');
final RegExp _orderedListPattern = RegExp(r'^\s{0,3}\d+\.\s+');
final RegExp _thematicBreakPattern = RegExp(r'^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$');
final RegExp _tableSeparatorPattern =
    RegExp(r'^\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$');

String _sanitizeLanguageTag(String languageTag) {
  final normalized = languageTag.replaceAll('_', '-').trim();
  return normalized.isEmpty ? 'en-US' : normalized;
}

String _primaryLanguageSubtag(String languageTag) {
  final normalized = _sanitizeLanguageTag(languageTag).toLowerCase();
  final separator = normalized.indexOf('-');
  return separator == -1 ? normalized : normalized.substring(0, separator);
}

String _resolveDetectedLanguageTag(String detected, String fallback) {
  final normalizedDetected = _sanitizeLanguageTag(detected);
  final normalizedFallback = _sanitizeLanguageTag(fallback);
  if (_primaryLanguageSubtag(normalizedDetected) ==
      _primaryLanguageSubtag(normalizedFallback)) {
    return normalizedFallback;
  }
  return normalizedDetected;
}

String _normalizeSpeakableInlineText(String text) => text
    .replaceAll('`', '')
    .replaceAll('|', ' ')
    .replaceAll(r'\$', r'$')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? _fenceMarkerForLine(String line) {
  final match = _fencePattern.firstMatch(line);
  return match?.group(1);
}

String _normalizeMarkdownSpeakableLine(String line, bool startsAtLineBoundary) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return '';
  if (!startsAtLineBoundary) return _normalizeSpeakableInlineText(line);
  if (_thematicBreakPattern.hasMatch(trimmed) ||
      _tableSeparatorPattern.hasMatch(trimmed)) {
    return '';
  }
  var withoutHeading = trimmed.replaceFirst(_headingPattern, '');
  var withoutQuote = withoutHeading.replaceFirst(_blockquotePattern, '');
  var withoutUnordered = withoutQuote.replaceFirst(_unorderedListPattern, '');
  var withoutOrdered = withoutUnordered.replaceFirst(_orderedListPattern, '');
  return _normalizeSpeakableInlineText(withoutOrdered);
}

/// Strips markdown structure (headings, quotes, lists, tables, code fences)
/// so a card face can be read aloud as prose.
String makeSpeakableText(String text) {
  final speakableLines = <String>[];
  String? activeFenceMarker;
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final startsAtLineBoundary = true;
    final marker = _fenceMarkerForLine(line);
    if (activeFenceMarker != null) {
      if (marker == activeFenceMarker) {
        activeFenceMarker = null;
      }
      continue;
    }
    if (marker != null) {
      activeFenceMarker = marker;
      continue;
    }
    final normalized = _normalizeMarkdownSpeakableLine(line, startsAtLineBoundary);
    if (normalized.isNotEmpty) {
      speakableLines.add(normalized);
    }
  }
  return speakableLines.join('\n');
}

const _latinLanguageHeuristics = <({String tag, List<String> markers})>[
  (tag: 'es-ES', markers: [' el ', ' la ', ' que ', ' de ', ' y ', ' por ', ' para ', ' hola ', ' gracias ', ' cómo ', ' está ']),
  (tag: 'fr-FR', markers: [' le ', ' la ', ' les ', ' des ', ' une ', ' bonjour ', ' merci ', ' avec ', ' pour ', ' est ']),
  (tag: 'de-DE', markers: [' der ', ' die ', ' das ', ' und ', ' nicht ', ' danke ', ' bitte ', ' ist ', ' wie ', ' ich ']),
  (tag: 'it-IT', markers: [' il ', ' lo ', ' gli ', ' una ', ' ciao ', ' grazie ', ' per ', ' non ', ' come ', ' che ']),
  (tag: 'pt-PT', markers: [' não ', ' você ', ' obrigado ', ' olá ', ' para ', ' com ', ' uma ', ' que ', ' está ']),
  (tag: 'en-US', markers: [' the ', ' and ', ' you ', ' are ', ' with ', ' this ', ' that ', ' hello ', ' thanks ', ' what ']),
];

int _scoreLanguageHeuristic(String text, List<String> markers) {
  final padded = ' $text ';
  return markers.where(padded.contains).length;
}

/// Heuristic language detection: script ranges first, then Latin-language
/// marker scoring, falling back to the UI language tag.
String detectSpeechLanguage(String text, String fallbackLanguageTag) {
  final normalized = ' ${text.toLowerCase()} ';

  bool hasAny(List<RegExp> patterns) =>
      patterns.any((pattern) => pattern.hasMatch(normalized));

  final scripts = <String, List<RegExp>>{
    'ja-JP': [RegExp(r'[\u3040-\u30ff]')],
    'ko-KR': [RegExp(r'[\uac00-\ud7af]')],
    'zh-CN': [RegExp(r'[\u4e00-\u9fff]')],
    'ru-RU': [RegExp(r'[\u0400-\u04ff]')],
    'el-GR': [RegExp(r'[\u0370-\u03ff]')],
    'he-IL': [RegExp(r'[\u0590-\u05ff]')],
    'ar-SA': [RegExp(r'[\u0600-\u06ff]')],
    'th-TH': [RegExp(r'[\u0e00-\u0e7f]')],
    'hi-IN': [RegExp(r'[\u0900-\u097f]')],
  };
  for (final entry in scripts.entries) {
    if (hasAny(entry.value)) {
      return _resolveDetectedLanguageTag(entry.key, fallbackLanguageTag);
    }
  }
  if (RegExp(r'[¿¡ñ]').hasMatch(normalized)) {
    return _resolveDetectedLanguageTag('es-ES', fallbackLanguageTag);
  }
  if (RegExp(r'[äöüß]').hasMatch(normalized)) {
    return _resolveDetectedLanguageTag('de-DE', fallbackLanguageTag);
  }
  if (RegExp(r'[ãõ]').hasMatch(normalized)) {
    return _resolveDetectedLanguageTag('pt-PT', fallbackLanguageTag);
  }
  if (RegExp(r'[àèìòù]').hasMatch(normalized)) {
    return _resolveDetectedLanguageTag('it-IT', fallbackLanguageTag);
  }
  if (RegExp(r'[çœæ]').hasMatch(normalized)) {
    return _resolveDetectedLanguageTag('fr-FR', fallbackLanguageTag);
  }

  String? bestTag;
  var bestScore = 0;
  for (final heuristic in _latinLanguageHeuristics) {
    final score = _scoreLanguageHeuristic(normalized, heuristic.markers);
    if (score > bestScore) {
      bestTag = heuristic.tag;
      bestScore = score;
    }
  }
  if (bestTag != null && bestScore > 0) {
    return _resolveDetectedLanguageTag(bestTag, fallbackLanguageTag);
  }
  return _sanitizeLanguageTag(fallbackLanguageTag);
}
