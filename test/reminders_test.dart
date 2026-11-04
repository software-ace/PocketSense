import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/sync/merge.dart';
import 'package:pocket_sense/utils/format.dart';
import 'package:pocket_sense/utils/reminder_notifications.dart';
import 'package:pocket_sense/utils/reminders.dart';

RecurringExpense rent({int? reminderDays = 3, int dueMinutes = defaultReminderMinutes, bool active = true}) => RecurringExpense(
    id: 1, description: 'rent', amountFils: 450000, frequency: 'monthly', anchorDate: DateTime(2026, 1, 1),
    active: active, dueMinutes: dueMinutes, reminderDays: reminderDays);

Loan loan({String direction = 'lent', DateTime? due, int? reminderDays = 3, int repaid = 0, int minutes = defaultReminderMinutes}) => Loan(
    id: 7, direction: direction, person: 'Ahmad', dueDate: due ?? DateTime(2026, 11, 20), amountFils: 70000, repaidFils: repaid,
    reminderDays: reminderDays, dueMinutes: minutes);

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  final from = DateTime(2026, 11, 4, 12);
  final to = DateTime(2027, 1, 15);

  group('remindersBetween', () {
    test('a monthly item: days before each due date, at its due time', () {
      final rs = remindersBetween([rent(dueMinutes: 18 * 60 + 30)], const [], from, to);
      expect(rs.map((r) => r.at), [DateTime(2026, 11, 28, 18, 30), DateTime(2026, 12, 29, 18, 30)]);
      expect(rs.map((r) => r.due), [DateTime(2026, 12, 1), DateTime(2027, 1, 1)]);
      expect(rs.first.payload, 'recurring:1');
    });

    test('only after from: a reminder earlier today is past', () {
      final rs = remindersBetween([rent(reminderDays: 0)], const [], DateTime(2026, 12, 1, 9, 1), DateTime(2026, 12, 31));
      expect(rs, isEmpty);
      expect(remindersBetween([rent(reminderDays: 0)], const [], DateTime(2026, 12, 1, 8, 59), DateTime(2026, 12, 1, 9)).single.at,
          DateTime(2026, 12, 1, 9), reason: 'up to and including to');
    });

    test('paused items and items without a reminder have none', () {
      expect(remindersBetween([rent(active: false), rent(reminderDays: null)], const [], from, to), isEmpty);
    });

    test('a loan: days before and again on the day, at its reminder time', () {
      final rs = remindersBetween(const [], [loan(minutes: 8 * 60)], from, to);
      expect(rs.map((r) => r.at), [DateTime(2026, 11, 17, 8), DateTime(2026, 11, 20, 8)]);
      expect(rs.first.payload, 'loan:7');
      expect(remindersBetween(const [], [loan(reminderDays: 0)], from, to).length, 1, reason: 'on the day only once');
    });

    test('settled loans and loans without a reminder have none', () {
      expect(remindersBetween(const [], [loan(repaid: 70000), loan(reminderDays: null)], from, to), isEmpty);
    });

    test('out-of-range values from a synced row are ignored', () {
      expect(remindersBetween([rent(reminderDays: 999)], [loan(reminderDays: -1)], from, to), isEmpty);
      expect(remindersBetween([rent(dueMinutes: 5000)], const [], from, to).first.at.hour, 9);
    });

    test('ids are stable and differ per occurrence', () {
      final a = remindersBetween([rent()], const [], from, to);
      final b = remindersBetween([rent()], const [], from, to);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      expect(a.map((r) => r.id).toSet().length, a.length);
    });
  });

  test('the makers that need Autostart are matched as Android reports them, any case', () {
    // Build.MANUFACTURER values: Redmi and POCO phones report Xiaomi.
    for (final m in ['Xiaomi', 'HUAWEI', 'HONOR', 'OPPO', 'vivo', 'realme', 'OnePlus', 'samsung']) {
      expect(ReminderNotifications.limitingMakers.contains(m.toLowerCase()), isTrue, reason: m);
    }
    expect(ReminderNotifications.limitingMakers.contains('google'), isFalse);
  });

  group('reminderText', () {
    final r = remindersBetween([rent()], const [], from, to).first; // due Dec 1, reminded Nov 28
    final lent = remindersBetween(const [], [loan()], from, to);

    test('no amounts unless the setting is on', () {
      expect(reminderText(en, r, r.at, amounts: false, locale: 'en'), 'Your rent is due in 3 days. Check Recurring.');
      expect(reminderText(en, lent.first, lent.first.at, amounts: false, locale: 'en'), 'Your loan with Ahmad is due in 3 days.');
      expect(reminderText(en, lent.last, lent.last.at, amounts: false, locale: 'en'), 'Your loan with Ahmad is due today.');
    });

    test('with amounts: the item\'s amount, or what is still owed', () {
      expect(reminderText(en, r, r.at, amounts: true, locale: 'en'), 'Your rent (${formatMoney(450000, locale: 'en')}) is due in 3 days. Check Recurring.');
      expect(reminderText(en, lent.first, lent.first.at, amounts: true, locale: 'en'), 'Ahmad owes you ${formatMoney(70000, locale: 'en')}, due in 3 days.');
      final borrowed = remindersBetween(const [], [loan(direction: 'borrowed', repaid: 20000)], from, to).first;
      expect(reminderText(en, borrowed, borrowed.at, amounts: true, locale: 'en'), 'You owe Ahmad ${formatMoney(50000, locale: 'en')}, due in 3 days.');
    });

    test('a missed one shown late counts from today', () {
      expect(reminderText(en, r, DateTime(2026, 11, 30, 10), amounts: false, locale: 'en'), 'Your rent is due tomorrow. Check Recurring.');
      expect(reminderText(en, r, DateTime(2026, 12, 3), amounts: false, locale: 'en'), 'Your rent is 2 days overdue. Check Recurring.');
    });

    test('in Arabic, with its plural forms', () {
      expect(reminderText(ar, r, r.at, amounts: false, locale: 'ar'), 'rent مستحق بعد 3 أيام. راجع المتكررة.');
      expect(reminderText(ar, lent.last, lent.last.at, amounts: false, locale: 'ar'), 'قرضك مع Ahmad مستحق اليوم.');
    });
  });

  group('stored with the item', () {
    late LocalStore store;
    final repo = FinanceRepo();
    setUp(() async {
      store = await LocalStore.openInMemoryForTest();
      LocalStore.overrideInstanceForTest(store);
    });

    test('a recurring item keeps its due time and reminder, and an edit can turn it off', () async {
      final id = await repo.insertRecurring(
          description: 'rent', amountFils: 1, frequency: 'monthly', anchorDate: DateTime(2026, 1, 1), dueMinutes: 600, reminderDays: 3);
      expect([(await repo.recurring()).single.dueMinutes, (await repo.recurring()).single.reminderDays], [600, 3]);
      await repo.updateRecurring(id, description: 'rent', amountFils: 1, frequency: 'monthly', anchorDate: DateTime(2026, 1, 1), dueMinutes: 600);
      expect((await repo.recurring()).single.reminderDays, isNull);
    });

    test('a loan keeps its reminder only while it has a due date', () async {
      final id = await repo.insertLoan(direction: 'lent', person: 'Ahmad', amountFils: 1000, date: DateTime(2026, 11, 1),
          dueDate: DateTime(2026, 11, 20), reminderDays: 1, dueMinutes: 480, description: 'x');
      final l = (await repo.loans()).single;
      expect([l.reminderDays, l.dueMinutes], [1, 480]);
      await repo.updateLoan(id, person: 'Ahmad', amountFils: 1000, date: DateTime(2026, 11, 1), reminderDays: 1, describe: (_, _) => 'x');
      expect((await repo.loans()).single.reminderDays, isNull);
    });

    test('a reminder syncs with its item', () async {
      final peer = await LocalStore.openInMemoryForTest();
      await repo.insertRecurring(
          description: 'rent', amountFils: 1, frequency: 'monthly', anchorDate: DateTime(2026, 1, 1), dueMinutes: 1200, reminderDays: 7);
      await Merge.apply(peer, await Merge.changesSince(store, 0));
      final row = (await peer.selectRows('recurring_expenses')).single;
      expect([row['due_time'], row['reminder_days']], [1200, 7]);
    });

    test('a v4 database, and a v5 test build\'s, get the due time and reminder columns', () async {
      for (final (t, c) in [('recurring_expenses', 'due_time'), ('recurring_expenses', 'reminder_days'), ('loans', 'reminder_days'), ('loans', 'due_time')]) {
        await store.db.execute('ALTER TABLE $t DROP COLUMN $c');
      }
      await LocalStore.upgrade(store.db, 4, const {});
      await LocalStore.upgrade(store.db, 4, const {}); // a second run changes nothing
      final loanColumns = [for (final c in await store.db.rawQuery('PRAGMA table_info(loans)')) c['name']];
      expect(loanColumns, containsAll(['reminder_days', 'due_time']));

      // A v5 test build named the loan's time reminder_time.
      await store.db.execute('ALTER TABLE loans DROP COLUMN due_time');
      await store.db.execute('ALTER TABLE loans ADD COLUMN reminder_time INTEGER');
      await LocalStore.upgrade(store.db, 5, const {});
      expect([for (final c in await store.db.rawQuery('PRAGMA table_info(loans)')) c['name']], contains('due_time'));
    });
  });
}
