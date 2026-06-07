import 'package:flutter/material.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/calendar/calendar_settings_screen.dart';
import '../features/game_activity/game_activity_settings_screen.dart';
import '../features/game_activity/game_activity_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/expenses/expenses_settings_screen.dart';
import '../features/health/health_data_screen.dart';
import '../features/health/health_settings_screen.dart';
import '../shell/main_shell.dart';
import '../features/location/location_screen.dart';
import '../features/location/location_settings_screen.dart';
import '../features/prompts/personal_information_screen.dart';
import '../features/prompts/prompts_screen.dart';
import '../features/results/results_settings_screen.dart';
import '../features/settings/general_settings_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const healthData = '/health';
  static const healthSettings = '/health/settings';
  static const expenses = '/expenses';
  static const expensesSettings = '/expenses/settings';
  static const location = '/location';
  static const locationSettings = '/location/settings';
  static const personalInformation = '/personal-information';
  static const prompts = '/prompts';
  static const gameActivity = '/game-activity';
  static const gameActivitySettings = '/game-activity/settings';
  static const calendar = '/calendar';
  static const calendarSettings = '/calendar/settings';
  static const resultsSettings = '/results/settings';
  static const generalSettings = '/settings/general';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      home => MaterialPageRoute(builder: (_) => const MainShell()),
      healthData => MaterialPageRoute(builder: (_) => const HealthDataScreen()),
      healthSettings => MaterialPageRoute(
        builder: (_) => const HealthSettingsScreen(),
      ),
      expenses => MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      expensesSettings => MaterialPageRoute(
        builder: (_) => const ExpensesSettingsScreen(),
      ),
      location => MaterialPageRoute(builder: (_) => const LocationScreen()),
      locationSettings => MaterialPageRoute(
        builder: (_) => const LocationSettingsScreen(),
      ),
      personalInformation => MaterialPageRoute(
        builder: (_) => const PersonalInformationScreen(),
      ),
      prompts => MaterialPageRoute(builder: (_) => const PromptsScreen()),
      gameActivity =>
        MaterialPageRoute(builder: (_) => const GameActivityScreen()),
      gameActivitySettings => MaterialPageRoute(
        builder: (_) => const GameActivitySettingsScreen(),
      ),
      calendar => MaterialPageRoute(builder: (_) => const CalendarScreen()),
      calendarSettings => MaterialPageRoute(
        builder: (_) => const CalendarSettingsScreen(),
      ),
      resultsSettings => MaterialPageRoute(
        builder: (_) => const ResultsSettingsScreen(),
      ),
      generalSettings => MaterialPageRoute(
        builder: (_) => const GeneralSettingsScreen(),
      ),
      _ => MaterialPageRoute(builder: (_) => const MainShell()),
    };
  }
}
