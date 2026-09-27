import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'outbox.dart';
import 'sync_plan.dart';
import 'sync_reconcile.dart';

/// Tables mirrored locally, in FK-safe order (parents before children).
const List<String> kSyncTables = [
  'categories',
  'transactions',
  'budgets',
  'recurring_expenses',
];

/// PostgREST caps responses (1000 rows by default), so page through indexes.
const int _kPageSize = 1000;

/// Keep `id=in.(...)` URLs well under proxy length limits.
const int _kFetchChunk = 100;

/// Raised when a queued local change was rejected or couldn't be sent.
class SyncPushException implements Exception {
  final OutboxEntry entry;
  final Object cause;
  SyncPushException(this.entry, this.cause);

  @override
  String toString() => 'Could not upload ${entry.op} on ${entry.table} #${entry.payload['id'] ?? '?'}: $cause';
}

class SyncEngine {
  final LocalStore store;
  final SupabaseClient _remote;
  SyncEngine(this.store, this._remote);

  /// Full round-trip: push pending local mutations, then reconcile every table
  /// against the server. Push first so our own writes are already remote when
  /// we diff. Returns true if the local mirror changed.
  ///
  /// A rejected push doesn't skip the pull — the user still gets fresh data —
  /// but the push error is rethrown afterwards so it can be surfaced.
  Future<bool> sync() async {
    final pushed = await replayOutbox(store, _applyRemote);
    var changed = false;
    for (final table in kSyncTables) {
      changed = await _pull(table) || changed;
    }
    final err = pushed.error;
    if (err != null) throw err;
    return changed;
  }

  Future<void> _applyRemote(OutboxEntry entry) async {
    try {
      switch (entry.op) {
        case 'insert':
          // Upsert keeps replay idempotent: if the insert landed but the ack
          // didn't (app killed mid-sync), the retry must not fail or duplicate.
          await _remote.from(entry.table).upsert(entry.payload);
        case 'update':
          final id = entry.payload['id'];
          final values = Map.of(entry.payload)..remove('id');
          await _remote.from(entry.table).update(values).eq('id', id);
        case 'delete':
          await _remote.from(entry.table).delete().eq('id', entry.payload['id']);
        default:
          throw ArgumentError('unknown op ${entry.op}');
      }
    } catch (e) {
      throw SyncPushException(entry, e);
    }
  }

  Future<bool> _pull(String table) async {
    final remote = <int, String?>{};
    for (var from = 0;; from += _kPageSize) {
      final page = await _remote.from(table).select('id,updated_at').order('id').range(from, from + _kPageSize - 1);
      for (final r in page) {
        remote[(r['id'] as num).toInt()] = r['updated_at']?.toString();
      }
      if (page.length < _kPageSize) break;
    }

    final localRows = await store.allRows(table);
    final local = <int, String?>{
      for (final r in localRows.values) (r['id'] as num).toInt(): r['updated_at']?.toString(),
    };
    final plan = planReconcile(local: local, remote: remote, pendingIds: await _pendingIds(table));

    final fetched = <Map<String, dynamic>>[];
    for (var i = 0; i < plan.toFetch.length; i += _kFetchChunk) {
      final chunk = plan.toFetch.sublist(i, (i + _kFetchChunk).clamp(0, plan.toFetch.length));
      fetched.addAll((await _remote.from(table).select('*').inFilter('id', chunk)).cast<Map<String, dynamic>>());
    }
    if (fetched.isNotEmpty) {
      // Last-write-wins merge still protects a newer, not-yet-pushed local edit.
      await applyPull(store, table: table, pulled: fetched, watermark: DateTime.now().toUtc());
    }
    if (plan.toDeleteLocally.isNotEmpty) {
      // Re-check the outbox: a write may have landed while we were fetching.
      final pendingNow = await _pendingIds(table);
      await store.deleteIds(table, plan.toDeleteLocally.where((id) => !pendingNow.contains(id)).toList());
    }
    return fetched.isNotEmpty || plan.toDeleteLocally.isNotEmpty;
  }

  Future<Set<int>> _pendingIds(String table) async {
    final ids = <int>{};
    for (final row in await store.pending()) {
      if (row['table'] != table) continue;
      final id = (jsonDecode(row['payload'] as String) as Map<String, dynamic>)['id'];
      if (id is num) ids.add(id.toInt());
    }
    return ids;
  }
}
