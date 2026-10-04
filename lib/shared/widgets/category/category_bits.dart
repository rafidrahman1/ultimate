import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insight_detail_overlay.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// "Today", "Yesterday", or "Mon 3 Oct".
String dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE d MMM').format(day);
}

/// Overline title above a block of a category page.
class CategoryTitle extends StatelessWidget {
  const CategoryTitle(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(), style: context.sectionLabel),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled raised card holding a chart or breakdown.
class CategoryPanel extends StatelessWidget {
  const CategoryPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryTitle(title, trailing: trailing),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// A day's group in a list: heading with an optional total, then the rows
/// in one shared card separated by hairlines.
class DayGroup extends StatelessWidget {
  const DayGroup({
    super.key,
    required this.date,
    required this.children,
    this.total,
    this.accent,
  });

  final DateTime date;
  final String? total;
  final Color? accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel(date),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                if (total != null)
                  Text(
                    total!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent ?? palette.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 16, color: palette.border),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits [items] into per-day groups, newest day first.
List<MapEntry<DateTime, List<T>>> groupByDay<T>(
  Iterable<T> items,
  DateTime Function(T item) dateOf, {
  bool newestFirst = true,
}) {
  final groups = <DateTime, List<T>>{};
  for (final item in items) {
    final d = dateOf(item);
    groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(item);
  }
  final entries = groups.entries.toList()
    ..sort(
      (a, b) => newestFirst ? b.key.compareTo(a.key) : a.key.compareTo(b.key),
    );
  return entries;
}

/// A single list row: tinted icon, two text lines, trailing value.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.detail,
    this.trailing,
    this.trailingColor,
    this.muted = false,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;

  /// Optional third line, clamped to two lines.
  final String? detail;
  final String? trailing;
  final Color? trailingColor;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = muted ? palette.textMuted : accent;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: AppOpacity.medium),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Icon(icon, size: 18, color: tone),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: muted ? palette.textMuted : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                trailing!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: trailingColor ?? (muted ? palette.textMuted : null),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the exact text that is sent to the AI for this source.
class AnalysisDataLink extends StatelessWidget {
  const AnalysisDataLink({
    super.key,
    required this.promptText,
    required this.title,
    required this.accent,
    required this.icon,
  });

  final String promptText;
  final String title;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      tier: AppCardTier.flat,
      onTap: () => showInsightDetailOverlay(
        context,
        title: title,
        body: promptText,
        accent: accent,
        icon: icon,
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 20, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data sent to analysis',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'See exactly what the AI receives for this source',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
        ],
      ),
    );
  }
}

/// Label, value and a proportional bar, e.g. a spending category.
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    super.key,
    required this.items,
    required this.color,
    this.maxItems = 6,
  });

  final List<({String label, double value, String display})> items;
  final Color color;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final shown = items.take(maxItems).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final maxValue = shown.map((i) => i.value).reduce((a, b) => a > b ? a : b);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
            child: Semantics(
              label: '${shown[i].label}: ${shown[i].display}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 2,
                    children: [
                      Text(
                        shown[i].label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        shown[i].display,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxValue == 0
                            ? 0
                            : (shown[i].value / maxValue).clamp(0.03, 1.0),
                      ),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: palette.border,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (items.length > maxItems)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              '+${items.length - maxItems} more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
