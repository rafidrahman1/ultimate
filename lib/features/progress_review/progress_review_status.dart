import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';

/// Shared status vocabulary for the progress review dashboard: replaces the
/// four separate, duplicated color switches that used to reuse domain/error
/// colors for opposite meanings (see app_theme.dart's StatusColors).
enum ReviewStatus { good, warning, critical, unverifiable, neutral }

Color reviewStatusColor(BuildContext context, ReviewStatus status) {
  final statusColors = context.statusColors;
  return switch (status) {
    ReviewStatus.good => statusColors.good,
    ReviewStatus.warning => statusColors.warning,
    ReviewStatus.critical => statusColors.critical,
    ReviewStatus.unverifiable => statusColors.neutral,
    ReviewStatus.neutral => statusColors.neutral,
  };
}

ReviewStatus reviewStatusFromLabel(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('improved')) return ReviewStatus.good;
  if (normalized.contains('partial')) return ReviewStatus.warning;
  if (normalized.contains('declined')) return ReviewStatus.critical;
  if (normalized.contains('unverifiable')) return ReviewStatus.unverifiable;
  return ReviewStatus.neutral;
}

ReviewStatus reviewStatusFromTone(VarianceTone tone) {
  return switch (tone) {
    VarianceTone.positive => ReviewStatus.good,
    VarianceTone.compliant => ReviewStatus.good,
    VarianceTone.neutral => ReviewStatus.neutral,
    VarianceTone.negative => ReviewStatus.critical,
  };
}

/// Score bands collapse to 3 (good/warning/critical) to match the
/// improved/partial/declined vocabulary used elsewhere on this screen.
ReviewStatus reviewStatusFromScore(int score) {
  if (score >= 76) return ReviewStatus.good;
  if (score >= 26) return ReviewStatus.warning;
  return ReviewStatus.critical;
}
