import 'package:flutter/material.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insight_detail_overlay.dart';
import 'package:personal/features/results/insight_rich_text.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/weekly_checklist_panel.dart';

/// Premium dark dashboard for structured AI insight markdown.
class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({
    super.key,
    required this.rawMarkdown,
    required this.resultId,
    required this.period,
    this.padding = EdgeInsets.zero,
  });

  final String rawMarkdown;
  final String resultId;
  final AnalysisPeriod period;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final report = InsightsReportParser.parse(rawMarkdown);
    if (report.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          'No structured insights to display.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
        ),
      );
    }

    final checklistMonth = period.checklistMonthLabel;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.anomalies.isNotEmpty) ...[
            _SectionHeading(
              title: 'Patterns & anomalies',
              icon: Icons.auto_graph_rounded,
              accent: context.palette.warning,
            ),
            const SizedBox(height: 14),
            ...report.anomalies.map(_AnomalyCard.new),
          ],
          if (report.actions.isNotEmpty) ...[
            if (report.anomalies.isNotEmpty) const SizedBox(height: 32),
            _SectionHeading(
              title: '$checklistMonth checklist',
              subtitle: 'One segment per week',
              icon: Icons.playlist_add_check_rounded,
              accent: context.palette.accentAlt,
            ),
            const SizedBox(height: 14),
            WeeklyChecklistPanel(
              resultId: resultId,
              period: period,
              report: report,
              monthLabel: checklistMonth,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard(this.anomaly);

  final InsightAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _AnomalyVisual.forAnomaly(anomaly, context.palette);
    final combined = '${anomaly.title} ${anomaly.description}';

    final detailBody =
        anomaly.description.isNotEmpty ? anomaly.description : anomaly.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InsightLongPressCard(
        detailTitle: anomaly.title,
        detailBody: detailBody,
        accent: visual.accent,
        icon: visual.icon,
        child: Card(
          margin: EdgeInsets.zero,
          color: context.palette.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: visual.borderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            anomaly.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.palette.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(label: anomaly.category, color: visual.accent),
                      ],
                    ),
                    if (anomaly.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      HighlightedInsightText(
                        text: anomaly.description,
                        highlightColor: visual.accent,
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                    if (_extractHighlights(combined).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _extractHighlights(combined)
                            .take(4)
                            .map(
                              (h) => _MetricChip(
                                label: h,
                                color: visual.accent,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

List<InsightItemCategory> _categoriesFor(List<ActionDirective> directives) {
  final seen = <InsightItemCategory>{};
  for (final action in directives) {
    seen.add(action.categoryEnum);
  }
  const order = [
    InsightItemCategory.health,
    InsightItemCategory.expenses,
    InsightItemCategory.transport,
    InsightItemCategory.general,
  ];
  return order.where(seen.contains).toList();
}

String? _groupHeaderFor(
  List<ActionDirective> directives,
  InsightItemCategory category,
) {
  for (final action in directives) {
    if (action.categoryEnum != category) continue;
    if (action.groupLabel != null && action.groupLabel!.isNotEmpty) {
      return action.groupLabel;
    }
  }
  return null;
}

int _globalOffsetForCategory(
  List<ActionDirective> directives,
  List<InsightItemCategory> categories,
  int tabIndex,
) {
  var offset = 0;
  for (var i = 0; i < tabIndex; i++) {
    offset += directives
        .where((a) => a.categoryEnum == categories[i])
        .length;
  }
  return offset;
}

/// Groups [directives] by domain when multiple categories are present.
class InsightsGroupedActionList extends StatelessWidget {
  const InsightsGroupedActionList({
    super.key,
    required this.directives,
    required this.checked,
    required this.onToggle,
  });

  final List<ActionDirective> directives;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesFor(directives);
    if (categories.isEmpty) {
      return InsightsActionList(
        directives: directives,
        globalOffset: 0,
        checked: checked,
        onToggle: onToggle,
      );
    }

    if (categories.length == 1) {
      return InsightsActionList(
        directives: directives,
        globalOffset: 0,
        checked: checked,
        onToggle: onToggle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _ActionGroupHeader(
            label: _groupHeaderFor(directives, categories[i]) ??
                categories[i].label,
            category: categories[i],
          ),
          const SizedBox(height: 8),
          InsightsActionList(
            directives: directives
                .where((a) => a.categoryEnum == categories[i])
                .toList(),
            globalOffset: _globalOffsetForCategory(directives, categories, i),
            checked: checked,
            onToggle: onToggle,
          ),
          if (i < categories.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _ActionGroupHeader extends StatelessWidget {
  const _ActionGroupHeader({required this.label, required this.category});

  final String label;
  final InsightItemCategory category;

  @override
  Widget build(BuildContext context) {
    final visual = _ActionVisual.forCategory(category, context.palette);
    return Row(
      children: [
        Icon(visual.icon, size: 18, color: visual.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

/// Checklist rows for a single week's action directives.
class InsightsActionList extends StatelessWidget {
  const InsightsActionList({
    super.key,
    required this.directives,
    required this.globalOffset,
    required this.checked,
    required this.onToggle,
  });

  final List<ActionDirective> directives;
  final int globalOffset;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (directives.isEmpty) {
      return Text(
        'No actions in this group.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < directives.length; i++)
          _ActionTile(
            directive: directives[i],
            index: globalOffset + i,
            checked: checked.contains(globalOffset + i),
            onToggle: () => onToggle(globalOffset + i),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.directive,
    required this.index,
    required this.checked,
    required this.onToggle,
  });

  final ActionDirective directive;
  final int index;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _ActionVisual.forCategory(directive.categoryEnum, context.palette);

    final detailBody = directive.description.isNotEmpty
        ? '${directive.title}\n\n${directive.description}'
        : directive.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InsightLongPressCard(
        detailTitle: directive.title,
        detailBody: detailBody,
        accent: visual.accent,
        icon: visual.icon,
        child: Material(
          color: context.palette.cardElevated,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: checked
                    ? visual.accent.withValues(alpha: 0.5)
                    : context.palette.border,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: _CheckCircle(done: checked, color: visual.accent),
              title: Text(
                directive.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: checked
                      ? context.palette.textMuted
                      : context.palette.textPrimary,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: directive.description.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: HighlightedInsightText(
                        text: directive.description,
                        highlightColor: visual.accent,
                        maxLines: 1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.45,
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
              trailing: Icon(visual.icon, color: visual.accent, size: 22),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done, required this.color});

  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.replaceAll('**', ''),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AnomalyVisual {
  const _AnomalyVisual({
    required this.icon,
    required this.accent,
    required this.borderColor,
  });

  final IconData icon;
  final Color accent;
  final Color borderColor;

  factory _AnomalyVisual.forAnomaly(InsightAnomaly anomaly, AppPalette palette) {
    final text = '${anomaly.title} ${anomaly.description}'.toLowerCase();

    if (_containsAny(text, const [
      'financial',
      'hemorrhage',
      'expense',
      'spending',
      'discretionary',
      'salary',
      'runway',
      'gift',
    ])) {
      final alert = text.contains('hemorrhage') || text.contains('critically');
      return _AnomalyVisual(
        icon: alert ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
        accent: palette.expenses,
        borderColor: palette.expenses.withValues(alpha: 0.45),
      );
    }

    if (_containsAny(text, const [
      'vespa',
      'fuel',
      'economy',
      'mileage',
      'carburetor',
      'transport',
      'mobility',
      'motorcycle',
      'location',
    ])) {
      return _AnomalyVisual(
        icon: text.contains('fuel') || text.contains('octane')
            ? Icons.local_gas_station_rounded
            : Icons.moped_rounded,
        accent: palette.mobility,
        borderColor: palette.mobility.withValues(alpha: 0.4),
      );
    }

    if (_containsAny(text, const [
      'sleep',
      'cardiovascular',
      'neat',
      'steps',
      'heart',
    ])) {
      final useBed = text.contains('sleep') || text.contains('bedtime');
      return _AnomalyVisual(
        icon: useBed ? Icons.bedtime_rounded : Icons.favorite_rounded,
        accent: useBed ? palette.warning : palette.health,
        borderColor: (useBed ? palette.warning : palette.health).withValues(alpha: 0.4),
      );
    }

    return _AnomalyVisual(
      icon: Icons.insights_rounded,
      accent: palette.accent,
      borderColor: palette.border,
    );
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

class _ActionVisual {
  const _ActionVisual({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  factory _ActionVisual.forCategory(InsightItemCategory category, AppPalette palette) {
    return switch (category) {
      InsightItemCategory.health => _ActionVisual(
          icon: Icons.bedtime_rounded,
          accent: palette.health,
        ),
      InsightItemCategory.expenses => _ActionVisual(
          icon: Icons.account_balance_wallet_rounded,
          accent: palette.expenses,
        ),
      InsightItemCategory.transport => _ActionVisual(
          icon: Icons.moped_rounded,
          accent: palette.mobility,
        ),
      InsightItemCategory.general => _ActionVisual(
          icon: Icons.task_alt_rounded,
          accent: palette.accent,
        ),
    };
  }
}

List<String> _extractHighlights(String text) {
  final highlights = <String>[];
  final seen = <String>{};
  for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(text)) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.contains(key)) continue;
    if (!RegExp(r'\d').hasMatch(value)) continue;
    seen.add(key);
    highlights.add(value);
  }
  return highlights;
}
