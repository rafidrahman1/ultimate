import 'package:intl/intl.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';

String _money(double amount, String currency) {
  // Float noise from summing paired corrections would print as "-0".
  final clean = amount.abs() < 0.005 ? 0.0 : amount;
  return '${formatExpenseMoney(clean)} $currency';
}

/// Savings, debts, a normal month, bookkeeping gaps and income sources: the
/// money that moves without being spent. Aggregates only. Debts are totals
/// and counts, never names.
String buildMoneyFlowText(
  ExpensesSummary summary, {
  DateTime? periodStart,
  DateTime? now,
}) {
  final insights = computeExpenseInsights(
    summary,
    periodStart: periodStart,
    now: now,
  );
  final currency = summary.currency;
  final lines = <String>[];

  // Not spending, so the totals above aren't a mystery.
  final loanMovement = summary.transactions
      .where((t) => t.isLoanMovement && t.amount != 0)
      .fold<double>(0, (sum, t) => sum + t.amount.abs());
  final excluded = <String>[
    if (insights.savings.saved > 0)
      'savings ${_money(insights.savings.saved, currency)}',
    if (loanMovement > 0) 'loan movements ${_money(loanMovement, currency)}',
  ];
  if (excluded.isNotEmpty) {
    lines.add(
      '- Not counted as spending: ${excluded.join(', ')} '
      '(money set aside or moved between people, not consumed)',
    );
  }

  final typical = insights.typicalMonth;
  final projection = insights.projection;
  if (typical != null) {
    lines.add(
      '- Typical month: ${_money(typical, currency)} of spending '
      '(median of recent months)',
    );
  }
  if (projection != null) {
    lines.add(
      '- On pace for ${_money(projection.projected, currency)} this month '
      '(${_money(projection.spentSoFar, currency)} spent in '
      '${projection.daysElapsed} of ${projection.daysInMonth} days, then a '
      'normal daily rate)',
    );
  }

  final savings = insights.savings;
  if (savings.hasActivity) {
    final rate = savings.rate;
    lines.add(
      '- Savings: ${_money(savings.saved, currency)} put aside in '
      '${savings.deposits} ${savings.deposits == 1 ? 'transfer' : 'transfers'}'
      '${savings.withdrawn > 0 ? ', ${_money(savings.withdrawn, currency)} taken out' : ''}'
      '${rate == null ? '' : ' (net ${(rate * 100).round()}% of income)'}',
    );
  }
  final activeRecurring = insights.recurring.where(
    (r) => r.isActive(now ?? DateTime.now()),
  );
  if (activeRecurring.isNotEmpty) {
    lines.add(
      '- Active recurring entries: ${activeRecurring.length} '
      '(${activeRecurring.map((r) => '${r.label} ${r.cadence}').join(', ')})',
    );
  } else if (insights.recurring.isNotEmpty) {
    lines.add(
      '- Recurring entries: ${insights.recurring.length} found, none active '
      'recently',
    );
  }

  final loans = insights.loans;
  if (loans.hasAny) {
    final parts = <String>[
      if (loans.youOwe > 0)
        'you owe ${_money(loans.youOwe, currency)} across '
            '${loans.borrowedCount} ${loans.borrowedCount == 1 ? 'person' : 'people'}',
      if (loans.owedToYou > 0)
        'you are owed ${_money(loans.owedToYou, currency)} across '
            '${loans.lentCount} ${loans.lentCount == 1 ? 'person' : 'people'}',
    ];
    final oldest = loans.oldest;
    final age = oldest == null
        ? ''
        : ', oldest unsettled from ${DateFormat('MMM yyyy').format(oldest)}';
    lines.add('- Debts: ${parts.join('; ')}$age');
  }

  final corrections = insights.corrections;
  if (corrections.count > 0) {
    lines.add(
      '- Balance corrections: ${corrections.count} '
      '(net ${_money(corrections.net, currency)}, '
      '${_money(corrections.absoluteTotal, currency)} adjusted in total)'
      '${corrections.suggestsMissedEntries ? ' — many adjustments usually mean transactions were not recorded' : ''}',
    );
  }

  if (insights.incomeMix.isNotEmpty) {
    lines.add(
      '- Income sources: ${insights.incomeMix.map((s) => '${s.label} ${_money(s.amount, currency)}').join(', ')}',
    );
  }

  if (insights.merchants.isNotEmpty) {
    lines.add(
      '- Most frequent places: ${insights.merchants.take(3).map((m) => '${m.name} ${m.count}× (${_money(m.total, currency)})').join(', ')}',
    );
  }

  // Recent months, so a single month isn't read in isolation.
  final recent = summary.history
      .where((m) => m.spend > 0 || m.income > 0 || m.saved > 0)
      .toList();
  if (recent.length >= 2) {
    final shown = recent.length > 6
        ? recent.sublist(recent.length - 6)
        : recent;
    lines.add('- Recent months (spending / income / saved):');
    for (final m in shown) {
      lines.add(
        '  - ${DateFormat('MMM yyyy').format(m.month)}: '
        '${formatExpenseMoney(m.spend)} / ${formatExpenseMoney(m.income)} / '
        '${formatExpenseMoney(m.saved)}',
      );
    }
  }

  if (lines.isEmpty) return '';
  return ['Money Flow:', ...lines].join('\n');
}
