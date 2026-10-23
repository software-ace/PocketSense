import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

void main() {
  final repo = FinanceRepo();
  final day = DateTime(2026, 10, 10);

  setUp(() async => LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest()));

  test('inserts, sorts case-insensitively and dedupes case-insensitively', () async {
    final first = await repo.insertMerchant(' Reem ');
    expect(first, greaterThan(0), reason: 'a fresh name gets a row');

    final again = await repo.insertMerchant('reem');
    expect(again, first, reason: 'the same name, any case, returns the row it already has');

    await repo.insertMerchant('Carrefour');
    await repo.insertMerchant('abb');

    expect((await repo.merchants()).map((m) => m.name).toList(), ['abb', 'Carrefour', 'Reem']);
  });

  test('rejects empty names', () async {
    expect(() => repo.insertMerchant('  '), throwsArgumentError);
    expect(() => repo.renameMerchant(1, ' '), throwsArgumentError);
  });

  test('rename cascades to transactions and recurring items that spelled the old name', () async {
    final id = await repo.insertMerchant('Star');
    await repo.insertTransaction(amountFils: 1000, type: 'expense', date: day, description: '', merchant: ' star ');
    await repo.insertTransaction(amountFils: 2000, type: 'expense', date: day, description: '', merchant: 'STAR');
    await repo.insertTransaction(amountFils: 3000, type: 'expense', date: day, description: '', merchant: 'Other');
    await repo.insertRecurring(description: '', amountFils: 500, frequency: 'monthly', anchorDate: day, merchant: 'star');

    await repo.renameMerchant(id, 'Starbucks');

    final store = await LocalStore.instance();
    expect([for (final t in await store.selectRows('transactions')) t['merchant']], ['Starbucks', 'Starbucks', 'Other']);
    expect((await store.selectRows('recurring_expenses')).single['merchant'], 'Starbucks');
    expect((await store.selectRows('merchants')).single['name'], 'Starbucks');
  });

  test('renaming only fixes spelling keeps the entries untouched', () async {
    final id = await repo.insertMerchant('star');
    await repo.insertTransaction(amountFils: 1000, type: 'expense', date: day, description: '', merchant: 'star');
    await repo.renameMerchant(id, 'Star');
    final store = await LocalStore.instance();
    expect((await store.selectRows('transactions')).single['merchant'], 'star');
    expect((await store.selectRows('merchants')).single['name'], 'Star');
  });

  test('renaming onto an existing name fails', () async {
    await repo.insertMerchant('One');
    final id = await repo.insertMerchant('Two');
    expect(() => repo.renameMerchant(id, 'one'), throwsStateError);
  });

  test('delete keeps past transactions', () async {
    final id = await repo.insertMerchant('Gone');
    await repo.insertTransaction(amountFils: 1000, type: 'expense', date: day, description: '', merchant: 'Gone');

    await repo.deleteMerchant(id);

    final store = await LocalStore.instance();
    expect(await store.selectRows('merchants'), isEmpty);
    expect((await store.selectRows('transactions')).single['merchant'], 'Gone');
  });

  test('a database from v2 gets the merchants table, synced and backfilled', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.insertRow('transactions', {
      'amount_fils': 1000, 'type': 'expense', 'date': day.millisecondsSinceEpoch, 'description': '', 'merchant': 'Backfilled',
    });
    await store.insertRow('transactions', {
      'amount_fils': 2000, 'type': 'expense', 'date': day.millisecondsSinceEpoch, 'description': '', 'merchant': 'backfilled',
    });
    await store.insertRow('transactions', {
      'amount_fils': 3000, 'type': 'expense', 'date': day.millisecondsSinceEpoch, 'description': '', 'merchant': 'Kept',
    });
    final sentSeq = [for (final t in await store.selectRows('transactions')) t['seq'] as int].reduce((a, b) => a > b ? a : b);
    await store.db.execute('DROP TABLE merchants');

    // A device upgrading from v2 has no merchants table at all: this is
    // exactly the state upgrade() then walks out of.
    await LocalStore.upgrade(store.db, 2, const {});

    final cols = [for (final c in await store.db.rawQuery('PRAGMA table_info(merchants)')) c['name'] as String];
    expect(cols, containsAll(['name', 'uid', 'hlc', 'seq']));
    final rows = await store.selectRows('merchants');
    expect(rows.map((r) => r['name']).toSet(), {'Backfilled', 'Kept'}, reason: 'one entry per distinct name, case-insensitively');
    for (final r in rows) {
      expect(r['uid'], isNotNull);
      expect(LocalStore.hlcPattern.hasMatch(r['hlc'] as String), isTrue);
      // Above every seq the device had already sent, so already-paired
      // devices pull the backfilled rows.
      expect(r['seq'] as int, greaterThan(sentSeq));
    }
    final indices = await store.db.rawQuery('PRAGMA index_list(merchants)');
    expect(indices.map((i) => i['name']), contains('idx_merchants_uid'));
  });
}
