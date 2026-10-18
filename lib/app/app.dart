import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/core/theme/theme_mode_controller.dart';
import 'package:motohealth/shell/main_shell.dart';

class MotoHealthApp extends ConsumerWidget {
  const MotoHealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'MotoHealth',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

void runMotoHealthApp() {
  runApp(const ProviderScope(child: MotoHealthApp()));
}
