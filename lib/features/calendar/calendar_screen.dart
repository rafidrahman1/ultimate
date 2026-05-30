import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analysis_prompt_preview_card.dart';
import '../../widgets/collapsible_summary_section.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pinned_summary_layout.dart';
import '../../widgets/pinned_summary_skeleton.dart';
import '../../widgets/status_message.dart';
import 'calendar_event.dart';
import 'calendar_holiday_groups.dart';
import 'calendar_service.dart';
import 'calendar_settings_service.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIfNeeded());
  }

  /// Auto-sync only when the page opens with no cached events and Google is connected.
  void _syncIfNeeded() {
    final hasEvents = ref.read(calendarSummaryProvider).events.isNotEmpty;
    final isConnected =
        ref.read(calendarSettingsProvider).valueOrNull?.isConnected ?? false;
    if (!hasEvents && isConnected) {
      _loadAuto();
    }
  }

  Future<void> _loadAuto({bool interactive = false}) async {
    final hasEvents = ref.read(calendarSummaryProvider).events.isNotEmpty;
    if (_loading) return;

    setState(() {
      if (!hasEvents) _loading = true;
      _loadError = null;
    });

    try {
      await ref
          .read(calendarSummaryProvider.notifier)
          .loadAuto(interactiveSignIn: interactive);
      final email = ref.read(calendarSummaryProvider).accountEmail;
      final savedEmail =
          ref.read(calendarSettingsProvider).valueOrNull?.connectedEmail;
      if (email != null && email != savedEmail) {
        await ref
            .read(calendarSettingsProvider.notifier)
            .saveConnectedEmail(email);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(calendarSummaryProvider);
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final isConnected = settings?.isConnected ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Calendar settings',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.calendarSettings),
          ),
          if (summary.events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () =>
                  ref.read(calendarSummaryProvider.notifier).clear(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync calendar',
            onPressed: _loading ? null : () => _loadAuto(),
          ),
        ],
      ),
      body: _loading
          ? const PinnedSummarySkeleton(
              metricCount: 2,
              listItemStyle: PinnedSummaryListItemStyle.detailed,
            )
          : summary.events.isEmpty
              ? StatusMessage(
                  icon: Icons.calendar_month_outlined,
                  title: 'No calendar events loaded',
                  subtitle: _loadError ??
                      (isConnected
                          ? 'Tap Sync to load your calendar.'
                          : 'Open Calendar settings and connect your Google account.'),
                  action: FilledButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.calendarSettings,
                    ),
                    child: const Text('Open settings'),
                  ),
                )
              : _CalendarBody(summary: summary),
      floatingActionButton: isConnected
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : () => _loadAuto(),
              icon: const Icon(Icons.sync),
              label: const Text('Sync'),
            )
          : FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.calendarSettings),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Connect'),
            ),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody({required this.summary});

  final CalendarSummary summary;

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  late List<CalendarTimelineEntry> _timeline;
  late String _promptText;

  @override
  void initState() {
    super.initState();
    _rebuildDerivedData();
  }

  @override
  void didUpdateWidget(covariant _CalendarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) {
      _rebuildDerivedData();
    }
  }

  void _rebuildDerivedData() {
    _timeline = widget.summary.timeline;
    _promptText = widget.summary.toAnalysisPromptText();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final dateFormat = DateFormat('EEE, d MMM · HH:mm');
    final dayFormat = DateFormat('EEE, d MMM');

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary.accountEmail != null) Text(summary.accountEmail!),
          if (summary.accountEmail != null) const SizedBox(height: 4),
          Text(
            summary.periodRangeLabel ?? 'Synced range unavailable',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle: summary.holidayGroupCount > 0
            ? '${summary.events.length} events · '
                '${summary.holidayGroupCount} BD holidays · '
                '${summary.upcomingEvents.length} upcoming'
            : '${summary.events.length} events · '
                '${summary.upcomingEvents.length} upcoming',
        icon: Icons.calendar_month_outlined,
        accent: AppColors.calendar,
        metrics: [
          MetricCard(
            title: 'Total events',
            value: '${summary.events.length}',
            icon: Icons.event_outlined,
            color: AppColors.calendar,
            compact: true,
          ),
          MetricCard(
            title: 'Upcoming',
            value: '${summary.upcomingEvents.length}',
            icon: Icons.upcoming_outlined,
            color: AppColors.accent,
            subtitle: '${summary.allDayCount} all-day',
            compact: true,
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: _promptText,
          detailTitle: 'Calendar data for analysis',
          accent: AppColors.calendar,
          icon: Icons.calendar_month_outlined,
          compact: true,
        ),
      ),
      bodyBuilder: (context, padding) => ListView.separated(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _timeline.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return switch (_timeline[index]) {
            CalendarPersonalEntry(:final event) => _EventTile(
                event: event,
                dateFormat: dateFormat,
                dayFormat: dayFormat,
              ),
            CalendarHolidayGroupEntry(:final group) => _HolidayGroupTile(
                group: group,
                dayFormat: dayFormat,
              ),
          };
        },
      ),
    );
  }
}

class _HolidayGroupTile extends StatelessWidget {
  const _HolidayGroupTile({
    required this.group,
    required this.dayFormat,
  });

  final CalendarHolidayGroup group;
  final DateFormat dayFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = group.isSingleDay
        ? dayFormat.format(group.start)
        : formatHolidayGroupDateRange(group);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.calendar.withValues(alpha: 0.12),
              child: const Icon(
                Icons.flag_outlined,
                color: AppColors.calendar,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.dayCount > 1
                        ? '$dateLabel · ${group.dayCount} days'
                        : '$dateLabel · All day',
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

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.dateFormat,
    required this.dayFormat,
  });

  final CalendarEvent event;
  final DateFormat dateFormat;
  final DateFormat dayFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = event.allDay
        ? 'All day'
        : dateFormat.format(event.start);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.calendar.withValues(alpha: 0.12),
              child: Icon(
                event.isHoliday
                    ? Icons.flag_outlined
                    : event.allDay
                        ? Icons.wb_sunny_outlined
                        : Icons.schedule,
                color: AppColors.calendar,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.allDay
                        ? dayFormat.format(event.start)
                        : timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.location!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
