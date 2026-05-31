import 'package:flutter/material.dart';

import 'insight_dashboard_theme.dart';
import 'insight_detail_overlay.dart';
import 'insight_rich_text.dart';
import 'insights_models.dart';
import 'insights_parser.dart';

/// Premium dark dashboard for structured AI insight markdown.
class InsightsDashboard extends StatefulWidget {
  const InsightsDashboard({
    super.key,
    required this.rawMarkdown,
    this.padding = EdgeInsets.zero,
  });

  final String rawMarkdown;
  final EdgeInsets padding;

  @override
  State<InsightsDashboard> createState() => _InsightsDashboardState();
}

class _InsightsDashboardState extends State<InsightsDashboard> {
  late InsightsParsedReport _report;
  final _checkedActions = <int>{};

  @override
  void initState() {
    super.initState();
    _report = InsightParser.parse(widget.rawMarkdown);
  }

  @override
  void didUpdateWidget(covariant InsightsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawMarkdown != widget.rawMarkdown) {
      _report = InsightParser.parse(widget.rawMarkdown);
      _checkedActions.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_report.isEmpty) {
      return Padding(
        padding: widget.padding,
        child: Text(
          'No structured insights to display.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: InsightDashboardColors.textSecondary,
              ),
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_report.anomalies.isNotEmpty) ...[
            const _SectionHeading(
              title: 'Patterns & anomalies',
              icon: Icons.auto_graph_rounded,
              accent: InsightDashboardColors.warning,
            ),
            const SizedBox(height: 14),
            ..._report.anomalies.map(_AnomalyCard.new),
          ],
          if (_report.actions.isNotEmpty) ...[
            if (_report.anomalies.isNotEmpty) const SizedBox(height: 32),
            const _SectionHeading(
              title: 'Clear next actions',
              subtitle: 'Next month checklist',
              icon: Icons.playlist_add_check_rounded,
              accent: InsightDashboardColors.accentMint,
            ),
            const SizedBox(height: 14),
            _ActionsPanel(
              report: _report,
              checked: _checkedActions,
              onToggle: (index) {
                setState(() {
                  if (_checkedActions.contains(index)) {
                    _checkedActions.remove(index);
                  } else {
                    _checkedActions.add(index);
                  }
                });
              },
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
                  color: InsightDashboardColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: InsightDashboardColors.textMuted,
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
    final visual = _AnomalyVisual.forAnomaly(anomaly);
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
          color: InsightDashboardColors.card,
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
                              color: InsightDashboardColors.textPrimary,
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
                          color: InsightDashboardColors.textSecondary,
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

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({
    required this.report,
    required this.checked,
    required this.onToggle,
  });

  final InsightsParsedReport report;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final categories = report.actionCategories.toList();
    if (categories.isEmpty) {
      return _ActionList(
        directives: report.actions,
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
            label: _groupHeaderFor(report, categories[i]) ?? categories[i].label,
            category: categories[i],
          ),
          const SizedBox(height: 8),
          _ActionList(
            directives: report.actionsFor(categories[i]),
            globalOffset: _globalOffset(report, categories, i),
            checked: checked,
            onToggle: onToggle,
          ),
          if (i < categories.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }

  String? _groupHeaderFor(
    InsightsParsedReport report,
    InsightItemCategory category,
  ) {
    for (final action in report.actions) {
      if (action.categoryEnum != category) continue;
      if (action.groupLabel != null && action.groupLabel!.isNotEmpty) {
        return action.groupLabel;
      }
    }
    return null;
  }

  int _globalOffset(
    InsightsParsedReport report,
    List<InsightItemCategory> categories,
    int tabIndex,
  ) {
    var offset = 0;
    for (var i = 0; i < tabIndex; i++) {
      offset += report.actionsFor(categories[i]).length;
    }
    return offset;
  }

}

class _ActionGroupHeader extends StatelessWidget {
  const _ActionGroupHeader({required this.label, required this.category});

  final String label;
  final InsightItemCategory category;

  @override
  Widget build(BuildContext context) {
    final visual = _ActionVisual.forCategory(category);
    return Row(
      children: [
        Icon(visual.icon, size: 18, color: visual.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: InsightDashboardColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
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
              color: InsightDashboardColors.textMuted,
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
    final visual = _ActionVisual.forCategory(directive.categoryEnum);

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
          color: InsightDashboardColors.cardElevated,
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
                    : InsightDashboardColors.border,
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
                      ? InsightDashboardColors.textMuted
                      : InsightDashboardColors.textPrimary,
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
                          color: InsightDashboardColors.textSecondary,
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
        color: InsightDashboardColors.border.withValues(alpha: 0.6),
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

  static const _healthEmerald = Color(0xFF34D399);
  static const _healthAmber = Color(0xFFFBBF24);
  static const _financeCrimson = Color(0xFFEF4444);
  static const _transportCyan = Color(0xFF22D3EE);

  factory _AnomalyVisual.forAnomaly(InsightAnomaly anomaly) {
    final text = '${anomaly.title} ${anomaly.description}'.toLowerCase();

    if (_containsAny(text, const [
      'financial',
      'hemorrhage',
      'expense',
      'salary',
      'runway',
      'gift',
    ])) {
      final alert = text.contains('hemorrhage') || text.contains('critically');
      return _AnomalyVisual(
        icon: alert ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
        accent: _financeCrimson,
        borderColor: _financeCrimson.withValues(alpha: 0.45),
      );
    }

    if (_containsAny(text, const [
      'vespa',
      'fuel',
      'economy',
      'mileage',
      'carburetor',
      'transport',
    ])) {
      return _AnomalyVisual(
        icon: text.contains('fuel') || text.contains('octane')
            ? Icons.local_gas_station_rounded
            : Icons.moped_rounded,
        accent: _transportCyan,
        borderColor: _transportCyan.withValues(alpha: 0.4),
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
        accent: useBed ? _healthAmber : _healthEmerald,
        borderColor: (useBed ? _healthAmber : _healthEmerald).withValues(alpha: 0.4),
      );
    }

    return _AnomalyVisual(
      icon: Icons.insights_rounded,
      accent: InsightDashboardColors.accentBlue,
      borderColor: InsightDashboardColors.border,
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

  factory _ActionVisual.forCategory(InsightItemCategory category) {
    return switch (category) {
      InsightItemCategory.health => const _ActionVisual(
          icon: Icons.bedtime_rounded,
          accent: Color(0xFF34D399),
        ),
      InsightItemCategory.expenses => const _ActionVisual(
          icon: Icons.account_balance_wallet_rounded,
          accent: Color(0xFFEF4444),
        ),
      InsightItemCategory.transport => const _ActionVisual(
          icon: Icons.moped_rounded,
          accent: Color(0xFF22D3EE),
        ),
      InsightItemCategory.general => const _ActionVisual(
          icon: Icons.task_alt_rounded,
          accent: InsightDashboardColors.accentBlue,
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
