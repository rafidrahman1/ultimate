import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';

/// A value over its label.
class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Stats side by side, wrapping onto a second line when text is large.
class _StatRow extends StatelessWidget {
  const _StatRow(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xl,
    runSpacing: AppSpacing.md,
    children: children,
  );
}

/// How this month is going against a normal one.
class MonthPacePanel extends StatelessWidget {
  const MonthPacePanel({
    super.key,
    required this.projection,
    required this.money,
  });

  final MonthProjection projection;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final over = projection.projected > projection.typicalMonth * 1.15;
    final under = projection.projected < projection.typicalMonth * 0.85;
    final verdict = over
        ? 'Above a normal month'
        : under
        ? 'Below a normal month'
        : 'In line with a normal month';

    return CategoryPanel(
      title: 'This month',
      trailing: 'day ${projection.daysElapsed} of ${projection.daysInMonth}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatRow([
            _Stat('spent so far', money.format(projection.spentSoFar)),
            _Stat(
              'on pace for',
              money.format(projection.projected),
              color: over ? palette.warning : accent,
            ),
            _Stat('a normal month', money.format(projection.typicalMonth)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$verdict. The pace adds a normal day’s spending for each day left, '
            'so one big purchase doesn’t skew it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Spending per month with a line at the typical month.
class MonthlyTrendPanel extends StatelessWidget {
  const MonthlyTrendPanel({
    super.key,
    required this.history,
    required this.typicalMonth,
    required this.money,
  });

  final List<MonthlyExpenseRow> history;
  final double? typicalMonth;
  final NumberFormat money;

  static const _months = 12;

  @override
  Widget build(BuildContext context) {
    final accent = AppSemanticColors.expenses(context);
    final rows = history.length > _months
        ? history.sublist(history.length - _months)
        : history;

    return CategoryPanel(
      title: 'Spending by month',
      trailing: 'excludes savings and loans',
      child: DayBars(
        data: [for (final r in rows) DayBarDatum(r.month, r.spend)],
        color: accent,
        target: typicalMonth,
        targetLabel: typicalMonth == null ? null : 'Typical month',
        format: (v) => money.format(v),
        readoutDateFormat: 'MMMM yyyy',
        averageLabel: 'Average per month',
        unitNoun: 'months',
        axisLabel: (d) => DateFormat.MMM().format(d),
        axisLabelEvery: 2,
        emptyLabel: 'No history yet',
      ),
    );
  }
}

/// Money set aside, and the recurring entries behind it.
class SavingsPanel extends StatelessWidget {
  const SavingsPanel({
    super.key,
    required this.savings,
    required this.recurring,
    required this.money,
    this.now,
  });

  final SavingsStats savings;
  final List<RecurringSeries> recurring;
  final NumberFormat money;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.accent(context);
    final today = now ?? DateTime.now();
    final rate = savings.rate;
    final active = recurring.where((r) => r.isActive(today)).toList();
    final ended = recurring.where((r) => !r.isActive(today)).toList();
    // Running entries first; show a few ended ones for context.
    final shownActive = active.take(4).toList();
    final shownEnded = ended.take(active.isEmpty ? 3 : 1).toList();
    final hidden = recurring.length - shownActive.length - shownEnded.length;

    Widget seriesRow(RecurringSeries r, {required bool live}) => CategoryRow(
      icon: live ? Icons.repeat_rounded : Icons.history_toggle_off_rounded,
      accent: accent,
      muted: !live,
      title: r.label,
      subtitle:
          '${money.format(r.typicalAmount.abs())} ${r.cadence} · ${r.count} times',
      trailing: live
          ? 'active'
          : 'last ${DateFormat('MMM yyyy').format(r.last)}',
    );

    return CategoryPanel(
      title: 'Savings',
      trailing: rate == null ? null : '${(rate * 100).round()}% of income',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (savings.hasActivity)
            _StatRow([
              _Stat('put aside', money.format(savings.saved), color: accent),
              if (savings.withdrawn > 0)
                _Stat('taken out', money.format(savings.withdrawn)),
              _Stat('net', money.format(savings.net), color: accent),
            ])
          else
            Text(
              'Nothing moved into savings in this period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          if (active.isNotEmpty || ended.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Recurring',
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.textMuted,
              ),
            ),
            for (final r in shownActive) seriesRow(r, live: true),
            for (final r in shownEnded) seriesRow(r, live: false),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$hidden more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Who you owe and who owes you, from Cashew's lent/borrowed records.
class DebtsPanel extends StatelessWidget {
  const DebtsPanel({super.key, required this.loans, required this.money});

  final LoanSummary loans;
  final NumberFormat money;

  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final owe = palette.warning;
    final owed = AppSemanticColors.accent(context);
    final dateFormat = DateFormat('d MMM yyyy');

    // Largest first within what's shown, so the debts that matter lead.
    final items = [...loans.items]
      ..sort((a, b) => b.unpaid.compareTo(a.unpaid));
    final shown = items.take(_shown).toList();

    return CategoryPanel(
      title: 'Debts',
      trailing: '${loans.items.length} unsettled',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatRow([
            _Stat('you owe', money.format(loans.youOwe), color: owe),
            _Stat('you are owed', money.format(loans.owedToYou), color: owed),
          ]),
          const SizedBox(height: AppSpacing.sm),
          for (final loan in shown)
            CategoryRow(
              icon: loan.owedToYou
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
              accent: loan.owedToYou ? owed : owe,
              title: loan.person?.isNotEmpty == true
                  ? loan.person!
                  : (loan.owedToYou ? 'Lent' : 'Borrowed'),
              subtitle:
                  '${loan.owedToYou ? 'You lent' : 'You borrowed'} · '
                  '${dateFormat.format(loan.date)}',
              detail: loan.note,
              trailing: money.format(loan.unpaid),
              trailingColor: loan.owedToYou ? owed : owe,
            ),
          if (items.length > _shown)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${items.length - _shown} smaller',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'From Cashew’s lent and borrowed records. Settle them in Cashew '
            'and they disappear here.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Income by source, and the places you return to.
class IncomeMixPanel extends StatelessWidget {
  const IncomeMixPanel({super.key, required this.slices, required this.money});

  final List<IncomeSlice> slices;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return CategoryPanel(
      title: 'Income sources',
      child: BreakdownBars(
        color: AppSemanticColors.accent(context),
        items: [
          for (final s in slices)
            (
              label: s.label,
              value: s.amount,
              display: '${money.format(s.amount)} · ${s.count}×',
            ),
        ],
      ),
    );
  }
}

class RepeatPlacesPanel extends StatelessWidget {
  const RepeatPlacesPanel({
    super.key,
    required this.merchants,
    required this.money,
  });

  final List<MerchantStat> merchants;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return CategoryPanel(
      title: 'Places you return to',
      trailing: 'by spend',
      child: BreakdownBars(
        color: AppSemanticColors.expenses(context),
        maxItems: 5,
        items: [
          for (final m in merchants)
            (
              label: m.name,
              value: m.total,
              display: '${money.format(m.total)} · ${m.count}×',
            ),
        ],
      ),
    );
  }
}

/// A nudge when balance corrections suggest missed entries.
class CorrectionsHint extends StatelessWidget {
  const CorrectionsHint({super.key, required this.stats, required this.money});

  final CorrectionStats stats;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_rounded, color: palette.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.count} balance corrections',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'They adjusted ${money.format(stats.absoluteTotal)} in total '
                  '(net ${money.format(stats.net)}). Many corrections usually '
                  'mean some purchases weren’t recorded, so spending may be '
                  'understated.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
