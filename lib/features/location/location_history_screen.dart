import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_message.dart';
import 'location_service.dart';
import 'location_settings_service.dart';
import 'timeline_entry.dart';
import 'travel_mode_icons.dart';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFolder());
  }

  Future<void> _loadFromFolder() async {
    final settings = ref.read(locationSettingsProvider).valueOrNull;
    if (settings == null || !settings.hasFolder || settings.needsReselect) {
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await ref
          .read(locationHistoryProvider.notifier)
          .loadFromConfiguredFolder();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(locationHistoryProvider);
    final settings = ref.watch(locationSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;

    ref.listen(locationSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.timelineFolderUri;
      final nextUri = next.valueOrNull?.timelineFolderUri;
      if (prevUri != nextUri) _loadFromFolder();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location history'),
        actions: [
          if (summary.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () =>
                  ref.read(locationHistoryProvider.notifier).clear(),
            ),
          if (summary.hasMonthData)
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: 'Copy summary for AI',
              onPressed: () => _copyForAi(context, summary),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from folder',
            onPressed: hasFolder && !_loading ? _loadFromFolder : null,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Timeline Edits.json',
            onPressed: () => _importJson(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : summary.entries.isEmpty
              ? StatusMessage(
                  icon: Icons.location_on_outlined,
                  title: 'No location history loaded',
                  subtitle: _loadError ??
                      (needsReselect
                          ? 'Open Location settings and choose your Timeline folder again '
                              'so Android can read files in that folder.'
                          : hasFolder
                              ? 'No Timeline Edits.json found in your selected folder. '
                                  'Tap refresh after exporting from Google Takeout.'
                              : 'Choose your Timeline export folder in Location settings, '
                                  'or tap the upload icon to import JSON manually.'),
                  action: _successAction(context, hasFolder || needsReselect),
                )
              : !summary.hasMonthData
                  ? StatusMessage(
                      icon: Icons.calendar_month_outlined,
                      title: 'No data for ${summary.monthLabel}',
                      subtitle:
                          'Your import has timeline data, but nothing starts in the current month.',
                    )
                  : _LocationHistoryBody(summary: summary),
      floatingActionButton: hasFolder
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _loadFromFolder,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _importJson(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import JSON'),
            ),
    );
  }

  Widget? _successAction(BuildContext context, bool showSettings) {
    if (!showSettings) return null;
    return FilledButton(
      onPressed: () =>
          Navigator.pushNamed(context, AppRoutes.locationSettings),
      child: const Text('Open settings'),
    );
  }

  Future<void> _importJson(BuildContext context) async {
    try {
      await ref.read(locationHistoryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _LocationHistoryBody extends StatelessWidget {
  const _LocationHistoryBody({required this.summary});

  final LocationHistorySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = summary.sortedByTime;
    final travelModes = summary.travelByMode;
    final kmFormat = NumberFormat('#,##0.0');
    final dateFormat = DateFormat('d MMM yyyy');
    final timeFormat = DateFormat('HH:mm');

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.periodRangeLabel != null)
                  _DateRangeBanner(
                    monthLabel: summary.monthLabel,
                    rangeLabel: summary.periodRangeLabel!,
                    dayCount: summary.periodDays,
                  ),
                if (summary.fileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary.fileName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Travel this month',
                  value: kmFormat.format(summary.totalDistanceKm),
                  unit: 'km',
                  icon: Icons.route,
                  color: AppColors.location,
                  subtitle:
                      '${summary.activityCount} trips · ${summary.visitCount} visits',
                ),
                const SizedBox(height: 12),
                if (travelModes.isNotEmpty) ...[
                  Text(
                    'Distance by mode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...travelModes.map(
                    (stat) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TravelModeTile(
                        stat: stat,
                        kmFormat: kmFormat,
                        totalKm: summary.totalDistanceKm,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _copyForAi(context, summary),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Copy summary for AI'),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
          sliver: SliverList.separated(
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _TimelineEntryTile(
                entry: entry,
                dateFormat: dateFormat,
                timeFormat: timeFormat,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateRangeBanner extends StatelessWidget {
  const _DateRangeBanner({
    required this.monthLabel,
    required this.rangeLabel,
    this.dayCount,
  });

  final String monthLabel;
  final String rangeLabel;
  final int? dayCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.location.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              color: AppColors.location,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current month',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (dayCount != null)
                    Text(
                      '$dayCount days with activity',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _copyForAi(BuildContext context, LocationHistorySummary summary) {
  Clipboard.setData(ClipboardData(text: summary.toAiSummary()));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Travel summary copied for AI')),
  );
}

class _TravelModeTile extends StatelessWidget {
  const _TravelModeTile({
    required this.stat,
    required this.kmFormat,
    required this.totalKm,
  });

  final TravelModeStat stat;
  final NumberFormat kmFormat;
  final double totalKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = totalKm > 0 ? stat.distanceKm / totalKm : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconForTravelMode(stat.mode),
                  color: AppColors.location,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stat.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${kmFormat.format(stat.distanceKm)} km',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.location,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: AppColors.location,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${stat.tripCount} trips · '
              '${NumberFormat.decimalPercentPattern(decimalDigits: 0).format(share)} of travel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntryTile extends StatelessWidget {
  const _TimelineEntryTile({
    required this.entry,
    required this.dateFormat,
    required this.timeFormat,
  });

  final TimelineEntry entry;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisit = entry.kind == TimelineEntryKind.visit;
    final color = isVisit ? AppColors.location : AppColors.chat;
    final icon = isVisit ? Icons.place : Icons.directions;
    final duration = entry.duration;
    final durationLabel = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(entry.startTime)} · '
                    '${timeFormat.format(entry.startTime)}–'
                    '${timeFormat.format(entry.endTime)} · $durationLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.latitude.toStringAsFixed(5)}, '
                    '${entry.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
