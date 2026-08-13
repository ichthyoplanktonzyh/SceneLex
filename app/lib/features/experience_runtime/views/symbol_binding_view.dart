/// Symbol binding view: the first moment the L2 word appears.
///
/// Only after every concept unit has been answered. Shows reveal data and
/// offers pronunciation via TTS.
library;

import 'package:flutter/material.dart';

import '../../../domain/experience_program/symbol_binding.dart';
import '../../../l10n/gen/app_localizations.dart';

class SymbolBindingView extends StatelessWidget {
  const SymbolBindingView({
    super.key,
    required this.reveal,
    this.minimalL1Gloss,
    this.onPronounce,
  });

  final Reveal reveal;
  final String? minimalL1Gloss;

  /// Optional pronunciation hook; the button is hidden when absent
  /// (widget tests do not touch TTS).
  final VoidCallback? onPronounce;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.motion_photos_on, size: 40, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                reveal.l2Word,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '/${reveal.ipa}/',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onPronounce != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onPronounce,
                  icon: const Icon(Icons.volume_up),
                  label: Text(l10n.experienceRuntimePronunciation),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                reveal.presentation,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 12),
              if (minimalL1Gloss != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    minimalL1Gloss!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
