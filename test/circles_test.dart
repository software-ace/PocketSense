import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/screens/circles_screen.dart';
import 'package:pocket_sense/sync/merge.dart';
import 'package:pocket_sense/utils/reminders.dart';

import 'helpers/screen_with_db.dart';

String describe(String type, String name) => type == 'expense' ? 'Payment to $name' : 'Payout from $name';

Circle circle({int rounds = 10, int turn = 3, int paid = 0, int received = 0, String frequency = 'monthly', DateTime? start}) => Circle(
      id: 1,
      name: 'Family',
      contributionFils: 50000,
      rounds: rounds,
      frequency: frequency,
      startDate: start ?? DateTime(2026, 1, 31),
      payoutRound: turn,
      paidFils: paid,
      receivedFils: received,
    );

void main() {
  group('the figures', () {
    test('a month-end start stays at month end, weeks step by 7 and 14 days', () {
      final c = circle();
      expect([for (var r = 1; r <= 4; r++) c.dueDate(r)], [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
      expect(circle(frequency: 'weekly', start: DateTime(2026, 3, 1)).dueDate(3), DateTime(2026, 3, 15));
      expect(circle(frequency: 'biweekly', start: DateTime(2026, 3, 1)).dueDate(2), DateTime(2026, 3, 15));
    });

    test('payments fill rounds oldest first; a part payment is the next round\'s', () {
      final c = circle(paid: 120000);
      expect((c.paidRounds, c.partialFils, c.nextRound, c.leftToPayFils), (2, 20000, 3, 380000));
      expect(c.overdue(DateTime(2026, 3, 31)), isFalse);
      expect(c.overdue(DateTime(2026, 4, 1)), isTrue, reason: 'round 3 was due Mar 31');
    });

    test('an early turn is owed to the circle, a late one is saved ahead', () {
      // Turn 3 of 10, three rounds paid and the pot taken: 350 owed back.
      final early = circle(paid: 150000, received: 500000);
      expect(early.positionFils, 350000);
      expect((early.upToTurnFils, early.afterTurnFils), (150000, 350000));
      // Turn 9: eight rounds in, nothing back yet.
      final late = circle(turn: 9, paid: 400000);
      expect(late.positionFils, -400000);
      expect(circleTotals([early, late]), (owedToYou: 400000, youOwe: 350000));
    });

    test('done once everything is paid and the payout is in', () {
      expect(circle(paid: 500000).done, isFalse);
      expect(circle(paid: 500000, received: 500000).done, isTrue);
      expect(circle(paid: 600000).nextRound, isNull, reason: 'overpaying stops at the last round');
    });

    test('the countdown\'s words follow each language\'s plurals', () {
      final ar = lookupAppLocalizations(const Locale('ar')), en = lookupAppLocalizations(const Locale('en'));
      expect([for (final n in [1, 2, 3, 11, 100]) ar.countdownDays(n)], ['يوم واحد', 'يومان', '3 أيام', '11 يومًا', '100 يوم']);
      expect([ar.countdownSeconds(2), ar.countdownSeconds(5)], ['ثانيتان', '5 ثوانٍ']);
      expect([en.countdownHours(1), en.countdownHours(4)], ['1 hour', '4 hours']);
    });

    test('a bad row from a peer still gives defined figures', () {
      final c = Circle.fromMap({'id': 1, 'name': 'x', 'contribution_fils': 0, 'rounds': 1 << 30, 'payout_round': -4, 'start_date': 'junk'});
      expect((c.contributionFils, c.rounds, c.payoutRound), (1, Circle.maxRounds, 1));
      expect(c.paidRounds, 0);
    });
  });

  group('the repo', () {
    final repo = FinanceRepo();
    setUp(useSeededTestDb);

    test('payments are spending and the payout income, in the circle categories, and delete goes with the circle', () async {
      final id = await repo.insertCircle(
          name: 'Family', contributionFils: 50000, rounds: 10, frequency: 'monthly', startDate: DateTime(2026, 10, 1), payoutRound: 2);
      await repo.recordCircleEntry(id, type: 'expense', amountFils: 50000, date: DateTime(2026, 10, 1), description: describe('expense', 'Family'));
      await repo.recordCircleEntry(id, type: 'expense', amountFils: 50000, date: DateTime(2026, 11, 1), description: describe('expense', 'Family'));
      await repo.recordCircleEntry(id, type: 'income', amountFils: 500000, date: DateTime(2026, 11, 1), description: describe('income', 'Family'));

      final c = (await repo.circle(id))!;
      expect((c.paidFils, c.receivedFils, c.paidRounds, c.positionFils), (100000, 500000, 2, 400000));
      expect(await repo.totals(DateTime(2026, 10, 1), DateTime(2026, 11, 30)), (income: 500000, expense: 100000));
      final txs = await repo.transactions(circleId: id);
      expect(txs.map((t) => (t.categoryName, t.circleId)).toSet(), {('Circle Payments', id), ('Circle Payouts', id)});

      await repo.updateCircle(id,
          name: 'Cousins', contributionFils: 50000, rounds: 10, frequency: 'monthly', startDate: DateTime(2026, 10, 1), payoutRound: 2, describe: describe);
      expect((await repo.transactions(circleId: id)).map((t) => t.description).toSet(), {'Payment to Cousins', 'Payout from Cousins'});

      expect(await repo.deleteCircle(id), 3);
      expect(await repo.circles(), isEmpty);
      expect(await repo.transactions(circleId: id), isEmpty);
    });

    test('refuses a turn outside the circle', () async {
      expect(
          () => repo.insertCircle(name: 'x', contributionFils: 1000, rounds: 5, frequency: 'monthly', startDate: DateTime(2026), payoutRound: 6),
          throwsArgumentError);
    });
  });

  test('a v7 database gets the circles table and its two categories, above every seq sent', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.insertRow('transactions', {'amount_fils': 1000, 'type': 'expense', 'date': '2026-10-01', 'description': ''});
    final sent = (await store.db.rawQuery('SELECT max(seq) AS s FROM transactions')).first['s'] as int;
    await LocalStore.upgrade(store.db, 7, const {}, categoryNames: const {'circlePayments': 'دفعات الجمعيات'});
    await LocalStore.upgrade(store.db, 7, const {}); // a second run changes nothing

    final cats = await store.selectRows('categories');
    expect([for (final c in cats) (c['uid'], c['name'])],
        [('default:circlePayments', 'دفعات الجمعيات'), ('default:circlePayouts', 'Circle Payouts')]);
    expect(cats.every((c) => (c['seq'] as int) > sent), isTrue);
  });

  test('reminds before each round not yet paid', () {
    final c = Circle(
        id: 7, name: 'Family', contributionFils: 50000, rounds: 4, frequency: 'monthly', startDate: DateTime(2026, 1, 10), payoutRound: 1,
        reminderDays: 1, paidFils: 50000);
    final rs = remindersBetween(const [], const [], DateTime(2026, 1, 1), DateTime(2026, 12, 31), [c]);
    expect(rs.map((r) => (r.payload, r.due)), [
      ('circle:7', DateTime(2026, 2, 10)),
      ('circle:7', DateTime(2026, 3, 10)),
      ('circle:7', DateTime(2026, 4, 10)),
    ]);
    expect(rs.first.at, DateTime(2026, 2, 9, 9));
  });

  test('circles and their entries sync with the link between them', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final id = await a.insertRow('circles',
        {'name': 'Family', 'contribution_fils': 50000, 'rounds': 10, 'frequency': 'monthly', 'start_date': '2026-10-01', 'payout_round': 2});
    await a.insertRow('transactions', {'amount_fils': 50000, 'type': 'expense', 'date': '2026-10-01', 'description': 'x', 'circle_id': id});
    await Merge.apply(b, await Merge.changesSince(a, 0));

    final bCircle = (await b.db.query('circles')).single;
    expect(bCircle['name'], 'Family');
    expect((await b.db.query('transactions')).single['circle_id'], bCircle['id']);
  });

  group('screens', () {
    final repo = FinanceRepo();
    setUp(useSeededTestDb);

    testWidgets('a circle with a reminder counts down to it above the schedule; one without shows nothing', (tester) async {
      final start = DateTime.now().add(const Duration(days: 3));
      final withReminder = (await tester.runAsync(() => repo.insertCircle(
          name: 'Family', contributionFils: 50000, rounds: 10, frequency: 'monthly', startDate: start, payoutRound: 1, reminderDays: 1)))!;
      final without = (await tester.runAsync(() => repo.insertCircle(
          name: 'Work', contributionFils: 50000, rounds: 10, frequency: 'monthly', startDate: start, payoutRound: 1)))!;

      await pumpScreenWithDb(tester, CircleScreen(circleId: withReminder));
      final countdown = find.textContaining('Your next payment reminder in:');
      expect(countdown, findsOneWidget);
      // One day before a due date 3 days off, at 9:00: about 1–2 days away.
      expect(tester.widget<Text>(countdown).data, matches(RegExp(r'in: (1 day|2 days)(, \d+ hours?)?(, \d+ minutes?)?, \d+ seconds?$')));
      expect(tester.getTopLeft(countdown).dy, lessThan(tester.getTopLeft(find.text('Schedule')).dy));

      await pumpScreenWithDb(tester, CircleScreen(key: ValueKey(without), circleId: without));
      expect(find.textContaining('Your next payment reminder in:'), findsNothing);
    });

    testWidgets('a new circle, then a payment from its page, shows where you stand', (tester) async {
      await pumpScreenWithDb(tester, const CirclesScreen());
      expect(find.text('No savings circles yet'), findsOneWidget);

      await tester.tap(find.text('New circle'));
      await settleWithDb(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Family');
      await tester.enterText(find.widgetWithText(TextFormField, 'Payment each round'), '50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Your turn (round)'), '11');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('From 1 to 10'), findsOneWidget, reason: 'the turn must be one of the 10 rounds');
      // Arabic-Indic digits, as an Arabic keyboard types them.
      await tester.enterText(find.widgetWithText(TextFormField, 'Number of participants'), '١٠');
      await tester.enterText(find.widgetWithText(TextFormField, 'Your turn (round)'), '٣');
      await tester.tap(find.text('Save'));
      await settleWithDb(tester);
      expect(find.text('Family'), findsOneWidget);

      await tester.tap(find.text('Family'));
      await settleWithDb(tester);
      expect(find.text('Schedule'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await settleWithDb(tester);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Save')));
      await settleWithDb(tester);

      final c = (await tester.runAsync(() => repo.circles()))!.single;
      expect((c.rounds, c.payoutRound, c.paidRounds, c.positionFils), (10, 3, 1, -50000));
      expect(find.text('The circle owes you'), findsOneWidget);
      final entries = (await tester.runAsync(() => repo.transactions()))!;
      expect(entries.single.description, 'Payment to Family');
    });
  });
}
