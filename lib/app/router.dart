import 'package:flutter/material.dart';

import 'package:personal/features/analysis/ui/analysis_prompt_screen.dart';
import 'package:personal/features/calendar/ui/calendar_screen.dart';
import 'package:personal/features/calendar/ui/calendar_settings_screen.dart';
import 'package:personal/features/dashboard/ui/dashboard_screen.dart';
import 'package:personal/features/expenses/ui/expenses_screen.dart';
import 'package:personal/features/game_activity/game_activity_screen.dart';
import 'package:personal/features/health/ui/health_data_screen.dart';
import 'package:personal/features/health/ui/health_settings_screen.dart';
import 'package:personal/features/location/ui/location_screen.dart';
import 'package:personal/features/prompts/personal_information_screen.dart';
import 'package:personal/features/prompts/prompts_screen.dart';
import 'package:personal/features/settings/general_settings_screen.dart';
import 'package:personal/features/settings/settings_screen.dart';
import 'package:personal/shell/main_shell.dart';

/// A part of the General settings screen a caller can open it scrolled to.
enum SettingsSection { storage, notifications, ai }

abstract final class AppRoutes {
  static const home = '/';
  static const dashboard = '/dashboard';
  static const healthData = '/health';
  static const healthSettings = '/health/settings';
  static const expenses = '/expenses';
  static const location = '/location';
  static const personalInformation = '/personal-information';
  static const prompts = '/prompts';
  static const gameActivity = '/game-activity';
  static const calendar = '/calendar';
  static const calendarSettings = '/calendar/settings';
  static const analysisPrompt = '/analysis-prompt';
  static const settings = '/settings';
  static const generalSettings = '/settings/general';

  static Widget screenFor(String route) {
    return switch (route) {
      home => const MainShell(),
      dashboard => const DashboardScreen(),
      healthData => const HealthDataScreen(),
      healthSettings => const HealthSettingsScreen(),
      expenses => const ExpensesScreen(),
      location => const LocationScreen(),
      personalInformation => const PersonalInformationScreen(),
      prompts => const PromptsScreen(),
      gameActivity => const GameActivityScreen(),
      calendar => const CalendarScreen(),
      calendarSettings => const CalendarSettingsScreen(),
      analysisPrompt => const AnalysisPromptScreen(),
      settings => const SettingsScreen(),
      generalSettings => const GeneralSettingsScreen(),
      _ => _UnknownRouteScreen(route),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => screenFor(settings.name ?? home),
    );
  }
}

/// Shown for a route name nobody registered, so a typo is visible instead of
/// quietly landing on Home.
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen(this.route);

  final String route;

  @override
  Widget build(BuildContext context) {
    assert(false, 'Unknown route: $route');
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('No screen for "$route".')),
    );
  }
}
