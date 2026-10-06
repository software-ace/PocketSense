import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

void main() {
  late LocalStore store;
  final repo = FinanceRepo();

  setUp(() async {
    store = await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
  });

  Future<void> seed() async {
    final food = await repo.insertCategory(name: 'Food', type: 'expense', color: '#22c55e');
    final pay = await repo.insertCategory(name: 'Salary', type: 'income', color: '#16a34a');
    await repo.insertTransaction(amountFils: 3500, type: 'expense', date: DateTime(2026, 9, 28), description: 'Lunch', merchant: 'Reem', categoryId: food);
    await repo.insertTransaction(amountFils: 900000, type: 'income', date: DateTime(2026, 9, 25), description: 'Pay', categoryId: pay);
    await repo.insertBudget(categoryId: food, limitFils: 100000, period: 'weekly');
    await repo.insertRecurring(description: 'Rent', amountFils: 350000, frequency: 'monthly', anchorDate: DateTime(2026, 10, 1));
  }

  // hlc and seq are left out: they're sync bookkeeping, and an import
  // stamps every row afresh so paired devices take it.
  Future<Map<String, List<Map<String, Object?>>>> dump(LocalStore s) async => {
        for (final t in ['categories', 'transactions', 'budgets', 'recurring_expenses'])
          t: [for (final r in await s.db.query(t, orderBy: 'id')) {...r}..remove('hlc')..remove('seq')],
      };

  Map<String, dynamic> decode(String json) => jsonDecode(json) as Map<String, dynamic>;

  test('export then import into an empty database restores every row exactly', () async {
    await seed();
    final json = await Backup.export(store, now: DateTime.utc(2026, 9, 29));
    final doc = decode(json);
    expect(doc['format'], 'pocketsense-backup');
    expect(doc['version'], 1);
    expect(doc['currency'], 'JOD');
    expect(doc['exported_at'], '2026-09-29T00:00:00.000Z');

    final fresh = await LocalStore.openInMemoryForTest();
    final summary = await Backup.import(fresh, json);
    expect(summary, (categories: 2, transactions: 2, budgets: 1, recurring: 1));
    expect(await dump(fresh), await dump(store));
  });

  // The README screenshots are taken with this file; it must keep importing.
  test('the demo backup in docs/ imports', () async {
    final summary = await Backup.import(store, File('docs/demo-backup.json').readAsStringSync());
    expect(summary, (categories: 13, transactions: 180, budgets: 6, recurring: 8));
  });

  test('import replaces what was there and notifies listeners', () async {
    await seed();
    final json = await Backup.export(store);
    await repo.insertTransaction(amountFils: 1, type: 'expense', date: DateTime(2026, 9, 29), description: 'after export');
    var notified = 0;
    store.changes.addListener(() => notified++);

    await Backup.import(store, json);

    expect((await repo.transactions()).map((t) => t.description), isNot(contains('after export')));
    expect(await repo.transactions(), hasLength(2));
    expect(notified, 1);
  });

  group('refuses', () {
    Future<void> expectProblem(String json, BackupProblem problem) async {
      await seed();
      final before = await dump(store);
      await expectLater(Backup.import(store, json), throwsA(isA<BackupException>().having((e) => e.problem, 'problem', problem)));
      expect(await dump(store), before, reason: 'a refused file must leave the data untouched');
    }

    Map<String, dynamic> valid() => {
          'format': 'pocketsense-backup',
          'version': 1,
          'currency': 'JOD',
          'tables': {
            'categories': [
              {'id': 1, 'name': 'Food', 'type': 'expense', 'color': '#000000'},
            ],
            'transactions': [
              {'id': 2, 'amount_fils': 500, 'type': 'expense', 'date': '2026-09-01', 'description': 'x', 'category_id': 1},
            ],
          },
        };

    test('corrupt JSON', () => expectProblem('{"format": "pocketsense-b', BackupProblem.notJson));
    test('some other JSON file', () => expectProblem('{"hello": "world"}', BackupProblem.notABackup));
    test('a newer backup version', () => expectProblem(jsonEncode(valid()..['version'] = 2), BackupProblem.tooNew));
    test('another currency', () => expectProblem(jsonEncode(valid()..['currency'] = 'USD'), BackupProblem.wrongCurrency));

    test('a row missing a required column', () {
      final doc = valid();
      ((doc['tables'] as Map)['transactions'] as List).first.remove('amount_fils');
      return expectProblem(jsonEncode(doc), BackupProblem.badData);
    });

    test('a non-integer amount', () {
      final doc = valid();
      ((doc['tables'] as Map)['transactions'] as List).first['amount_fils'] = '12.5';
      return expectProblem(jsonEncode(doc), BackupProblem.badData);
    });

    test('a budget for a category that is not in the file (rolled back)', () {
      final doc = valid();
      (doc['tables'] as Map)['budgets'] = [
        {'id': 3, 'category_id': 999, 'limit_fils': 1000},
      ];
      return expectProblem(jsonEncode(doc), BackupProblem.badData);
    });
  });

  test('columns this version does not know are ignored', () async {
    final json = jsonEncode({
      'format': 'pocketsense-backup',
      'version': 1,
      'currency': 'JOD',
      'tables': {
        'categories': [
          {'id': 1, 'name': 'Food', 'type': 'expense', 'color': '#000000', 'emoji': '🍔'},
        ],
      },
    });
    final summary = await Backup.import(store, json);
    expect(summary.categories, 1);
    expect((await repo.categories()).single.name, 'Food');
  });

  group('encrypted', () {
    // Few iterations keep the test fast; the format records the count.
    Future<String> encrypt(String json, String password) => Backup.encrypt(json, password, iterations: 1000);

    test('round-trips, and the file shows none of the data', () async {
      await seed();
      final plain = await Backup.export(store);
      final sealed = await encrypt(plain, 'correct horse');
      expect(Backup.isEncrypted(sealed), isTrue);
      expect(Backup.isEncrypted(plain), isFalse);
      expect(sealed, isNot(contains('Lunch')));
      expect(await Backup.decrypt(sealed, 'correct horse'), plain);
    });

    test('imports end to end', () async {
      await seed();
      final before = await dump(store);
      final sealed = await encrypt(await Backup.export(store), 'pw-12345');
      final fresh = await LocalStore.openInMemoryForTest();
      await Backup.import(fresh, await Backup.decrypt(sealed, 'pw-12345'));
      expect(await dump(fresh), before);
    });

    test('a wrong password or a damaged file is wrongPassword', () async {
      final sealed = await encrypt(await Backup.export(store), 'right password');
      await expectLater(Backup.decrypt(sealed, 'wrong password'),
          throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.wrongPassword)));

      final doc = decode(sealed);
      final data = base64.decode(doc['data'] as String)..[0] ^= 1;
      final damaged = jsonEncode({...doc, 'data': base64.encode(data)});
      await expectLater(Backup.decrypt(damaged, 'right password'),
          throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.wrongPassword)));
    });

    test('a newer encrypted format is tooNew', () async {
      final doc = decode(await encrypt(await Backup.export(store), 'pw-12345'));
      await expectLater(Backup.decrypt(jsonEncode({...doc, 'version': 2}), 'pw-12345'),
          throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.tooNew)));
    });
  });
}
