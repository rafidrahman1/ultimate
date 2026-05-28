import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';

enum HomeFeatureId { health, expenses, location, chat, prompts, results }

class HomeFeature {
  const HomeFeature({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  final HomeFeatureId id;
  final String label;
  final IconData icon;
  final Color color;
  final String route;
}

const homeFeatures = [
  HomeFeature(
    id: HomeFeatureId.health,
    label: 'Health',
    icon: Icons.health_and_safety,
    color: AppColors.health,
    route: AppRoutes.healthData,
  ),
  HomeFeature(
    id: HomeFeatureId.expenses,
    label: 'Expenses',
    icon: Icons.account_balance_wallet,
    color: AppColors.expenses,
    route: AppRoutes.expenses,
  ),
  HomeFeature(
    id: HomeFeatureId.location,
    label: 'Location',
    icon: Icons.route_outlined,
    color: AppColors.location,
    route: AppRoutes.location,
  ),
  HomeFeature(
    id: HomeFeatureId.chat,
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    color: AppColors.chat,
    route: AppRoutes.chat,
  ),
  HomeFeature(
    id: HomeFeatureId.prompts,
    label: 'System Prompt',
    icon: Icons.tune_outlined,
    color: AppColors.prompt,
    route: AppRoutes.prompts,
  ),
  HomeFeature(
    id: HomeFeatureId.results,
    label: 'Results',
    icon: Icons.insights_outlined,
    color: AppColors.result,
    route: AppRoutes.results,
  ),
];
