import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/sync_merge.dart';

/// A row is a plain map; `updated_at` is an ISO-8601 UTC string, as PostgREST
/// returns it. The merge decides, per id, which side wins.
void main() {
  group('mergeRows', () {
    test('remote-only rows are added', () {
      final result = mergeRows(local: {}, remote: {'2': _row(2, 'b')});
      expect(result.keys, containsAll(['2']));
    });

    test('local-only rows are kept', () {
      final result = mergeRows(local: {'1': _row(1, 'a')}, remote: {});
      expect(result['1'], isNotNull);
    });

    test('newer updated_at wins regardless of side', () {
      final olderLocal = _row(1, 'local-edit', at: '2026-09-01T00:00:00Z');
      final newerRemote = _row(1, 'remote-edit', at: '2026-09-02T00:00:00Z');
      final result = mergeRows(
        local: {'1': olderLocal},
        remote: {'1': newerRemote},
      );
      expect(result['1']!['name'], 'remote-edit');

      final newerLocal = _row(1, 'local-edit', at: '2026-09-03T00:00:00Z');
      final olderRemote = _row(1, 'remote-edit', at: '2026-09-02T00:00:00Z');
      final result2 = mergeRows(
        local: {'1': newerLocal},
        remote: {'1': olderRemote},
      );
      expect(result2['1']!['name'], 'local-edit');
    });

    test('identical updated_at keeps local (stable tie-break)', () {
      final t = '2026-09-01T00:00:00Z';
      final result = mergeRows(
        local: {'1': _row(1, 'local', at: t)},
        remote: {'1': _row(1, 'remote', at: t)},
      );
      expect(result['1']!['name'], 'local');
    });

    test('missing updated_at on one side loses to any timestamped row', () {
      final noTs = <String, dynamic>{'id': 1, 'name': 'untimestamped'};
      final stamped = _row(1, 'stamped', at: '2020-01-01T00:00:00Z');
      final result = mergeRows(local: {'1': noTs}, remote: {'1': stamped});
      expect(result['1']!['name'], 'stamped');
    });

    test('returns a new map and does not mutate inputs', () {
      final l = {'1': _row(1, 'a')};
      final r = {'1': _row(1, 'b', at: '2026-09-09T00:00:00Z')};
      final before = Map<String, dynamic>.of(l['1'] as Map<String, dynamic>);
      mergeRows(local: l, remote: r);
      expect(l['1'], before);
    });
  });
}

Map<String, dynamic> _row(
  int id,
  String name, {
  String at = '2026-09-05T00:00:00Z',
}) => {'id': id, 'name': name, 'updated_at': at};
