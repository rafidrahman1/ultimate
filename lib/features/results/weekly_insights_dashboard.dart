import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/analysis_period.dart';
import 'insight_checklist_service.dart';
import '../../theme/app_theme.dart';
import 'insight_detail_overlay.dart';
import 'insight_models.dart';
import 'insight_parser.dart';
import 'insight_rich_text.dart';
import 'insights_parser.dart';
import 'weekly_checklist_panel.dart';

class WeeklyInsightsDashboard extends ConsumerWidget {
  const WeeklyInsightsDashboard({
    super.key,
    required this.report,
    required this.resultId,
    required this.generatedAt,
    required this.period,
    required this.markdownOutput,
    this.userName,
    this.dataSources = const {},
  });

  final InsightReport report;
  final String resultId;
  final DateTime generatedAt;
  final AnalysisPeriod period;
  final String markdownOutput;
  final String? userName;
  final Map<String, String> dataSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistReport = InsightParser.parse(markdownOutput);
    final name = userName?.trim().isNotEmpty == true
        ? userName!.trim()
        : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightsHeader(name: name, period: period),
        const SizedBox(height: 28),
        _SectionLabel(
          title: 'Patterns & anomalies',
          icon: Icons.auto_graph_outlined,
          accent: context.palette.warning,
        ),
        const SizedBox(height: 14),
        _PatternsPanel(report: report),
        if (checklistReport.actions.isNotEmpty) ...[
          const SizedBox(height: 32),
          WeeklyChecklistPanel(
            resultId: resultId,
            period: period,
            report: checklistReport,
            monthLabel: period.checklistMonthLabel,
          ),
        ] else if (report.allActions.isNotEmpty) ...[
          const SizedBox(height: 32),
          _LegacyActionChecklist(
            resultId: resultId,
            actions: report.allActions,
          ),
        ],
        if (dataSources.isNotEmpty) ...[
          const SizedBox(height: 28),
          _DataFootnote(sources: dataSources),
        ],
      ],
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader({required this.name, required this.period});

  final String name;
  final AnalysisPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rangeLabel = period.dataRangeLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey $name, here is your pulse check',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: context.palette.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monthly insights · ${period.checklistMonthLabel} checklist',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.palette.border),
          ),
          child: Text(
            rangeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.palette.accentAlt,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _PatternsPanel extends StatelessWidget {
  const _PatternsPanel({required this.report});

  final InsightReport report;

  @override
  Widget build(BuildContext context) {
    final sleep = report.sleepCard;
    final finance = report.financeCard;

    final children = <Widget>[];

    if (sleep != null) {
      children.add(_SleepPatternCard(data: sleep));
    }
    if (finance != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(_FinancePatternCard(data: finance));
    }
    if (children.isEmpty) {
      return _FallbackPatternList(report: report);
    }

    return Column(children: children);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SleepPatternCard extends StatelessWidget {
  const _SleepPatternCard({required this.data});

  final InsightSleepCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metric = data.metric.replaceAll('**', '');
    final detailBody = '$metric\n\n${data.narrative}';

    return InsightLongPressCard(
      detailTitle: 'Sleep & pulse',
      detailBody: detailBody,
      accent: data.showWarning
          ? context.palette.warning
          : context.palette.accentAlt,
      icon: Icons.bedtime_outlined,
      child: _InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep & pulse',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        metric,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.palette.textPrimary,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.showWarning)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: context.palette.warning,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.palette.warning,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              data.narrative,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancePatternCard extends StatelessWidget {
  const _FinancePatternCard({required this.data});

  final InsightFinanceCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spikeValue = _parseAmount(data.spikeAmount);
    final leakValue = _parseAmount(data.leakAmount);
    final maxBar = [spikeValue, leakValue, 1.0].reduce((a, b) => a > b ? a : b);

    final detailBody =
        '${data.leakAmount.replaceAll('**', '')} — ${data.leakLabel}\n'
        '${data.spikeAmount.replaceAll('**', '')} — ${data.spikeLabel}';

    return InsightLongPressCard(
      detailTitle: 'Finances',
      detailBody: detailBody,
      accent: context.palette.accent,
      icon: Icons.account_balance_wallet_outlined,
      child: _InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finances',
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.leakAmount.replaceAll('**', ''),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.palette.accent,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.leakLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: leakValue / maxBar,
                          minHeight: 5,
                          backgroundColor: context.palette.border,
                          color: context.palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        data.spikeAmount.replaceAll('**', ''),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.spikeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: spikeValue / maxBar,
                          minHeight: 5,
                          backgroundColor: context.palette.border,
                          color: context.palette.textMuted.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _parseAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(digits) ?? 1;
  }
}

class _FallbackPatternList extends StatelessWidget {
  const _FallbackPatternList({required this.report});

  final InsightReport report;

  @override
  Widget build(BuildContext context) {
    final bullets = report.allPatternBullets;
    if (bullets.isEmpty) {
      return Text(
        'No patterns detected in this run.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.palette.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < bullets.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < bullets.length - 1 ? 10 : 0),
            child: InsightLongPressCard(
              detailTitle: 'Pattern',
              detailBody: stripMarkdown(bullets[i].displayText),
              child: _InsightCard(
                child: Text(
                  stripMarkdown(bullets[i].displayText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegacyActionChecklist extends ConsumerWidget {
  const _LegacyActionChecklist({
    required this.resultId,
    required this.actions,
  });

  final String resultId;
  final List<({InsightBullet bullet, InsightDomain domain, String group})>
  actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const weekIndex = 0;
    final storageKey = insightChecklistStorageKey(resultId, weekIndex);
    final checked = ref.watch(insightChecklistProvider(storageKey));
    final done = checked.valueOrNull ?? {};

    return Column(
      children: actions.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isDone = done.contains(index);
        final accent = domainColor(item.domain);
        final title = item.bullet.headline ?? stripMarkdown(item.group);
        final subtitle = item.bullet.headline != null
            ? stripMarkdown(item.bullet.body)
            : stripMarkdown(item.bullet.displayText);
        final sleepGain = _sleepGainLabel(title, subtitle);

        final detailBody = subtitle.isNotEmpty ? '$title\n\n$subtitle' : title;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InsightLongPressCard(
            detailTitle: title,
            detailBody: detailBody,
            accent: accent,
            icon: domainIcon(item.domain, forActions: true),
            highlights: item.bullet.highlights,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref
                    .read(insightChecklistProvider(storageKey).notifier)
                    .toggle(index),
                child: _InsightCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CircleCheckbox(done: isDone, color: accent),
                      const SizedBox(width: 14),
                      Icon(
                        domainIcon(item.domain, forActions: true),
                        size: 22,
                        color: accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDone
                                    ? context.palette.textMuted
                                    : context.palette.textPrimary,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              HighlightedInsightText(
                                text: subtitle,
                                highlights: item.bullet.highlights,
                                highlightColor: accent,
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.palette.textSecondary,
                                  height: 1.45,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                            if (sleepGain != null) ...[
                              const SizedBox(height: 10),
                              _SleepGainChip(label: sleepGain),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String? _sleepGainLabel(String title, String subtitle) {
    final text = '$title $subtitle'.toLowerCase();
    if (!text.contains('sleep') && !text.contains('bedtime')) return null;
    final match = RegExp(r'(\d+)\s*minutes?').firstMatch(text);
    if (match != null) {
      return '+${match.group(1)} min sleep gain';
    }
    if (text.contains('30 minute')) return '+30 min sleep gain';
    if (text.contains('60 min') || text.contains('1 hour')) {
      return '+60 min sleep gain';
    }
    if (text.contains('bedtime')) return '+sleep window';
    return null;
  }
}

class _CircleCheckbox extends StatelessWidget {
  const _CircleCheckbox({required this.done, required this.color});

  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _SleepGainChip extends StatelessWidget {
  const _SleepGainChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.palette.accentAlt.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.palette.accentAlt.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 4,
            color: context.palette.textMuted,
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.palette.accentAlt,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.accentAlt,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataFootnote extends StatelessWidget {
  const _DataFootnote({required this.sources});

  final Map<String, String> sources;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[];
    void maybeAdd(String key, String label) {
      final v = sources[key]?.trim() ?? '';
      if (v.isNotEmpty && !v.toLowerCase().startsWith('no ')) labels.add(label);
    }

    maybeAdd('health', 'Health');
    maybeAdd('expenses', 'Expenses');
    maybeAdd('location', 'Location');
    maybeAdd('gameActivity', 'Gaming');
    maybeAdd('calendar', 'Calendar');

    if (labels.isEmpty) return const SizedBox.shrink();

    return Text(
      'Based on ${labels.join(', ')} data',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: context.palette.textMuted),
    );
  }
}
