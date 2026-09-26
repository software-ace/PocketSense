import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/sync_plan.dart';

void main() {
  group('pullFilter', () {
    test('first sync (no watermark) pulls everything', () {
      expect(pullFilter(watermark: null), isNull);
    });

    test('incremental sync filters on updated_at > watermark', () {
      final f = pullFilter(watermark: DateTime.utc(2026, 9, 1, 12));
      expect(f, isNotNull);
      expect(f!.column, 'updated_at');
      expect(f.operator, 'gt');
      expect(f.value.toString(), '2026-09-01T12:00:00.000Z');
    });
  });

  group('applyPull', () {
    test('merges pulled rows into local and advances watermark', () async {
      final store = _FakeStore(
        local: {'1': _row(1, 'old-local', at: '2026-09-05T00:00:00Z')},
      );
      final pulled = [
        _row(1, 'newer-remote'),
        _row(2, 'brand-new'),
      ]; // pulled rows stamped 09-11 > 09-05
      final wm = DateTime.utc(2026, 9, 10, 8);
      await applyPull(
        store,
        table: 'categories',
        pulled: pulled,
        watermark: wm,
      );
      expect(
        store.local['1']!['name'],
        'newer-remote',
      ); // newer remote beat older local
      expect(store.local['2'], isNotNull);
      expect(store.watermarks['categories'], wm.toIso8601String());
    });

    test('keeps local row when it is newer than the pulled one', () async {
      final store = _FakeStore(
        local: {'1': _row(1, 'local-newer', at: '2026-09-12T00:00:00Z')},
      );
      await applyPull(
        store,
        table: 'categories',
        pulled: [_row(1, 'remote-older', at: '2026-09-01T00:00:00Z')],
        watermark: DateTime.utc(2026, 9, 10),
      );
      expect(store.local['1']!['name'], 'local-newer');
    });
  });
}

Map<String, dynamic> _row(
  int id,
  String name, {
  String at = '2026-09-11T00:00:00Z',
}) => {'id': id, 'name': name, 'updated_at': at};

class _FakeStore implements SyncStore {
  Map<String, dynamic> local;
  final watermarks = <String, String>{};
  _FakeStore({required this.local});

  @override
  Future<Map<String, dynamic>> allRows(String table) async {
    final out = <String, dynamic>{};
    local.forEach((k, v) => out[k] = Map<String, dynamic>.of(v));
    return out;
  }

  @override
  Future<void> upsertMany(String table, List<Map<String, dynamic>> rows) async {
    for (final r in rows) {
      local[r['id'].toString()] = r;
    }
  }

  @override
  String? watermarkFor(String table) => watermarks[table];

  @override
  Future<void> setWatermark(String table, DateTime ts) async {
    watermarks[table] = ts.toIso8601String();
  }
}
