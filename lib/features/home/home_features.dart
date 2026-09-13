import 'package:flutter/material.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';

enum HomeFeatureId {
  dashboard,
  health,
  expenses,
  location,
  gameActivity,
  calendar,
  prompt,
}

class HomeFeature {
  const HomeFeature({
    required this.id,
    required this.label,
    required this.route,
    required this.icon,
  });

  final HomeFeatureId id;
  final String label;
  final String route;
  final IconData icon;

  Color colorFor(BuildContext context) {
    return switch (id) {
      HomeFeatureId.dashboard => AppSemanticColors.insights(context),
      HomeFeatureId.health => AppSemanticColors.health(context),
      HomeFeatureId.expenses => AppSemanticColors.expenses(context),
      HomeFeatureId.location => AppSemanticColors.location(context),
      HomeFeatureId.gameActivity => AppSemanticColors.gameActivity(context),
      HomeFeatureId.calendar => AppSemanticColors.calendar(context),
      HomeFeatureId.prompt => AppSemanticColors.prompt(context),
    };
  }
}

const homeFeatures = [
  HomeFeature(
    id: HomeFeatureId.dashboard,
    label: 'Dashboard',
    route: AppRoutes.dashboard,
    icon: Icons.space_dashboard_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.health,
    label: 'Health',
    route: AppRoutes.healthData,
    icon: Icons.favorite_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.expenses,
    label: 'Expenses',
    route: AppRoutes.expenses,
    icon: Icons.account_balance_wallet_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.location,
    label: 'Location',
    route: AppRoutes.location,
    icon: Icons.route_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.gameActivity,
    label: 'Game Activity',
    route: AppRoutes.gameActivity,
    icon: Icons.sports_esports_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.calendar,
    label: 'Calendar',
    route: AppRoutes.calendar,
    icon: Icons.calendar_month_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.prompt,
    label: 'Prompt',
    route: AppRoutes.analysisPrompt,
    icon: Icons.auto_awesome_rounded,
  ),
];
