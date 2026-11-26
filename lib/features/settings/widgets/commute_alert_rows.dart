import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/commute_alert/commute_alert_service.dart';
import 'package:personal/features/forecasts/commute_alert/commute_profile_refresh.dart';
import 'package:personal/features/forecasts/commute_alert/google_traffic_client.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/settings/widgets/notifications_card.dart';

/// Settings for the "When to leave for work" reminder: on/off, when it runs,
/// how you travel, the Google Maps key, and a manual check.
///
/// Owns its own state, since the reminder keeps its settings itself.
class CommuteAlertRows extends ConsumerStatefulWidget {
  const CommuteAlertRows({super.key});

  @override
  ConsumerState<CommuteAlertRows> createState() => _CommuteAlertRowsState();
}

class _CommuteAlertRowsState extends ConsumerState<CommuteAlertRows> {
  CommuteAlertSettings? _settings;
  CommuteAlertResult? _last;
  DateTime? _next;
  DateTime? _leaveAlarm;
  bool _hasProfile = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshProfile();
  }

  /// The profile is otherwise only saved from the Predictions tab, so build
  /// it here too rather than say there are no trips when there are.
  Future<void> _refreshProfile() async {
    await refreshCommuteProfileNow(ref);
    if (mounted) await _load();
  }

  Future<void> _load() async {
    final settings = await CommuteAlertService.settings();
    final last = await CommuteAlertService.lastResult();
    final next = await CommuteAlertService.nextRun();
    final profile = await CommuteAlertService.profile();
    final leaveAlarm = await CommuteAlertService.pendingLeaveAlarm();
    if (!mounted) return;
    setState(() {
      _leaveAlarm = leaveAlarm;
      _settings = settings;
      _last = last;
      _next = next;
      _hasProfile = profile != null;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    await CommuteAlertService.setEnabled(enabled);
    await _load();
  }

  Future<void> _pickTime(int minutes) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Check traffic at',
    );
    if (picked == null) return;
    await CommuteAlertService.setTime(picked.hour * 60 + picked.minute);
    await _load();
  }

  Future<void> _setMode(CommuteTravelMode mode) async {
    await CommuteAlertService.setMode(mode);
    await _load();
  }

  Future<void> _setUseAi(bool useAi) async {
    await CommuteAlertService.setUseAi(useAi);
    await _load();
  }

  Future<void> _setRing(bool ring) async {
    await CommuteAlertService.setRingAlarm(ring);
    await _load();
  }

  Future<void> _setPrep(int minutes) async {
    await CommuteAlertService.setPrepMinutes(minutes);
    await _load();
  }

  Future<void> _editKey(bool hasKey) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Maps API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A key with the Routes API enabled. Home and work coordinates '
              'are sent to Google once per reminder.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                hintText: hasKey ? 'Saved; paste to replace' : 'AIza…',
              ),
            ),
          ],
        ),
        actions: [
          if (hasKey)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    if (result.trim().isEmpty && !hasKey) return;
    await CommuteAlertService.setMapsKey(result);
    await _load();
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await refreshCommuteProfileNow(ref);
      await CommuteAlertService.run();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error is FormatException ? error.message : '$error'),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _checking = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final s = _settings;
    final last = _last;
    final next = _next;
    final divider = Divider(height: 1, indent: 68, color: palette.border);

    final subtitle = s == null
        ? 'Checks Google traffic and your own trips.'
        : !_hasProfile
        ? 'Needs a few home-to-work trips in your timeline first.'
        : s.enabled && next != null
        ? 'Next check ${weekdayShort(next)} ${clockLabel(next.hour * 60 + next.minute)}. '
              'Uses Google traffic and your own trips.'
        : 'On working days, checks Google traffic and your own trips and '
              'tells you when to leave.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          secondary: SettingsRowIcon(
            Icons.directions_bike_outlined,
            palette.mobility,
          ),
          title: const Text('When to leave for work'),
          subtitle: Text(subtitle),
          value: s?.enabled ?? false,
          onChanged: s == null ? null : _setEnabled,
        ),
        if (s != null && s.enabled) ...[
          divider,
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(68, 0, AppSpacing.lg, 0),
            title: const Text('Check at'),
            trailing: Text(
              clockLabel(s.minutes),
              style: theme.textTheme.titleMedium,
            ),
            onTap: () => _pickTime(s.minutes),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              68,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<CommuteTravelMode>(
              segments: [
                for (final m in CommuteTravelMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {s.mode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => _setMode(v.first),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(68, 0, AppSpacing.lg, 0),
            title: const Text('Getting going'),
            subtitle: const Text('Door to riding off. Added to Google’s time.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: s.prepMinutes > 0
                      ? () => _setPrep(s.prepMinutes - 1)
                      : null,
                ),
                Text(
                  '${s.prepMinutes} min',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: s.prepMinutes < 30
                      ? () => _setPrep(s.prepMinutes + 1)
                      : null,
                ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(68, 0, AppSpacing.lg, 0),
            title: const Text('Ask AI for the leave time'),
            subtitle: const Text(
              'Sends your recent trips, Google’s traffic and the weather to '
              'your AI provider, which may shift the time by up to 30 min.',
            ),
            value: s.useAi,
            onChanged: _setUseAi,
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(68, 0, AppSpacing.lg, 0),
            title: const Text('Ring an alarm at leave time'),
            subtitle: Text(
              _leaveAlarm != null && s.ringAlarm
                  ? 'Set for ${clockLabel(_leaveAlarm!.hour * 60 + _leaveAlarm!.minute)} today.'
                  : 'Alarm sound until you stop it.',
            ),
            value: s.ringAlarm,
            onChanged: _setRing,
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(68, 0, AppSpacing.lg, 0),
            title: const Text('Google Maps key'),
            subtitle: Text(
              s.hasKey ? 'Saved' : 'Not set, so only your own trips are used.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editKey(s.hasKey),
          ),
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(
              68,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            title: const Text('Check now'),
            subtitle: last == null
                ? const Text('Sends the reminder now and sets today’s alarm.')
                : Text(
                    'Last: ${last.title}. ${last.body}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
            trailing: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_outlined),
            onTap: _checking ? null : _checkNow,
          ),
        ],
      ],
    );
  }
}
