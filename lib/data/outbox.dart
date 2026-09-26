import 'dart:convert';

/// A queued local mutation awaiting push to Supabase.
class OutboxEntry {
  final int seq;
  final String table; // PostgREST table name, e.g. 'transactions'
  final String op; // 'insert' | 'update' | 'delete'
  final Map<String, dynamic> payload; // full row for insert/update, {'id': n} for delete

  OutboxEntry({required this.seq, required this.table, required this.op, required this.payload});

  factory OutboxEntry.fromRow(Map<String, dynamic> row) => OutboxEntry(
        seq: row['seq'] as int,
        table: row['"table"'] as String,
        op: row['op'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      );
}

/// Persistence seam for the mutation queue. Implemented by LocalStore (sqflite);
/// tests use an in-memory fake so queue semantics are exercised without a DB.
abstract class Outbox {
  /// Queue a mutation. Returns the entry's seq (monotonic per device).
  Future<int> append({required String table, required String op, required Map<String, dynamic> payload});

  /// All unpushed entries, oldest first.
  Future<List<Map<String, dynamic>>> pending();

  /// Drop an entry after its remote push succeeded.
  Future<void> ack(int seq);
}

class ReplayResult {
  final int pushed;
  final int? stoppedAt; // seq of the failed entry, null if all succeeded
  ReplayResult(this.pushed, this.stoppedAt);
}

/// Push queued mutations to [push] one at a time, in FIFO order. Stops at the
/// first failure and leaves it (and everything behind it) queued for retry.
Future<ReplayResult> replayOutbox(Outbox ob, Future<void> Function(OutboxEntry) push) async {
  var pushed = 0;
  for (final row in await ob.pending()) {
    final entry = OutboxEntry.fromRow(row);
    try {
      await push(entry);
    } catch (_) {
      return ReplayResult(pushed, entry.seq);
    }
    await ob.ack(entry.seq);
    pushed += 1;
  }
  return ReplayResult(pushed, null);
}
