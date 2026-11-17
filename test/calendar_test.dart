import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/screens/recurring_calendar.dart';
import 'package:pocket_sense/screens/recurring_screen.dart';
import 'package:pocket_sense/utils/calendar.dart';
import 'package:pocket_sense/utils/format.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

void main() {
  final today = DateTime(2026, 11, 15);
  setUpAll(() => initializeDateFormatting());

  RecurringExpense rec(String freq, DateTime anchor, {int fils = 1000, String type = 'expense', bool active = true}) =>
      RecurringExpense(id: 1, description: 'x', amountFils: fils, type: type, frequency: freq, anchorDate: anchor, active: active);

  Loan loan(String direction, DateTime? due, {int amount = 70000, int repaid = 0}) => Loan(id: 1, direction: direction, person: 'Ahmad', dueDate: due, amountFils: amount, repaidFils: repaid);

  Circle circle(String frequency, DateTime start, {int paid = 0, int received = 0, int turn = 3}) =>
      Circle(id: 1, name: 'Family', contributionFils: 50000, rounds: 10, frequency: frequency, startDate: start, payoutRound: turn, paidFils: paid, receivedFils: received);

  List<DateTime> dates(List<CalendarItem> items) => items.map((i) => i.date).toList();

  test('a month-end anchor falls to the shorter month\'s last day', () {
    final feb = monthItems(2027, 2, recurring: [rec('monthly', DateTime(2026, 1, 31))], loans: [], circles: [], today: today);
    expect(dates(feb), [DateTime(2027, 2, 28)]);
  });

  test('a weekly circle has a round every week, paused recurring items none', () {
    final nov = monthItems(2026, 11, recurring: [rec('weekly', DateTime(2026, 1, 1), active: false)], loans: [], circles: [circle('weekly', DateTime(2026, 11, 2))], today: today);
    // Round 3 (Nov 16) is your turn, so the payout lands beside it.
    expect(dates(nov.where((i) => !i.payout).toList()), [DateTime(2026, 11, 2), DateTime(2026, 11, 9), DateTime(2026, 11, 16), DateTime(2026, 11, 23), DateTime(2026, 11, 30)]);
    expect(nov.where((i) => i.payout).single.date, DateTime(2026, 11, 16));
  });

  test('overdue: open loans past due and unpaid past rounds; settled and paid ones are not', () {
    final late = overdueItems(
      loans: [loan('lent', DateTime(2026, 10, 22)), loan('lent', DateTime(2026, 10, 1), repaid: 70000), loan('borrowed', DateTime(2026, 11, 30))],
      circles: [
        circle('monthly', DateTime(2026, 9, 15), paid: 50000), // round 1 paid; round 2 (Oct 15) late; round 3 is today
        circle('monthly', DateTime(2026, 6, 1), paid: 300000), // rounds 1-6 paid, but the Aug 1 payout never came in
        circle('monthly', DateTime(2026, 6, 1), paid: 300000, received: 500000), // the same, paid out: nothing late
      ],
      today: today,
    );
    expect(late.map((i) => (i.date, i.loan != null, i.payout)).toList(), [
      (DateTime(2026, 8, 1), false, true),
      (DateTime(2026, 10, 15), false, false),
      (DateTime(2026, 10, 22), true, false),
    ]);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the calendar fits a phone and shows what is overdue (${locale.languageCode})', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = todayDate();
      await tester.pumpWidget(localizedApp(
          Scaffold(
            body: RecurringCalendar(
              recurring: [rec('monthly', DateTime(now.year, now.month, 1), fils: 1250000, type: 'income'), rec('weekly', now)],
              loans: [loan('lent', now.subtract(const Duration(days: 3)))],
              circles: [circle('monthly', DateTime(now.year, now.month - 2, now.day))],
              onEdit: (_) {},
            ),
          ),
          locale: locale));
      // Round 1 is unpaid and two months old, round 2 a month old: both late, with the loan.
      expect(find.text(lookupAppLocalizations(locale).calendarOverdueCount(3)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  group('on the Recurring screen', () {
    setUp(() async {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      await useSeededTestDb();
    });

    testWidgets('a change saved elsewhere keeps the calendar on the month you moved to', (tester) async {
      await pumpScreenWithDb(tester, const RecurringScreen());
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      final now = todayDate(), next = DateFormat.yMMMM().format(DateTime(now.year, now.month + 1));
      expect(find.text(next), findsOneWidget);
      // Any write anywhere, e.g. saving an item opened from the calendar. A frame
      // runs before the reload finishes, as in the app.
      (await tester.runAsync(LocalStore.instance))!.notifyChanged();
      await tester.pump();
      await settleWithDb(tester);
      expect(find.text(next), findsOneWidget);
    });
  });

  test('still due counts only unpaid items from today on, and a payout only until it is received', () {
    final c = circle('monthly', DateTime(2026, 9, 15), paid: 100000, turn: 3);
    final items = monthItems(
      2026,
      11,
      recurring: [
        rec('monthly', DateTime(2026, 1, 1), fils: 1250000, type: 'income'),
        rec('quarterly', DateTime(2026, 2, 15), fils: 90000),
      ],
      loans: [loan('borrowed', DateTime(2026, 11, 30), amount: 125000)],
      circles: [c],
      today: today,
    );
    // Salary on the 1st is past. Gym (90.000), round 3 (50.000) and Omar (125.000) are still to go; the 500.000 payout still to come.
    expect(stillDue(items, today), (coming: 500000, going: 265000));
    final received = monthItems(2026, 11, recurring: [], loans: [], circles: [circle('monthly', DateTime(2026, 9, 15), paid: 100000, received: 500000)], today: today);
    expect(stillDue(received, today).coming, 0);
  });
}
