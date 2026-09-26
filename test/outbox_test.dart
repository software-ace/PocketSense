import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/outbox.dart';

/// In-memory stand-in so queue semantics are tested without a database.
class _MemoryOutbox implements Outbox {
  final List<Map<String, dynamic>> rows = [];
  int _seq = 0;

  @override
  Future<int> append({
    required String table,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    _seq += 1;
    // Key matches the real SQLite column name ("table" is a reserved word).
    rows.add({
      'seq': _seq,
      '"table"': table,
      'op': op,
      'payload': jsonEncode(payload),
    });
    return _seq;
  }

  @override
  Future<List<Map<String, dynamic>>> pending() async => List.of(rows);

  @override
  Future<void> ack(int seq) async => rows.removeWhere((r) => r['seq'] == seq);
}

void main() {
  group('Outbox', () {
    test('pending is FIFO by insertion order', () async {
      final ob = _MemoryOutbox();
      await ob.append(table: 'transactions', op: 'insert', payload: {'a': 1});
      await ob.append(table: 'categories', op: 'update', payload: {'b': 2});
      final p = await ob.pending();
      expect(p.map((r) => r['"table"']), ['transactions', 'categories']);
    });

    test('ack removes only the acknowledged entry', () async {
      final ob = _MemoryOutbox();
      final s1 = await ob.append(table: 't', op: 'insert', payload: {});
      await ob.append(table: 't', op: 'delete', payload: {});
      await ob.ack(s1);
      final p = await ob.pending();
      expect(p.length, 1);
      expect(p.single['op'], 'delete');
    });

    test('failed push keeps the entry for retry (no ack)', () async {
      final ob = _MemoryOutbox();
      await ob.append(table: 't', op: 'insert', payload: {});
      // simulate: push throws -> caller does not ack
      expect(await ob.pending(), hasLength(1));
    });
  });

  group('replayOutbox', () {
    test('executes entries in order and acks successes', () async {
      final ob = _MemoryOutbox();
      await ob.append(table: 't', op: 'insert', payload: {'n': 'first'});
      await ob.append(table: 't', op: 'insert', payload: {'n': 'second'});
      final executed = <String>[];
      final result = await replayOutbox(ob, (entry) async {
        executed.add(entry.payload['n'] as String);
      });
      expect(executed, ['first', 'second']);
      expect(result.pushed, 2);
      expect(await ob.pending(), isEmpty);
    });

    test('stops at first failure and leaves it queued', () async {
      final ob = _MemoryOutbox();
      await ob.append(table: 't', op: 'insert', payload: {'n': 'ok'});
      await ob.append(table: 't', op: 'insert', payload: {'n': 'boom'});
      await ob.append(table: 't', op: 'insert', payload: {'n': 'never'});
      final executed = <String>[];
      final result = await replayOutbox(ob, (entry) async {
        executed.add(entry.payload['n'] as String);
        if (entry.payload['n'] == 'boom') throw Exception('offline');
      });
      expect(executed, ['ok', 'boom']);
      expect(result.pushed, 1);
      expect(result.stoppedAt, isNotNull);
      final remaining = await ob.pending();
      expect(remaining, hasLength(2));
      expect(remaining.first['op'], 'insert');
    });
  });
}
