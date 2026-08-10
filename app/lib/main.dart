import 'package:flutter/material.dart';

import 'shell/app_shell.dart';

void main() {
  runApp(const SceneLexApp());
}

class SceneLexApp extends StatelessWidget {
  const SceneLexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SceneLex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AppShell(),
    );
  }
}
