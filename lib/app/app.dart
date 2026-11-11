import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/lifecycle/app_lifecycle_host.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';

class PersonalApp extends ConsumerWidget {
  const PersonalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppLifecycleHost(
      child: MaterialApp(
        title: 'Personal',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        initialRoute: AppRoutes.home,
        debugShowCheckedModeBanner: false,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}

void runPersonalApp() {
  runApp(
    ProviderScope(
      // A failed load is retried by the user (pull to refresh, Retry
      // buttons), not behind their back: an automatic retry would re-hit
      // Health Connect, Google and the AI provider on every failure.
      retry: (retryCount, error) => null,
      child: const PersonalApp(),
    ),
  );
}
