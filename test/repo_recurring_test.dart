import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

void main() {
  late LocalStore store;
  final repo = FinanceRepo();

  setUp(() async {
    store = await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
  });

  group('recurring type', () {
    test('defaults to expense', () async {
      await repo.insertRecurring(description: 'Rent', amountCents: 50000, frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      expect((await repo.recurring()).single.type, 'expense');
    });

    test('income round-trips', () async {
      final id = await repo.insertRecurring(
          description: 'Salary', amountCents: 300000, type: 'income', frequency: 'monthly', anchorDate: DateTime(2026, 9, 25));
      final r = (await repo.recurring()).single;
      expect(r.id, id);
      expect(r.type, 'income');
    });

    test('update can switch an item to income', () async {
      final id = await repo.insertRecurring(description: 'Refund', amountCents: 1000, frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      await repo.updateRecurring(id, description: 'Refund', amountCents: 1000, type: 'income', frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      expect((await repo.recurring()).single.type, 'income');
    });

    test('posting an income item records an income transaction', () async {
      await repo.insertRecurring(description: 'Salary', amountCents: 300000, type: 'income', frequency: 'monthly', anchorDate: DateTime(2026, 9, 25));
      await repo.postRecurring((await repo.recurring()).single);

      final tx = (await repo.transactions()).single;
      expect(tx.type, 'income');
      expect(tx.amountCents, 300000);
      expect(tx.createdAt, isNotNull, reason: 'Home shows the entry time from created_at');
      expect((await repo.recurring()).single.lastPosted, isNotNull);
    });

    test('posting an expense item still records an expense', () async {
      await repo.insertRecurring(description: 'Internet', amountCents: 2500, frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      await repo.postRecurring((await repo.recurring()).single);
      expect((await repo.transactions()).single.type, 'expense');
    });
  });

  test('same-day transactions list newest entry first', () async {
    final day = DateTime(2026, 9, 27);
    await repo.insertTransaction(amountCents: 100, type: 'expense', date: day, description: 'first');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.insertTransaction(amountCents: 200, type: 'expense', date: day, description: 'second');
    expect((await repo.transactions()).map((t) => t.description), ['second', 'first']);
  });

  group('budget progress', () {
    // Sun 2026-09-27: its week is Mon 09-21 .. Sun 09-27; its month is September.
    final now = DateTime(2026, 9, 27, 12);

    test('weekly budgets count only this week; monthly count the whole month', () async {
      final food = await repo.insertCategory(name: 'Food', type: 'expense', color: '#000000');
      final fun = await repo.insertCategory(name: 'Fun', type: 'expense', color: '#000000');
      await repo.insertBudget(categoryId: food, limitCents: 10000, period: 'weekly');
      await repo.insertBudget(categoryId: fun, limitCents: 50000, period: 'monthly');

      Future<void> spend(int cat, int cents, DateTime day) =>
          repo.insertTransaction(amountCents: cents, type: 'expense', date: day, description: 'x', categoryId: cat);
      await spend(food, 1000, DateTime(2026, 9, 20)); // last week: excluded from weekly
      await spend(food, 2000, DateTime(2026, 9, 21)); // Monday: included
      await spend(food, 3000, DateTime(2026, 9, 27)); // Sunday: included
      await spend(fun, 4000, DateTime(2026, 9, 1));
      await spend(fun, 5000, DateTime(2026, 9, 20));
      await spend(fun, 6000, DateTime(2026, 8, 31)); // last month: excluded
      await repo.insertTransaction(amountCents: 9999, type: 'income', date: DateTime(2026, 9, 22), description: 'refund', categoryId: food);

      final byCat = {for (final p in await repo.budgetProgress(now: now)) p.budget.categoryId: p};
      expect(byCat[food]!.spentCents, 5000);
      expect(byCat[food]!.start, DateTime(2026, 9, 21));
      expect(byCat[fun]!.spentCents, 9000);
      expect(byCat[fun]!.end, DateTime(2026, 9, 30));
    });
  });

  test('a transaction keeps the date it was given', () async {
    await repo.insertTransaction(amountCents: 100, type: 'expense', date: DateTime(2026, 9, 3), description: 'backdated');
    expect((await repo.transactions()).single.date, DateTime(2026, 9, 3));
  });
}
