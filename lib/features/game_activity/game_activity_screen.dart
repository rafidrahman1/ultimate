import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/analysis_month_settings_service.dart';
import '../../core/analysis_view_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analysis_prompt_preview_card.dart';
import '../../widgets/collapsible_summary_section.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pinned_summary_layout.dart';
import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/pinned_summary_skeleton.dart';
import '../../widgets/status_message.dart';
import 'game_activity_service.dart';
import 'game_activity_session.dart';
import 'game_activity_settings_service.dart';

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
    final settings = ref.read(gameActivitySettingsProvider).valueOrNull;
    if (settings == null || !settings.hasFolder || settings.needsReselect) {
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await ref.read(gameActivitySummaryProvider.notifier).loadFromConfiguredFolder();
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
    final settings = ref.watch(gameActivitySettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;

    ref.listen(gameActivitySettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.exportFolderUri;
      final nextUri = next.valueOrNull?.exportFolderUri;
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
              onPressed: () => ref.read(gameActivitySummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: _loading ? null : _loadAuto,
          ),
        ],
      ),
      body: _loading
          ? const PinnedSummarySkeleton(metricCount: 2, listItemStyle: PinnedSummaryListItemStyle.detailed)
          : summary.sessions.isEmpty
          ? StatusMessage(
              icon: Icons.sports_esports_outlined,
              title: rawSummary.sessions.isEmpty ? 'No game activity loaded' : 'No game activity in ${period.dataRangeLabel}',
              subtitle:
                  _loadError ??
                  (needsReselect
                      ? 'Open Game Activity settings and choose your export folder again '
                            'so Android can read files in that folder.'
                      : hasFolder
                      ? 'No GameActivity_Export_*.csv found in your selected folder. '
                            'Tap refresh after exporting.'
                      : 'Choose your Game Activity export folder in settings, '
                            'or tap the upload icon to import a CSV manually.'),
              action: _emptyAction(context, hasFolder || needsReselect),
            )
          : _GameActivityBody(summary: summary, periodLabel: period.dataRangeLabel),
      floatingActionButton: hasFolder
          ? FloatingActionButton.extended(onPressed: _loading ? null : _loadFromFolder, icon: const Icon(Icons.refresh), label: const Text('Reload'))
          : FloatingActionButton.extended(onPressed: _importCsv, icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
    );
  }

  Widget? _emptyAction(BuildContext context, bool showSettings) {
    if (!showSettings) return null;
    return FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.gameActivitySettings), child: const Text('Open settings'));
  }
}

class _GameActivityBody extends StatelessWidget {
  const _GameActivityBody({required this.summary, required this.periodLabel});

  final GameActivitySummary summary;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy · HH:mm');
    final sessions = summary.sortedByDate;
    final promptText = summary.toAnalysisPromptText();

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(periodLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (summary.fileName != null) ...[
            const SizedBox(height: 4),
            Text(summary.fileName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle:
            '${summary.sessions.length} sessions · '
            '${_formatDuration(summary.totalPlayTime)} total',
        icon: Icons.sports_esports_outlined,
        accent: AppColors.gameActivity,
        metrics: [
          MetricCard(title: 'Sessions', value: '${summary.sessions.length}', icon: Icons.videogame_asset_outlined, color: AppColors.gameActivity, compact: true),
          MetricCard(
            title: 'Total play time',
            value: _formatDuration(summary.totalPlayTime),
            icon: Icons.timer_outlined,
            color: AppColors.accent,
            subtitle: '${summary.uniqueGameCount} games',
            compact: true,
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: promptText,
          detailTitle: 'Game activity data for analysis',
          accent: AppColors.gameActivity,
          icon: Icons.sports_esports_outlined,
          compact: true,
        ),
      ),
      bodyBuilder: (context, padding) => ListView.separated(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _SessionTile(session: session, dateFormat: dateFormat);
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.dateFormat});

  final GameActivitySession session;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.gameActivity.withValues(alpha: 0.12),
              child: Icon(Icons.sports_esports_outlined, color: AppColors.gameActivity, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(session.sessionDate), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              _formatDuration(session.timePlayed),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.gameActivity),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}
