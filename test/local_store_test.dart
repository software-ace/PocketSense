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

}
