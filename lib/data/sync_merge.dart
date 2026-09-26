/// Pure last-write-wins merge for one table's rows, keyed by id.
///
/// Rows are plain maps (as PostgREST and sqflite both produce) carrying an
/// `updated_at` ISO-8601 string. The newer timestamp wins; ties and missing
/// timestamps resolve deterministically so sync is stable across runs.
Map<String, dynamic> mergeRows({
  required Map<String, dynamic> local,
  required Map<String, dynamic> remote,
}) {
  final result = <String, dynamic>{...local};
  for (final entry in remote.entries) {
    final existing = result[entry.key];
    if (existing == null || _wins(entry.value as Map<String, dynamic>, existing as Map<String, dynamic>)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

bool _wins(Map<String, dynamic> candidate, Map<String, dynamic> incumbent) {
  final cTs = _parse(candidate['updated_at']);
  final iTs = _parse(incumbent['updated_at']);
  if (cTs == null && iTs == null) return false; // tie on "no info": keep incumbent (local)
  if (cTs == null) return false;
  if (iTs == null) return true;
  // Strictly newer wins; equal keeps incumbent (local-first tie-break).
  return cTs.isAfter(iTs);
}

DateTime? _parse(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}
