import 'sync_merge.dart';

/// PostgREST-style filter descriptor for incremental pulls.
class PullFilter {
  final String column;
  final String operator; // 'gt' | 'gte'
  final Object value;
  PullFilter(this.column, this.operator, this.value);
}

/// First sync has no watermark → pull the whole table.
PullFilter? pullFilter({DateTime? watermark}) {
  if (watermark == null) return null;
  return PullFilter('updated_at', 'gt', watermark.toUtc().toIso8601String());
}

/// Seam over the local cache that the sync engine needs. Implemented by
/// LocalStore; tests use a fake.
abstract class SyncStore {
  Future<Map<String, dynamic>> allRows(String table);
  Future<void> upsertMany(String table, List<Map<String, dynamic>> rows);
  String? watermarkFor(String table);
  Future<void> setWatermark(String table, DateTime ts);
}

/// Merge [pulled] remote rows into the local cache (last-write-wins) and
/// advance the table's watermark to [watermark].
Future<void> applyPull(
  SyncStore store, {
  required String table,
  required List<Map<String, dynamic>> pulled,
  required DateTime watermark,
}) async {
  final local = await store.allRows(table);
  final keyedLocal = <String, dynamic>{for (final r in local.values) r['id'].toString(): r};
  final keyedRemote = <String, dynamic>{for (final r in pulled) r['id'].toString(): r};
  final merged = mergeRows(local: keyedLocal, remote: keyedRemote);
  final winners = merged.values.cast<Map<String, dynamic>>().toList();
  // Only write back rows that actually changed, to keep churn low.
  final changed = winners.where((r) => !identical(r, keyedLocal[r['id'].toString()])).toList();
  if (changed.isNotEmpty) {
    await store.upsertMany(table, changed);
  }
  await store.setWatermark(table, watermark);
}
