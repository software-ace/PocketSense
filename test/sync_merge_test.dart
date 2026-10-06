import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/sync/merge.dart';

/// Devices in one test, with the watermarks the peers table would keep.
class Mesh {
  final _sent = <(LocalStore, LocalStore), int>{};

  /// One direction of a sync: [from]'s changes since last time, into [to].
  Future<int> send(LocalStore from, LocalStore to) async {
    final changes = await Merge.changesSince(from, _sent[(from, to)] ?? 0);
    final n = await Merge.apply(to, changes);
    _sent[(from, to)] = changes['up_to'] as int;
    return n;
  }

  Future<void> sync(LocalStore a, LocalStore b) async {
    await send(a, b);
    await send(b, a);
  }

  /// Syncs every pair until nothing changes any more.
  Future<void> settle(List<LocalStore> stores) async {
    for (var round = 0; round < 10; round++) {
      var changed = 0;
      for (final a in stores) {
        for (final b in stores) {
          if (a != b) changed += await send(a, b);
        }
      }
      if (changed == 0) return;
    }
    fail('did not settle');
  }
}

/// Everything a user can see, keyed by uid and with categories by uid, so
/// two devices' databases can be compared.
Future<Map<String, Object>> snapshot(LocalStore s) async {
  final catUid = {for (final r in await s.db.query('categories')) r['id']: r['uid']};
  return {
    for (final t in LocalStore.syncedTables)
      t: {
        for (final r in await s.db.query(t))
          r['uid']: {
            for (final e in r.entries)
              if (!{'id', 'seq', 'uid'}.contains(e.key)) e.key: e.key == 'category_id' ? catUid[e.value] : e.value,
          },
      },
  };
}

Future<int> category(LocalStore s, String name) =>
    s.insertRow('categories', {'name': name, 'type': 'expense', 'color': '#000000'});

Future<int> entry(LocalStore s, {int? categoryId, int fils = 100}) => s.insertRow('transactions', {
      'amount_fils': fils,
      'type': 'expense',
      'date': '2026-09-01',
      'description': 'x',
      'category_id': categoryId,
    });

/// Two devices' clocks only order changes a millisecond or more apart;
/// within one, the node id decides.
Future<void> later() => Future.delayed(const Duration(milliseconds: 2));

// SYNC_FUZZ_SEEDS=2000 flutter test test/sync_merge_test.dart --timeout none
final fuzzSeeds = int.tryParse(Platform.environment['SYNC_FUZZ_SEEDS'] ?? '') ?? 15;

void main() {
  test('starter categories are the same rows on every device', () async {
    final a = await LocalStore.openInMemoryForTest(seed: true);
    final b = await LocalStore.openInMemoryForTest(seed: true, categoryNames: {'groceries': 'بقالة'});
    expect((await b.db.query('categories', where: "name = 'بقالة'")).single['uid'], 'default:groceries');

    await Mesh().settle([a, b]);

    expect(await a.db.query('categories'), hasLength(13));
    expect(await snapshot(a), await snapshot(b));
  });

  test('edits, deletes and cascades reach the other device', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    final food = await category(a, 'Food');
    final tx = await entry(a, categoryId: food);
    await a.insertRow('budgets', {'category_id': food, 'limit_fils': 1000, 'period': 'monthly'});
    await mesh.sync(a, b);
    expect(await b.db.query('budgets'), hasLength(1));

    await a.updateRow('transactions', tx, {'amount_fils': 250});
    await a.deleteRow('categories', food);
    await mesh.sync(a, b);

    final bTx = (await b.db.query('transactions')).single;
    expect(bTx['amount_fils'], 250);
    expect(bTx['category_id'], isNull);
    expect(await b.db.query('budgets'), isEmpty);
    expect(await snapshot(a), await snapshot(b));
  });

  test('the newer edit wins, whichever device syncs first', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    final tx = await entry(a);
    await mesh.sync(a, b);
    final bId = (await b.db.query('transactions')).single['id'] as int;

    await a.updateRow('transactions', tx, {'amount_fils': 1});
    await later();
    await b.updateRow('transactions', bId, {'amount_fils': 2});
    await mesh.sync(a, b);

    expect((await a.db.query('transactions')).single['amount_fils'], 2);
    expect(await snapshot(a), await snapshot(b));
  });

  test('a deleted entry stays deleted, an edit after the delete brings it back', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    final tx = await entry(a);
    await mesh.sync(a, b);
    final bId = (await b.db.query('transactions')).single['id'] as int;

    await b.updateRow('transactions', bId, {'amount_fils': 7});
    await later();
    await a.deleteRow('transactions', tx);
    await mesh.sync(a, b);
    expect(await b.db.query('transactions'), isEmpty);
    expect(await a.db.query('transactions'), isEmpty);

    final tx2 = await entry(a);
    await mesh.sync(a, b);
    await a.deleteRow('transactions', tx2);
    await later();
    await b.updateRow('transactions', (await b.db.query('transactions')).single['id'] as int, {'amount_fils': 9});
    await mesh.sync(a, b);
    expect((await a.db.query('transactions')).single['amount_fils'], 9);
    expect(await snapshot(a), await snapshot(b));
  });

  test('two categories with one name merge, keeping both sides\' entries', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    await entry(a, categoryId: await category(a, 'Coffee'));
    final bCoffee = await category(b, 'coffee');
    await entry(b, categoryId: bCoffee);
    await b.insertRow('budgets', {'category_id': bCoffee, 'limit_fils': 1000, 'period': 'monthly'});

    await Mesh().settle([a, b]);

    for (final s in [a, b]) {
      final cats = await s.db.query('categories');
      expect(cats, hasLength(1));
      final txs = await s.db.query('transactions');
      expect(txs, hasLength(2));
      expect(txs.map((t) => t['category_id']), everyElement(cats.single['id']));
      expect(await s.db.query('budgets'), hasLength(1));
    }
    expect(await snapshot(a), await snapshot(b));
  });

  test('a category deleted and re-created under the same name syncs cleanly', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    await category(a, 'Coffee');
    await mesh.sync(a, b);
    await a.deleteRow('categories', (await a.db.query('categories')).single['id'] as int);
    await category(a, 'Coffee');
    await mesh.sync(a, b);
    expect(await snapshot(a), await snapshot(b));
    expect(await b.db.query('categories'), hasLength(1));
  });

  test('changes travel on through a device in between', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final c = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    await entry(a);
    await mesh.sync(a, b);
    await entry(c, fils: 5);
    await mesh.sync(b, c);
    await mesh.sync(a, b);
    for (final s in [a, b, c]) {
      expect(await s.db.query('transactions'), hasLength(2));
    }
  });

  test('importing a backup replaces the data on paired devices too', () async {
    final a = await LocalStore.openInMemoryForTest();
    final b = await LocalStore.openInMemoryForTest();
    final mesh = Mesh();
    await entry(a, fils: 1);
    final saved = await Backup.export(a);
    await entry(a, fils: 2);
    await mesh.sync(a, b);
    expect(await b.db.query('transactions'), hasLength(2));

    await Backup.import(a, saved);
    await mesh.sync(a, b);

    expect((await b.db.query('transactions')).map((r) => r['amount_fils']), [1]);
    expect(await snapshot(a), await snapshot(b));
  });

  test('bad rows from a peer are refused and change nothing', () async {
    final a = await LocalStore.openInMemoryForTest();
    final good = await Merge.changesSince(a, 0);
    for (final bad in [
      {'tables': {'transactions': [{'uid': 'u', 'hlc': 'nope', 'amount_fils': 1, 'type': 'expense', 'date': '2026-01-01', 'description': ''}]}, 'tombstones': []},
      {'tables': {'transactions': [{'uid': 'u', 'hlc': '000000000000001-0000-ab', 'amount_fils': '1', 'type': 'expense', 'date': '2026-01-01', 'description': ''}]}, 'tombstones': []},
      {'tables': {'transactions': [{'uid': 'u', 'hlc': '000000000000001-0000-ab', 'amount_fils': 1, 'type': 'gift', 'date': '2026-01-01', 'description': ''}]}, 'tombstones': []},
      {'tables': {}, 'tombstones': [{'tbl': 'peers', 'uid': 'u', 'hlc': '000000000000001-0000-ab'}]},
      'not a map',
    ]) {
      await expectLater(Merge.apply(a, bad), throwsA(isA<SyncDataException>()), reason: '$bad');
    }
    expect(await Merge.changesSince(a, 0), good);
  });

  test('random edits on three devices converge', () async {
    for (var seed = 0; seed < fuzzSeeds; seed++) {
      final rng = Random(seed);
      final stores = [for (var i = 0; i < 3; i++) await LocalStore.openInMemoryForTest(seed: true)];
      final mesh = Mesh();
      const names = ['Coffee', 'coffee', 'Rent', 'Fuel', 'Gifts'];
      for (var step = 0; step < 120; step++) {
        final s = stores[rng.nextInt(3)];
        final cats = [for (final r in await s.db.query('categories')) r['id'] as int];
        final txs = [for (final r in await s.db.query('transactions')) r['id'] as int];
        final budgets = [for (final r in await s.db.query('budgets')) r['id'] as int];
        T pick<T>(List<T> l) => l[rng.nextInt(l.length)];
        try {
          switch (rng.nextInt(10)) {
            case 0:
              await category(s, pick(names));
            case 1 when cats.isNotEmpty:
              await s.updateRow('categories', pick(cats), {'name': pick(names)});
            case 2 when cats.isNotEmpty:
              await s.deleteRow('categories', pick(cats));
            case 3 || 4:
              await entry(s, categoryId: cats.isEmpty || rng.nextBool() ? null : pick(cats), fils: rng.nextInt(1000));
            case 5 when txs.isNotEmpty:
              await s.updateRow('transactions', pick(txs), {'amount_fils': rng.nextInt(1000), if (cats.isNotEmpty) 'category_id': pick(cats)});
            case 6 when txs.isNotEmpty:
              await s.deleteRow('transactions', pick(txs));
            case 7 when cats.isNotEmpty:
              await s.insertRow('budgets', {'category_id': pick(cats), 'limit_fils': rng.nextInt(1000), 'period': 'monthly'});
            case 8 when budgets.isNotEmpty:
              await s.deleteRow('budgets', pick(budgets));
            case 9:
              final a = pick(stores), b = pick(stores);
              if (a != b) await mesh.sync(a, b);
          }
        } on Exception catch (e) {
          // A local name clash, refused as the UI would.
          if (!'$e'.contains('UNIQUE')) rethrow;
        }
      }
      await mesh.settle(stores);
      final first = await snapshot(stores[0]);
      for (final s in stores.skip(1)) {
        expect(await snapshot(s), first, reason: 'seed $seed');
      }
    }
  });
}
