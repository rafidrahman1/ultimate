import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/journal/data/journal_models.dart';
import 'package:personal/features/journal/data/journal_service.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';

/// Today's check-in: mood, energy and stress on a 1 to 5 scale. Saves as soon
/// as all three are picked, and again on every later change.
class CheckInCard extends ConsumerStatefulWidget {
  const CheckInCard({super.key});

  @override
  ConsumerState<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<CheckInCard> {
  int? _mood;
  int? _energy;
  int? _stress;
  bool _touched = false;

  void _set({int? mood, int? energy, int? stress}) {
    setState(() {
      _touched = true;
      _mood = mood ?? _mood;
      _energy = energy ?? _energy;
      _stress = stress ?? _stress;
    });
    final m = _mood;
    final e = _energy;
    final s = _stress;
    if (m == null || e == null || s == null) return;
    ref
        .read(journalProvider.notifier)
        .checkIn(habitDayOf(clock.now()), mood: m, energy: e, stress: s);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(journalProvider).checkInOn(habitDayOf(clock.now()));
    if (!_touched && saved != null) {
      _mood = saved.mood;
      _energy = saved.energy;
      _stress = saved.stress;
    }
    final left = [_mood, _energy, _stress].where((v) => v == null).length;
    return CategoryPanel(
      title: 'How was today?',
      trailing: saved != null && left == 0
          ? 'saved'
          : left == 3
          ? null
          : '$left to go',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScaleRow(
            label: 'Mood',
            low: 'low',
            high: 'great',
            value: _mood,
            onChanged: (v) => _set(mood: v),
          ),
          _ScaleRow(
            label: 'Energy',
            low: 'drained',
            high: 'full',
            value: _energy,
            onChanged: (v) => _set(energy: v),
          ),
          _ScaleRow(
            label: 'Stress',
            low: 'calm',
            high: 'tense',
            value: _stress,
            onChanged: (v) => _set(stress: v),
          ),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.label,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String low;
  final String high;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
              Text(
                '1 $low · 5 $high',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<int>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (var v = 1; v <= 5; v++)
                ButtonSegment(
                  value: v,
                  label: Semantics(
                    label: '$label $v of 5',
                    excludeSemantics: true,
                    child: Text('$v'),
                  ),
                ),
            ],
            selected: {?value},
            onSelectionChanged: (picked) {
              if (picked.isNotEmpty) onChanged(picked.first);
            },
          ),
        ],
      ),
    );
  }
}
