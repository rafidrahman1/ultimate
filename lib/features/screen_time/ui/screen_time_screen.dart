import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';
import 'package:personal/features/screen_time/data/screen_time_service.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';
import 'package:personal/shared/widgets/status_message.dart';

String formatScreenTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the Usage access settings page should pick up the grant.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only the no-access state can change from Settings; with access already
    // granted a refetch on every resume just re-queries usage stats.
    if (state == AppLifecycleState.resumed &&
        ref.read(screenTimeProvider).value?.hasAccess != true) {
      ref.invalidate(screenTimeProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(screenTimeProvider);
    await ref.read(screenTimeProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(screenTimeProvider);
    final supported = ref.watch(screenTimeServiceProvider).isSupported;
    final monthStart = ref.watch(selectedAnalysisMonthProvider);

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Screen time',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(screenTimeProvider),
          ),
        ],
      ),
      body: !supported
          ? const StatusMessage(
              icon: Icons.phonelink_erase_rounded,
              title: 'Android only',
              subtitle: 'Screen time is read from Android usage stats.',
            )
          : state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => StatusMessage(
                icon: Icons.error_outline,
                title: 'Could not read screen time',
                subtitle: e.toString(),
              ),
              data: (data) {
                if (!data.hasAccess) {
                  return StatusMessage(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'Allow usage access',
                    subtitle:
                        'Android keeps per-app screen time behind a special '
                        'permission. Enable "Usage access" for this app; the '
                        'data never leaves your device.',
                    action: FilledButton(
                      onPressed: () => ref
                          .read(screenTimeServiceProvider)
                          .openAccessSettings(),
                      child: const Text('Open settings'),
                    ),
                  );
                }
                if (data.summary.isEmpty) {
                  return StatusMessage(
                    icon: Icons.hourglass_empty_rounded,
                    title:
                        'No screen time in ${DateFormat.yMMMM().format(monthStart)}',
                    subtitle:
                        'Android only keeps usage history for a limited time.',
                  );
                }
                return PullToRefresh(
                  onRefresh: _refresh,
                  child: _Body(summary: data.summary, monthStart: monthStart),
                );
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.monthStart});

  final ScreenTimeSummary summary;
  final DateTime monthStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppSemanticColors.primary(context);
    final apps = summary.topApps;
    final maxMinutes = apps.isEmpty
        ? 1
        : apps.first.duration.inMinutes.clamp(1, 1 << 30);
    final days = buildDayBars([
      for (final e in summary.byDay.entries)
        (date: e.key, value: e.value.inMinutes / 60),
    ], monthStart);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          tier: AppCardTier.hero,
          accent: accent,
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Daily average',
                  value: formatScreenTime(summary.averagePerActiveDay),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Month total',
                  value: formatScreenTime(summary.total),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: DayBars(
            data: days,
            color: accent,
            format: (v) =>
                formatScreenTime(Duration(minutes: (v * 60).round())),
            averageLabel: 'Average per day',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Most used apps', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final app in apps.take(15))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              tier: AppCardTier.flat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        formatScreenTime(app.duration),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: app.duration.inMinutes / maxMinutes,
                      minHeight: 6,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}
