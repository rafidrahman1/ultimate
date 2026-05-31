import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analysis_period.dart';
import '../../widgets/status_message.dart';
import 'insight_dashboard_theme.dart';
import 'insights_parser.dart';
import 'results_service.dart';
import 'weekly_checklist_panel.dart';

/// Checklist-only view for the monthly action plan (weekly segments).
class WeeklyChecklistsScreen extends ConsumerStatefulWidget {
  const WeeklyChecklistsScreen({super.key});

  @override
  ConsumerState<WeeklyChecklistsScreen> createState() =>
      _WeeklyChecklistsScreenState();
}

class _WeeklyChecklistsScreenState extends ConsumerState<WeeklyChecklistsScreen> {
  String? _selectedResultId;

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(analysisResultsProvider);
    final baseTheme = Theme.of(context);

    return Theme(
      data: insightDashboardTheme(baseTheme),
      child: Scaffold(
        backgroundColor: InsightDashboardColors.canvas,
        appBar: AppBar(
          title: const Text('Weekly checklists'),
        ),
        body: resultsAsync.when(
          data: (results) => _buildBody(context, results),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatusMessage(
            icon: Icons.error_outline,
            title: 'Could not load checklists',
            subtitle: error.toString(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<AnalysisResult> results) {
    final withChecklist = results
        .where((r) => InsightParser.parse(r.output).actions.isNotEmpty)
        .toList();

    if (withChecklist.isEmpty) {
      return const StatusMessage(
        icon: Icons.playlist_add_check_outlined,
        title: 'No checklists yet',
        subtitle:
            'Run Analyze data from Home after your monthly insight is ready.',
      );
    }

    final selectedId = _selectedResultId ?? withChecklist.first.id;
    final result = withChecklist.firstWhere((r) => r.id == selectedId);
    final report = InsightParser.parse(result.output);
    final period = AnalysisPeriod.forReference(result.createdAt);
    final monthLabel = period.checklistMonthLabel;
    final dateFormat = DateFormat('d MMM yyyy · HH:mm');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (withChecklist.length > 1) ...[
          Text(
            'Analysis report',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: InsightDashboardColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _ReportSelector(
            results: withChecklist,
            selectedId: selectedId,
            dateFormat: dateFormat,
            onSelected: (id) => setState(() => _selectedResultId = id),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          monthLabel,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: InsightDashboardColors.textPrimary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Generated ${dateFormat.format(result.createdAt.toLocal())}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: InsightDashboardColors.textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        WeeklyChecklistPanel(
          resultId: result.id,
          generatedAt: result.createdAt,
          report: report,
          monthLabel: monthLabel,
        ),
      ],
    );
  }
}

class _ReportSelector extends StatelessWidget {
  const _ReportSelector({
    required this.results,
    required this.selectedId,
    required this.dateFormat,
    required this.onSelected,
  });

  final List<AnalysisResult> results;
  final String selectedId;
  final DateFormat dateFormat;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: InsightDashboardColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InsightDashboardColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          dropdownColor: InsightDashboardColors.cardElevated,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: InsightDashboardColors.textPrimary,
              ),
          items: [
            for (final result in results)
              DropdownMenuItem(
                value: result.id,
                child: Text(
                  '${result.title} · ${dateFormat.format(result.createdAt.toLocal())}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onSelected(id);
          },
        ),
      ),
    );
  }
}
