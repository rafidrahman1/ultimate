import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/analysis_prompt_preview_card.dart';
import '../../widgets/collapsible_summary_section.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pinned_summary_layout.dart';
import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/pinned_summary_skeleton.dart';
import '../../widgets/status_message.dart';
import '../../core/analysis_month_settings_service.dart';
import '../../core/analysis_period.dart';
import 'health_service.dart';
import 'health_summary.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final dataAsync = ref.watch(monthlyHealthDataProvider);
    final period = ref.watch(analysisPeriodProvider);

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Health',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: () =>
                ref.read(monthlyHealthDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: authAsync.when(
        data: (isAuthorized) {
          if (!isAuthorized) {
            return const StatusMessage(
              icon: Icons.lock_outline,
              title: 'Health permissions required',
              subtitle:
                  'Open Health Settings from the menu to connect and grant access.',
            );
          }
          return dataAsync.when(
            data: (result) => _MonthlyHealthBody(fetch: result, period: period),
            loading: () => const PinnedSummarySkeleton(
              metricCount: 1,
              listItemCount: 28,
              listItemStyle: PinnedSummaryListItemStyle.compact,
              showListSectionHeader: true,
              reserveFabSpace: false,
            ),
            error: (err, _) => StatusMessage(
              icon: Icons.error_outline,
              title: 'Could not load health data',
              subtitle: err.toString(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Authorization failed',
          subtitle: err.toString(),
        ),
      ),
    );
  }
}

class _MonthlyHealthBody extends StatelessWidget {
  const _MonthlyHealthBody({required this.fetch, required this.period});

  final MonthlyHealthFetchResult fetch;
  final AnalysisPeriod period;

  @override
  Widget build(BuildContext context) {
    if (!fetch.hasData) {
      return StatusMessage(
        icon: Icons.monitor_heart_outlined,
        title: 'No health data yet',
        subtitle:
            'Sync Samsung Health and check back for ${period.dataRangeLabel}.',
      );
    }

    final summary = MonthlyHealthSummary.fromFetch(fetch);
    final promptText = summary.toAnalysisPromptText();

    final theme = Theme.of(context);

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.periodRangeLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Samsung Health (via Health Connect) · steps avg, sleep anomalies in analysis',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle:
            '${summary.avgStepsPerDay.round()} steps avg · '
            '${summary.sleepNightsTracked} nights sleep',
        icon: Icons.summarize_outlined,
        accent: AppColors.health,
        metrics: [
          MetricCard(
            title: 'Steps',
            value: '${summary.avgStepsPerDay.round()}',
            unit: 'avg / day',
            icon: Icons.directions_walk,
            color: AppColors.accent,
            compact: true,
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: promptText,
          detailTitle: 'Health data for analysis',
          accent: AppColors.health,
          icon: Icons.monitor_heart_outlined,
          compact: true,
        ),
      ),
      reserveFabSpace: false,
      bodyBuilder: (context, padding) => ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'Sleep by day',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary.sleepNightsTracked > 0
                ? '${summary.sleepNightsTracked} of ${summary.dayCount} nights tracked'
                : 'No sleep records in period',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...summary.dailySleep.map((day) {
            final subtitle = day.hasData
                ? '${formatDuration(day.session!.duration)} · '
                    'bed ${formatTime(day.session!.startTime)} · '
                    'wake ${formatTime(day.session!.endTime)}'
                : 'No data';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.bedtime,
                  color: day.hasData
                      ? AppColors.prompt
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(formatWakeDate(day.wakeDate)),
                subtitle: Text(subtitle),
              ),
            );
          }),
        ],
      ),
    );
  }
}
