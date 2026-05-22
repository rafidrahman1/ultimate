import 'package:flutter/material.dart';

import '../features/health/health_data_screen.dart';
import '../features/health/health_settings_screen.dart';
import '../features/home/home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const healthData = '/health';
  static const healthSettings = '/health/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      home => MaterialPageRoute(builder: (_) => const HomeScreen()),
      healthData => MaterialPageRoute(builder: (_) => const HealthDataScreen()),
      healthSettings =>
        MaterialPageRoute(builder: (_) => const HealthSettingsScreen()),
      _ => MaterialPageRoute(builder: (_) => const HomeScreen()),
    };
  }
}
