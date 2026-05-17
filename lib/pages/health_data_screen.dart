import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../services/health_service.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final dataAsync = ref.watch(healthDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(healthDataProvider))],
      ),
      body: authAsync.when(
        data: (isAuthorized) {
          if (!isAuthorized) {
            return _buildNoPermissionView(context);
          }
          return dataAsync.when(
            data: (data) => _buildSummaryView(context, data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Auth Error: $err')),
      ),
    );
  }

  Widget _buildSummaryView(BuildContext context, List<HealthDataPoint> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No health data found for the last 24 hours.'));
    }

    // Process Steps: Sum of all steps in the last 24 hours
    final stepsData = data.where((p) => p.type == HealthDataType.STEPS);
    double totalSteps = 0;
    for (var p in stepsData) {
      final value = p.value;
      if (value is NumericHealthValue) {
        totalSteps += value.numericValue.toDouble();
      }
    }

    // Process Heart Rate: Latest record
    final heartRateData = data.where((p) => p.type == HealthDataType.HEART_RATE).toList();
    heartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    final latestHeartRate = heartRateData.isNotEmpty ? heartRateData.first : null;

    // Process Sleep: Aggregate all stages for the most recent session
    final sleepSummary = _calculateSleepSummary(data);

    // Process Workouts: Summary of all workouts in the last 24 hours
    final workoutsData = data.where((p) => p.type == HealthDataType.WORKOUT).toList();
    double totalCalories = 0;
    for (var p in workoutsData) {
      final value = p.value;
      if (value is WorkoutHealthValue) {
        totalCalories += value.totalEnergyBurned?.toDouble() ?? 0;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildMetricCard(context, 'Total Steps', '${totalSteps.toInt()}', 'steps today', Icons.directions_walk, Colors.blue),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            'Latest Heart Rate',
            latestHeartRate != null ? _formatHeartRate(latestHeartRate.value) : '--',
            'bpm',
            Icons.favorite,
            Colors.red,
            subtitle: latestHeartRate != null ? 'Last updated: ${_formatTime(latestHeartRate.dateFrom)}' : null,
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            'Sleep Data',
            sleepSummary != null ? _formatDuration(sleepSummary.totalDuration) : '--',
            '',
            Icons.bedtime,
            Colors.indigo,
            subtitle: sleepSummary != null ? 'Session: ${_formatTime(sleepSummary.startTime)} - ${_formatTime(sleepSummary.endTime)}' : null,
          ),
          const SizedBox(height: 16),
          _buildMetricCard(
            context,
            'Workouts',
            '${workoutsData.length}',
            'sessions today',
            Icons.fitness_center,
            Colors.orange,
            subtitle: 'Total calories: ${totalCalories.toInt()} kcal',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String unit, IconData icon, Color color, {String? subtitle}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 8),
                Text(unit, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600])),
              ],
            ),
            if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]))],
          ],
        ),
      ),
    );
  }

  String _formatHeartRate(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toInt().toString();
    }
    return '--';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  _SleepSummary? _calculateSleepSummary(List<HealthDataPoint> data) {
    // Collect all sleep-related points
    final sleepTypes = {
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
    };

    final sleepPoints = data.where((p) => sleepTypes.contains(p.type)).toList();
    if (sleepPoints.isEmpty) return null;

    // Sort by dateTo descending to find the most recent end point
    sleepPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    // The most recent point defines our session anchor
    final latestPoint = sleepPoints.first;
    // We assume all points within 14 hours of the end of the latest point belong to the same session/night
    final sessionThreshold = latestPoint.dateTo.subtract(const Duration(hours: 14));

    final currentSessionPoints = sleepPoints.where((p) => p.dateTo.isAfter(sessionThreshold)).toList();

    Duration totalAsleep = Duration.zero;
    DateTime sessionStart = latestPoint.dateFrom;
    DateTime sessionEnd = latestPoint.dateTo;

    // Identify if we have granular stages
    final stages = currentSessionPoints
        .where((p) => {HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_REM}.contains(p.type))
        .toList();

    if (stages.isNotEmpty) {
      // If we have stages, sum their durations
      for (var s in stages) {
        totalAsleep += s.dateTo.difference(s.dateFrom);
      }
      // Expand session window based on all points including AWAKE and SESSION
      for (var p in currentSessionPoints) {
        if (p.dateFrom.isBefore(sessionStart)) sessionStart = p.dateFrom;
        if (p.dateTo.isAfter(sessionEnd)) sessionEnd = p.dateTo;
      }
    } else {
      // Fallback to SLEEP_SESSION if no granular stages found
      final sessions = currentSessionPoints.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();
      if (sessions.isNotEmpty) {
        final latestSession = sessions.first;
        totalAsleep = latestSession.dateTo.difference(latestSession.dateFrom);
        sessionStart = latestSession.dateFrom;
        sessionEnd = latestSession.dateTo;
      } else {
        // Just use the latest point available if nothing else
        totalAsleep = latestPoint.dateTo.difference(latestPoint.dateFrom);
        sessionStart = latestPoint.dateFrom;
        sessionEnd = latestPoint.dateTo;
      }
    }

    return _SleepSummary(totalAsleep, sessionStart, sessionEnd);
  }

  Widget _buildNoPermissionView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Health permissions are required to view data.'),
          const SizedBox(height: 24),
          const Text('Please configure sharing in Health Settings.'),
        ],
      ),
    );
  }
}

class _SleepSummary {
  final Duration totalDuration;
  final DateTime startTime;
  final DateTime endTime;

  _SleepSummary(this.totalDuration, this.startTime, this.endTime);
}
