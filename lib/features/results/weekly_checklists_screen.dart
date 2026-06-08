import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';
import 'package:personal/features/results/weekly_checklist_panel.dart';

/// Checklist-only view for the monthly action plan (weekly segments).
class WeeklyChecklistsScreen extends ConsumerWidget {
  const WeeklyChecklistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(analysisResultsProvider);
    return resultsAsync.when(
      data: (results) => _buildBody(context, ref, results),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatusMessage(
        icon: Icons.error_outline,
        title: 'Could not load checklists',
        subtitle: error.toString(),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<AnalysisResult> results,
  ) {
    final withChecklist = analysisResultsWithChecklist(results);
    final storedId = ref.watch(selectedChecklistResultIdProvider);

    if (withChecklist.isEmpty) {
      return const StatusMessage(
        icon: Icons.playlist_add_check_outlined,
        title: 'No checklists yet',
        subtitle:
            'Run Analyze data after your monthly insight is ready.',
      );
    }

    final selectedId = resolveSelectedChecklistResultId(
      withChecklist: withChecklist,
      storedId: storedId,
    )!;
    if (storedId != selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedChecklistResultIdProvider.notifier).select(selectedId);
      });
    }
    final result = withChecklist.firstWhere((r) => r.id == selectedId);
    final report = InsightsReportParser.parse(result.output);
    final period = result.analysisPeriod;
    final monthLabel = period.checklistMonthLabel;
    final dateFormat = DateFormat('d MMM yyyy · HH:mm');

    // The weekly screen is rendered inside `MainShell`'s Scaffold, which has a
    // floating bottom pill navbar. Add extra bottom padding so the last items
    // remain scrollable above the nav pill.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomInset + extraBottomForNavPill,
      ),
      children: [
        Text(
          monthLabel,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.palette.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Generated ${dateFormat.format(result.createdAt.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        WeeklyChecklistPanel(
          resultId: result.id,
          period: period,
          report: report,
          monthLabel: monthLabel,
        ),
      ],
    );
  }
}
