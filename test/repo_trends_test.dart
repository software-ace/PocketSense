import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

void main() {
  final repo = FinanceRepo();

  setUp(() async => LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest()));

  Future<void> add(DateTime date, int fils, {String type = 'expense'}) =>
      repo.insertTransaction(amountFils: fils, type: type, date: date, description: '');

  test('monthly totals: oldest first, every month listed, across a new year', () async {
    await add(DateTime(2025, 11, 30), 1000);
    await add(DateTime(2026, 1, 5), 2000);
    await add(DateTime(2026, 1, 25), 50000, type: 'income');
    await add(DateTime(2025, 10, 31), 9999); // before the window

    final rows = await repo.monthlyTotals(DateTime(2026, 2, 10), months: 4);
    expect(rows, [
      (month: DateTime(2025, 11), income: 0, expense: 1000),
      (month: DateTime(2025, 12), income: 0, expense: 0),
      (month: DateTime(2026, 1), income: 50000, expense: 2000),
      (month: DateTime(2026, 2), income: 0, expense: 0),
    ]);
  });

  test('months with entries: each once, newest first', () async {
    await add(DateTime(2025, 12, 31), 100);
    await add(DateTime(2026, 2, 1), 200);
    await add(DateTime(2026, 2, 28), 300, type: 'income');
    expect(await repo.transactionMonths(), [DateTime(2026, 2), DateTime(2025, 12)]);
  });

  test('pace: this month so far against all of last month, added up by day', () async {
    await add(DateTime(2025, 12, 1), 100);
    await add(DateTime(2025, 12, 31), 400);
    await add(DateTime(2026, 1, 2), 300);
    await add(DateTime(2026, 1, 2), 900, type: 'income');

    final pace = await repo.monthPace(DateTime(2026, 1, 3));
    expect(pace.thisMonth, [0, 300, 300]);
    expect(pace.lastMonth.length, 31);
    expect(pace.lastMonth.first, 100);
    expect(pace.lastMonth.last, 500);
  });

  test('weekday averages: Monday first, over whole weeks', () async {
    // 2026-10-19 is a Monday; two weeks back reaches Tuesday 2026-10-06.
    await add(DateTime(2026, 10, 19), 4000); // Monday
    await add(DateTime(2026, 10, 12), 2000); // Monday
    await add(DateTime(2026, 10, 10), 600); // Saturday
    await add(DateTime(2026, 10, 5), 7000); // Monday, a day too early

    expect(await repo.weekdayAverages(DateTime(2026, 10, 19), weeks: 2), [3000, 0, 0, 0, 0, 300, 0]);
  });

  test('entries come newest first: by date, then entry time, entries without one last; the limit keeps the newest', () async {
    final store = await LocalStore.instance();
    Future<void> add(String d, String date, String? createdAt) =>
        store.insertRow('transactions', {'amount_fils': 1, 'type': 'expense', 'date': date, 'description': d, 'created_at': createdAt});
    await add('old', '2026-09-01', '2026-09-01T08:00:00.000Z');
    await add('no time', '2026-10-01', null);
    await add('morning', '2026-10-01', '2026-10-01T06:00:00.000Z');
    await add('evening', '2026-10-01', '2026-10-01T18:00:00.000Z');
    await add('later day', '2026-10-02', '2026-10-01T05:00:00.000Z'); // entered ahead of time

    expect((await repo.transactions()).map((t) => t.description), ['later day', 'evening', 'morning', 'no time', 'old']);
    expect((await repo.transactions(limit: 2)).map((t) => t.description), ['later day', 'evening']);
  });
}
