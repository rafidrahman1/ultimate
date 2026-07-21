import 'package:intl/intl.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';

class MobilityFuelRefuel {
  const MobilityFuelRefuel({
    required this.date,
    required this.amount,
    this.ratePerLitre,
    this.description,
  });

  final DateTime date;
  final double amount;
  final double? ratePerLitre;
  final String? description;
}

class MobilityFuelSummary {
  const MobilityFuelSummary({
    required this.totalSpend,
    required this.refuelCount,
    required this.currency,
    this.refuels = const [],
  });

  final double totalSpend;
  final int refuelCount;
  final String currency;
  final List<MobilityFuelRefuel> refuels;
}

MobilityFuelSummary? mobilityFuelSummaryFromExpenses(ExpensesSummary expenses) {
  final fuelTransactions =
      expenses.transactions
          .where((tx) => tx.isRealExpense && ExpensesSummary.isFuelExpense(tx))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  if (fuelTransactions.isEmpty) return null;

  final refuels = fuelTransactions
      .map(
        (tx) => MobilityFuelRefuel(
          date: tx.date,
          amount: tx.amount.abs(),
          ratePerLitre: ExpensesSummary.fuelRatePerLitreFromDescription(tx),
          description: tx.note?.trim().isNotEmpty == true
              ? tx.note!.trim()
              : tx.title?.trim(),
        ),
      )
      .toList();

  return MobilityFuelSummary(
    totalSpend: refuels.fold(0.0, (sum, refuel) => sum + refuel.amount),
    refuelCount: refuels.length,
    currency: expenses.currency,
    refuels: refuels,
  );
}

String formatMobilityDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatMobilityTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
