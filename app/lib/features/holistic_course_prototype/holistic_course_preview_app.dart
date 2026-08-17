/// Holistic Course preview entry: the dev prototype behind
/// `--dart-define=SCENELEX_HOLISTIC_COURSE_PREVIEW=<sense>`.
///
/// Loads the deterministic lowering of the generated Holistic Course
/// Package (`assets/content/holistic-course-preview/<sense>.json`) and runs
/// its `learning_flow` + `review_progression` strictly in order. No login,
/// no server, no sync. The production App and the other previews are
/// untouched; only [main] switches on this define.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/scenelex_tokens.dart';
import 'holistic_course_models.dart';
import 'holistic_course_preview_page.dart';

class HolisticCoursePreviewApp extends StatelessWidget {
  const HolisticCoursePreviewApp({super.key, required this.senseId});

  final String senseId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildSceneLexTheme(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _HolisticPreviewBoot(senseId: senseId),
    );
  }
}

class _HolisticPreviewBoot extends StatefulWidget {
  const _HolisticPreviewBoot({required this.senseId});

  final String senseId;

  @override
  State<_HolisticPreviewBoot> createState() => _HolisticPreviewBootState();
}

class _HolisticPreviewBootState extends State<_HolisticPreviewBoot> {
  late final Future<HolisticCourse> _course;

  @override
  void initState() {
    super.initState();
    SemanticsBinding.instance.ensureSemantics();
    _course = _load();
  }

  /// Dev-only URL parameters for web screenshots / demos:
  /// `?step=<index>` jumps to that step, `?dev=0` hides dev chrome,
  /// `?view=overview` auto-opens the developer overview sheet.
  /// They only position the preview — they never change the course.
  Map<String, String> get _query => Uri.base.queryParameters;

  Future<HolisticCourse> _load() async {
    final raw = await rootBundle.loadString(
      'assets/content/holistic-course-preview/${widget.senseId}.json',
    );
    return HolisticCourse.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HolisticCourse>(
      future: _course,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Holistic course load failed: ${snapshot.error}'),
              ),
            ),
          );
        }
        return HolisticCoursePreviewPage(
          course: snapshot.data!,
          devMode: _query['dev'] != '0',
          initialStepIndex: int.tryParse(_query['step'] ?? '') ?? 0,
          autoOpenOverview: _query['view'] == 'overview',
        );
      },
    );
  }
}
