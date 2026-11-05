import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/shared/widgets/data_source_status_view.dart';
import 'package:personal/shared/widgets/sparkline.dart';

/// One data source on Home: icon + label, one prominent metric, one supporting
/// line and (when there is a trend) a sparkline. The category colour is an
/// accent only; the surface stays neutral.
class SourceSummaryCard extends StatelessWidget {
  const SourceSummaryCard({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
    this.stat,
    this.state = DataSourceState.available,
    this.emptyHint = 'No data yet',
    this.wide = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;
  final HomeTileStat? stat;

  /// [DataSourceState.loading] shows a skeleton only when [stat] is null, so
  /// cached values stay visible during a refresh.
  final DataSourceState state;
  final String emptyHint;

  /// Full-width layout: sparkline sits beside the metric.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final hasData = stat != null;
    final loading = state == DataSourceState.loading && !hasData;
    final refreshing = state == DataSourceState.loading && hasData;
    const radius = BorderRadius.all(Radius.circular(AppRadii.cardLarge));

    final spoken = loading
        ? 'loading'
        : hasData
        ? '${stat!.spoken}${stat!.secondary == null ? '' : ', ${stat!.secondary}'}'
        : emptyHint;

    final metric = loading
        ? const DataSourceStatusView(
            state: DataSourceState.loading,
            accent: Colors.transparent,
            compact: true,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat?.value ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.statDisplay.copyWith(
                  fontSize: 24,
                  color: hasData ? palette.textPrimary : palette.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasData ? stat!.caption : emptyHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          );

    final series = stat?.series;

    return Semantics(
      button: true,
      label: '$label, $spoken',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: palette.border),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.sectionLabel.copyWith(color: color),
                      ),
                    ),
                    if (refreshing)
                      SizedBox.square(
                        dimension: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: palette.textMuted,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: palette.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (wide && series != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: metric),
                      Sparkline(
                        values: series,
                        color: color,
                        width: 110,
                        height: 32,
                      ),
                    ],
                  )
                else ...[
                  metric,
                  if (series != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Sparkline(
                      values: series,
                      color: color,
                      width: double.infinity,
                      height: 24,
                    ),
                  ],
                ],
                if (stat?.secondary case final secondary?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
