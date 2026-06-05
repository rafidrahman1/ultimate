import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';

enum HomeFeatureId { health, expenses, location, gameActivity, calendar }

class HomeFeature {
  const HomeFeature({
    required this.id,
    required this.label,
    required this.color,
    required this.route,
    this.backgroundAsset,
  });

  final HomeFeatureId id;
  final String label;
  final Color color;
  final String route;
  final String? backgroundAsset;
}

const homeFeatures = [
  HomeFeature(
    id: HomeFeatureId.health,
    label: 'Health',
    color: AppColors.health,
    route: AppRoutes.healthData,
    backgroundAsset: 'assets/Health_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.expenses,
    label: 'Expenses',
    color: AppColors.expenses,
    route: AppRoutes.expenses,
    backgroundAsset: 'assets/Expenses_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.location,
    label: 'Location',
    color: AppColors.location,
    route: AppRoutes.location,
    backgroundAsset: 'assets/Location_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.gameActivity,
    label: 'Game Activity',
    color: AppColors.gameActivity,
    route: AppRoutes.gameActivity,
    backgroundAsset: 'assets/GameActivity_background.png',
  ),
  HomeFeature(
    id: HomeFeatureId.calendar,
    label: 'Calendar',
    color: AppColors.calendar,
    route: AppRoutes.calendar,
    backgroundAsset: 'assets/Calendar_background.png',
  ),
];
