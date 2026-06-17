import 'package:flutter/material.dart';

import 'package:personal/features/calendar/calendar_screen.dart';
import 'package:personal/features/dashboard/dashboard_screen.dart';
import 'package:personal/features/calendar/calendar_settings_screen.dart';
import 'package:personal/features/game_activity/game_activity_screen.dart';
import 'package:personal/features/expenses/expenses_screen.dart';
import 'package:personal/features/health/health_data_screen.dart';
import 'package:personal/features/health/health_settings_screen.dart';
import 'package:personal/features/home/analysis_prompt_screen.dart';
import 'package:personal/shell/main_shell.dart';
import 'package:personal/features/location/location_screen.dart';
import 'package:personal/features/prompts/personal_information_screen.dart';
import 'package:personal/features/prompts/prompts_screen.dart';
import 'package:personal/features/settings/general_settings_screen.dart';

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
      generalSettings => const GeneralSettingsScreen(),
      _ => const MainShell(),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      home => MaterialPageRoute(builder: (_) => const MainShell()),
      dashboard => MaterialPageRoute(builder: (_) => const DashboardScreen()),
      healthData => MaterialPageRoute(builder: (_) => const HealthDataScreen()),
      healthSettings => MaterialPageRoute(
        builder: (_) => const HealthSettingsScreen(),
      ),
      expenses => MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      location => MaterialPageRoute(builder: (_) => const LocationScreen()),
      personalInformation => MaterialPageRoute(
        builder: (_) => const PersonalInformationScreen(),
      ),
      prompts => MaterialPageRoute(builder: (_) => const PromptsScreen()),
      gameActivity =>
        MaterialPageRoute(builder: (_) => const GameActivityScreen()),
      calendar => MaterialPageRoute(builder: (_) => const CalendarScreen()),
      calendarSettings => MaterialPageRoute(
        builder: (_) => const CalendarSettingsScreen(),
      ),
      analysisPrompt => MaterialPageRoute(
        builder: (_) => const AnalysisPromptScreen(),
      ),
      generalSettings => MaterialPageRoute(
        builder: (_) => const GeneralSettingsScreen(),
      ),
      _ => MaterialPageRoute(builder: (_) => const MainShell()),
    };
  }
}
