import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'outbox.dart';
import 'sync_plan.dart';

/// Tables mirrored locally, in FK-safe order (parents before children).
const List<String> kSyncTables = [
  'categories',
  'transactions',
  'budgets',
  'recurring_expenses',
];

class SyncEngine {
  final LocalStore store;
  final SupabaseClient _remote;
  SyncEngine(this.store, this._remote);

  /// Full round-trip: push pending local mutations, then pull remote changes.
  /// Push first so our own writes aren't immediately re-pulled as "new".
  Future<void> sync() async {
    await _push();
    for (final table in kSyncTables) {
      await _pull(table);
    }
  }

  Future<void> _push() async {
    await replayOutbox(store, (entry) => _applyRemote(entry));
  }

  Future<void> _applyRemote(OutboxEntry entry) async {
    switch (entry.op) {
      case 'insert':
        await _remote.from(entry.table).insert(entry.payload);
      case 'update':
        final id = entry.payload['id'];
        final values = Map.of(entry.payload)..remove('id');
        await _remote.from(entry.table).update(values).eq('id', id);
      case 'delete':
        await _remote.from(entry.table).delete().eq('id', entry.payload['id']);
      default:
        throw ArgumentError('unknown op ${entry.op}');
    }
  }

  Future<void> _pull(String table) async {
    final wmIso = store.watermarkFor(table);
    var query = _remote.from(table).select('*');
    if (wmIso != null) {
      query = query.gt('updated_at', wmIso);
    }
    final rows = (await query).cast<Map<String, dynamic>>();
    // Watermark = max(updated_at) seen this pull, or now() on an empty pull so
    // the next incremental fetch stays bounded.
    final ts = rows.fold<DateTime?>(null, (acc, r) {
      final t = DateTime.tryParse((r['updated_at'] ?? '').toString());
      if (t == null) return acc;
      return acc == null || t.isAfter(acc) ? t : acc;
    }) ?? DateTime.now().toUtc();
    await applyPull(store, table: table, pulled: rows, watermark: ts);
  }
}
