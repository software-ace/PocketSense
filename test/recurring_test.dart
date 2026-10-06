import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/utils/recurring.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);
  DateTime next(String freq, DateTime anchor, DateTime from) => nextOccurrence(freq, anchor, from);

  group('yearly', () {
    test('keeps the anchor month (Sep 20 is next due in September, not Oct 20)', () {
      expect(next('yearly', d(2026, 9, 20), d(2026, 10, 1)), d(2027, 9, 20));
    });
    test('due later this year', () {
      expect(next('yearly', d(2025, 12, 5), d(2026, 10, 1)), d(2026, 12, 5));
    });
    test('due today', () {
      expect(next('yearly', d(2024, 10, 1), d(2026, 10, 1)), d(2026, 10, 1));
    });
  });

  group('quarterly', () {
    test('keeps its 3-month rhythm', () {
      // Jan 15, Apr 15, Jul 15, Oct 15…
      expect(next('quarterly', d(2026, 1, 15), d(2026, 2, 1)), d(2026, 4, 15));
      expect(next('quarterly', d(2026, 1, 15), d(2026, 4, 16)), d(2026, 7, 15));
      expect(next('quarterly', d(2026, 1, 15), d(2026, 10, 1)), d(2026, 10, 15));
    });
  });

  group('monthly', () {
    test('this month or next', () {
      expect(next('monthly', d(2026, 1, 25), d(2026, 10, 1)), d(2026, 10, 25));
      expect(next('monthly', d(2026, 1, 5), d(2026, 10, 6)), d(2026, 11, 5));
    });
    test('month-end overflow rolls forward', () {
      // Jan 31, then "Feb 31" = Mar 3 in 2026.
      expect(next('monthly', d(2026, 1, 31), d(2026, 2, 1)), d(2026, 3, 3));
    });
  });

  group('weekly and bi-weekly', () {
    test('weekly lands on the anchor weekday', () {
      // Thu Oct 1, 2026 → next Monday from a Monday anchor.
      expect(next('weekly', d(2026, 9, 7), d(2026, 10, 1)), d(2026, 10, 5));
    });
    test('bi-weekly keeps its week', () {
      // Anchored Mon Sep 7: Sep 21, Oct 5, Oct 19… so not Mon Sep 28.
      expect(next('biweekly', d(2026, 9, 7), d(2026, 9, 22)), d(2026, 10, 5));
      expect(next('biweekly', d(2026, 9, 7), d(2026, 10, 5)), d(2026, 10, 5));
    });
    test('across a daylight-saving change', () {
      // Most of Europe and the US change clocks between these dates.
      expect(next('weekly', d(2026, 3, 2), d(2026, 4, 1)), d(2026, 4, 6));
      expect(next('weekly', d(2026, 10, 19), d(2026, 11, 3)), d(2026, 11, 9));
    });
  });

  test('a future first due date is the next occurrence, for every frequency', () {
    for (final f in frequencies) {
      expect(next(f, d(2026, 12, 5), d(2026, 10, 1)), d(2026, 12, 5), reason: f);
    }
  });

  test('unknown frequency throws', () {
    expect(() => next('daily', d(2026, 1, 1), d(2026, 2, 1)), throwsArgumentError);
  });
}
