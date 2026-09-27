import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/main.dart' show initialSyncDone;

void main() {
  late LocalStore store;
  final repo = FinanceRepo();

  setUpAll(() {
    // The repo gates reads on the first sync; there is no sync in tests.
    if (!initialSyncDone.isCompleted) initialSyncDone.complete();
  });

  setUp(() async {
    store = await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
  });

  Future<List<Map<String, dynamic>>> outbox() async =>
      [for (final r in await store.pending()) {'op': r['op'], ...jsonDecode(r['payload'] as String) as Map<String, dynamic>}];

  group('recurring type', () {
    test('defaults to expense', () async {
      await repo.insertRecurring(description: 'Rent', amountCents: 50000, frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      expect((await repo.recurring()).single.type, 'expense');
    });

    test('income round-trips and is queued with its id and type', () async {
      final id = await repo.insertRecurring(
          description: 'Salary', amountCents: 300000, type: 'income', frequency: 'monthly', anchorDate: DateTime(2026, 9, 25));
      expect((await repo.recurring()).single.type, 'income');

      final queued = (await outbox()).single;
      expect(queued['op'], 'insert');
      expect(queued['id'], id, reason: 'server must receive the same id the device uses');
      expect(queued['type'], 'income');
    });

    test('update can switch an item to income', () async {
      final id = await repo.insertRecurring(description: 'Refund', amountCents: 1000, frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      await repo.updateRecurring(id, description: 'Refund', amountCents: 1000, type: 'income', frequency: 'monthly', anchorDate: DateTime(2026, 9, 1));
      expect((await repo.recurring()).single.type, 'income');
      expect((await outbox()).last['type'], 'income');
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
}
