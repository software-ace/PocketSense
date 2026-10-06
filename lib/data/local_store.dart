import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_sqlcipher/sqflite.dart' as sq;

import '../models/default_categories.dart';
import '../sync/identity.dart';
import '../utils/app_dirs.dart';
import 'backup.dart';
import 'db_key.dart';

/// The app's only data store: one SQLCipher-encrypted database on the device,
/// keyed by [DbKey]. Nothing leaves it except through an explicit backup
/// export, or sync with a device the user paired.
class LocalStore {
  static LocalStore? _instance;

  static Future<LocalStore> instance() async {
    final s = _instance;
    if (s == null) throw StateError('Local store is not open');
    return s;
  }

  /// Point [instance] at [store] (e.g. [openInMemoryForTest]) so repo-level
  /// tests run against real SQLite without touching the on-device database.
  static void overrideInstanceForTest(LocalStore store) => _instance = store;

  final sq.Database db;
  LocalStore._(this.db);

  /// Bumped after every write so open tabs (kept alive in an IndexedStack)
  /// know to reload.
  final ValueNotifier<int> changes = ValueNotifier(0);
  void notifyChanged() => changes.value++;

  static const fileName = 'pocketsense.db';
  static const schemaVersion = 2;

  /// Tables whose rows sync between paired devices, parents first.
  static const syncedTables = ['categories', 'transactions', 'budgets', 'recurring_expenses'];

  static Future<String> _dir() async => Platform.isLinux ? linuxDataDir() : await sq.getDatabasesPath();

  static Future<String> path() async => p.join(await _dir(), fileName);

  /// Opens (creating and seeding on first run) the on-device database.
  /// [categoryNames] maps [defaultCategories] keys to localized names;
  /// [starterNames] maps them to every default name they've had, which the
  /// v2 upgrade uses to recognize the starter categories.
  static Future<LocalStore> open({Map<String, String> categoryNames = const {}, Map<String, Set<String>> starterNames = const {}}) async {
    await closeCurrent();
    await _deleteLegacyFiles();
    final file = await path();
    final key = await DbKey.obtain(dbExists: await File(file).exists());
    final sq.Database db;
    if (Platform.isLinux) {
      db = await openEncryptedFfi(file, key, categoryNames: categoryNames, starterNames: starterNames);
    } else {
      db = await sq.openDatabase(file,
          password: key,
          version: schemaVersion,
          onConfigure: _configure,
          onCreate: (db, _) => createSchema(db, categoryNames: categoryNames),
          onUpgrade: (db, from, _) => upgrade(db, from, starterNames));
    }
    return _instance = await LocalStore._(db)._loadClock();
  }

  /// Linux: sqflite_common_ffi on the system libsqlcipher (see hooks: in
  /// pubspec.yaml). [hexKey] is a raw 256-bit key, so SQLCipher skips its
  /// passphrase KDF. The key must be the very first statement.
  @visibleForTesting
  static Future<sq.Database> openEncryptedFfi(String file, String hexKey,
      {Map<String, String> categoryNames = const {}, Map<String, Set<String>> starterNames = const {}}) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi.openDatabase(file,
        options: sq.OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('''PRAGMA key = "x'$hexKey'"''');
            await _configure(db);
          },
          onCreate: (db, _) => createSchema(db, categoryNames: categoryNames),
          onUpgrade: (db, from, _) => upgrade(db, from, starterNames),
        ));
  }

  static Future<void> _configure(sq.Database db) async {
    // Plain SQLite silently ignores PRAGMA key and would write an unencrypted
    // file. SQLCipher answers cipher_version; refuse to continue without it.
    final v = await db.rawQuery('PRAGMA cipher_version');
    if (v.isEmpty || (v.first.values.first?.toString() ?? '').isEmpty) {
      await db.close();
      throw StateError('SQLCipher is not available, so the database would not be encrypted. '
          'On Linux, install SQLCipher (libsqlcipher).');
    }
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Deletes the database file and its key. Used by "erase all data".
  static Future<void> eraseAll() async {
    await closeCurrent();
    final f = File(await path());
    if (await f.exists()) await f.delete();
    await DbKey.delete();
    // Kept, it would let "Forgot PIN" → erase → import an automatic backup
    // read everything without the PIN.
    await BackupPassword.delete();
    // The paired devices went with the database; a new key means none of
    // them trusts this device any more.
    await SyncIdentity.delete();
  }

  /// v1.x kept one plaintext database per Supabase account. v2 starts fresh
  /// and doesn't read them, so remove them rather than leave financial data
  /// lying around unencrypted.
  static Future<void> _deleteLegacyFiles() async {
    final dir = Directory(await _dir());
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      final name = p.basename(f.path);
      if (f is File && name.startsWith('pocketsense') && name.contains('.sqlite')) {
        await f.delete();
      }
    }
  }

  static Future<void> closeCurrent() async {
    final s = _instance;
    _instance = null;
    await s?.db.close();
  }

  /// Real SQLite in memory, for tests that must exercise sqflite's actual
  /// row shape (a hand-written fake once hid a column-key mismatch).
  static Future<LocalStore> openInMemoryForTest({bool seed = false, Map<String, String> categoryNames = const {}}) async {
    ffi.sqfliteFfiInit();
    // singleInstance: false → a fresh, isolated DB per call (the default reuses one).
    final db = await ffi.databaseFactoryFfi.openDatabase(sq.inMemoryDatabasePath,
        options: sq.OpenDatabaseOptions(
          singleInstance: false,
          version: schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createSchema(db, seed: seed, categoryNames: categoryNames),
        ));
    return LocalStore._(db)._loadClock();
  }

  static Future<void> createSchema(sq.Database db, {bool seed = true, Map<String, String> categoryNames = const {}}) async {
    // INTEGER PRIMARY KEY: SQLite assigns ids. NOCASE: "Food" and "food" are
    // the same category to a person.
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, type TEXT NOT NULL, color TEXT NOT NULL
      )
    ''');
    // created_at orders same-day entries.
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY, amount_fils INTEGER NOT NULL, type TEXT NOT NULL,
        date TEXT NOT NULL, description TEXT NOT NULL, merchant TEXT,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL, created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        limit_fils INTEGER NOT NULL, period TEXT NOT NULL DEFAULT 'monthly'
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY, description TEXT NOT NULL, amount_fils INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense', frequency TEXT NOT NULL, anchor_date TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        merchant TEXT, notes TEXT, active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    if (seed) await _seedCategories(db, categoryNames);
    // A new database goes through the same upgrade as an old one, so there
    // is one schema, not two that could drift apart.
    await _upgradeToV2(db, {for (final c in defaultCategories) c.key: {(categoryNames[c.key] ?? c.name).toLowerCase()}});
  }

  static Future<void> upgrade(sq.Database db, int from, Map<String, Set<String>> starterNames) async {
    if (from < 2) await _upgradeToV2(db, starterNames);
  }

  /// v2 adds what sync needs. Every synced row gets:
  /// - uid: an id shared by all devices (the integer id stays local).
  ///   Starter categories get a fixed one, `default:<key>`, so each
  ///   device's own "Groceries" turns out to be the same category.
  /// - hlc: when it last changed, as a hybrid logical clock (see [nextHlc]).
  ///   The newer one wins when two devices changed the same row.
  /// - seq: this device's change counter, so a peer can ask for "everything
  ///   since N". Raised again when a change arrives from another device, so
  ///   it travels on to the next one.
  /// Deleted rows leave a tombstone, so the deletion syncs too.
  static Future<void> _upgradeToV2(sq.Database db, Map<String, Set<String>> starterNames) async {
    final node = randomHex(8);
    final hlc = _formatHlc(DateTime.now().millisecondsSinceEpoch, 0, node);
    for (final t in syncedTables) {
      await db.execute('ALTER TABLE $t ADD COLUMN uid TEXT');
      await db.execute('ALTER TABLE $t ADD COLUMN hlc TEXT');
      await db.execute('ALTER TABLE $t ADD COLUMN seq INTEGER');
      await db.execute("UPDATE $t SET uid = lower(hex(randomblob(16))), hlc = ?, seq = 1", [hlc]);
    }
    final taken = <String>{};
    for (final c in await db.query('categories', columns: ['id', 'name'])) {
      final name = (c['name'] as String).toLowerCase();
      final key = starterNames.entries.where((e) => !taken.contains(e.key) && e.value.contains(name)).firstOrNull?.key;
      if (key == null) continue;
      taken.add(key);
      await db.update('categories', {'uid': 'default:$key'}, where: 'id = ?', whereArgs: [c['id']]);
    }
    for (final t in syncedTables) {
      await db.execute('CREATE UNIQUE INDEX idx_${t}_uid ON $t(uid)');
      await db.execute('CREATE INDEX idx_${t}_seq ON $t(seq)');
    }
    await db.execute('''
      CREATE TABLE tombstones (
        tbl TEXT NOT NULL, uid TEXT NOT NULL, hlc TEXT NOT NULL, seq INTEGER NOT NULL, PRIMARY KEY (tbl, uid)
      )
    ''');
    await db.execute('CREATE INDEX idx_tombstones_seq ON tombstones(seq)');
    // received_seq: the peer's seq up to which its changes are applied here.
    // sent_seq: this device's seq up to which the peer has confirmed ours.
    await db.execute('''
      CREATE TABLE peers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, public_key TEXT NOT NULL,
        received_seq INTEGER NOT NULL DEFAULT 0, sent_seq INTEGER NOT NULL DEFAULT 0,
        last_sync TEXT, last_addr TEXT
      )
    ''');
    await db.execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)');
    await db.insert('meta', {'k': 'node', 'v': node});
  }

  static Future<void> _seedCategories(sq.Database db, Map<String, String> names) async {
    final batch = db.batch();
    for (final c in defaultCategories) {
      batch.insert('categories', {'name': names[c.key] ?? c.name, 'type': c.type, 'color': c.color});
    }
    await batch.commit(noResult: true);
  }

  // ── Change stamps ─────────────────────────────────────────────────────

  late String node;
  late String _lastHlc;
  late int _seq;

  Future<LocalStore> _loadClock() async {
    node = (await db.query('meta', where: "k = 'node'")).first['v'] as String;
    final union = [for (final t in [...syncedTables, 'tombstones']) 'SELECT seq, hlc FROM $t'].join(' UNION ALL ');
    final m = (await db.rawQuery('SELECT max(seq) AS s, max(hlc) AS h FROM ($union)')).first;
    _seq = m['s'] as int? ?? 0;
    _lastHlc = m['h'] as String? ?? _formatHlc(0, 0, node);
    return this;
  }

  static String randomHex(int bytes) {
    final rng = Random.secure();
    return [for (var i = 0; i < bytes; i++) rng.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }

  static String _formatHlc(int ms, int counter, String node) =>
      '${ms.toString().padLeft(15, '0')}-${counter.toRadixString(16).padLeft(4, '0')}-$node';

  /// Fixed widths, so stamps compare as strings; the node breaks ties.
  static final hlcPattern = RegExp(r'^\d{15}-[0-9a-f]{4}-[0-9a-f]{1,32}$');

  /// A stamp later than every one seen so far, here or from a peer, even
  /// if this device's clock is behind theirs.
  String nextHlc() {
    final ms = int.parse(_lastHlc.substring(0, 15));
    final counter = int.parse(_lastHlc.substring(16, 20), radix: 16);
    final now = DateTime.now().millisecondsSinceEpoch;
    final (m, c) = now > ms ? (now, 0) : (counter < 0xffff ? (ms, counter + 1) : (ms + 1, 0));
    return _lastHlc = _formatHlc(m, c, node);
  }

  /// Moves the clock past a stamp from another device.
  void observeHlc(String hlc) {
    if (hlc.compareTo(_lastHlc) > 0) _lastHlc = hlc;
  }

  int nextSeq() => ++_seq;

  /// hlc and seq for a change made here. Taken inside the transaction that
  /// writes it, so seq order is commit order: a peer that has seen seq N
  /// can't later miss a change below N.
  Map<String, Object> stamp() => {'hlc': nextHlc(), 'seq': nextSeq()};

  // ── Row access ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> selectRows(String table, {String? where, List<Object?>? whereArgs}) =>
      db.query(table, where: where, whereArgs: whereArgs);

  Future<int> insertRow(String table, Map<String, dynamic> values) async {
    final id = await db.transaction((txn) => txn.insert(table, {'uid': randomHex(16), ...values, ...stamp()}));
    notifyChanged();
    return id;
  }

  Future<int> updateRow(String table, int id, Map<String, dynamic> values) async {
    final n = await db.transaction((txn) => txn.update(table, {...values, ...stamp()}, where: 'id = ?', whereArgs: [id]));
    notifyChanged();
    return n;
  }

  /// Deletes the row and leaves a tombstone for peers.
  Future<int> deleteRow(String table, int id) async {
    final n = await db.transaction((txn) async {
      final row = (await txn.query(table, columns: ['uid'], where: 'id = ?', whereArgs: [id])).firstOrNull;
      if (row == null) return 0;
      if (table == 'categories') await releaseCategory(txn, id);
      await txn.insert('tombstones', {'tbl': table, 'uid': row['uid'], ...stamp()}, conflictAlgorithm: sq.ConflictAlgorithm.replace);
      return txn.delete(table, where: 'id = ?', whereArgs: [id]);
    });
    notifyChanged();
    return n;
  }

  /// What the foreign keys do when a category is deleted (entries and
  /// recurring items uncategorized, budgets deleted), but as stamped
  /// changes. A silent cascade would leave this device disagreeing with a
  /// peer where the category came back through a later edit.
  ///
  /// A child with a newer version in [incoming] (uid → hlc, from the batch
  /// being merged) is changed without a stamp: that version replaces it
  /// right after, and a stamp would wrongly outrank it.
  Future<void> releaseCategory(sq.Transaction txn, int categoryId, {Map<String, String> incoming = const {}}) async {
    bool replaced(Map<String, Object?> r) => (incoming[r['uid']] ?? '').compareTo(r['hlc'] as String) > 0;
    for (final t in ['transactions', 'recurring_expenses']) {
      for (final r in await txn.query(t, columns: ['id', 'uid', 'hlc'], where: 'category_id = ?', whereArgs: [categoryId])) {
        await txn.update(t, {'category_id': null, if (!replaced(r)) ...stamp()}, where: 'id = ?', whereArgs: [r['id']]);
      }
    }
    for (final b in await txn.query('budgets', columns: ['uid', 'hlc'], where: 'category_id = ?', whereArgs: [categoryId])) {
      if (replaced(b)) continue;
      await txn.insert('tombstones', {'tbl': 'budgets', 'uid': b['uid'], ...stamp()}, conflictAlgorithm: sq.ConflictAlgorithm.replace);
    }
    await txn.delete('budgets', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  /// Empties the synced tables without leaving tombstones, so nothing is
  /// deleted on peers. Used before taking a peer's data instead of ours.
  Future<void> wipeSyncedData() async {
    await db.transaction((txn) async {
      for (final t in syncedTables.reversed) {
        await txn.delete(t);
      }
      await txn.delete('tombstones');
    });
    notifyChanged();
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();
}
