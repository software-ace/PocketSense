import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/outbox.dart';

void main() {
  test('queued outbox rows parse back into entries (real SQLite)', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.append(table: 'recurring_expenses', op: 'delete', payload: {'id': 7});

    final pushed = <OutboxEntry>[];
    final result = await replayOutbox(store, (e) async => pushed.add(e));

    expect(result.error, isNull);
    expect(pushed.single.table, 'recurring_expenses');
    expect(pushed.single.payload, {'id': 7});
    expect(await store.pending(), isEmpty);
  });

  test('watermarks round-trip through SQLite', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.setWatermark('transactions', DateTime.utc(2026, 9, 1));
    await store.loadWatermarks();
    expect(store.watermarkFor('transactions'), '2026-09-01T00:00:00.000Z');
  });

  test('initSchema adds recurring type to a pre-existing table', () async {
    final store = await LocalStore.openInMemoryForTest();
    // Simulate an install from before the column existed.
    await store.db.execute('DROP TABLE recurring_expenses');
    await store.db.execute('CREATE TABLE recurring_expenses (id INTEGER PRIMARY KEY, description TEXT NOT NULL, '
        'amount_cents INTEGER NOT NULL, frequency TEXT NOT NULL, anchor_date TEXT NOT NULL, updated_at TEXT)');
    await store.db.insert('recurring_expenses', {'id': 1, 'description': 'Rent', 'amount_cents': 100, 'frequency': 'monthly', 'anchor_date': '2026-09-01'});

    await store.initSchema();
    await store.initSchema(); // idempotent

    final rows = await store.db.query('recurring_expenses');
    expect(rows.single['type'], 'expense');
  });

  test('initSchema adds user_id to pre-auth tables', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.db.execute('DROP TABLE transactions');
    await store.db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL, type TEXT NOT NULL, '
        'date TEXT NOT NULL, description TEXT NOT NULL, updated_at TEXT)');

    await store.initSchema();

    // A pulled server row now includes its owner; storing it must not fail.
    await store.upsertMany('transactions', [
      {'id': 1, 'amount_cents': 5, 'type': 'expense', 'date': '2026-09-27', 'description': 'x', 'user_id': 'u-1'},
    ]);
    expect((await store.db.query('transactions')).single['user_id'], 'u-1');
  });
}
