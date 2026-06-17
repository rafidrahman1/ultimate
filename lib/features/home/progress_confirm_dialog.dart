import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/features/home/analysis_confirm_context.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/results/checklist_prompt_builder.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';

class ProgressReviewRequest {
  const ProgressReviewRequest({
    required this.selection,
    required this.checklistSource,
  });

  final AnalysisSourceSelection selection;
  final AnalysisResult checklistSource;
}

/// Shows checklist source, completion, and data sources for a progress review.
Future<ProgressReviewRequest?> showProgressConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AnalysisResult checklistSource,
}) async {
  final checklistPeriod = checklistSource.analysisPeriod;

  final parsed = InsightsReportParser.parse(checklistSource.output);
  final completion = await loadChecklistCompletionForResult(
    checklistSource.id,
    parsed.checklistWeekCount,
  );
  final completionSummary = buildChecklistCompletionSummary(
    report: parsed,
    completionByWeek: completion,
  );

  if (!context.mounted) return null;

  final preview = await loadAnalysisRunPreview(
    ref,
    context,
    onDeviceInsightLabel: 'On-device summary (no API call)',
  );
  if (preview == null) return null;
  if (!context.mounted) return null;

  final monthMatches = preview.period.dataMonthStart.year ==
          checklistPeriod.checklistMonthStart.year &&
      preview.period.dataMonthStart.month == checklistPeriod.checklistMonthStart.month;

  return showDialog<ProgressReviewRequest>(
    context: context,
    builder: (dialogContext) => _ProgressConfirmDialog(
      preview: preview,
      checklistSource: checklistSource,
      checklistMonthLabel: checklistPeriod.checklistMonthLabel,
      completionSummary: completionSummary,
      monthAligned: monthMatches,
    ),
  );
}

class _ProgressConfirmDialog extends StatefulWidget {
  const _ProgressConfirmDialog({
    required this.preview,
    required this.checklistSource,
    required this.checklistMonthLabel,
    required this.completionSummary,
    required this.monthAligned,
  });

  final AnalysisRunPreview preview;
  final AnalysisResult checklistSource;
  final String checklistMonthLabel;
  final String completionSummary;
  final bool monthAligned;

  @override
  State<_ProgressConfirmDialog> createState() => _ProgressConfirmDialogState();
}

class _ProgressConfirmDialogState extends State<_ProgressConfirmDialog> {
  late final Set<AnalysisDataSourceId> _included = {
    for (final source in widget.preview.sources)
      if (source.hasData) source.id,
  };

  void _toggle(AnalysisDataSourceId id, bool? checked) {
    setState(() {
      if (checked == true) {
        _included.add(id);
      } else {
        _included.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;
    final monthLabel =
        DateFormat('MMMM yyyy').format(preview.period.dataMonthStart);
    final canRun = !preview.healthLoading && _included.isNotEmpty;

    return AlertDialog(
      title: const Text('Review checklist progress'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compare checklist targets against current-month data.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Checklist source',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.checklistSource.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Targets: ${widget.checklistMonthLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              widget.completionSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Current data: $monthLabel',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Data window: ${preview.period.dataRangeLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!widget.monthAligned) ...[
              const SizedBox(height: 12),
              Text(
                'Note: checklist targets ${widget.checklistMonthLabel}, but '
                'current data is $monthLabel. The AI will still compare what it can.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Include in this run',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final source in preview.sources)
              _SourceCheckboxRow(
                source: source,
                included: _included.contains(source.id),
                onChanged: (checked) => _toggle(source.id, checked),
              ),
            const SizedBox(height: 12),
            Text(
              preview.insightEngineLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_included.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Select at least one source to run the review.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canRun
              ? () => Navigator.pop(
                    context,
                    ProgressReviewRequest(
                      selection: AnalysisSourceSelection(Set.from(_included)),
                      checklistSource: widget.checklistSource,
                    ),
                  )
              : null,
          child: const Text('Review progress'),
        ),
      ],
    );
  }
}

class _SourceCheckboxRow extends StatelessWidget {
  const _SourceCheckboxRow({
    required this.source,
    required this.included,
    required this.onChanged,
  });

  final AnalysisDataSourcePreview source;
  final bool included;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = !included;

    return CheckboxListTile(
      value: included,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(
        source.icon,
        size: 20,
        color: analysisSourceColor(context, source.id),
      ),
      title: Text(
        source.label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: muted ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        source.detail,
        style: theme.textTheme.bodySmall?.copyWith(
          color: muted ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
    );
  }
}
