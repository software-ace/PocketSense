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
  static const schemaVersion = 8;

  /// Tables whose rows sync between paired devices, parents first.
  static const syncedTables = ['categories', 'merchants', 'loans', 'circles', 'accounts', 'transactions', 'budgets', 'recurring_expenses', 'transfers'];

  // The synced tables before v8, for the upgrades that run before it.
  static const _tablesBeforeV8 = ['categories', 'merchants', 'loans', 'accounts', 'transactions', 'budgets', 'recurring_expenses', 'transfers'];

  // The synced tables before v7, for the upgrades that run before it.
  static const _tablesBeforeV7 = ['categories', 'merchants', 'loans', 'transactions', 'budgets', 'recurring_expenses'];

  /// The key in `categoryNames` (see [open]) for the first account's name,
  /// "Cash" in the UI language.
  static const cashNameKey = 'account:cash';

  /// The first account's uid: the same on every device, so two paired
  /// devices that each upgrade make one account, not two.
  static const cashUid = 'default:cash';

  // The synced tables before v4. The older upgrades run on databases that
  // don't have the newer tables yet.
  static const _tablesBeforeV4 = ['categories', 'merchants', 'transactions', 'budgets', 'recurring_expenses'];

  // The desktop opens SQLCipher through FFI; Android through sqflite_sqlcipher.
  static bool get _desktop => Platform.isLinux || Platform.isWindows;

  static Future<String> _dir() async => _desktop ? desktopDataDir() : await sq.getDatabasesPath();

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
    if (_desktop) {
      db = await openEncryptedFfi(file, key, categoryNames: categoryNames, starterNames: starterNames);
    } else {
      db = await sq.openDatabase(file,
          password: key,
          version: schemaVersion,
          onConfigure: _configure,
          onCreate: (db, _) => createSchema(db, categoryNames: categoryNames),
          onUpgrade: (db, from, _) => upgrade(db, from, starterNames, categoryNames: categoryNames));
    }
    return _instance = await LocalStore._(db)._loadClock();
  }

  /// Linux and Windows: sqflite_common_ffi on the sqlite3 package's
  /// bundled SQLCipher (see hooks: in pubspec.yaml). [hexKey] is a raw 256-bit key, so SQLCipher skips its
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
          onUpgrade: (db, from, _) => upgrade(db, from, starterNames, categoryNames: categoryNames),
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
    await db.execute('''
      CREATE TABLE merchants (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE
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
    // Seeding already made the loan categories, or the caller wants none.
    await _upgradeToV4(db, categoryNames, addCategories: false);
    await _upgradeToV6(db);
    await _upgradeToV7(db, categoryNames[cashNameKey] ?? 'Cash');
    await _upgradeToV8(db, categoryNames, addCategories: false);
  }

  /// [categoryNames]: as for [open]; names the categories v4 adds.
  static Future<void> upgrade(sq.Database db, int from, Map<String, Set<String>> starterNames,
      {Map<String, String> categoryNames = const {}}) async {
    if (from < 2) await _upgradeToV2(db, starterNames);
    if (from < 3) await _upgradeToV3(db);
    if (from < 4) await _upgradeToV4(db, categoryNames);
    if (from < 6) await _upgradeToV6(db);
    if (from < 7) await _upgradeToV7(db, categoryNames[cashNameKey] ?? 'Cash');
    if (from < 8) await _upgradeToV8(db, categoryNames);
  }

  /// v8 adds savings circles, built like loans (v4): a circle holds its
  /// terms, and its money is ordinary transactions that point at it, in two
  /// starter categories with fixed uids. Safe to run twice.
  static Future<void> _upgradeToV8(sq.Database db, Map<String, String> categoryNames, {bool addCategories = true}) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS circles (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, contribution_fils INTEGER NOT NULL,
        rounds INTEGER NOT NULL, frequency TEXT NOT NULL, start_date TEXT NOT NULL,
        payout_round INTEGER NOT NULL, note TEXT, due_time INTEGER, reminder_days INTEGER,
        uid TEXT, hlc TEXT, seq INTEGER
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_circles_uid ON circles(uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_circles_seq ON circles(seq)');
    final txColumns = {for (final c in await db.rawQuery('PRAGMA table_info(transactions)')) c['name']};
    if (!txColumns.contains('circle_id')) {
      // SET NULL is the fallback only: deleting a circle deletes its entries
      // first, as stamped changes.
      await db.execute('ALTER TABLE transactions ADD COLUMN circle_id INTEGER REFERENCES circles(id) ON DELETE SET NULL');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_circle ON transactions(circle_id)');
    if (!addCategories) return;
    // Above every seq already sent to a peer, as in v3.
    final union = [for (final t in [...syncedTables, 'tombstones']) 'SELECT seq FROM $t'].join(' UNION ALL ');
    var seq = (await db.rawQuery('SELECT max(seq) AS s FROM ($union)')).first['s'] as int? ?? 0;
    final node = (await db.query('meta', where: "k = 'node'")).firstOrNull?['v'] as String? ?? randomHex(8);
    for (final c in defaultCategories.where((c) => circleCategoryKeys.contains(c.key))) {
      // As in v4: skipped if the user has a category of that name.
      await db.insert('categories', {
        'name': categoryNames[c.key] ?? c.name, 'type': c.type, 'color': c.color, 'uid': 'default:${c.key}',
        'hlc': _formatHlc(0, 0, node), 'seq': ++seq,
      }, conflictAlgorithm: sq.ConflictAlgorithm.ignore);
    }
  }

  /// The starter categories circle entries go in: payments, payouts.
  static const circleCategoryKeys = ['circlePayments', 'circlePayouts'];

  /// v6 adds due times and reminders, part of the item so they sync with
  /// it: due_time in minutes after midnight (null is 9:00), reminder_days
  /// before it (null is off). Older apps drop these columns from synced rows
  /// and leave them alone. Safe to run twice, like v4. (v5 was only a test
  /// build's, with the loan's time named reminder_time.)
  static Future<void> _upgradeToV6(sq.Database db) async {
    const added = {
      'recurring_expenses': ['due_time', 'reminder_days'],
      'loans': ['due_time', 'reminder_days'],
    };
    for (final MapEntry(key: table, value: columns) in added.entries) {
      final have = {for (final c in await db.rawQuery('PRAGMA table_info($table)')) c['name']};
      for (final c in columns.where((c) => !have.contains(c))) {
        await db.execute('ALTER TABLE $table ADD COLUMN $c INTEGER');
      }
    }
  }

  /// v7 adds accounts and transfers. Every entry and recurring item belongs
  /// to an account. Everyone starts with one, Cash ([cashUid]), and all
  /// existing entries go into it; people add the others they need.
  /// Transfers are a table of their own, not a third kind of entry, so
  /// nothing that sums income and spending can count one. Safe to run twice.
  static Future<void> _upgradeToV7(sq.Database db, String cashName) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'cash',
        opening_fils INTEGER NOT NULL DEFAULT 0, closed INTEGER NOT NULL DEFAULT 0,
        uid TEXT, hlc TEXT, seq INTEGER
      )
    ''');
    // SET NULL is the fallback only: deleting an account moves its entries
    // and transfers first, as stamped changes.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfers (
        id INTEGER PRIMARY KEY,
        from_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        to_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
        amount_fils INTEGER NOT NULL, date TEXT NOT NULL, note TEXT, created_at TEXT,
        uid TEXT, hlc TEXT, seq INTEGER
      )
    ''');
    for (final t in ['accounts', 'transfers']) {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_${t}_uid ON $t(uid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_${t}_seq ON $t(seq)');
    }
    for (final t in ['transactions', 'recurring_expenses']) {
      final have = {for (final c in await db.rawQuery('PRAGMA table_info($t)')) c['name']};
      if (!have.contains('account_id')) {
        await db.execute('ALTER TABLE $t ADD COLUMN account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL');
      }
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)');

    // Above every seq already sent to a peer, as in v3.
    final union = [for (final t in [..._tablesBeforeV8, 'tombstones']) 'SELECT seq FROM $t'].join(' UNION ALL ');
    final seq = (await db.rawQuery('SELECT max(seq) AS s FROM ($union)')).first['s'] as int? ?? 0;
    final node = (await db.query('meta', where: "k = 'node'")).firstOrNull?['v'] as String? ?? randomHex(8);
    // Time 0, as for starter categories (v2).
    await db.insert('accounts', {
      'name': cashName, 'kind': 'cash', 'uid': cashUid,
      'hlc': _formatHlc(0, 0, node), 'seq': seq + 1,
    }, conflictAlgorithm: sq.ConflictAlgorithm.ignore);
    final cash = (await db.query('accounts', columns: ['id'], where: 'uid = ?', whereArgs: [cashUid])).first['id'];
    // Not stamped: every device does the same, so there's nothing to send.
    for (final t in ['transactions', 'recurring_expenses']) {
      await db.update(t, {'account_id': cash}, where: 'account_id IS NULL');
    }
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
    for (final t in _tablesBeforeV4) {
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
      // Time 0, like every starter row: each device makes its own, and a
      // real rename or delete anywhere must outrank one made later.
      await db.update('categories', {'uid': 'default:$key', 'hlc': _formatHlc(0, 0, node)}, where: 'id = ?', whereArgs: [c['id']]);
    }
    for (final t in _tablesBeforeV4) {
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

  /// v3 adds merchants: the names the merchant picker offers. They sync like
  /// the other tables, and the list starts with the names already written on
  /// transactions and recurring items.
  static Future<void> _upgradeToV3(sq.Database db) async {
    // A database coming from v2 has no merchants table yet; one that just
    // went through _upgradeToV2 already has it, with the sync columns.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS merchants (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        uid TEXT, hlc TEXT, seq INTEGER
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_merchants_uid ON merchants(uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_merchants_seq ON merchants(seq)');
    // Backfill from the merchant text already on transactions and recurring
    // items, one list entry per distinct name (case-insensitively). The new
    // rows must sit above every seq already sent to a peer, or devices that
    // have already synced would never receive them.
    final union = [for (final t in [..._tablesBeforeV4, 'tombstones']) 'SELECT seq FROM $t'].join(' UNION ALL ');
    var seq = (await db.rawQuery('SELECT max(seq) AS s FROM ($union)')).first['s'] as int? ?? 0;
    final node = (await db.query('meta', where: "k = 'node'")).firstOrNull?['v'] as String? ?? randomHex(8);
    final ms = DateTime.now().millisecondsSinceEpoch;
    var counter = 0;
    for (final r in await db.rawQuery('''
      SELECT DISTINCT trim(merchant) AS name FROM (
        SELECT merchant FROM transactions UNION ALL SELECT merchant FROM recurring_expenses
      ) WHERE merchant IS NOT NULL AND trim(merchant) != ''
    ''')) {
      seq++;
      await db.insert('merchants', {
        'name': r['name'] as String, 'uid': randomHex(16),
        'hlc': _formatHlc(ms, counter++, node), 'seq': seq,
      }, conflictAlgorithm: sq.ConflictAlgorithm.ignore);
    }
  }

  /// v4 adds loans. A loan holds who and when it's due; its money is
  /// ordinary transactions that point at it, so every total stays a sum of
  /// transactions. Older databases also get the two loan categories, as
  /// starters with fixed uids, so each device's copy is the same row.
  /// Safe to run twice: a new database runs it after creating the rest.
  static Future<void> _upgradeToV4(sq.Database db, Map<String, String> categoryNames, {bool addCategories = true}) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS loans (
        id INTEGER PRIMARY KEY, direction TEXT NOT NULL, person TEXT NOT NULL COLLATE NOCASE,
        due_date TEXT, note TEXT, uid TEXT, hlc TEXT, seq INTEGER
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_loans_uid ON loans(uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_loans_seq ON loans(seq)');
    final txColumns = {for (final c in await db.rawQuery('PRAGMA table_info(transactions)')) c['name']};
    if (!txColumns.contains('loan_id')) {
      // SET NULL is the fallback only: deleting a loan deletes its entries
      // first, as stamped changes.
      await db.execute('ALTER TABLE transactions ADD COLUMN loan_id INTEGER REFERENCES loans(id) ON DELETE SET NULL');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tx_loan ON transactions(loan_id)');
    if (!addCategories) return;
    // Above every seq already sent to a peer, as in v3.
    final union = [for (final t in [..._tablesBeforeV7, 'tombstones']) 'SELECT seq FROM $t'].join(' UNION ALL ');
    var seq = (await db.rawQuery('SELECT max(seq) AS s FROM ($union)')).first['s'] as int? ?? 0;
    final node = (await db.query('meta', where: "k = 'node'")).firstOrNull?['v'] as String? ?? randomHex(8);
    for (final c in defaultCategories.where((c) => loanCategoryKeys.contains(c.key))) {
      // Ignored if one is there already, or the user has a category of
      // that name: loan entries are then uncategorized.
      await db.insert('categories', {
        'name': categoryNames[c.key] ?? c.name, 'type': c.type, 'color': c.color, 'uid': 'default:${c.key}',
        'hlc': _formatHlc(0, 0, node), 'seq': ++seq, // time 0, as in v2
      }, conflictAlgorithm: sq.ConflictAlgorithm.ignore);
    }
  }

  /// The starter categories loan entries go in: money out, money in.
  static const loanCategoryKeys = ['loansPaid', 'loansReceived'];

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

  /// Writes that land together or not at all, made with the *In methods
  /// below. Listeners hear about them once, after.
  Future<T> write<T>(Future<T> Function(sq.Transaction txn) body) async {
    final result = await db.transaction(body);
    notifyChanged();
    return result;
  }

  Future<int> insertRow(String table, Map<String, dynamic> values) => write((txn) => insertIn(txn, table, values));

  Future<int> updateRow(String table, int id, Map<String, dynamic> values) => write((txn) => updateIn(txn, table, id, values));

  /// Deletes the row and leaves a tombstone for peers.
  Future<int> deleteRow(String table, int id) => write((txn) => deleteIn(txn, table, id));

  Future<int> insertIn(sq.Transaction txn, String table, Map<String, dynamic> values) =>
      txn.insert(table, {'uid': randomHex(16), ...values, ...stamp()});

  Future<int> updateIn(sq.Transaction txn, String table, int id, Map<String, dynamic> values) =>
      txn.update(table, {...values, ...stamp()}, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteIn(sq.Transaction txn, String table, int id) async {
    final row = (await txn.query(table, columns: ['uid'], where: 'id = ?', whereArgs: [id])).firstOrNull;
    if (row == null) return 0;
    if (table == 'categories') await releaseCategory(txn, id);
    await txn.insert('tombstones', {'tbl': table, 'uid': row['uid'], ...stamp()}, conflictAlgorithm: sq.ConflictAlgorithm.replace);
    return txn.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Moves everything in account [from] into [to], as stamped changes:
  /// entries, recurring items and transfers (those between the two would go
  /// from an account to itself, so they're deleted). [addOpening]: [from]'s
  /// opening balance moves too, so the total stays the same; a peer applying
  /// a delete leaves it out, since the device that deleted already moved it.
  Future<void> moveAccountIn(sq.Transaction txn, int from, int to, {bool addOpening = true}) async {
    for (final t in ['transactions', 'recurring_expenses']) {
      for (final r in await txn.query(t, columns: ['id'], where: 'account_id = ?', whereArgs: [from])) {
        await updateIn(txn, t, r['id'] as int, {'account_id': to});
      }
    }
    for (final r in await txn.query('transfers', where: 'from_account_id = ? OR to_account_id = ?', whereArgs: [from, from])) {
      final f = r['from_account_id'] == from ? to : r['from_account_id'];
      final t = r['to_account_id'] == from ? to : r['to_account_id'];
      if (f == t) {
        await deleteIn(txn, 'transfers', r['id'] as int);
      } else {
        await updateIn(txn, 'transfers', r['id'] as int, {'from_account_id': f, 'to_account_id': t});
      }
    }
    if (!addOpening) return;
    final opening = (await txn.query('accounts', columns: ['opening_fils'], where: 'id = ?', whereArgs: [from])).first['opening_fils'] as int;
    if (opening == 0) return;
    final target = (await txn.query('accounts', columns: ['opening_fils'], where: 'id = ?', whereArgs: [to])).first['opening_fils'] as int;
    await updateIn(txn, 'accounts', to, {'opening_fils': target + opening});
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
