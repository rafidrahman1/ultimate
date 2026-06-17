import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';

CashewTransaction _expense(DateTime date) {
  return CashewTransaction(
    account: 'Bank',
    amount: -500,
    currency: 'BDT',
    date: date,
    isIncome: false,
    title: 'Dinner',
    category: 'Food',
    subcategory: 'Restaurant',
  );
}

void main() {
  group('findExpenseEventAssociation', () {
    test('links purchase during timed event', () {
      final association = findExpenseEventAssociation(
        transaction: _expense(DateTime(2026, 6, 14, 19, 15)),
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Wife outing',
            start: DateTime(2026, 6, 14, 18),
            end: DateTime(2026, 6, 14, 21),
            isHoliday: false,
          ),
        ],
      );

      expect(association.hasAssociation, isTrue);
      expect(association.timingDetail, contains('during event'));
    });

    test('rejects purchase more than 2h before timed event', () {
      final association = findExpenseEventAssociation(
        transaction: _expense(DateTime(2026, 6, 14, 5)),
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Evening plans',
            start: DateTime(2026, 6, 14, 18),
            end: DateTime(2026, 6, 14, 21),
            isHoliday: false,
          ),
        ],
      );

      expect(association.hasAssociation, isFalse);
    });

    test('uses day offsets for all-day events within one day', () {
      final association = findExpenseEventAssociation(
        transaction: _expense(DateTime(2026, 6, 13, 13, 20)),
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Trip',
            start: DateTime(2026, 6, 14),
            end: DateTime(2026, 6, 16, 23, 59, 59),
            isHoliday: false,
            allDay: true,
          ),
        ],
      );

      expect(association.hasAssociation, isTrue);
      expect(association.timingDetail, '1 day before event start');
    });

    test('rejects purchase more than one day from all-day event', () {
      final association = findExpenseEventAssociation(
        transaction: _expense(DateTime(2026, 6, 12, 13, 20)),
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Trip',
            start: DateTime(2026, 6, 14),
            end: DateTime(2026, 6, 16, 23, 59, 59),
            isHoliday: false,
            allDay: true,
          ),
        ],
      );

      expect(association.hasAssociation, isFalse);
      expect(association.linkType, ExpenseEventLinkType.unrelated);
    });

    test('labels post-event spending outside attribution window', () {
      final association = findExpenseEventAssociation(
        transaction: _expense(DateTime(2026, 6, 16, 1)),
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Rick and Morty',
            start: DateTime(2026, 6, 15, 20),
            end: DateTime(2026, 6, 15, 22),
            isHoliday: false,
          ),
        ],
      );

      expect(association.hasAssociation, isFalse);
      expect(
        association.linkType,
        ExpenseEventLinkType.postEventLowConfidence,
      );
    });
  });
}
