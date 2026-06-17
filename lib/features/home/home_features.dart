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
    this.backgroundAsset,
  });

  final HomeFeatureId id;
  final String label;
  final String route;
  final String? backgroundAsset;

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
  ),
  HomeFeature(
    id: HomeFeatureId.health,
    label: 'Health',
    route: AppRoutes.healthData,
    backgroundAsset: 'assets/Health_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.expenses,
    label: 'Expenses',
    route: AppRoutes.expenses,
    backgroundAsset: 'assets/Expenses_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.location,
    label: 'Location',
    route: AppRoutes.location,
    backgroundAsset: 'assets/Location_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.gameActivity,
    label: 'Game Activity',
    route: AppRoutes.gameActivity,
    backgroundAsset: 'assets/GameActivity_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.calendar,
    label: 'Calendar',
    route: AppRoutes.calendar,
    backgroundAsset: 'assets/Calendar_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.prompt,
    label: 'Prompt',
    route: AppRoutes.analysisPrompt,
  ),
];
