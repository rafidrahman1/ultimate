import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_period.dart';
import '../../core/period_range.dart';
import 'insight_checklist_service.dart';
import '../../theme/app_theme.dart';
import 'insights_dashboard.dart';
import 'insights_models.dart';

/// Weekly pager for the monthly action checklist with persisted check state.
class WeeklyChecklistPanel extends ConsumerStatefulWidget {
  const WeeklyChecklistPanel({
    super.key,
    required this.resultId,
    required this.period,
    required this.report,
    required this.monthLabel,
  });

  final String resultId;
  final AnalysisPeriod period;
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
      period: widget.period,
      weekCount: _weekCount,
      today: DateTime.now(),
    );
  }

  int get _weekCount {
    return math.max(widget.report.checklistWeekCount, widget.period.checklistWeekCount);
  }

  String _weekRangeLabel(int index) {
    if (index < widget.period.checklistWeeks.length) {
      final week = widget.period.checklistWeeks[index];
      return formatCompactPeriodRange(week.start, week.end);
    }
    return '';
  }

  List<ActionDirective> _actionsForWeek(int index) =>
      widget.report.actionsForWeekIndex(index);

  String? _weekThemeLabel(int index) => widget.report.themeForWeekIndex(index);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekPillBar(
          weekCount: _weekCount,
          selectedIndex: _weekIndex,
          rangeLabelFor: _weekRangeLabel,
          onSelected: (index) => setState(() => _weekIndex = index),
        ),
        if (_weekThemeLabel(_weekIndex) != null) ...[
          const SizedBox(height: 10),
          _WeekThemeChip(theme: _weekThemeLabel(_weekIndex)!),
        ],
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

class _WeekPillBar extends StatelessWidget {
  const _WeekPillBar({
    required this.weekCount,
    required this.selectedIndex,
    required this.rangeLabelFor,
    required this.onSelected,
  });

  final int weekCount;
  final int selectedIndex;
  final String Function(int index) rangeLabelFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < weekCount; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _WeekPill(
              weekLabel: 'Week ${i + 1}',
              rangeLabel: rangeLabelFor(i),
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekPill extends StatelessWidget {
  const _WeekPill({
    required this.weekLabel,
    required this.rangeLabel,
    required this.selected,
    required this.onTap,
  });

  final String weekLabel;
  final String rangeLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.palette.accentAlt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minWidth: 132),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.18)
                : context.palette.cardElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : context.palette.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? accent : context.palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rangeLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  rangeLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? accent.withValues(alpha: 0.9)
                        : context.palette.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekThemeChip extends StatelessWidget {
  const _WeekThemeChip({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accentAlt;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Theme: $theme',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
