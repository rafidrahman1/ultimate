import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/settings/widgets/month_picker_dialog.dart';

/// Lets the user choose which month Home, the dashboard and analysis cover.
Future<void> pickAnalysisMonth(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final currentMonth = ref.read(selectedAnalysisMonthProvider);
  final picked = await showMonthPicker(
    context: context,
    initialDate: currentMonth,
    firstDate: DateTime(2020, 1),
    lastDate: DateTime(DateTime.now().year + 1, 12),
    helpText: 'Choose analysis month',
  );
  if (picked == null || !context.mounted) return;
  await ref.read(selectedAnalysisMonthProvider.notifier).setMonth(picked);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Analysis month set to ${DateFormat('MMMM yyyy').format(picked)}',
      ),
    ),
  );
}
