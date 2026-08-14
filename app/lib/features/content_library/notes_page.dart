/// 笔记: notes per sense, editable and removable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/gen/app_localizations.dart';

import '../../data/product_providers.dart';
import '../../ui/theme/scenelex_tokens.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notes = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notesTitle)),
      body: notes.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.notesLoadError(error))),
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Text(
                l10n.notesEmpty,
                style: TextStyle(color: Color(0xFF9A9AA4)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final note = data[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.senseId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kColorTealSignal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.noteText,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
