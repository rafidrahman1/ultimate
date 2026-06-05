import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_period.dart';
import 'insight_checklist_service.dart';
import '../../theme/app_theme.dart';
import 'insights_dashboard.dart';
import 'insights_models.dart';

/// Weekly pager for the monthly action checklist with persisted check state.
class WeeklyChecklistPanel extends ConsumerStatefulWidget {
  const WeeklyChecklistPanel({
    super.key,
    required this.resultId,
    required this.generatedAt,
    required this.report,
    required this.monthLabel,
  });

  final String resultId;
  final DateTime generatedAt;
  final InsightsParsedReport report;
  final String monthLabel;

  @override
  ConsumerState<WeeklyChecklistPanel> createState() =>
      _WeeklyChecklistPanelState();
}

class _WeeklyChecklistPanelState extends ConsumerState<WeeklyChecklistPanel> {
  late int _weekIndex;

  @override
  void initState() {
    super.initState();
    _weekIndex = resolveDefaultChecklistWeekIndex(
      period: AnalysisPeriod.forReference(widget.generatedAt),
      weekCount: _weekCount,
      today: DateTime.now(),
    );
  }

  int get _weekCount {
    final period = AnalysisPeriod.forReference(widget.generatedAt);
    return math.max(widget.report.checklistWeekCount, period.checklistWeekCount);
  }

  String _weekTitle(int index) {
    final parsed = widget.report.weeks;
    if (index < parsed.length && parsed[index].title.trim().isNotEmpty) {
      return parsed[index].title;
    }
    final period = AnalysisPeriod.forReference(widget.generatedAt);
    if (index < period.checklistWeeks.length) {
      final week = period.checklistWeeks[index];
      return 'Week ${week.weekNumber} · ${week.rangeLabel}';
    }
    return 'Week ${index + 1}';
  }

  List<ActionDirective> _actionsForWeek(int index) =>
      widget.report.actionsForWeekIndex(index);

  @override
  Widget build(BuildContext context) {
    if (_weekCount == 0 || widget.report.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final storageKey =
        insightChecklistStorageKey(widget.resultId, _weekIndex);
    final checked = ref.watch(insightChecklistProvider(storageKey));
    final weekActions = _actionsForWeek(_weekIndex);
    final done = checked.valueOrNull ?? {};
    var doneCount = 0;
    for (var i = 0; i < weekActions.length; i++) {
      if (done.contains(i)) doneCount++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekSelectorCard(
          title: _weekTitle(_weekIndex),
          weekIndex: _weekIndex,
          weekCount: _weekCount,
          doneLabel: weekActions.isEmpty
              ? null
              : '$doneCount / ${weekActions.length}',
          onPrevious: _weekIndex > 0
              ? () => setState(() => _weekIndex--)
              : null,
          onNext: _weekIndex < _weekCount - 1
              ? () => setState(() => _weekIndex++)
              : null,
        ),
        const SizedBox(height: 14),
        if (weekActions.isEmpty)
          Text(
            'No actions for this week in the latest analysis.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
          )
        else
          InsightsGroupedActionList(
            directives: weekActions,
            checked: done,
            onToggle: (index) => ref
                .read(insightChecklistProvider(storageKey).notifier)
                .toggle(index),
          ),
      ],
    );
  }
}

class _WeekSelectorCard extends StatelessWidget {
  const _WeekSelectorCard({
    required this.title,
    required this.weekIndex,
    required this.weekCount,
    required this.onPrevious,
    required this.onNext,
    this.doneLabel,
  });

  final String title;
  final int weekIndex;
  final int weekCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            color: onPrevious == null
                ? context.palette.textMuted
                : context.palette.textPrimary,
            tooltip: 'Previous week',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Week ${weekIndex + 1} of $weekCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                if (doneLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    doneLabel!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: context.palette.accentAlt,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: onNext == null
                ? context.palette.textMuted
                : context.palette.textPrimary,
            tooltip: 'Next week',
          ),
        ],
      ),
    );
  }
}
