import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/journal/data/journal_models.dart';
import 'package:personal/features/journal/data/journal_service.dart';
import 'package:personal/features/journal/ui/check_in_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/content_width.dart';

final _time = DateFormat('HH:mm');
final _day = DateFormat('EEE d MMM');

/// The hand-logged side of the app: how the day felt, and when the coffees
/// and meals were.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  Future<void> _logAt(
    BuildContext context,
    WidgetRef ref,
    IntakeKind kind,
  ) async {
    final now = clock.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: '${kind.label} at',
    );
    if (picked == null) return;
    var at = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    // A time still ahead today was yesterday evening's.
    if (at.isAfter(now)) at = at.subtract(const Duration(days: 1));
    await ref.read(journalProvider.notifier).logIntake(kind, at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final journal = ref.watch(journalProvider);
    final notifier = ref.read(journalProvider.notifier);
    final today = habitDayOf(clock.now());
    final todays = journal.intakesOn(today).reversed.toList();
    final history = journal.checkIns.reversed.take(14).toList();
    final coffeeDays = journal.countByDay(IntakeKind.caffeine).length;
    final mealDays = journal.countByDay(IntakeKind.meal).length;

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Check-in'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            const CheckInCard(),
            const SizedBox(height: AppSpacing.lg),
            CategoryPanel(
              title: 'Coffee & meals',
              trailing: todays.isEmpty ? null : '${todays.length} today',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  for (final kind in IntakeKind.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () =>
                                  notifier.logIntake(kind, clock.now()),
                              icon: Icon(
                                kind == IntakeKind.caffeine
                                    ? Icons.coffee_rounded
                                    : Icons.restaurant_rounded,
                                size: 18,
                              ),
                              label: Text('${kind.label} now'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () => _logAt(context, ref, kind),
                            child: const Text('Earlier'),
                          ),
                        ],
                      ),
                    ),
                  for (final e in todays)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.kind.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          _time.format(e.at),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete entry',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => notifier.removeIntake(e),
                        ),
                      ],
                    ),
                  Text(
                    'Only the last coffee and the last meal of each day are '
                    'compared with your sleep, so those are the ones worth '
                    'logging. Logged on $coffeeDays coffee '
                    '${coffeeDays == 1 ? 'day' : 'days'} and $mealDays meal '
                    '${mealDays == 1 ? 'day' : 'days'}; each prediction '
                    'starts at 8.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CategoryPanel(
              title: 'Past check-ins',
              trailing: journal.checkIns.isEmpty
                  ? null
                  : '${journal.checkIns.length} logged',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  if (history.isEmpty)
                    Text(
                      'Nothing yet. After 7 check-ins the Energy today '
                      'prediction appears; it starts naming what moves your '
                      'energy once a habit lines up on 8 days.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  for (final c in history)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _day.format(c.day),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          'mood ${c.mood} · energy ${c.energy} · '
                          'stress ${c.stress}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete check-in',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => notifier.removeCheckIn(c.day),
                        ),
                      ],
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
