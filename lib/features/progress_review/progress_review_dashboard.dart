import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/features/progress_review/progress_review_charts.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';

/// Progress review page: header score, domain breakdown, discrepancy matrix.
class ProgressReviewDashboard extends StatelessWidget {
  const ProgressReviewDashboard({super.key, required this.data});

  final ProgressReviewViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(data: data),
        const SizedBox(height: 24),
        _SectionLabel(
          title: 'Domain breakdown',
          icon: Icons.grid_view_rounded,
          accent: context.palette.accentAlt,
        ),
        const SizedBox(height: 14),
        ...data.domains.map(
          (domain) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DomainCard(domain: domain),
          ),
        ),
        const SizedBox(height: 12),
        _SectionLabel(
          title: 'Discrepancy matrix',
          icon: Icons.compare_arrows_rounded,
          accent: context.palette.warning,
        ),
        const SizedBox(height: 14),
        _DiscrepancyMatrix(rows: data.discrepancies),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final ProgressReviewViewData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.cardElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        'System ID · ${data.id}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ScoreRingChart(score: data.overallScore, size: 104, stroke: 11),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryCallout(summary: data.summary),
        ],
      ),
    );
  }
}

class _SummaryCallout extends StatelessWidget {
  const _SummaryCallout({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: palette.cardElevated,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: palette.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.summarize_rounded,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Core summary',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Domain breakdown cards
// ---------------------------------------------------------------------------

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});

  final DomainBreakdown domain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = _domainColor(context, domain.name);
    final excluded = domain.excluded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: excluded ? palette.canvas : palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: excluded ? palette.border : accent.withValues(alpha: 0.28),
        ),
      ),
      child: Opacity(
        opacity: excluded ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: excluded ? 0.10 : 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_domainIcon(domain.name), size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    domain.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: domain.status, excluded: excluded),
              ],
            ),
            if (excluded)
              _ExcludedBody(domain: domain)
            else
              _ScoredBody(domain: domain, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.excluded});

  final String status;
  final bool excluded;

  @override
  Widget build(BuildContext context) {
    final color = excluded
        ? context.palette.textMuted
        : _statusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoredBody extends StatelessWidget {
  const _ScoredBody({required this.domain, required this.accent});

  final DomainBreakdown domain;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: domain.progress,
                  minHeight: 10,
                  backgroundColor: palette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${domain.score}/100',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
        if (domain.metrics.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...domain.metrics.map((m) => _MetricLineTile(metric: m, accent: accent)),
        ],
        if (domain.warning != null) ...[
          const SizedBox(height: 12),
          _WarningBadge(text: domain.warning!),
        ],
      ],
    );
  }
}

class _ExcludedBody extends StatelessWidget {
  const _ExcludedBody({required this.domain});

  final DomainBreakdown domain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.cardElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, size: 16, color: palette.textMuted),
              const SizedBox(width: 8),
              Text(
                'Excluded from targets',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (domain.baselineStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Baseline stats',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ...domain.baselineStats.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      stat,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricLineTile extends StatelessWidget {
  const _MetricLineTile({required this.metric, required this.accent});

  final DomainMetricLine metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final flagColor = AppSemanticColors.health(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: metric.flagged
            ? flagColor.withValues(alpha: 0.10)
            : palette.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: metric.flagged
              ? flagColor.withValues(alpha: 0.4)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (metric.flagged) ...[
                Icon(Icons.warning_amber_rounded, size: 14, color: flagColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  metric.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: metric.flagged ? flagColor : palette.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textPrimary,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: metric.actual,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: '  vs  ',
                  style: TextStyle(color: palette.textMuted),
                ),
                TextSpan(
                  text: metric.target,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.report_problem_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discrepancy matrix
// ---------------------------------------------------------------------------

class _DiscrepancyMatrix extends StatelessWidget {
  const _DiscrepancyMatrix({required this.rows});

  final List<DiscrepancyRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          const _MatrixHeaderRow(),
          for (var i = 0; i < rows.length; i++)
            _MatrixDataRow(row: rows[i], isLast: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _MatrixHeaderRow extends StatelessWidget {
  const _MatrixHeaderRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 24, child: _HeaderCell('Domain')),
          Expanded(flex: 28, child: _HeaderCell('Benchmark')),
          Expanded(flex: 24, child: _HeaderCell('Actual')),
          Expanded(flex: 24, child: _HeaderCell('Variance')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.palette.textMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _MatrixDataRow extends StatelessWidget {
  const _MatrixDataRow({required this.row, required this.isLast});

  final DiscrepancyRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tone = _toneColor(context, row.tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 24,
            child: Text(
              row.domain,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              row.benchmark,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              row.actual,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Row(
              children: [
                Icon(_toneIcon(row.tone), size: 13, color: tone),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    row.variance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

Color _domainColor(BuildContext context, String name) {
  return AppSemanticColors.forDomainName(name, context);
}

IconData _domainIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('health') || n.contains('sleep')) return Icons.favorite_rounded;
  if (n.contains('expense')) return Icons.account_balance_wallet_rounded;
  if (n.contains('location') || n.contains('mobility')) {
    return Icons.route_rounded;
  }
  if (n.contains('gaming') || n.contains('leisure')) {
    return Icons.sports_esports_rounded;
  }
  if (n.contains('calendar') || n.contains('schedule')) {
    return Icons.calendar_month_rounded;
  }
  return Icons.insights_rounded;
}

Color _statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final n = status.toLowerCase();
  if (n.contains('improved')) return AppSemanticColors.expenses(context);
  if (n.contains('partial')) return scheme.tertiary;
  if (n.contains('declined')) return scheme.error;
  if (n.contains('unverifiable')) return AppSemanticColors.mobility(context);
  return context.palette.textMuted;
}

Color _toneColor(BuildContext context, VarianceTone tone) {
  return switch (tone) {
    VarianceTone.positive => AppSemanticColors.expenses(context),
    VarianceTone.compliant => AppSemanticColors.mobility(context),
    VarianceTone.neutral => context.palette.textMuted,
    VarianceTone.negative => Theme.of(context).colorScheme.error,
  };
}

IconData _toneIcon(VarianceTone tone) {
  return switch (tone) {
    VarianceTone.positive => Icons.trending_down_rounded,
    VarianceTone.compliant => Icons.check_circle_rounded,
    VarianceTone.neutral => Icons.trending_flat_rounded,
    VarianceTone.negative => Icons.trending_up_rounded,
  };
}
