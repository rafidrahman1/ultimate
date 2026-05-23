import 'package:flutter/material.dart';

import '../features/chat/chat_data_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/health/health_data_screen.dart';
import '../features/health/health_settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/location/location_history_screen.dart';
import '../features/prompts/prompts_screen.dart';
import '../features/results/results_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const healthData = '/health';
  static const healthSettings = '/health/settings';
  static const expenses = '/expenses';
  static const locationHistory = '/location';
  static const chat = '/chat';
  static const prompts = '/prompts';
  static const results = '/results';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      home => MaterialPageRoute(builder: (_) => const HomeScreen()),
      healthData => MaterialPageRoute(builder: (_) => const HealthDataScreen()),
      healthSettings =>
        MaterialPageRoute(builder: (_) => const HealthSettingsScreen()),
      expenses => MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      locationHistory =>
        MaterialPageRoute(builder: (_) => const LocationHistoryScreen()),
      chat => MaterialPageRoute(builder: (_) => const ChatDataScreen()),
      prompts => MaterialPageRoute(builder: (_) => const PromptsScreen()),
      results => MaterialPageRoute(builder: (_) => const ResultsScreen()),
      _ => MaterialPageRoute(builder: (_) => const HomeScreen()),
    };
  }
}
