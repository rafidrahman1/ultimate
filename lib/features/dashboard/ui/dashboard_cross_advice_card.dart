part of 'dashboard_tiles.dart';

/// AI suggestions drawn from how the sources move together (sleep vs screen
/// time vs spending and so on). The raw links are sent only when the user
/// taps the button, and nothing is shown until then.
class _CrossAdviceCard extends ConsumerStatefulWidget {
  const _CrossAdviceCard({required this.data});

  final DashboardViewData data;

  @override
  ConsumerState<_CrossAdviceCard> createState() => _CrossAdviceCardState();
}

class _CrossAdviceCardState extends ConsumerState<_CrossAdviceCard> {
  List<AdviceItem>? _advice;
  String? _error;
  bool _loading = false;
  bool _remind = false;
  String _forFacts = '';

  String get _signature => buildAdviceFacts(widget.data);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Brings back the last advice and the reminder switch after a restart.
  Future<void> _restore() async {
    final saved = await AdviceReminderService.loadAdvice();
    final remind = await AdviceReminderService.isEnabled();
    if (!mounted) return;
    setState(() {
      if (saved.isNotEmpty && _advice == null) _advice = saved;
      _remind = remind;
    });
  }

  Future<void> _setRemind(bool value) async {
    setState(() => _remind = value);
    await AdviceReminderService.setEnabled(value);
  }

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _reminderLabel(AdviceItem item) {
    if (item.minutes == null) return '';
    final days = item.weekdays.toList()..sort();
    final when = days.length == 7
        ? 'Daily'
        : days.map((d) => _dayLabels[d - 1]).join(' ');
    return '$when · ${item.timeLabel}';
  }

  Future<void> _run() async {
    final signature = _signature;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ref.read(aiSettingsProvider.future);
      if (!settings.enableApiCalls) {
        throw Exception('AI calls are turned off in Settings.');
      }
      final advice = await adviseFromData(settings: settings, facts: signature);
      if (!mounted) return;
      setState(() {
        _advice = advice;
        _forFacts = signature;
      });
      await AdviceReminderService.saveAdvice(advice);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final advice = _advice;
    final stale =
        advice != null && _forFacts.isNotEmpty && _forFacts != _signature;
    final reminderCount = advice == null
        ? 0
        : AdviceReminderService.reminderCount(advice);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge + 8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What to improve',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'The few changes that matter most, from all your data',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (advice != null)
              for (final item in advice)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 20,
                        color: palette.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.text, style: theme.textTheme.bodyMedium),
                            if (item.minutes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_none_rounded,
                                      size: 14,
                                      color: palette.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _reminderLabel(item),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: palette.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (reminderCount > 0)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Remind me ($reminderCount)',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Notifications for the next 2 weeks',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                value: _remind,
                onChanged: _setRemind,
              ),
            if (stale)
              Text(
                'Your data changed since these were made.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.warning,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : _run,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _loading
                      ? 'Thinking…'
                      : advice == null
                      ? 'Get suggestions'
                      : 'Refresh',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
