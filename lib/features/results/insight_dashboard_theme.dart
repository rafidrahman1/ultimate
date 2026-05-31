import 'package:flutter/material.dart';

/// Visual tokens for the monthly insights dashboard (dark-first layout).
abstract final class InsightDashboardColors {
  static const canvas = Color(0xFF0B111E);
  static const card = Color(0xFF121A2B);
  static const cardElevated = Color(0xFF161F33);
  static const border = Color(0xFF1E293B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const warning = Color(0xFFF59E0B);
  static const accentBlue = Color(0xFF3B82F6);
  static const accentMint = Color(0xFF10B981);
}

ThemeData insightDashboardTheme(ThemeData base) {
  return base.copyWith(
    scaffoldBackgroundColor: InsightDashboardColors.canvas,
    cardColor: InsightDashboardColors.card,
    dividerColor: InsightDashboardColors.border,
    colorScheme: base.colorScheme.copyWith(
      surface: InsightDashboardColors.canvas,
      onSurface: InsightDashboardColors.textPrimary,
      onSurfaceVariant: InsightDashboardColors.textSecondary,
      outline: InsightDashboardColors.border,
      outlineVariant: InsightDashboardColors.border,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: InsightDashboardColors.canvas,
      foregroundColor: InsightDashboardColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: InsightDashboardColors.textPrimary,
      displayColor: InsightDashboardColors.textPrimary,
    ),
  );
}
