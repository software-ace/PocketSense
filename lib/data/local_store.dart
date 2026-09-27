import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'outbox.dart';
import 'sync_plan.dart';

/// Local SQLite mirror of the four finance tables plus a mutation outbox and
/// per-table sync watermarks. This is what makes the app offline-first: every
/// read hits this store, every write lands here first and queues for push.
class LocalStore implements Outbox, SyncStore {
  static LocalStore? _instance;
  static Future<LocalStore> instance() async => _instance ??= await _open();

  /// Point [instance] at [store] (e.g. [openInMemoryForTest]) so repo-level
  /// tests run against real SQLite without touching the on-device database.
  static void overrideInstanceForTest(LocalStore store) => _instance = store;

  final sq.Database db;
  LocalStore._(this.db);

  static const String kDbName = 'pocketsense.sqlite';

  static Future<LocalStore> _open() async {
    if (Platform.isLinux) {
      ffi.sqfliteFfiInit();
      final dir = ffi.databaseFactoryFfi.openDatabase(p.join(_linuxDataDir(), kDbName));
      return LocalStore._(await dir);
    }
    // Android / mobile: standard plugin-backed factory.
    final path = await sq.getDatabasesPath();
    final dir = sq.databaseFactory.openDatabase(p.join(path, kDbName));
    return LocalStore._(await dir);
  }

  /// Real SQLite in memory, for tests that must exercise sqflite's actual
  /// row shape (a hand-written fake once hid a column-key mismatch).
  static Future<LocalStore> openInMemoryForTest() async {
    ffi.sqfliteFfiInit();
    // singleInstance: false → a fresh, isolated DB per call (the default reuses one).
    final store = LocalStore._(await ffi.databaseFactoryFfi.openDatabase(sq.inMemoryDatabasePath,
        options: sq.OpenDatabaseOptions(singleInstance: false)));
    await store.initSchema();
    return store;
  }

  static String _linuxDataDir() {
    final home = Platform.environment['HOME'] ?? '.';
    final dir = p.join(home, '.local', 'share', 'pocket_sense');
    Directory(dir).createSync(recursive: true);
    return dir;
  }

  /// Schema mirrors Postgres column-for-column so rows round-trip unchanged.
  Future<void> initSchema() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, type TEXT NOT NULL,
        color TEXT NOT NULL, icon TEXT NOT NULL DEFAULT 'tag',
        created_at TEXT, updated_at TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL, type TEXT NOT NULL,
        date TEXT NOT NULL, description TEXT NOT NULL, merchant TEXT,
        category_id INTEGER REFERENCES categories(id), source TEXT NOT NULL DEFAULT 'manual',
        reference TEXT, notes TEXT, created_at TEXT, updated_at TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id),
        limit_cents INTEGER NOT NULL, period TEXT NOT NULL DEFAULT 'monthly',
        active INTEGER NOT NULL DEFAULT 1, created_at TEXT, updated_at TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INTEGER PRIMARY KEY, description TEXT NOT NULL, amount_cents INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense', frequency TEXT NOT NULL, anchor_date TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id), merchant TEXT, notes TEXT,
        active INTEGER NOT NULL DEFAULT 1, last_posted TEXT,
        created_at TEXT, updated_at TEXT
      );
    ''');
    // "table" is a reserved keyword in SQLite — quote it everywhere.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        seq INTEGER PRIMARY KEY AUTOINCREMENT, "table" TEXT NOT NULL, op TEXT NOT NULL,
        payload TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_watermarks (
        "table" TEXT PRIMARY KEY, ts TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)');
    await _addColumnIfMissing('recurring_expenses', 'type', "TEXT NOT NULL DEFAULT 'expense'");
  }

  /// CREATE TABLE IF NOT EXISTS won't touch an existing table, so columns
  /// added after first release have to be patched onto older installs.
  Future<void> _addColumnIfMissing(String table, String column, String decl) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    if (cols.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $decl');
  }

  // ── Generic row access (used by sync + repo reads) ────────────────────

  @override
  Future<Map<String, dynamic>> allRows(String table) async {
    final rows = await db.query(table);
    return {for (final r in rows) r['id'].toString(): r};
  }

  /// SQLite stores booleans as integers; PostgREST returns real bools.
  static Object? _normalize(Object? v) => v is bool ? (v ? 1 : 0) : v;

  @override
  Future<void> upsertMany(String table, List<Map<String, dynamic>> rows) async {
    final batch = db.batch();
    for (final r in rows) {
      batch.insert(table, {for (final e in r.entries) e.key: _normalize(e.value)},
          conflictAlgorithm: sq.ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>?> selectRows(String table, {String? where, List<Object?>? whereArgs}) async {
    final rows = await db.query(table, where: where, whereArgs: whereArgs);
    return rows.isEmpty ? null : rows;
  }

  Future<int> insertRow(String table, Map<String, dynamic> values) async {
    return db.insert(table, {for (final e in values.entries) e.key: _normalize(e.value)});
  }

  Future<int> updateRow(String table, int id, Map<String, dynamic> values) async {
    return db.update(table, {for (final e in values.entries) e.key: _normalize(e.value)},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRow(String table, int id) async {
    return db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIds(String table, List<int> ids) async {
    if (ids.isEmpty) return;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Stamp a locally-authored row with a fresh updated_at before it is stored.
  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  // ── Watermarks ────────────────────────────────────────────────────────

  @override
  String? watermarkFor(String table) {
    // Synchronous read via a cached map refreshed on set; cheap enough.
    return _wmCache[table];
  }

  final Map<String, String> _wmCache = {};

  Future<void> loadWatermarks() async {
    final rows = await db.query('sync_watermarks');
    _wmCache.clear();
    for (final r in rows) {
      final table = r['table']?.toString() ?? '';
      final ts = r['ts']?.toString() ?? '';
      if (table.isNotEmpty && ts.isNotEmpty) {
        _wmCache[table] = ts;
      }
    }
  }

  @override
  Future<void> setWatermark(String table, DateTime ts) async {
    final iso = ts.toUtc().toIso8601String();
    _wmCache[table] = iso;
    await db.insert('sync_watermarks', {'"table"': table, 'ts': iso},
        conflictAlgorithm: sq.ConflictAlgorithm.replace);
  }

  // ── Outbox ────────────────────────────────────────────────────────────

  /// Fired after every queued mutation so the app can schedule a push.
  void Function()? onAppend;

  @override
  Future<int> append({required String table, required String op, required Map<String, dynamic> payload}) async {
    final seq = await db.insert('outbox', {'"table"': table, 'op': op, 'payload': jsonEncode(payload)});
    onAppend?.call();
    return seq;
  }

  @override
  Future<List<Map<String, dynamic>>> pending() async {
    return db.query('outbox', orderBy: 'seq ASC');
  }

  @override
  Future<void> ack(int seq) async {
    await db.delete('outbox', where: 'seq = ?', whereArgs: [seq]);
  }
}
