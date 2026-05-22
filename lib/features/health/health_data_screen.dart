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
    final dataAsync = ref.watch(healthDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(healthDataProvider),
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
            data: (result) => _HealthSummaryBody(result: result),
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

class _HealthSummaryBody extends StatelessWidget {
  const _HealthSummaryBody({required this.result});

  final HealthFetchResult result;

  @override
  Widget build(BuildContext context) {
    if (result.points.isEmpty && result.todaySteps == 0) {
      return const StatusMessage(
        icon: Icons.monitor_heart_outlined,
        title: 'No health data yet',
        subtitle: 'Sync Samsung Health and check back for the last 24 hours.',
      );
    }

    final summary = HealthSummary.fromData(
      result.points,
      todaySteps: result.todaySteps,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MetricCard(
          title: 'Steps',
          value: '${summary.totalSteps}',
          unit: 'today',
          icon: Icons.directions_walk,
          color: AppColors.chat,
          subtitle: result.stepsFromHealthConnectOnly
              ? 'Via Health Connect — may differ from Samsung Health until sync'
              : null,
        ),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Heart rate',
          value: summary.latestHeartRate?.toString() ?? '--',
          unit: 'bpm',
          icon: Icons.favorite,
          color: AppColors.health,
          subtitle: summary.latestHeartRateTime != null
              ? 'Updated ${formatTime(summary.latestHeartRateTime!)}'
              : null,
        ),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Sleep',
          value: summary.sleep != null
              ? formatDuration(summary.sleep!.duration)
              : '--',
          icon: Icons.bedtime,
          color: AppColors.prompt,
          subtitle: summary.sleep != null
              ? '${formatTime(summary.sleep!.startTime)} – ${formatTime(summary.sleep!.endTime)}'
              : null,
        ),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Workouts',
          value: '${summary.workoutCount}',
          unit: 'sessions',
          icon: Icons.fitness_center,
          color: AppColors.location,
          subtitle: '${summary.totalWorkoutCalories} kcal burned',
        ),
      ],
    );
  }
}
