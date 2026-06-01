import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';

enum HomeFeatureId { health, expenses, location, gameActivity, calendar, results }

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
    icon: Icons.health_and_safety_outlined,
    color: AppColors.health,
    route: AppRoutes.healthData,
  ),
  HomeFeature(
    id: HomeFeatureId.expenses,
    label: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
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
    id: HomeFeatureId.gameActivity,
    label: 'Game Activity',
    icon: Icons.sports_esports_outlined,
    color: AppColors.gameActivity,
    route: AppRoutes.gameActivity,
  ),
  HomeFeature(
    id: HomeFeatureId.calendar,
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    color: AppColors.calendar,
    route: AppRoutes.calendar,
  ),
  HomeFeature(
    id: HomeFeatureId.results,
    label: 'Results',
    icon: Icons.insights_outlined,
    color: AppColors.result,
    route: AppRoutes.results,
  ),
  
];
