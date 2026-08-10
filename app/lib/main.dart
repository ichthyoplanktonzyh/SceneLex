import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_controller.dart';
import 'features/login/login_page.dart';
import 'shell/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: SceneLexApp()));
}

class SceneLexApp extends ConsumerWidget {
  const SceneLexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'SceneLex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: switch (auth.status) {
        AuthStatus.loading =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthStatus.signedOut => const LoginPage(),
        AuthStatus.signedIn => const AppShell(),
      },
    );
  }
}
