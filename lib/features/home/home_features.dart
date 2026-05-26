import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';

class HomeFeature {
  const HomeFeature({
    required this.label,
    required this.icon,
    required this.color,
    this.route,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? route;
}

const homeFeatures = [
  HomeFeature(
    label: 'Health',
    icon: Icons.health_and_safety,
    color: AppColors.health,
    route: AppRoutes.healthData,
  ),
  HomeFeature(
    label: 'Expenses',
    icon: Icons.account_balance_wallet,
    color: AppColors.expenses,
    route: AppRoutes.expenses,
  ),
  HomeFeature(
    label: 'Commute',
    icon: Icons.two_wheeler,
    color: AppColors.location,
    route: AppRoutes.commuteTracking,
  ),
  HomeFeature(
    label: 'Chat',
    icon: Icons.chat_bubble_outline,
    color: AppColors.chat,
    route: AppRoutes.chat,
  ),
  HomeFeature(
    label: 'Prompts',
    icon: Icons.auto_stories_outlined,
    color: AppColors.prompt,
    route: AppRoutes.prompts,
  ),
  HomeFeature(
    label: 'Results',
    icon: Icons.insights_outlined,
    color: AppColors.result,
    route: AppRoutes.results,
  ),
];
