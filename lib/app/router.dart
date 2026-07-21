import 'package:flutter/material.dart';

import 'package:personal/features/calendar/calendar_settings_screen.dart';
import 'package:personal/features/dashboard/dashboard_screen.dart';
import 'package:personal/features/health/health_settings_screen.dart';
import 'package:personal/features/settings/general_settings_screen.dart';
import 'package:personal/shell/main_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const dashboard = '/dashboard';
  static const healthSettings = '/health/settings';
  static const calendarSettings = '/calendar/settings';
  static const generalSettings = '/settings/general';

  static Widget screenFor(String route) {
    return switch (route) {
      home => const MainShell(),
      dashboard => const DashboardScreen(),
      healthSettings => const HealthSettingsScreen(),
      calendarSettings => const CalendarSettingsScreen(),
      generalSettings => const GeneralSettingsScreen(),
      _ => const MainShell(),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      home => MaterialPageRoute(builder: (_) => const MainShell()),
      dashboard => MaterialPageRoute(builder: (_) => const DashboardScreen()),
      healthSettings => MaterialPageRoute(
        builder: (_) => const HealthSettingsScreen(),
      ),
      calendarSettings => MaterialPageRoute(
        builder: (_) => const CalendarSettingsScreen(),
      ),
      generalSettings => MaterialPageRoute(
        builder: (_) => const GeneralSettingsScreen(),
      ),
      _ => MaterialPageRoute(builder: (_) => const MainShell()),
    };
  }
}
