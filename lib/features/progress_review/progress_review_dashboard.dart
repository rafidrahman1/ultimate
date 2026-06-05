import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../results/insight_rich_text.dart';
import 'progress_review_models.dart';
import 'progress_review_parser.dart';

class ProgressReviewDashboard extends StatelessWidget {
  const ProgressReviewDashboard({
    super.key,
    required this.rawMarkdown,
    this.generatedAt,
    this.title,
  });

  final String rawMarkdown;
  final DateTime? generatedAt;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final report = ProgressReviewParser.parse(rawMarkdown);
    if (report.isEmpty) {
      return Text(
        'Could not parse this progress review.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || generatedAt != null) ...[
          _ReviewMetaHeader(title: title, generatedAt: generatedAt),
          const SizedBox(height: 20),
        ],
        if (_hasOverallSection(report)) ...[
          _SectionHeading(
            title: 'Overall improvement',
            icon: Icons.trending_up_rounded,
            accent: context.palette.accent,
          ),
          const SizedBox(height: 14),
          _OverallCard(report: report),
        ],
        if (report.domains.isNotEmpty) ...[
          const SizedBox(height: 32),
          _SectionHeading(
            title: 'Domain progress',
            icon: Icons.grid_view_rounded,
            accent: context.palette.accentAlt,
          ),
          const SizedBox(height: 14),
          ...report.domains.map(
            (domain) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DomainCard(domain: domain),
            ),
          ),
        ],
        if (report.whatWorked.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeading(
            title: 'What worked',
            icon: Icons.check_circle_outline_rounded,
            accent: AppColors.expenses,
          ),
          const SizedBox(height: 14),
          _BulletGroupCard(items: report.whatWorked),
        ],
        if (report.gaps.isNotEmpty) ...[
          const SizedBox(height: 32),
          _SectionHeading(
            title: 'Gaps & next focus',
            icon: Icons.flag_outlined,
            accent: context.palette.warning,
          ),
          const SizedBox(height: 14),
          _BulletGroupCard(items: report.gaps),
        ],
      ],
    );
  }

  bool _hasOverallSection(ProgressReviewParsedReport report) {
    return report.checklistAdherence != null ||
        report.dataBackedSummary != null ||
        report.overallScore != null;
  }
}

class _ReviewMetaHeader extends StatelessWidget {
  const _ReviewMetaHeader({this.title, this.generatedAt});

  final String? title;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          if (generatedAt != null) ...[
            if (title != null) const SizedBox(height: 6),
            Text(
              DateFormat('d MMM yyyy · HH:mm').format(generatedAt!.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
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
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.report});

  final ProgressReviewParsedReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final score = _extractScore(report.overallScore);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (score != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    '/100',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (report.checklistAdherence != null) ...[
            if (score != null) const SizedBox(height: 16),
            _MetricRow(
              label: 'Checklist adherence',
              value: report.checklistAdherence!,
            ),
          ],
          if (report.dataBackedSummary != null) ...[
            const SizedBox(height: 14),
            Text(
              'Summary',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            HighlightedInsightText(
              text: report.dataBackedSummary!,
              highlightColor: palette.accent,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
                height: 1.55,
              ),
            ),
          ],
          if (report.overallScore != null) ...[
            const SizedBox(height: 14),
            HighlightedInsightText(
              text: report.overallScore!,
              highlightColor: palette.accent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});

  final ProgressReviewDomain domain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final verdictColor = _verdictColor(context, domain.verdict);
    final score = _extractScore(domain.score);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  domain.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (domain.verdict != null) ...[
                const SizedBox(width: 8),
                _VerdictChip(label: domain.verdict!, color: verdictColor),
              ],
              if (score != null) ...[
                const SizedBox(width: 8),
                _ScoreChip(score: score),
              ],
            ],
          ),
          if (domain.checklistTarget != null) ...[
            const SizedBox(height: 14),
            _MetricRow(
              label: 'Checklist target',
              value: domain.checklistTarget!,
            ),
          ],
          if (domain.actualOutcome != null) ...[
            const SizedBox(height: 12),
            _MetricRow(
              label: 'Actual outcome',
              value: domain.actualOutcome!,
            ),
          ],
          if (domain.delta != null) ...[
            const SizedBox(height: 12),
            _MetricRow(
              label: 'Delta',
              value: domain.delta!,
              emphasize: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _BulletGroupCard extends StatelessWidget {
  const _BulletGroupCard({required this.items});

  final List<ProgressReviewBullet> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: palette.border, height: 1),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                if (items[i].description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  HighlightedInsightText(
                    text: items[i].description,
                    highlightColor: palette.accent,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        HighlightedInsightText(
          text: value,
          highlightColor: emphasize ? palette.warning : palette.accent,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            height: 1.5,
            fontWeight: emphasize ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
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

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        '$score',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

int? _extractScore(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,3})\s*/\s*100').firstMatch(raw);
  if (match != null) return int.tryParse(match.group(1)!);
  final plain = RegExp(r'^\d{1,3}$').firstMatch(raw.trim());
  if (plain != null) return int.tryParse(plain.group(0)!);
  return null;
}

Color _verdictColor(BuildContext context, String? verdict) {
  final scheme = Theme.of(context).colorScheme;
  final normalized = verdict?.trim().toLowerCase() ?? '';

  if (normalized.contains('improved')) return AppColors.expenses;
  if (normalized.contains('partial')) return scheme.tertiary;
  if (normalized.contains('declined')) return scheme.error;
  if (normalized.contains('unchanged')) return scheme.onSurfaceVariant;
  return scheme.outline;
}
