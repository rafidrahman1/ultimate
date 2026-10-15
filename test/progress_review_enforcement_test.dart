import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/results/reports/insights_models.dart';

ActionDirective _action(String text) =>
    ActionDirective(title: text, description: '', category: 'Expenses');

void main() {
  group('parseMonthlyIncomeBdt', () {
    test('strips currency symbols and separators', () {
      expect(parseMonthlyIncomeBdt('৳ 65,000'), 65000);
      expect(parseMonthlyIncomeBdt('BDT 12,500.50'), 12500.5);
    });

    test('returns null when there are no digits', () {
      expect(parseMonthlyIncomeBdt('varies'), isNull);
      expect(parseMonthlyIncomeBdt(''), isNull);
    });
  });

  group('extractSpendingCapBdt', () {
    test('finds a cap phrased several ways', () {
      expect(
        extractSpendingCapBdt([_action('Keep outlays below 40,000 BDT')]),
        40000,
      );
      expect(extractSpendingCapBdt([_action('Capped at 35000 BDT')]), 35000);
    });

    test('takes the highest cap when several are present', () {
      expect(
        extractSpendingCapBdt([
          _action('Stay under 30,000 BDT'),
          _action('Stay under 45,000 BDT'),
        ]),
        45000,
      );
    });

    test('is null when no action states a cap', () {
      expect(extractSpendingCapBdt([_action('Cook at home more')]), isNull);
    });
  });
}
