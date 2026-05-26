import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'insight_checklist_service.dart';
import 'insight_dashboard_theme.dart';
import 'insight_detail_overlay.dart';
import 'insight_models.dart';
import 'insight_parser.dart';
import 'insight_rich_text.dart';

class WeeklyInsightsDashboard extends ConsumerWidget {
  const WeeklyInsightsDashboard({
    super.key,
    required this.report,
    required this.resultId,
    required this.generatedAt,
    this.userName,
    this.dataSources = const {},
  });

  final InsightReport report;
  final String resultId;
  final DateTime generatedAt;
  final String? userName;
  final Map<String, String> dataSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = report.allActions;
    final checked = ref.watch(insightChecklistProvider(resultId));
    final doneCount = checked.valueOrNull?.length ?? 0;
    final name = userName?.trim().isNotEmpty == true ? userName!.trim() : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsightsHeader(name: name, generatedAt: generatedAt),
        const SizedBox(height: 28),
        _SectionLabel(
          title: 'Patterns & anomalies',
          icon: Icons.auto_graph_outlined,
          accent: InsightDashboardColors.warning,
        ),
        const SizedBox(height: 14),
        _PatternsPanel(report: report),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 32),
          _SectionLabel(
            title: '7-day action plan',
            icon: Icons.check_circle_outline,
            accent: InsightDashboardColors.accentMint,
            trailing: doneCount == 0
                ? null
                : '$doneCount / ${actions.length}',
          ),
          const SizedBox(height: 14),
          _ActionChecklist(
            resultId: resultId,
            actions: actions,
            checked: checked,
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
  const _InsightsHeader({required this.name, required this.generatedAt});

  final String name;
  final DateTime generatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = generatedAt.subtract(const Duration(days: 14));
    final rangeLabel =
        '${DateFormat('MMM d').format(start.toLocal())} – ${DateFormat('MMM d').format(generatedAt.toLocal())}';

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
                  color: InsightDashboardColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Weekly insights & action plan',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: InsightDashboardColors.textSecondary,
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
            color: InsightDashboardColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: InsightDashboardColors.border),
          ),
          child: Text(
            rangeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: InsightDashboardColors.textSecondary,
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
              color: InsightDashboardColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: InsightDashboardColors.accentMint,
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
    final mobility = report.mobilityCard;

    final children = <Widget>[];

    if (sleep != null) {
      children.add(_SleepPatternCard(data: sleep));
    }
    if (finance != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(_FinancePatternCard(data: finance));
    }
    if (mobility != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(_MobilityPatternCard(data: mobility));
    }

    if (children.isEmpty) {
      return _FallbackPatternList(report: report);
    }

    return Column(children: children);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: InsightDashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InsightDashboardColors.border),
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
          ? InsightDashboardColors.warning
          : InsightDashboardColors.accentMint,
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
                        color: InsightDashboardColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      metric,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: InsightDashboardColors.textPrimary,
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
                  decoration: const BoxDecoration(
                    color: InsightDashboardColors.warning,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: InsightDashboardColors.warning,
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
                color: InsightDashboardColors.textSecondary,
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
      accent: InsightDashboardColors.accentBlue,
      icon: Icons.account_balance_wallet_outlined,
      child: _InsightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finances',
            style: theme.textTheme.labelLarge?.copyWith(
              color: InsightDashboardColors.textSecondary,
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
                        color: InsightDashboardColors.accentBlue,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.leakLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: InsightDashboardColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: leakValue / maxBar,
                        minHeight: 5,
                        backgroundColor: InsightDashboardColors.border,
                        color: InsightDashboardColors.accentBlue,
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
                        color: InsightDashboardColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.spikeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: InsightDashboardColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: spikeValue / maxBar,
                        minHeight: 5,
                        backgroundColor: InsightDashboardColors.border,
                        color: InsightDashboardColors.textMuted.withValues(alpha: 0.45),
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

class _MobilityPatternCard extends StatelessWidget {
  const _MobilityPatternCard({required this.data});

  final InsightMobilityCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _buildSummary(data);

    return InsightLongPressCard(
      detailTitle: 'Mobility context',
      detailBody: summary,
      accent: InsightDashboardColors.accentBlue,
      icon: Icons.two_wheeler_outlined,
      child: _InsightCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: InsightDashboardColors.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: InsightDashboardColors.accentBlue.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.two_wheeler_outlined,
              color: InsightDashboardColors.accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobility context',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: InsightDashboardColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: InsightDashboardColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _buildSummary(InsightMobilityCardData data) {
    if (data.tripCount != null && data.distanceKm != null) {
      final steps = data.stepAverage != null ? '${data.stepAverage} steps' : 'low steps';
      final fuel = data.fuelAmount != null ? '${data.fuelAmount} BDT fuel loop' : 'steady fuel spend';
      return '${data.tripCount} trips (${data.distanceKm} km) logged. '
          'Explains your $fuel and $steps.';
    }
    return data.narrative;
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
              color: InsightDashboardColors.textSecondary,
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
                        color: InsightDashboardColors.textSecondary,
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

class _ActionChecklist extends ConsumerWidget {
  const _ActionChecklist({
    required this.resultId,
    required this.actions,
    required this.checked,
  });

  final String resultId;
  final List<({InsightBullet bullet, InsightDomain domain, String group})> actions;
  final AsyncValue<Set<int>> checked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

        final detailBody =
            subtitle.isNotEmpty ? '$title\n\n$subtitle' : title;

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
                onTap: checked.isLoading
                    ? null
                    : () => ref.read(insightChecklistProvider(resultId).notifier).toggle(index),
                child: _InsightCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  ? InsightDashboardColors.textMuted
                                  : InsightDashboardColors.textPrimary,
                              decoration: isDone ? TextDecoration.lineThrough : null,
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
                                color: InsightDashboardColors.textSecondary,
                                height: 1.45,
                                decoration: isDone ? TextDecoration.lineThrough : null,
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
    if (text.contains('60 min') || text.contains('1 hour')) return '+60 min sleep gain';
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
        color: InsightDashboardColors.accentMint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InsightDashboardColors.accentMint.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 28, height: 4, color: InsightDashboardColors.textMuted),
          const SizedBox(width: 6),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: InsightDashboardColors.accentMint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: InsightDashboardColors.accentMint,
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
    maybeAdd('commute', 'Commute');
    maybeAdd('chat', 'Chat');

    if (labels.isEmpty) return const SizedBox.shrink();

    return Text(
      'Based on ${labels.join(', ')} data',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: InsightDashboardColors.textMuted,
          ),
    );
  }
}
