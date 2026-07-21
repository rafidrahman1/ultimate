import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/location/location_service.dart';

/// Compact per-domain sync/import controls, folded onto the Dashboard now
/// that there are no standalone per-domain screens.
class DashboardSyncPanel extends ConsumerStatefulWidget {
  const DashboardSyncPanel({super.key});

  @override
  ConsumerState<DashboardSyncPanel> createState() => _DashboardSyncPanelState();
}

class _DashboardSyncPanelState extends ConsumerState<DashboardSyncPanel> {
  final _busy = <String>{};
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  bool get _isGoogleConnected {
    final settings = ref.read(calendarSettingsProvider).valueOrNull;
    final authUser = ref.read(authStateProvider).valueOrNull;
    return (settings?.isConnected ?? false) || authUser != null;
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _bootstrapExpenses(),
      _bootstrapLocation(),
      _bootstrapGameActivity(),
      _bootstrapCalendar(),
    ]);
  }

  Future<void> _bootstrapExpenses() async {
    await ref.read(expensesSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    if (ref.read(expensesSummaryProvider).transactions.isEmpty &&
        _isGoogleConnected) {
      await _run(
        'expenses',
        () => ref.read(expensesSummaryProvider.notifier).loadFromGoogleDrive(),
      );
    }
  }

  Future<void> _bootstrapLocation() async {
    await ref.read(locationSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    if (!ref.read(locationSummaryProvider).hasAnyData) {
      await _run(
        'location',
        () => ref.read(locationSummaryProvider.notifier).loadAuto(),
      );
    }
  }

  Future<void> _bootstrapGameActivity() async {
    await ref.read(gameActivitySummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    if (ref.read(gameActivitySummaryProvider).sessions.isEmpty) {
      await _run(
        'gameActivity',
        () => ref.read(gameActivitySummaryProvider.notifier).loadAuto(),
      );
    }
  }

  Future<void> _bootstrapCalendar() async {
    await ref.read(calendarSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    if (ref.read(calendarSummaryProvider).events.isEmpty &&
        _isGoogleConnected) {
      await _run(
        'calendar',
        () => ref.read(calendarSummaryProvider.notifier).loadAuto(),
      );
    }
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() {
      _busy.add(key);
      _errors.remove(key);
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _errors[key] = e.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesSummaryProvider);
    final location = ref.watch(locationSummaryProvider);
    final gameActivity = ref.watch(gameActivitySummaryProvider);
    final calendar = ref.watch(calendarSummaryProvider);
    final healthAuth = ref.watch(healthAuthorizationProvider);
    final isConnected = _isGoogleConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourceRow(
          icon: Icons.bedtime_outlined,
          color: AppSemanticColors.health(context),
          label: 'Health',
          detail: healthAuth.when(
            data: (authorized) =>
                authorized ? 'Connected' : 'Permissions required',
            loading: () => 'Checking…',
            error: (_, _) => 'Unavailable',
          ),
          busy: false,
          error: null,
          actions: [
            _SourceAction(
              icon: Icons.refresh,
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(monthlyHealthDataProvider.notifier).refresh(),
            ),
            if (healthAuth.valueOrNull == false)
              _SourceAction(
                icon: Icons.help_outline,
                tooltip: 'How to connect',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.healthSettings),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SourceRow(
          icon: Icons.account_balance_wallet_outlined,
          color: AppSemanticColors.expenses(context),
          label: 'Expenses',
          detail: expenses.transactions.isEmpty
              ? (isConnected ? 'No transactions synced' : 'Not connected')
              : '${expenses.transactions.length} transactions',
          busy: _busy.contains('expenses'),
          error: _errors['expenses'],
          actions: [
            if (isConnected)
              _SourceAction(
                icon: Icons.sync,
                tooltip: 'Sync from Drive',
                onPressed: () => _run(
                  'expenses',
                  () => ref
                      .read(expensesSummaryProvider.notifier)
                      .loadFromGoogleDrive(interactiveSignIn: true),
                ),
              )
            else
              _SourceAction(
                icon: Icons.link,
                tooltip: 'Connect Google',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.calendarSettings),
              ),
            _SourceAction(
              icon: Icons.upload_file_outlined,
              tooltip: 'Import CSV',
              onPressed: () => _run(
                'expenses',
                () => ref
                    .read(expensesSummaryProvider.notifier)
                    .importFromPicker(),
              ),
            ),
            if (expenses.transactions.isNotEmpty)
              _SourceAction(
                icon: Icons.close,
                tooltip: 'Clear',
                onPressed: () async =>
                    ref.read(expensesSummaryProvider.notifier).clear(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SourceRow(
          icon: Icons.route_outlined,
          color: AppSemanticColors.location(context),
          label: 'Location',
          detail: location.hasAnyData
              ? '${location.activities.length} activities'
              : 'No timeline imported',
          busy: _busy.contains('location'),
          error: _errors['location'],
          actions: [
            _SourceAction(
              icon: Icons.sync,
              tooltip: 'Load',
              onPressed: () => _run(
                'location',
                () => ref.read(locationSummaryProvider.notifier).loadAuto(),
              ),
            ),
            _SourceAction(
              icon: Icons.upload_file_outlined,
              tooltip: 'Import JSON',
              onPressed: () => _run(
                'location',
                () => ref
                    .read(locationSummaryProvider.notifier)
                    .importFromPicker(),
              ),
            ),
            if (location.hasAnyData)
              _SourceAction(
                icon: Icons.close,
                tooltip: 'Clear',
                onPressed: () async =>
                    ref.read(locationSummaryProvider.notifier).clear(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SourceRow(
          icon: Icons.sports_esports_outlined,
          color: AppSemanticColors.gameActivity(context),
          label: 'Game Activity',
          detail: gameActivity.sessions.isEmpty
              ? 'No sessions imported'
              : '${gameActivity.sessions.length} sessions',
          busy: _busy.contains('gameActivity'),
          error: _errors['gameActivity'],
          actions: [
            _SourceAction(
              icon: Icons.sync,
              tooltip: 'Load',
              onPressed: () => _run(
                'gameActivity',
                () => ref.read(gameActivitySummaryProvider.notifier).loadAuto(),
              ),
            ),
            _SourceAction(
              icon: Icons.upload_file_outlined,
              tooltip: 'Import CSV',
              onPressed: () => _run(
                'gameActivity',
                () => ref
                    .read(gameActivitySummaryProvider.notifier)
                    .importFromPicker(),
              ),
            ),
            if (gameActivity.sessions.isNotEmpty)
              _SourceAction(
                icon: Icons.close,
                tooltip: 'Clear',
                onPressed: () async =>
                    ref.read(gameActivitySummaryProvider.notifier).clear(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SourceRow(
          icon: Icons.calendar_month_outlined,
          color: AppSemanticColors.calendar(context),
          label: 'Calendar',
          detail: calendar.events.isEmpty
              ? (isConnected ? 'No events synced' : 'Not connected')
              : '${calendar.events.length} events',
          busy: _busy.contains('calendar'),
          error: _errors['calendar'],
          actions: [
            if (isConnected)
              _SourceAction(
                icon: Icons.sync,
                tooltip: 'Sync',
                onPressed: () => _run(
                  'calendar',
                  () => ref
                      .read(calendarSummaryProvider.notifier)
                      .loadAuto(interactiveSignIn: true),
                ),
              )
            else
              _SourceAction(
                icon: Icons.link,
                tooltip: 'Connect Google',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.calendarSettings),
              ),
            if (calendar.events.isNotEmpty)
              _SourceAction(
                icon: Icons.close,
                tooltip: 'Clear',
                onPressed: () async =>
                    ref.read(calendarSummaryProvider.notifier).clear(),
              ),
          ],
        ),
      ],
    );
  }
}

class _SourceAction {
  const _SourceAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
    required this.busy,
    required this.error,
    required this.actions,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  final bool busy;
  final String? error;
  final List<_SourceAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    error ?? detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error != null
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              for (final action in actions)
                IconButton(
                  icon: Icon(action.icon, size: 20),
                  tooltip: action.tooltip,
                  onPressed: () => action.onPressed(),
                  visualDensity: VisualDensity.compact,
                ),
          ],
        ),
      ),
    );
  }
}
