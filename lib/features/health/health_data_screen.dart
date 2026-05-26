import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_message.dart';
import 'health_service.dart';
import 'health_summary.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final dataAsync = ref.watch(weeklyHealthDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(weeklyHealthDataProvider),
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
            data: (result) => _WeeklyHealthBody(fetch: result),
            loading: () => const Center(child: CircularProgressIndicator()),
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

class _WeeklyHealthBody extends StatelessWidget {
  const _WeeklyHealthBody({required this.fetch});

  final WeeklyHealthFetchResult fetch;

  @override
  Widget build(BuildContext context) {
    if (!fetch.hasData) {
      return const StatusMessage(
        icon: Icons.monitor_heart_outlined,
        title: 'No health data yet',
        subtitle:
            'Sync Samsung Health and check back for the last 7 days.',
      );
    }

    final summary = WeeklyHealthSummary.fromWeeklyFetch(fetch);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          summary.periodRangeLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Samsung Health (via Health Connect) · same data sent to analysis',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        MetricCard(
          title: 'Steps',
          value: '${summary.avgStepsPerDay.round()}',
          unit: 'avg / day',
          icon: Icons.directions_walk,
          color: AppColors.chat,
        ),
        const SizedBox(height: 12),
        Text(
          'Sleep by day',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          summary.sleepNightsTracked > 0
              ? '${summary.sleepNightsTracked} of 7 nights tracked'
              : 'No sleep records in period',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(formatWakeDate(day.wakeDate)),
              subtitle: Text(subtitle),
            ),
          );
        }),
      ],
    );
  }
}
