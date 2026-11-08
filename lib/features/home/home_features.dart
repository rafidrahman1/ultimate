import 'package:flutter/material.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';

enum HomeFeatureId {
  health,
  expenses,
  location,
  gameActivity,
  screenTime,
  calendar,
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
      HomeFeatureId.health => AppSemanticColors.health(context),
      HomeFeatureId.expenses => AppSemanticColors.expenses(context),
      HomeFeatureId.location => AppSemanticColors.location(context),
      HomeFeatureId.gameActivity => AppSemanticColors.gameActivity(context),
      HomeFeatureId.screenTime => AppSemanticColors.primary(context),
      HomeFeatureId.calendar => AppSemanticColors.calendar(context),
    };
  }
}

const homeFeatures = [
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
    id: HomeFeatureId.screenTime,
    label: 'Screen time',
    route: AppRoutes.screenTime,
    icon: Icons.hourglass_bottom_rounded,
  ),
  HomeFeature(
    id: HomeFeatureId.calendar,
    label: 'Calendar',
    route: AppRoutes.calendar,
    icon: Icons.calendar_month_rounded,
  ),
];
