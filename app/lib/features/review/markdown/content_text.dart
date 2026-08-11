import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'content_presentation.dart';

/// Renders unit narrative/task text with the reference presentation
/// heuristics: short plain text large and centered, paragraphs in body
/// style, and full markdown (headings/quotes/lists/tables/code fences) with
/// LaTeX degraded to monospace text.
class ContentText extends StatelessWidget {
  const ContentText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (classifyContentPresentation(text)) {
      case ContentPresentationMode.shortPlain:
        return Text(
          text.trim(),
          textAlign: textAlign ?? TextAlign.center,
          style: style ?? theme.textTheme.headlineMedium,
        );
      case ContentPresentationMode.paragraphPlain:
        return Text(
          text,
          textAlign: textAlign,
          style: style ?? theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        );
      case ContentPresentationMode.markdown:
        return MarkdownBody(
          data: downgradeLatex(text),
          extensionSet: md.ExtensionSet.gitHubFlavored,
          styleSheet: _markdownStyleSheet(theme),
        );
    }
  }

  MarkdownStyleSheet _markdownStyleSheet(ThemeData theme) {
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 16, height: 1.6);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ) ??
        TextStyle(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        );
    return MarkdownStyleSheet(
      p: base,
      h1: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
      h2: theme.textTheme.titleLarge?.copyWith(height: 1.3),
      h3: theme.textTheme.titleMedium?.copyWith(height: 1.3),
      h4: theme.textTheme.titleSmall?.copyWith(height: 1.3),
      h5: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      h6: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.outline,
      ),
      blockquote: base.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      code: codeStyle,
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      listBullet: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      tableHead: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      tableBody: base,
      tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
      tableColumnWidth: const FlexColumnWidth(),
    );
  }
}
