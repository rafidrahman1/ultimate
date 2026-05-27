import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_message.dart';
import 'location_settings_service.dart';
import 'location_service.dart';
import 'timeline_activity.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAuto());
  }

  Future<void> _loadAuto() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await ref.read(locationSummaryProvider.notifier).loadAuto();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(locationSummaryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(locationSummaryProvider);
    final settings = ref.watch(locationSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;
    final motorcycleTrips = summary.sortedMotorcyclingActivities;

    ref.listen(locationSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.timelineFolderUri;
      final nextUri = next.valueOrNull?.timelineFolderUri;
      if (prevUri != nextUri) _loadAuto();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Location settings',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.locationSettings),
          ),
          if (summary.activities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () =>
                  ref.read(locationSummaryProvider.notifier).clear(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Timeline.json',
            onPressed: _loading ? null : _loadAuto,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Timeline.json',
            onPressed: () => _importJson(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : summary.activities.isEmpty
          ? StatusMessage(
              icon: Icons.route_outlined,
              title: 'No location data loaded',
              subtitle:
                  _loadError ??
                  (needsReselect
                      ? 'Open Location settings and choose your Timeline folder again '
                            'so Android can read files in that folder.'
                      : hasFolder
                      ? 'No Timeline.json found in your selected folder. '
                            'Tap refresh after updating your export.'
                      : 'Choose your Timeline folder in Location settings, '
                            'or tap upload to import Timeline.json manually.'),
            )
          : _LocationBody(summary: summary, motorcycleTrips: motorcycleTrips),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importJson(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import JSON'),
      ),
    );
  }
}

class _LocationBody extends StatelessWidget {
  const _LocationBody({required this.summary, required this.motorcycleTrips});

  final LocationSummary summary;
  final List<TimelineActivity> motorcycleTrips;

  @override
  Widget build(BuildContext context) {
    final decimal = NumberFormat.decimalPattern();
    final km = (summary.motorcycleDistanceMeters / 1000).toStringAsFixed(2);
    final weekdayKm = (summary.motorcyclingWeekdayDistanceMeters / 1000)
        .toStringAsFixed(2);
    final weekendKm = (summary.motorcyclingWeekendDistanceMeters / 1000)
        .toStringAsFixed(2);
    final totalKm = (summary.totalDistanceMeters / 1000).toStringAsFixed(2);
    final dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.fileName != null) Text(summary.fileName!),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Month to date: ${summary.monthToDateRangeLabel()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Motorcycle distance',
                  value: '$km km',
                  icon: Icons.two_wheeler_outlined,
                  color: AppColors.location,
                  subtitle: '${decimal.format(motorcycleTrips.length)} trips',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Motorcycle weekdays (Sun–Thu)',
                  value: '$weekdayKm km',
                  icon: Icons.calendar_view_week_outlined,
                  color: AppColors.location,
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Motorcycle weekends (Fri–Sat)',
                  value: '$weekendKm km',
                  icon: Icons.weekend_outlined,
                  color: AppColors.location,
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'All tracked distance',
                  value: '$totalKm km',
                  icon: Icons.route_outlined,
                  color: AppColors.result,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
          sliver: SliverList.separated(
            itemCount: motorcycleTrips.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final trip = motorcycleTrips[index];
              final segmentKm = (trip.distanceMeters / 1000).toStringAsFixed(2);
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.two_wheeler_outlined,
                    color: AppColors.location,
                  ),
                  title: Text('$segmentKm km'),
                  subtitle: Text(
                    '${dateTimeFormat.format(trip.startTime.toLocal())} → '
                    '${dateTimeFormat.format(trip.endTime.toLocal())}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
