import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/month_grid.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_holiday_groups.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

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
  Future<void> _syncIfNeeded() async {
    await ref.read(calendarSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    final hasEvents = ref.read(calendarSummaryProvider).events.isNotEmpty;
    final isConnected =
        ref.read(calendarSettingsProvider).valueOrNull?.isConnected ?? false;
    if (!hasEvents && isConnected) {
      await _loadAuto();
    }
  }

  Future<void> _loadAuto({bool interactive = false}) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await ref
          .read(calendarSummaryProvider.notifier)
          .loadAuto(interactiveSignIn: interactive);
      final summary = ref.read(calendarSummaryProvider);
      final email = summary.accountEmail;
      final photoUrl = summary.accountPhotoUrl;
      final displayName = summary.accountDisplayName;
      final settings = ref.read(calendarSettingsProvider).valueOrNull;
      final savedEmail = settings?.connectedEmail;
      final savedPhotoUrl = settings?.connectedPhotoUrl;
      final savedDisplayName = settings?.connectedDisplayName;
      if (email != null &&
          (email != savedEmail ||
              photoUrl != savedPhotoUrl ||
              displayName != savedDisplayName)) {
        await ref
            .read(calendarSettingsProvider.notifier)
            .saveConnection(
              email: email,
              photoUrl: photoUrl,
              displayName: displayName,
            );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() => _loadError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(calendarForDisplayProvider);
    final rawSummary = ref.watch(calendarSummaryProvider);
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isConnected = (settings?.isConnected ?? false) || authUser != null;

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Calendar',
        extraActions: [
          if (rawSummary.events.isNotEmpty)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () =>
                  ref.read(calendarSummaryProvider.notifier).clear(),
            ),
        ],
      ),
      body: PullToRefresh(
        onRefresh: isConnected ? () => _loadAuto(interactive: true) : null,
        child: _loading
            ? const CardListSkeleton(cardHeights: [210, 200, 72, 72, 72])
            : summary.events.isEmpty
            ? StatusMessage(
                icon: Icons.calendar_month_outlined,
                title: rawSummary.events.isEmpty
                    ? 'No calendar events loaded'
                    : 'No calendar events in sync range',
                subtitle:
                    _loadError ??
                    (isConnected
                        ? 'Tap Sync to load your calendar.'
                        : 'Open Google account settings and sign in.'),
                action: FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.calendarSettings),
                  child: const Text('Open settings'),
                ),
              )
            : _CalendarBody(summary: summary, period: period),
      ),
      floatingActionButton: isConnected
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : () => _loadAuto(interactive: true),
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

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.summary, required this.period});

  final CalendarSummary summary;
  final AnalysisPeriod period;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final period = widget.period;
    final month = period.dataMonthStart;
    final accent = AppSemanticColors.calendar(context);
    final palette = context.palette;
    final theme = Theme.of(context);

    final analysisCalendar = ref.watch(calendarForAnalysisProvider);
    final healthFetch = ref.watch(monthlyHealthDataProvider).valueOrNull;
    final health = healthFetch != null && healthFetch.hasData
        ? MonthlyHealthSummary.fromFetch(healthFetch)
        : null;
    final location = ref.watch(locationForAnalysisProvider);
    final expenses = ref.watch(expensesForAnalysisProvider);
    final promptText = analysisCalendar.toAnalysisPromptText(
      health: health,
      upcomingSource: summary,
      upcomingAfter: period.dataMonthEnd,
      location: location,
      expenses: expenses,
      includeFutureEvents: true,
      includeEventAnalysis: true,
      includeSleepClusterCorrelation: true,
    );

    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;

    // Heat grid inputs: personal events per day, holiday days flagged.
    final counts = <int, int>{};
    final holidays = <int>{};
    for (final event in summary.events) {
      final start = event.start.toLocal();
      if (!inMonth(start)) continue;
      if (event.isHoliday) {
        holidays.add(start.day);
      } else {
        counts[start.day] = (counts[start.day] ?? 0) + 1;
      }
    }
    for (final entry in summary.timeline) {
      if (entry is! CalendarHolidayGroupEntry) continue;
      var day = DateTime(
        entry.group.start.year,
        entry.group.start.month,
        entry.group.start.day,
      );
      final last = DateTime(
        entry.group.end.year,
        entry.group.end.month,
        entry.group.end.day,
      );
      for (var n = 0; n < 31 && !day.isAfter(last); n++) {
        if (inMonth(day)) holidays.add(day.day);
        day = day.add(const Duration(days: 1));
      }
    }
    final busiest = counts.entries.isEmpty
        ? null
        : counts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Agenda: timeline entries grouped by day, optionally for one day.
    final selected = _selectedDay == null
        ? null
        : DateTime(month.year, month.month, _selectedDay!);
    DateTime dayOf(DateTime d) {
      final l = d.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    final visible = summary.timeline.where((entry) {
      if (selected == null) return true;
      return switch (entry) {
        CalendarPersonalEntry(:final event) => dayOf(event.start) == selected,
        CalendarHolidayGroupEntry(:final group) =>
          !selected.isBefore(dayOf(group.start)) &&
              !selected.isAfter(dayOf(group.end)),
      };
    }).toList();
    final groups = groupByDay(
      visible,
      (entry) => switch (entry) {
        CalendarPersonalEntry(:final event) => dayOf(event.start),
        CalendarHolidayGroupEntry(:final group) => dayOf(group.start),
      },
      newestFirst: false,
    );

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.calendar_month_rounded,
            label: 'Events',
            value: '${summary.events.length}',
            caption:
                '${summary.upcomingEvents.length} upcoming · '
                '${summary.allDayCount} all-day',
            footnote:
                summary.accountEmail ??
                summary.periodRangeLabel ??
                period.dataRangeLabel,
            stats: [
              if (busiest != null)
                HeroStat(
                  'Busiest day',
                  '${DateFormat('d MMM').format(DateTime(month.year, month.month, busiest.key))}'
                      ' · ${busiest.value}',
                ),
              if (summary.holidayGroupCount > 0)
                HeroStat('Holidays', '${summary.holidayGroupCount}'),
              if (summary.syncedAt != null)
                HeroStat('Synced', relativeTime(summary.syncedAt!)),
            ],
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: 'Month at a glance',
            trailing: _selectedDay == null ? 'Tap a day' : null,
            child: MonthHeatGrid(
              month: month,
              counts: counts,
              holidays: holidays,
              color: accent,
              selectedDay: _selectedDay,
              onSelect: (day) => setState(() => _selectedDay = day),
            ),
          ),
        ),
        categoryBox(
          CategoryTitle(
            selected == null
                ? 'Agenda'
                : DateFormat('EEEE d MMMM').format(selected),
            trailing: selected == null ? null : 'Showing one day',
          ),
          bottom: AppSpacing.xs,
        ),
        if (groups.isEmpty)
          categoryBox(
            Text(
              selected == null ? 'Nothing scheduled.' : 'Nothing on this day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          )
        else
          categoryList(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return DayGroup(
                date: group.key,
                total: group.value.length > 1 ? '${group.value.length}' : null,
                accent: accent,
                children: [
                  for (final entry in group.value)
                    switch (entry) {
                      CalendarPersonalEntry(:final event) => _EventRow(
                        event: event,
                      ),
                      CalendarHolidayGroupEntry(:final group) => _HolidayRow(
                        group: group,
                      ),
                    },
                ],
              );
            },
          ),
        categoryBox(
          AnalysisDataLink(
            promptText: promptText,
            title: 'Calendar & schedule prompt for analysis',
            accent: accent,
            icon: Icons.calendar_month_outlined,
          ),
        ),
      ],
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.group});

  final CalendarHolidayGroup group;

  @override
  Widget build(BuildContext context) {
    final dateLabel = group.isSingleDay
        ? DateFormat('EEE, d MMM').format(group.start)
        : formatHolidayGroupDateRange(group);
    return CategoryRow(
      icon: Icons.flag_outlined,
      accent: AppSemanticColors.calendar(context),
      title: group.title,
      subtitle: group.dayCount > 1
          ? '$dateLabel · ${group.dayCount} days'
          : 'All day',
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    final start = event.start.toLocal();
    final end = event.end.toLocal();
    return CategoryRow(
      icon: event.isHoliday
          ? Icons.flag_outlined
          : event.allDay
          ? Icons.wb_sunny_outlined
          : Icons.schedule,
      accent: AppSemanticColors.calendar(context),
      title: event.title,
      subtitle: event.allDay
          ? 'All day'
          : '${time.format(start)} – ${time.format(end)}',
      detail: event.location,
    );
  }
}
