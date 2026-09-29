import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sq;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../utils/app_dirs.dart';

/// Starter categories created with a new database. `key` identifies each one
/// so the name can be supplied in the user's language at first launch; after
/// that the names are ordinary user data.
const defaultCategories = <({String key, String name, String type, String color, String icon})>[
  (key: 'groceries', name: 'Groceries', type: 'expense', color: '#22c55e', icon: 'cart'),
  (key: 'dining', name: 'Dining Out', type: 'expense', color: '#f97316', icon: 'utensils'),
  (key: 'transport', name: 'Transport', type: 'expense', color: '#0ea5e9', icon: 'car'),
  (key: 'housing', name: 'Housing', type: 'expense', color: '#a855f7', icon: 'home'),
  (key: 'utilities', name: 'Utilities', type: 'expense', color: '#eab308', icon: 'bolt'),
  (key: 'entertainment', name: 'Entertainment', type: 'expense', color: '#ec4899', icon: 'film'),
  (key: 'shopping', name: 'Shopping', type: 'expense', color: '#ef4444', icon: 'bag'),
  (key: 'health', name: 'Health', type: 'expense', color: '#14b8a6', icon: 'heart'),
  (key: 'subscriptions', name: 'Subscriptions', type: 'expense', color: '#f59e0b', icon: 'tag'),
  (key: 'otherExpense', name: 'Other Expense', type: 'expense', color: '#64748b', icon: 'tag'),
  (key: 'salary', name: 'Salary', type: 'income', color: '#16a34a', icon: 'banknote'),
  (key: 'freelance', name: 'Freelance', type: 'income', color: '#0d9488', icon: 'briefcase'),
  (key: 'otherIncome', name: 'Other Income', type: 'income', color: '#475569', icon: 'plus-circle'),
];

/// The app's only data store: one SQLite database on the device. Nothing
/// leaves it except through an explicit backup export.
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
  static const schemaVersion = 1;

  static Future<String> _dir() async => Platform.isLinux ? linuxDataDir() : await sq.getDatabasesPath();

  static Future<String> path() async => p.join(await _dir(), fileName);

  /// Opens (creating and seeding on first run) the on-device database.
  /// [categoryNames] maps [defaultCategories] keys to localized names.
  static Future<LocalStore> open({Map<String, String> categoryNames = const {}}) async {
    await closeCurrent();
    await _deleteLegacyFiles();
    final options = sq.OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => createSchema(db, categoryNames: categoryNames),
    );
    final sq.Database db;
    if (Platform.isLinux) {
      ffi.sqfliteFfiInit();
      db = await ffi.databaseFactoryFfi.openDatabase(await path(), options: options);
    } else {
      db = await sq.databaseFactory.openDatabase(await path(), options: options);
    }
    return _instance = LocalStore._(db);
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
    return LocalStore._(db);
  }

  static Future<void> createSchema(sq.Database db, {bool seed = true, Map<String, String> categoryNames = const {}}) async {
    // NOCASE: "Food" and "food" are the same category to a person.
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, type TEXT NOT NULL,
        color TEXT NOT NULL, icon TEXT NOT NULL DEFAULT 'tag',
        created_at TEXT, updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL, type TEXT NOT NULL,
        date TEXT NOT NULL, description TEXT NOT NULL, merchant TEXT,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        source TEXT NOT NULL DEFAULT 'manual', reference TEXT, notes TEXT,
        created_at TEXT, updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        limit_cents INTEGER NOT NULL, period TEXT NOT NULL DEFAULT 'monthly',
        active INTEGER NOT NULL DEFAULT 1, created_at TEXT, updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_expenses (
        id INTEGER PRIMARY KEY, description TEXT NOT NULL, amount_cents INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense', frequency TEXT NOT NULL, anchor_date TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        merchant TEXT, notes TEXT, active INTEGER NOT NULL DEFAULT 1, last_posted TEXT,
        created_at TEXT, updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
    if (seed) await _seedCategories(db, categoryNames);
  }

  static Future<void> _seedCategories(sq.Database db, Map<String, String> names) async {
    // Same id scheme as newRowId() in repo.dart (epoch-ms × 1000 + n).
    final base = DateTime.now().millisecondsSinceEpoch * 1000;
    final now = nowIso();
    final batch = db.batch();
    for (final (i, c) in defaultCategories.indexed) {
      batch.insert('categories', {
        'id': base + i + 1,
        'name': names[c.key] ?? c.name,
        'type': c.type,
        'color': c.color,
        'icon': c.icon,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }

  // ── Row access ────────────────────────────────────────────────────────

  static Object? _normalize(Object? v) => v is bool ? (v ? 1 : 0) : v;

  Future<List<Map<String, dynamic>>?> selectRows(String table, {String? where, List<Object?>? whereArgs}) async {
    final rows = await db.query(table, where: where, whereArgs: whereArgs);
    return rows.isEmpty ? null : rows;
  }

  Future<int> insertRow(String table, Map<String, dynamic> values) async {
    final id = await db.insert(table, {for (final e in values.entries) e.key: _normalize(e.value)});
    notifyChanged();
    return id;
  }

  Future<int> updateRow(String table, int id, Map<String, dynamic> values) async {
    final n = await db.update(table, {for (final e in values.entries) e.key: _normalize(e.value)},
        where: 'id = ?', whereArgs: [id]);
    notifyChanged();
    return n;
  }

  Future<int> deleteRow(String table, int id) async {
    final n = await db.delete(table, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
    return n;
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();
}
