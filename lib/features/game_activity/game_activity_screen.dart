import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

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
            ? const PinnedSummarySkeleton(
                metricCount: 2,
                listItemStyle: PinnedSummaryListItemStyle.detailed,
              )
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
      onPressed: () => Navigator.pushNamed(context, AppRoutes.generalSettings),
      child: const Text('Open settings'),
    );
  }
}

class _GameActivityBody extends StatelessWidget {
  const _GameActivityBody({
    required this.summary,
    required this.periodLabel,
    required this.monthStart,
  });

  final GameActivitySummary summary;
  final String periodLabel;
  final DateTime monthStart;

  @override
  Widget build(BuildContext context) {
    final accent = AppSemanticColors.gameActivity(context);
    final sessions = summary.sortedByDate;

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

    final groups = groupByDay(sessions, (s) => s.sessionDate);

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.sports_esports_rounded,
            label: 'Play time',
            value: _formatDuration(summary.totalPlayTime, compact: true),
            caption:
                '${summary.sessions.length} sessions · '
                '${summary.uniqueGameCount} games',
            footnote: periodLabel,
            stats: [
              if (activeDays > 0)
                HeroStat(
                  'Avg per day played',
                  _formatDuration(avgPerDay, compact: true),
                ),
              if (longest != null)
                HeroStat(
                  'Longest session',
                  _formatDuration(longest.timePlayed, compact: true),
                ),
              if (games.isNotEmpty) HeroStat('Most played', games.first.key),
            ],
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: 'Play time by day',
            child: DayBars(
              data: days,
              color: accent,
              format: (v) => _formatDuration(
                Duration(minutes: (v * 60).round()),
                compact: true,
              ),
              emptyLabel: 'No sessions this month',
            ),
          ),
        ),
        if (games.length > 1)
          categoryBox(
            CategoryPanel(
              title: 'By game',
              trailing: '${games.length} games',
              child: BreakdownBars(
                color: accent,
                items: [
                  for (final entry in games)
                    (
                      label: entry.key,
                      value: entry.value.inSeconds.toDouble(),
                      display: _formatDuration(entry.value, compact: true),
                    ),
                ],
              ),
            ),
          ),
        categoryBox(const CategoryTitle('Sessions'), bottom: AppSpacing.xs),
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
                    subtitle: DateFormat('h:mm a').format(session.sessionDate),
                    trailing: _formatDuration(session.timePlayed),
                    trailingColor: accent,
                  ),
              ],
            );
          },
        ),
        categoryBox(
          AnalysisDataLink(
            promptText: summary.toAnalysisPromptText(),
            title: 'Game activity data for analysis',
            accent: accent,
            icon: Icons.sports_esports_outlined,
          ),
        ),
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
