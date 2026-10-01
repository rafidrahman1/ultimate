import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/progress_review/progress_review_evaluation.dart';

void main() {
  test('computes income ratios and headroom under the cap', () {
    const ratios = VerifiedFinancialRatios(
      actualExpensesBdt: 30000,
      monthlyBaselineBdt: 60000,
      spendingCapBdt: 36000,
    );

    expect(ratios.actualPercentOfIncome, 50);
    expect(ratios.capPercentOfIncome, 60);
    expect(ratios.headroomPercentUnderCap, 10);
    expect(
      ratios.buildExpenseDeltaLine(),
      contains('Headroom remaining under cap: 10.0%'),
    );
  });

  test('no baseline means no percentages', () {
    const ratios = VerifiedFinancialRatios(
      actualExpensesBdt: 30000,
      monthlyBaselineBdt: 0,
    );
    expect(ratios.actualPercentOfIncome, isNull);
    expect(ratios.toPromptBlock(), contains('do not compute'));
  });
}
