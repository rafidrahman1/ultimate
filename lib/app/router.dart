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
import 'package:personal/features/settings/settings_screen.dart';

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
      _ => const MainShell(),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => screenFor(settings.name ?? home),
    );
  }
}
