import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/screens/loans_screen.dart';
import 'package:pocket_sense/screens/recurring_screen.dart';
import 'package:pocket_sense/widgets/reminder_countdown.dart';

import 'helpers/screen_with_db.dart';

void main() {
  test('words, with zero units left out and seconds always there', () {
    final en = lookupAppLocalizations(const Locale('en')), ar = lookupAppLocalizations(const Locale('ar'));
    expect(countdownText(en, const Duration(days: 2, hours: 4, minutes: 5, seconds: 9)), '2 days, 4 hours, 5 minutes, 9 seconds');
    expect(countdownText(en, const Duration(days: 1, seconds: 1)), '1 day, 1 second');
    expect(countdownText(en, Duration.zero), '0 seconds');
    expect(countdownText(ar, const Duration(days: 2, hours: 3)), 'يومان، 3 ساعات، 0 ثانية');
  });

  group('screens', () {
    final repo = FinanceRepo();
    setUp(useSeededTestDb);
    final countdown = find.textContaining('Your next reminder in:');

    testWidgets('a loan with a reminder counts down to it above its repayments', (tester) async {
      final due = DateTime.now().add(const Duration(days: 3));
      final id = (await tester.runAsync(() => repo.insertLoan(
          direction: 'lent', person: 'Ahmad', amountFils: 10000, date: DateTime.now(), dueDate: due, reminderDays: 1, description: 'x')))!;
      await pumpScreenWithDb(tester, LoanScreen(loanId: id));
      expect(countdown, findsOneWidget);
      expect(tester.getTopLeft(countdown).dy, lessThan(tester.getTopLeft(find.text('Repayments')).dy));
    });

    testWidgets('a recurring item with a reminder counts down on its row; one without, or paused, does not', (tester) async {
      final soon = DateTime.now().add(const Duration(days: 3));
      await tester.runAsync(() async {
        await repo.insertRecurring(description: 'Rent', amountFils: 1000, frequency: 'monthly', anchorDate: soon, reminderDays: 1);
        await repo.insertRecurring(description: 'Gym', amountFils: 1000, frequency: 'monthly', anchorDate: soon);
        await repo.insertRecurring(description: 'Paused', amountFils: 1000, frequency: 'monthly', anchorDate: soon, reminderDays: 1, active: false);
      });
      await pumpScreenWithDb(tester, const RecurringScreen());
      expect(countdown, findsOneWidget);
      expect(find.ancestor(of: countdown, matching: find.widgetWithText(Card, 'Rent')), findsOneWidget);
    });
  });
}
