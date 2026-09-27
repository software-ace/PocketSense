/// What one table needs after comparing the remote index (id → updated_at)
/// with the local mirror.
class ReconcilePlan {
  /// Remote ids that are new locally or carry a different updated_at.
  final List<int> toFetch;

  /// Local ids the server no longer has (deleted elsewhere, or orphaned by an
  /// old sync bug) and that aren't waiting in the outbox to be pushed.
  final List<int> toDeleteLocally;

  ReconcilePlan(this.toFetch, this.toDeleteLocally);
}

/// Diff-based pull plan. Comparing the full id index instead of relying on an
/// `updated_at > watermark` filter means remote deletions are detected and
/// device clock skew can't make us skip rows. For a single-user DB the index
/// is small (two columns per row), so fetching it every sync is cheap.
ReconcilePlan planReconcile({
  required Map<int, String?> local,
  required Map<int, String?> remote,
  required Set<int> pendingIds,
}) {
  final toFetch = <int>[];
  for (final e in remote.entries) {
    if (!local.containsKey(e.key) || !_sameInstant(local[e.key], e.value)) {
      toFetch.add(e.key);
    }
  }
  final toDelete = <int>[
    for (final id in local.keys)
      if (!remote.containsKey(id) && !pendingIds.contains(id)) id,
  ];
  return ReconcilePlan(toFetch, toDelete);
}

// Postgres returns "+00:00" while Dart writes "Z"; compare instants, not text.
bool _sameInstant(String? a, String? b) {
  if (a == null || b == null) return a == b;
  final da = DateTime.tryParse(a);
  final db = DateTime.tryParse(b);
  if (da == null || db == null) return a == b;
  return da.isAtSameMomentAs(db);
}
