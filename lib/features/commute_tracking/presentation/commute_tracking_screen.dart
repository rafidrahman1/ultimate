import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/metric_card.dart';
import '../../../widgets/status_message.dart';
import '../application/commute_tracking_providers.dart';
import '../domain/entities/trip.dart';
import '../infrastructure/tracking/background_tracking_status.dart';

class CommuteTrackingScreen extends ConsumerStatefulWidget {
  const CommuteTrackingScreen({super.key});

  @override
  ConsumerState<CommuteTrackingScreen> createState() =>
      _CommuteTrackingScreenState();
}

class _CommuteTrackingScreenState extends ConsumerState<CommuteTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMonitoring());
  }

  Future<void> _startMonitoring() async {
    await ref.read(backgroundTrackingServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(backgroundTrackingStatusProvider);
    final tripsAsync = ref.watch(tripsProvider);
    final totalKmAsync = ref.watch(totalCommuteDistanceKmProvider);
    final kmFormat = NumberFormat('#,##0.1');
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');

    ref.listen(backgroundTrackingStatusProvider, (previous, next) {
      final savedId = next.valueOrNull?.lastSavedTripId;
      final prevId = previous?.valueOrNull?.lastSavedTripId;
      if (savedId != null && savedId != prevId) {
        ref.invalidate(tripsProvider);
        ref.invalidate(totalCommuteDistanceKmProvider);
        final message = next.valueOrNull?.message;
        if (message != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    });

    final status = statusAsync.valueOrNull;
    final phase = status?.phase ?? BackgroundTrackingPhase.idle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commute tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload trips',
            onPressed: () {
              ref.invalidate(tripsProvider);
              ref.invalidate(totalCommuteDistanceKmProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripsProvider);
          ref.invalidate(totalCommuteDistanceKmProvider);
          await ref.read(backgroundTrackingServiceProvider).start();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
          children: [
            _TrackingStatusBanner(phase: phase, status: status),
            const SizedBox(height: 12),
            totalKmAsync.when(
              data: (km) => MetricCard(
                title: 'Total logged',
                value: kmFormat.format(km),
                unit: 'km',
                icon: Icons.two_wheeler,
                color: AppColors.location,
                subtitle: 'Automatic motorcycle commutes',
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load totals: $e'),
            ),
            if (status?.activeDistanceKm != null) ...[
              const SizedBox(height: 12),
              MetricCard(
                title: 'Active trip',
                value: kmFormat.format(status!.activeDistanceKm),
                unit: 'km',
                icon: Icons.gps_fixed,
                color: theme.colorScheme.primary,
                subtitle: 'Recording route…',
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Logged trips',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            tripsAsync.when(
              data: (trips) {
                if (trips.isEmpty) {
                  return const StatusMessage(
                    icon: Icons.route_outlined,
                    title: 'No commutes yet',
                    subtitle:
                        'When you ride with IN_VEHICLE activity detected, '
                        'trips are recorded automatically and saved when you stop for 3 minutes.',
                  );
                }
                return Column(
                  children: [
                    for (final trip in trips)
                      _TripCard(trip: trip, dateFormat: dateFormat),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load trips: $e'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final service = ref.read(backgroundTrackingServiceProvider);
          if (phase == BackgroundTrackingPhase.monitoring ||
              phase == BackgroundTrackingPhase.tripActive) {
            await service.stop();
          } else {
            await service.start();
          }
          if (mounted) setState(() {});
        },
        icon: Icon(
          phase == BackgroundTrackingPhase.monitoring ||
                  phase == BackgroundTrackingPhase.tripActive
              ? Icons.pause
              : Icons.play_arrow,
        ),
        label: Text(
          phase == BackgroundTrackingPhase.monitoring ||
                  phase == BackgroundTrackingPhase.tripActive
              ? 'Pause monitoring'
              : 'Start monitoring',
        ),
      ),
    );
  }
}

class _TrackingStatusBanner extends StatelessWidget {
  const _TrackingStatusBanner({
    required this.phase,
    required this.status,
  });

  final BackgroundTrackingPhase phase;
  final BackgroundTrackingStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (phase) {
      BackgroundTrackingPhase.idle => (
          Icons.pause_circle_outline,
          'Monitoring paused',
          theme.colorScheme.outline,
        ),
      BackgroundTrackingPhase.monitoring => (
          Icons.sensors,
          'Watching for vehicle activity',
          AppColors.location,
        ),
      BackgroundTrackingPhase.tripActive => (
          Icons.gps_fixed,
          'Trip in progress',
          theme.colorScheme.primary,
        ),
      BackgroundTrackingPhase.saving => (
          Icons.save_outlined,
          'Saving trip…',
          theme.colorScheme.tertiary,
        ),
      BackgroundTrackingPhase.error => (
          Icons.error_outline,
          status?.message ?? 'Tracking error',
          theme.colorScheme.error,
        ),
    };

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.dateFormat,
  });

  final Trip trip;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kmFormat = NumberFormat('#,##0.1');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.location.withValues(alpha: 0.15),
          child: const Icon(Icons.two_wheeler, color: AppColors.location),
        ),
        title: Text('${kmFormat.format(trip.totalDistanceKm)} km'),
        subtitle: Text(
          '${dateFormat.format(trip.startTime.toLocal())} · '
          '${trip.route.length} points · '
          '${_formatDuration(trip.duration)}',
        ),
        trailing: Text(
          dateFormat.format(trip.endTime.toLocal()).split(', ').last,
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes} min';
  }
}
