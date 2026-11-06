import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/storage/data_folder_settings_service.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/game_activity/game_cover_service.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/pill_tabs.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';
import 'package:personal/shared/widgets/sparkline.dart';
import 'package:personal/shared/widgets/status_message.dart';

part 'game_activity_overview.dart';

class GameActivityScreen extends ConsumerStatefulWidget {
  const GameActivityScreen({super.key});

  @override
  ConsumerState<GameActivityScreen> createState() => _GameActivityScreenState();
}

class _GameActivityScreenState extends ConsumerState<GameActivityScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(gameActivitySummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    await _loadAutoIfNeeded();
  }

  Future<void> _loadAutoIfNeeded() async {
    if (ref.read(gameActivitySummaryProvider).sessions.isNotEmpty) return;
    await _loadAuto();
  }

  Future<void> _loadAuto() async {
    final hasData = ref.read(gameActivitySummaryProvider).sessions.isNotEmpty;
    setState(() {
      if (!hasData) _loading = true;
      _loadError = null;
    });

    try {
      await ref.read(gameActivitySummaryProvider.notifier).loadAuto();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFromFolder() async {
    final settings = ref.read(dataFolderSettingsProvider).valueOrNull;
    if (settings == null || !settings.hasFolder || settings.needsReselect) {
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await ref
          .read(gameActivitySummaryProvider.notifier)
          .loadFromConfiguredFolder();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gameActivitySummaryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(gameActivityForAnalysisProvider);
    final rawSummary = ref.watch(gameActivitySummaryProvider);
    final settings = ref.watch(dataFolderSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;

    ref.listen(dataFolderSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.folderUri;
      final nextUri = next.valueOrNull?.folderUri;
      if (prevUri != nextUri) _loadAuto();
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Game Activity',
        extraActions: [
          if (rawSummary.sessions.isNotEmpty)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () =>
                  ref.read(gameActivitySummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: _loading ? null : _loadAuto,
          ),
        ],
      ),
      body: PullToRefresh(
        onRefresh: _loadAuto,
        child: _loading
            ? const CardListSkeleton(cardHeights: [210, 200, 72, 72, 72])
            : summary.sessions.isEmpty
            ? StatusMessage(
                icon: Icons.sports_esports_outlined,
                title: rawSummary.sessions.isEmpty
                    ? 'No game activity loaded'
                    : 'No game activity in ${period.dataRangeLabel}',
                subtitle:
                    _loadError ??
                    (needsReselect
                        ? 'Open General settings and choose your data folder again '
                              'so Android can read files in that folder.'
                        : hasFolder
                        ? 'No GameActivity_Export* files found in your selected folder. '
                              'Tap refresh after exporting.'
                        : 'Choose your data folder in General settings, '
                              'or tap the upload icon to import a CSV manually.'),
                action: _emptyAction(context, hasFolder || needsReselect),
              )
            : _GameActivityBody(
                summary: summary,
                allSessions: rawSummary.sessions,
                periodLabel: period.dataRangeLabel,
                monthStart: period.dataMonthStart,
              ),
      ),
      floatingActionButton: hasFolder
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _loadFromFolder,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            )
          : FloatingActionButton.extended(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
    );
  }

  Widget? _emptyAction(BuildContext context, bool showSettings) {
    if (!showSettings) return null;
    return FilledButton(
      onPressed: () => Navigator.pushNamed(
        context,
        AppRoutes.generalSettings,
        arguments: SettingsSection.storage,
      ),
      child: const Text('Open settings'),
    );
  }
}

class _GameActivityBody extends StatefulWidget {
  const _GameActivityBody({
    required this.summary,
    required this.allSessions,
    required this.periodLabel,
    required this.monthStart,
  });

  final GameActivitySummary summary;

  /// Every imported session, for comparing against last month.
  final List<GameActivitySession> allSessions;
  final String periodLabel;
  final DateTime monthStart;

  @override
  State<_GameActivityBody> createState() => _GameActivityBodyState();
}

class _GameActivityBodyState extends State<_GameActivityBody> {
  GameTab _tab = GameTab.overview;

  void _go(GameTab tab) => setState(() => _tab = tab);

  /// Morning, afternoon, evening or night, by the hour a session started.
  static ({String name, String range}) _bucket(int hour) {
    if (hour >= 5 && hour < 12) {
      return (name: 'Morning', range: '5:00 AM – 12:00 PM');
    }
    if (hour >= 12 && hour < 18) {
      return (name: 'Afternoon', range: '12:00 PM – 6:00 PM');
    }
    if (hour >= 18 && hour < 23) {
      return (name: 'Evening', range: '6:00 PM – 11:00 PM');
    }
    return (name: 'Night', range: '11:00 PM – 5:00 AM');
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final monthStart = widget.monthStart;
    final accent = AppSemanticColors.gameActivity(context);
    final palette = context.palette;
    final sessions = summary.sortedByDate;
    final newestFirst = [...sessions]
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    final days = buildDayBars([
      for (final s in sessions)
        (date: s.sessionDate, value: s.timePlayed.inMinutes / 60),
    ], monthStart);
    final activeDays = days.where((d) => d.value > 0).length;
    final avgPerDay = activeDays == 0
        ? Duration.zero
        : Duration(
            minutes: (summary.totalPlayTime.inMinutes / activeDays).round(),
          );
    final longest = sessions.isEmpty
        ? null
        : sessions.reduce((a, b) => a.timePlayed >= b.timePlayed ? a : b);

    final byGame = <String, Duration>{};
    for (final s in sessions) {
      byGame[s.name] = (byGame[s.name] ?? Duration.zero) + s.timePlayed;
    }
    final games = byGame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var running = 0.0;
    final cumulative = [for (final d in days) running += d.value];

    // Last month, same days when this month is still running.
    final now = DateTime.now();
    final isCurrent =
        now.year == monthStart.year && now.month == monthStart.month;
    final prevStart = DateTime(monthStart.year, monthStart.month - 1);
    final prevDays = DateTime(prevStart.year, prevStart.month + 1, 0).day;
    final span = isCurrent ? now.day.clamp(1, prevDays) : prevDays;
    final prevTotal = widget.allSessions
        .where(
          (s) =>
              s.sessionDate.year == prevStart.year &&
              s.sessionDate.month == prevStart.month &&
              s.sessionDate.day <= span,
        )
        .fold(Duration.zero, (sum, s) => sum + s.timePlayed);
    final prevMonth = DateFormat.MMM().format(prevStart);
    ({String text, String caption, bool rising})? comparison;
    if (prevTotal > Duration.zero) {
      final change =
          (summary.totalPlayTime.inSeconds - prevTotal.inSeconds) /
          prevTotal.inSeconds *
          100;
      comparison = (
        text: '${change >= 0 ? '+' : '−'}${change.abs().round()}%',
        caption: isCurrent && span < prevDays
            ? 'vs $prevMonth 1–$span'
            : 'vs $prevMonth',
        rising: change >= 0,
      );
    }

    // Busiest day and time of day, from the sessions themselves.
    final busiest = days.isEmpty
        ? null
        : days.reduce((a, b) => a.value >= b.value ? a : b);
    final bucketMinutes = <String, int>{};
    final bucketRange = <String, String>{};
    for (final s in sessions) {
      final b = _bucket(s.sessionDate.hour);
      bucketMinutes[b.name] =
          (bucketMinutes[b.name] ?? 0) + s.timePlayed.inMinutes;
      bucketRange[b.name] = b.range;
    }
    final preferred = bucketMinutes.entries.isEmpty
        ? null
        : bucketMinutes.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final groups = groupByDay(sessions, (s) => s.sessionDate);
    final clock = DateFormat('h:mm a');
    String range(GameActivitySession s) =>
        '${clock.format(s.sessionDate)} – '
        '${clock.format(s.sessionDate.add(s.timePlayed))}';

    final chart = CategoryPanel(
      title: 'Daily play time',
      child: DayBars(
        data: days,
        color: accent,
        target: activeDays == 0
            ? null
            : days.fold<double>(0, (s, d) => s + d.value) / activeDays,
        targetLabel: activeDays == 0
            ? null
            : 'Avg ${_formatDuration(avgPerDay, compact: true)}',
        format: (v) =>
            _formatDuration(Duration(minutes: (v * 60).round()), compact: true),
        emptyLabel: 'No sessions this month',
      ),
    );

    final overview = <Widget>[
      categoryBox(
        PlayTimeHero(
          total: _formatDuration(summary.totalPlayTime, compact: true),
          caption:
              '${summary.sessions.length} sessions · '
              '${summary.uniqueGameCount} games',
          series: cumulative,
          comparison: comparison,
          stats: [
            (
              icon: Icons.hourglass_bottom_rounded,
              value: _formatDuration(avgPerDay, compact: true),
              label: 'Avg per day',
            ),
            if (longest != null)
              (
                icon: Icons.timer_outlined,
                value: _formatDuration(longest.timePlayed, compact: true),
                label: 'Longest session',
              ),
            (
              icon: Icons.event_available_outlined,
              value: '$activeDays ${activeDays == 1 ? 'day' : 'days'}',
              label: 'Active days',
            ),
            (
              icon: Icons.bar_chart_rounded,
              value: '${summary.sessions.length}',
              label: 'Total sessions',
            ),
          ],
        ),
      ),
      if (games.isNotEmpty)
        categoryBox(
          PlayTimeByGame(games: games, total: summary.totalPlayTime, limit: 4),
        ),
      categoryBox(PlayDaysGrid(days: days, monthStart: monthStart)),
      categoryBox(chart),
      if (busiest != null && busiest.value > 0 && preferred != null)
        categoryBox(
          PlayHighlights(
            rows: [
              (
                icon: Icons.sports_esports_rounded,
                label: 'Most active day',
                value: DateFormat('EEE, MMM d').format(busiest.date),
                caption: _formatDuration(
                  Duration(minutes: (busiest.value * 60).round()),
                  compact: true,
                ),
              ),
              (
                icon: Icons.schedule_rounded,
                label: 'Preferred time',
                value: preferred.key,
                caption: bucketRange[preferred.key] ?? '',
              ),
            ],
          ),
        ),
      if (newestFirst.isNotEmpty)
        categoryBox(
          RecentSessions(
            sessions: newestFirst.take(3).toList(),
            onSeeAll: () => _go(GameTab.sessions),
          ),
        ),
    ];

    final sessionsTab = <Widget>[
      categoryList(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final total = group.value.fold(
            Duration.zero,
            (sum, s) => sum + s.timePlayed,
          );
          return DayGroup(
            date: group.key,
            accent: accent,
            total: _formatDuration(total, compact: true),
            children: [
              for (final session in group.value)
                CategoryRow(
                  icon: Icons.sports_esports_outlined,
                  accent: accent,
                  title: session.name,
                  subtitle: range(session),
                  trailing: _formatDuration(session.timePlayed),
                  trailingColor: accent,
                ),
            ],
          );
        },
      ),
    ];

    final gamesTab = <Widget>[
      categoryBox(PlayTimeByGame(games: games, total: summary.totalPlayTime)),
    ];

    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final byWeekday = List<Duration>.filled(7, Duration.zero);
    for (final s in sessions) {
      byWeekday[s.sessionDate.weekday - 1] += s.timePlayed;
    }
    final trendsTab = <Widget>[
      categoryBox(chart),
      categoryBox(
        CategoryPanel(
          title: 'By weekday',
          child: BreakdownBars(
            color: accent,
            items: [
              for (var i = 0; i < 7; i++)
                (
                  label: weekdayNames[i],
                  value: byWeekday[i].inSeconds.toDouble(),
                  display: _formatDuration(byWeekday[i], compact: true),
                ),
            ],
          ),
        ),
      ),
      if (bucketMinutes.isNotEmpty)
        categoryBox(
          CategoryPanel(
            title: 'Time of day',
            child: BreakdownBars(
              color: accent,
              items: [
                for (final name in ['Morning', 'Afternoon', 'Evening', 'Night'])
                  (
                    label: name,
                    value: (bucketMinutes[name] ?? 0).toDouble(),
                    display: _formatDuration(
                      Duration(minutes: bucketMinutes[name] ?? 0),
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    final insightsTab = <Widget>[
      categoryBox(
        CategoryPanel(
          title: 'Highlights',
          child: Column(
            children: [
              if (sessions.isNotEmpty)
                line(
                  'Average session',
                  _formatDuration(
                    Duration(
                      minutes:
                          (summary.totalPlayTime.inMinutes / sessions.length)
                              .round(),
                    ),
                    compact: true,
                  ),
                ),
              if (longest != null)
                line(
                  'Longest session',
                  '${_formatDuration(longest.timePlayed, compact: true)} · ${longest.name}',
                ),
              if (activeDays > 0)
                line(
                  'Sessions per active day',
                  (sessions.length / activeDays).toStringAsFixed(1),
                ),
              if (games.isNotEmpty) line('Most played', games.first.key),
            ],
          ),
        ),
      ),
      categoryBox(
        AnalysisDataLink(
          promptText: summary.toAnalysisPromptText(),
          title: 'Game activity data summary',
          accent: accent,
          icon: Icons.sports_esports_outlined,
        ),
      ),
    ];

    return CategoryScroll(
      slivers: [
        categoryBox(
          PillTabs(
            labels: [for (final t in GameTab.values) t.label],
            selected: _tab.index,
            accent: accent,
            onSelected: (i) => _go(GameTab.values[i]),
          ),
        ),
        ...switch (_tab) {
          GameTab.overview => overview,
          GameTab.sessions => sessionsTab,
          GameTab.games => gamesTab,
          GameTab.trends => trendsTab,
          GameTab.insights => insightsTab,
        },
      ],
    );
  }
}

String _formatDuration(Duration duration, {bool compact = false}) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return compact ? '${minutes}m' : '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}
