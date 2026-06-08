import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

abstract final class AppSemanticColors {
  static DomainColors _domainColors(BuildContext context) =>
      context.domainColors;

  static Color health(BuildContext context) =>
      _domainColors(context).health;

  static Color expenses(BuildContext context) =>
      _domainColors(context).expenses;

  static Color mobility(BuildContext context) =>
      _domainColors(context).mobility;

  static Color location(BuildContext context) => mobility(context);

  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color accent(BuildContext context) => primary(context);

  static Color insights(BuildContext context) => primary(context);

  static Color result(BuildContext context) => insights(context);

  static Color gameActivity(BuildContext context) =>
      _domainColors(context).gameActivity;

  static Color calendar(BuildContext context) => mobility(context);

  static Color prompt(BuildContext context) => expenses(context);

  static Color forDomainName(String name, BuildContext context) {
    final normalized = name.toLowerCase();
    if (normalized.contains('health') || normalized.contains('sleep')) {
      return health(context);
    }
    if (normalized.contains('expense')) {
      return expenses(context);
    }
    if (normalized.contains('location') ||
        normalized.contains('mobility') ||
        normalized.contains('transport')) {
      return mobility(context);
    }
    if (normalized.contains('gaming') || normalized.contains('leisure')) {
      return gameActivity(context);
    }
    if (normalized.contains('calendar') || normalized.contains('schedule')) {
      return calendar(context);
    }
    return primary(context);
  }

  static Color forUnit(String unit, BuildContext context) {
    return switch (unit) {
      'BDT' => expenses(context),
      'steps/day' => health(context),
      'km' => mobility(context),
      'hours' => gameActivity(context),
      '%' || 'score' => primary(context),
      _ => primary(context),
    };
  }

  static Color forBulletTitle(String title, BuildContext context) {
    final normalized = title.toLowerCase();
    if (normalized.contains('gap') ||
        normalized.contains('sleep') ||
        normalized.contains('step')) {
      return health(context);
    }
    if (normalized.contains('spend') || normalized.contains('tech')) {
      return expenses(context);
    }
    if (normalized.contains('mobility')) {
      return mobility(context);
    }
    return primary(context);
  }

  static Color forDelta({
    required bool isPositive,
    required bool isNegative,
    required BuildContext context,
  }) {
    if (isPositive) return expenses(context);
    if (isNegative) return health(context);
    return mobility(context);
  }
}
