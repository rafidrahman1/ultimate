import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/commute_alert/commute_alert_service.dart';
import 'package:personal/features/forecasts/commute_alert/commute_profile_refresh.dart';
import 'package:personal/features/forecasts/commute_alert/google_traffic_client.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/shared/widgets/settings_kit.dart';

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
    final s = _settings;
    final last = _last;
    final next = _next;
    final leaveAlarm = _leaveAlarm;

    final subtitle = s == null
        ? 'Checks Google traffic and your own trips.'
        : !_hasProfile
        ? 'Needs a few home-to-work trips in your timeline first.'
        : s.enabled && next != null
        ? 'Next check ${weekdayShort(next)} '
              '${clockLabel(next.hour * 60 + next.minute)}'
        : 'On working days, says when to leave from live traffic and your '
              'own trips.';

    final value = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSwitchTile(
          icon: Icons.directions_bike_outlined,
          iconColor: palette.mobility,
          title: 'When to leave for work',
          subtitle: subtitle,
          value: s?.enabled ?? false,
          onChanged: s == null ? null : _setEnabled,
        ),
        if (s != null && s.enabled)
          Container(
            margin: const EdgeInsets.fromLTRB(
              kSettingsRowInset - AppSpacing.sm,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SubRow(
                  title: 'Check at',
                  onTap: () => _pickTime(s.minutes),
                  trailing: Text(clockLabel(s.minutes), style: value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
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
                _SubRow(
                  title: 'Getting going',
                  subtitle: 'Door to riding off, added to Google’s time.',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Less',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove),
                        onPressed: s.prepMinutes > 0
                            ? () => _setPrep(s.prepMinutes - 1)
                            : null,
                      ),
                      Text('${s.prepMinutes} min', style: value),
                      IconButton(
                        tooltip: 'More',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add),
                        onPressed: s.prepMinutes < 30
                            ? () => _setPrep(s.prepMinutes + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                _SubRow(
                  title: 'Ask AI for the leave time',
                  subtitle:
                      'Sends recent trips, traffic and weather to your AI '
                      'provider; it may shift the time by up to 30 min.',
                  onTap: () => _setUseAi(!s.useAi),
                  trailing: Switch(value: s.useAi, onChanged: _setUseAi),
                ),
                _SubRow(
                  title: 'Ring an alarm at leave time',
                  subtitle: leaveAlarm != null && s.ringAlarm
                      ? 'Set for '
                            '${clockLabel(leaveAlarm.hour * 60 + leaveAlarm.minute)} '
                            'today.'
                      : 'Alarm sound until you stop it.',
                  onTap: () => _setRing(!s.ringAlarm),
                  trailing: Switch(value: s.ringAlarm, onChanged: _setRing),
                ),
                _SubRow(
                  title: 'Google Maps key',
                  subtitle: s.hasKey
                      ? 'Saved'
                      : 'Not set, so only your own trips are used.',
                  onTap: () => _editKey(s.hasKey),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textMuted,
                  ),
                ),
                Divider(height: 1, color: palette.border),
                _SubRow(
                  title: 'Check now',
                  subtitle: last == null
                      ? 'Sends the reminder now and sets today’s alarm.'
                      : 'Last: ${last.title}. ${last.body}',
                  onTap: _checking ? null : _checkNow,
                  trailing: _checking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.play_arrow_rounded, color: palette.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A compact row inside the reminder's options panel.
class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: row,
      ),
    );
  }
}
