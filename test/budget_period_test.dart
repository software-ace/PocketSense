import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/utils/budget_period.dart';

void main() {
  group('weekly', () {
    test('runs Monday to Sunday', () {
      // Sun 2026-09-27 belongs to the week that started Mon 2026-09-21.
      final w = budgetPeriod('weekly', DateTime(2026, 9, 27, 23, 59));
      expect(w.start, DateTime(2026, 9, 21));
      expect(w.end, DateTime(2026, 9, 27));
    });

    test('a Monday starts a new week, even across a month boundary', () {
      final w = budgetPeriod('weekly', DateTime(2026, 9, 28, 8));
      expect(w.start, DateTime(2026, 9, 28));
      expect(w.end, DateTime(2026, 10, 4));
    });

    // Egypt's clocks change on Apr 24 and Oct 30, 2026. These catch 24-hour
    // steps only where clocks change (run with TZ=Africa/Cairo); elsewhere
    // they still pin the dates.
    test('a week with a clock change still runs midnight Monday to Sunday', () {
      for (final (now, monday) in [(DateTime(2026, 4, 25, 12), DateTime(2026, 4, 20)), (DateTime(2026, 10, 31, 12), DateTime(2026, 10, 26))]) {
        final w = budgetPeriod('weekly', now);
        expect((w.start, w.end), (monday, DateTime(monday.year, monday.month, monday.day + 6)));
      }
    });

    test('spans a year boundary', () {
      final w = budgetPeriod('weekly', DateTime(2027, 1, 1));
      expect(w.start, DateTime(2026, 12, 28));
      expect(w.end, DateTime(2027, 1, 3));
    });
  });

  group('monthly', () {
    test('runs from the 1st to the last day', () {
      final m = budgetPeriod('monthly', DateTime(2026, 9, 15));
      expect(m.start, DateTime(2026, 9, 1));
      expect(m.end, DateTime(2026, 9, 30));
    });

    test('handles leap-year February', () {
      expect(budgetPeriod('monthly', DateTime(2028, 2, 10)).end, DateTime(2028, 2, 29));
    });

    test('unknown periods fall back to monthly', () {
      expect(budgetPeriod('yearly', DateTime(2026, 9, 15)).start, DateTime(2026, 9, 1));
    });
  });
}
