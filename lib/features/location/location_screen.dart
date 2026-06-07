import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analysis_month_settings_service.dart';
import '../../core/analysis_period.dart';
import '../../core/analysis_view_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analysis_prompt_preview_card.dart';
import '../../widgets/collapsible_summary_section.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pinned_summary_layout.dart';
import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/pinned_summary_skeleton.dart';
import '../../widgets/status_message.dart';
import '../results/insight_detail_overlay.dart';
import 'location_service.dart';
import 'location_settings_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(locationSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    await _loadAutoIfNeeded();
  }

  Future<void> _loadAutoIfNeeded() async {
    if (ref.read(locationSummaryProvider).hasAnyData) return;
    await _loadAuto();
  }

  Future<void> _loadAuto() async {
    final hasData = ref.read(locationSummaryProvider).hasAnyData;
    setState(() {
      if (!hasData) _loading = true;
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
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(locationForAnalysisProvider);
    final rawSummary = ref.watch(locationSummaryProvider);
    final settings = ref.watch(locationSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;
    final motorcycleTrips = summary.sortedPeriodMotorcyclingActivities;

    ref.listen(locationSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.timelineFolderUri;
      final nextUri = next.valueOrNull?.timelineFolderUri;
      if (prevUri != nextUri) _loadAuto();
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Location',
        extraActions: [
          if (rawSummary.hasAnyData)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () => ref.read(locationSummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: _loading ? null : _loadAuto,
          ),
        ],
      ),
      body: _loading
          ? const PinnedSummarySkeleton(metricCount: 2, listItemStyle: PinnedSummaryListItemStyle.compact)
          : !summary.hasAnyData
          ? StatusMessage(
              icon: Icons.route_outlined,
              title: rawSummary.hasAnyData ? 'No location data in ${period.dataRangeLabel}' : 'No location data loaded',
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
          : _LocationBody(summary: summary, motorcycleTrips: motorcycleTrips, period: period),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _importJson(context), icon: const Icon(Icons.upload_file), label: const Text('Import JSON')),
    );
  }
}

class _LocationBody extends StatelessWidget {
  const _LocationBody({required this.summary, required this.motorcycleTrips, required this.period});

  final LocationSummary summary;
  final List<TimelineActivity> motorcycleTrips;
  final AnalysisPeriod period;

  @override
  Widget build(BuildContext context) {
    final decimal = NumberFormat.decimalPattern();
    final summary = this.summary;
    final motorcycleTrips = this.motorcycleTrips;
    final period = this.period;
    final transportationByType = summary.periodTransportationByType;
    final otherTransportationByType = transportationByType.where((mode) => mode.type != 'MOTORCYCLING').toList();
    final km = (summary.periodMotorcycleDistanceMeters / 1000).toStringAsFixed(2);
    final otherDistanceMeters =
        (summary.periodTotalDistanceMeters - summary.periodMotorcycleDistanceMeters)
            .clamp(0, double.infinity)
            .toDouble();
    final otherKm = (otherDistanceMeters / 1000).toStringAsFixed(2);
    final otherTrips = summary.activities.where((activity) => !activity.isMotorcycling && activity.distanceMeters > 0).length;
    final travelTime = formatTravelDuration(summary.periodMotorcycleTravelTime);
    final dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');
    final promptText = summary.toAnalysisPromptText(dataMonthStart: period.dataMonthStart, dataMonthEnd: period.dataMonthEnd);

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary.fileName != null) Text(summary.fileName!),
          if (summary.fileName != null) const SizedBox(height: 4),
          Text(period.dataRangeLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle: '$km km motorcycle · $travelTime · $otherKm km other',
        icon: Icons.summarize_outlined,
        accent: AppColors.location,
        metrics: [
          MetricCard(
            title: 'Motorcycle distance',
            value: '$km km',
            icon: Icons.two_wheeler_outlined,
            color: AppColors.location,
            subtitle: '${decimal.format(motorcycleTrips.length)} trips',
            compact: true,
          ),
          MetricCard(
            title: 'Other transportation',
            value: '$otherKm km',
            icon: Icons.directions_transit_outlined,
            color: AppColors.result,
            subtitle: '${decimal.format(otherTrips)} trips',
            compact: true,
            onLongPress: () => showInsightDetailOverlay(
              context,
              title: 'Other transportation breakdown',
              body: _buildOtherTransportationBreakdownText(otherTransportationByType, decimal),
              accent: AppColors.result,
              icon: Icons.directions_transit_outlined,
            ),
          ),
          MetricCard(
            title: 'Motorcycle travel time',
            value: travelTime,
            icon: Icons.schedule_outlined,
            color: AppColors.location,
            compact: true,
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: promptText,
          detailTitle: 'Location data for analysis',
          accent: AppColors.location,
          icon: Icons.route_outlined,
          compact: true,
        ),
      ),
      bodyBuilder: (context, padding) => ListView(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('Motorcycle trips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (motorcycleTrips.isEmpty)
            const Card(child: ListTile(title: Text('No motorcycle trips in this period.')))
          else
            ...motorcycleTrips.map((trip) {
              final segmentKm = (trip.distanceMeters / 1000).toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.two_wheeler_outlined, color: AppColors.location),
                    title: Text('$segmentKm km'),
                    subtitle: Text(
                      '${dateTimeFormat.format(trip.startTime.toLocal())} → '
                      '${dateTimeFormat.format(trip.endTime.toLocal())}',
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _buildOtherTransportationBreakdownText(
    List<TransportationModeSummary> otherTransportationByType,
    NumberFormat decimal,
  ) {
    if (otherTransportationByType.isEmpty) {
      return 'No other transportation activity found in this period.';
    }

    final lines = <String>[];
    for (final mode in otherTransportationByType) {
      final modeKm = (mode.distanceMeters / 1000).toStringAsFixed(2);
      lines.add(
        '- ${_formatTransportType(mode.type)}: $modeKm km (${decimal.format(mode.tripCount)} trips)',
      );
    }
    return lines.join('\n');
  }

  String _formatTransportType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split('_')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
