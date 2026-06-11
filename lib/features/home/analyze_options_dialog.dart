import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_launcher.dart';
import 'package:personal/features/results/analysis_service.dart';

/// Expands the AI analyze button into a compact options card.
Future<void> showAnalyzeOptionsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required BuildContext buttonContext,
}) async {
  final runState = ref.read(analysisRunProvider);
  if (runState.isRunning) return;

  await launchMonthlyInsightsAnalysis(context, ref);
}
