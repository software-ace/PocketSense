import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/screens/dashboard_screen.dart';
import 'package:pocket_sense/screens/loans_screen.dart';
import 'package:pocket_sense/utils/format.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

String describe(String type, String person) => type == 'expense' ? 'Payment for $person' : 'Payment from $person';

void main() {
  final repo = FinanceRepo();
  setUp(useSeededTestDb);

  Future<int> lend(String person, int fils, DateTime date, {String direction = 'lent'}) => repo.insertLoan(
      direction: direction, person: person, amountFils: fils, date: date, description: describe(direction == 'lent' ? 'expense' : 'income', person));

  Future<void> repay(int id, int? fils, DateTime date) async {
    final loan = (await repo.loan(id))!;
    await repo.recordRepayment(id, amountFils: fils, date: date, description: describe(loan.repaymentType, loan.person));
  }

  test('the worked example: loans move Spent and Income like the cash, and the totals say what is owed', () async {
    final ahmad = await lend('Ahmad', 200000, DateTime(2026, 10, 3));
    await repay(ahmad, 50000, DateTime(2026, 10, 10));
    final sara = await lend('Sara', 100000, DateTime(2026, 10, 15), direction: 'borrowed');
    await repay(ahmad, 30000, DateTime(2026, 10, 20));
    await repay(sara, null, DateTime(2026, 10, 28)); // settle

    final loans = await repo.loans();
    expect(loanTotals(loans), (owedToYou: 120000, youOwe: 0));
    final a = loans.firstWhere((l) => l.id == ahmad), s = loans.firstWhere((l) => l.id == sara);
    expect((a.amountFils, a.repaidFils, a.open, a.date), (200000, 80000, true, DateTime(2026, 10, 3)));
    expect((s.amountFils, s.repaidFils, s.open), (100000, 100000, false));

    final month = await repo.totals(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
    expect(month, (income: 180000, expense: 300000));

    final store = await LocalStore.instance();
    final cats = {for (final c in await store.selectRows('categories')) c['id']: c['uid']};
    final entries = await repo.transactions(limit: 100);
    expect([for (final t in entries.reversed) (t.description, t.type, cats[t.categoryId])], [
      ('Payment for Ahmad', 'expense', 'default:loansPaid'),
      ('Payment from Ahmad', 'income', 'default:loansReceived'),
      ('Payment from Sara', 'income', 'default:loansReceived'),
      ('Payment from Ahmad', 'income', 'default:loansReceived'),
      ('Payment for Sara', 'expense', 'default:loansPaid'),
    ]);
  });

  test('a repayment can\'t be more than what is left, and settling repays exactly that', () async {
    final id = await lend('Lina', 40000, DateTime(2026, 10, 1));
    await expectLater(repay(id, 40001, DateTime(2026, 10, 2)), throwsArgumentError);
    await expectLater(repay(id, 0, DateTime(2026, 10, 2)), throwsArgumentError);
    await repay(id, 15000, DateTime(2026, 10, 2));
    await repay(id, null, DateTime(2026, 10, 3));
    final loan = (await repo.loan(id))!;
    expect((loan.repaidFils, loan.remainingFils, loan.open), (40000, 0, false));
    // Nothing left to settle.
    await expectLater(repay(id, null, DateTime(2026, 10, 4)), throwsArgumentError);
  });

  test('entries edited or deleted in Activity change the loan, which has no copy of its own', () async {
    final id = await lend('Omar', 75000, DateTime(2026, 10, 1), direction: 'borrowed');
    await repay(id, 25000, DateTime(2026, 10, 5));
    final repayment = (await repo.transactions(loanId: id)).firstWhere((t) => t.type == 'expense');

    await repo.updateTransaction(repayment.id,
        amountFils: 30000, type: 'expense', date: repayment.date, description: repayment.description, categoryId: repayment.categoryId);
    expect((await repo.loan(id))!.remainingFils, 45000, reason: 'the link survives an edit in Activity');

    await repo.deleteTransaction(repayment.id);
    expect((await repo.loan(id))!.remainingFils, 75000);
  });

  test('editing a loan renames its generated entries, keeps reworded ones, and won\'t go below what was repaid', () async {
    final id = await lend('Ahmed', 200000, DateTime(2026, 10, 3));
    await repay(id, 50000, DateTime(2026, 10, 10));
    await repay(id, 10000, DateTime(2026, 10, 11));
    final reworded = (await repo.transactions(loanId: id)).firstWhere((t) => t.amountFils == 10000);
    await repo.updateTransaction(reworded.id,
        amountFils: 10000, type: 'income', date: reworded.date, description: 'Cash at lunch', categoryId: reworded.categoryId);

    await expectLater(
        repo.updateLoan(id, person: 'Ahmad', amountFils: 59000, date: DateTime(2026, 10, 3), describe: describe), throwsArgumentError);

    await repo.updateLoan(id, person: 'Ahmad', amountFils: 250000, date: DateTime(2026, 10, 4), dueDate: DateTime(2026, 11, 4), note: 'Rent', describe: describe);
    final loan = (await repo.loan(id))!;
    expect((loan.person, loan.amountFils, loan.repaidFils, loan.date, loan.dueDate, loan.note),
        ('Ahmad', 250000, 60000, DateTime(2026, 10, 4), DateTime(2026, 11, 4), 'Rent'));
    expect((await repo.transactions(loanId: id)).map((t) => t.description).toSet(), {'Payment for Ahmad', 'Payment from Ahmad', 'Cash at lunch'});
  });

  test('deleting a loan deletes its entries, and leaves the rest of Activity alone', () async {
    final id = await lend('Sara', 100000, DateTime(2026, 10, 15));
    await repay(id, 20000, DateTime(2026, 10, 16));
    await repo.insertTransaction(amountFils: 5000, type: 'expense', date: DateTime(2026, 10, 16), description: 'Lunch');

    expect(await repo.deleteLoan(id), 2);
    expect(await repo.loans(), isEmpty);
    expect((await repo.transactions()).map((t) => t.description), ['Lunch']);
    final store = await LocalStore.instance();
    expect((await store.selectRows('tombstones')).map((t) => t['tbl']), containsAll(['loans', 'transactions']),
        reason: 'paired devices delete them too');
  });

  test('a v3 database gets the loans table and the two categories, named in the UI language, above every seq sent', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.insertRow('transactions', {'amount_fils': 1000, 'type': 'expense', 'date': '2026-10-01', 'description': ''});
    final sent = (await store.db.rawQuery('SELECT max(seq) AS s FROM transactions')).first['s'] as int;

    await LocalStore.upgrade(store.db, 3, const {}, categoryNames: const {'loansPaid': 'ديون مدفوعة'});
    await LocalStore.upgrade(store.db, 3, const {}); // a second run changes nothing

    final cats = await store.selectRows('categories');
    expect([for (final c in cats) (c['uid'], c['name'], c['type'])], [
      ('default:loansPaid', 'ديون مدفوعة', 'expense'),
      ('default:loansReceived', 'Loans Received', 'income'),
    ]);
    for (final c in cats) {
      expect(c['seq'] as int, greaterThan(sent));
      expect(LocalStore.hlcPattern.hasMatch(c['hlc'] as String), isTrue);
    }
    final txColumns = [for (final c in await store.db.rawQuery('PRAGMA table_info(transactions)')) c['name']];
    expect(txColumns, contains('loan_id'));
  });

  group('screens', () {
    Future<void> pumpHome(WidgetTester tester) async {
      // As in dashboard_test: wide enough for the stat cards in the test font.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(localizedApp(const DashboardScreen()));
      await settleWithDb(tester);
    }

    testWidgets('Home always shows the Loans card, under the four cards: the way to the first loan', (tester) async {
      await pumpHome(tester);
      expect(find.text('Loans'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Loans')).dy, greaterThan(tester.getTopLeft(find.text('Spent this year')).dy));

      await tester.tap(find.text('Loans'));
      await settleWithDb(tester);
      expect(find.text('No loans yet'), findsOneWidget);
      expect(find.text('New loan'), findsOneWidget);

      await tester.runAsync(() => lend('Ahmad', 200000, DateTime.now()));
      await settleWithDb(tester);
      await tester.pageBack();
      await settleWithDb(tester);
      expect(find.text(formatMoney(200000)), findsWidgets, reason: 'owed to you, and spent');
    });

    testWidgets('a new loan from the Loans screen lists the person and adds the entry', (tester) async {
      await pumpScreenWithDb(tester, const LoansScreen());
      expect(find.text('No loans yet'), findsOneWidget);

      await tester.tap(find.text('New loan'));
      await settleWithDb(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Person'), 'Lina');
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '40');
      await tester.tap(find.text('Save'));
      await settleWithDb(tester);

      expect(find.text('Lina'), findsOneWidget);
      expect(find.text('Owes you'), findsOneWidget);
      final entries = (await tester.runAsync(() => repo.transactions()))!;
      expect(entries.single.description, 'Payment for Lina');
    });

    testWidgets('Record repayment starts at what is left and refuses more', (tester) async {
      final id = (await tester.runAsync(() => lend('Ahmad', 120000, DateTime.now())))!;
      await pumpScreenWithDb(tester, LoanScreen(loanId: id));

      await tester.tap(find.widgetWithText(FilledButton, 'Record repayment'));
      await settleWithDb(tester);
      final amount = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField)).first;
      expect(tester.widget<TextFormField>(amount).controller!.text, isNotEmpty);

      await tester.enterText(amount, '200');
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('At most'), findsOneWidget);

      await tester.enterText(amount, '20');
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Save')));
      await settleWithDb(tester);
      expect((await tester.runAsync(() => repo.loan(id)))!.remainingFils, 100000);
      expect(find.textContaining('repaid'), findsOneWidget);
    });

    testWidgets('Settle asks first, saying what it records; Cancel changes nothing', (tester) async {
      final id = (await tester.runAsync(() => lend('Ahmad', 120000, DateTime.now())))!;
      await pumpScreenWithDb(tester, LoanScreen(loanId: id));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Settle'));
      await tester.pumpAndSettle();
      expect(find.text('Settle this loan?'), findsOneWidget);
      expect(find.textContaining('Ahmad paid back the remaining ${formatMoney(120000)}'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settleWithDb(tester);
      expect((await tester.runAsync(() => repo.loan(id)))!.remainingFils, 120000);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Settle'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Settle')));
      await settleWithDb(tester);
      expect((await tester.runAsync(() => repo.loan(id)))!.open, isFalse);
    });
  });
}
