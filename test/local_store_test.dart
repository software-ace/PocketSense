import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/models/default_categories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('a new database is seeded with the starter categories', () async {
    final store = await LocalStore.openInMemoryForTest(seed: true);
    final rows = await store.db.query('categories');
    expect(rows, hasLength(defaultCategories.length));
    expect(rows.map((r) => r['name']), containsAll(['Groceries', 'Salary']));
    expect(rows.map((r) => r['id']).toSet(), hasLength(rows.length), reason: 'ids must be unique');
  });

  test('seeding uses the localized names it is given', () async {
    final store = await LocalStore.openInMemoryForTest(seed: true, categoryNames: {'groceries': 'بقالة'});
    final names = (await store.db.query('categories')).map((r) => r['name']);
    expect(names, contains('بقالة'));
    expect(names, contains('Salary'), reason: 'missing keys fall back to English');
  });

  test('category names are unique regardless of case', () async {
    final store = await LocalStore.openInMemoryForTest();
    await store.insertRow('categories', {'id': 1, 'name': 'Food', 'type': 'expense', 'color': '#000000'});
    expect(() => store.insertRow('categories', {'id': 2, 'name': 'food', 'type': 'expense', 'color': '#000000'}),
        throwsA(anything));
  });

  test('deleting a category uncategorizes its transactions and removes its budgets', () async {
    final store = await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
    final repo = FinanceRepo();
    final cat = await repo.insertCategory(name: 'Food', type: 'expense', color: '#000000');
    await repo.insertTransaction(amountFils: 100, type: 'expense', date: DateTime(2026, 9, 1), description: 'x', categoryId: cat);
    await repo.insertBudget(categoryId: cat, limitFils: 1000);

    await repo.deleteCategory(cat);

    expect((await repo.transactions()).single.categoryId, isNull);
    expect(await repo.budgets(), isEmpty);
  });

  test('every write notifies listeners', () async {
    final store = await LocalStore.openInMemoryForTest();
    var n = 0;
    store.changes.addListener(() => n++);
    await store.insertRow('categories', {'id': 1, 'name': 'A', 'type': 'expense', 'color': '#000000'});
    await store.updateRow('categories', 1, {'name': 'B'});
    await store.deleteRow('categories', 1);
    expect(n, 3);
  });

  // The schema app v2.0 and v2.1 shipped: no merchants, no sync columns.
  test('a v1 database from v2.0/v2.1 upgrades all the way, keeping its entries', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(db.close);
    await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, type TEXT NOT NULL, color TEXT NOT NULL)');
    await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount_fils INTEGER NOT NULL, type TEXT NOT NULL, date TEXT NOT NULL, '
        'description TEXT NOT NULL, merchant TEXT, category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL, created_at TEXT)');
    await db.execute("CREATE TABLE budgets (id INTEGER PRIMARY KEY, category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE, "
        "limit_fils INTEGER NOT NULL, period TEXT NOT NULL DEFAULT 'monthly')");
    await db.execute("CREATE TABLE recurring_expenses (id INTEGER PRIMARY KEY, description TEXT NOT NULL, amount_fils INTEGER NOT NULL, "
        "type TEXT NOT NULL DEFAULT 'expense', frequency TEXT NOT NULL, anchor_date TEXT NOT NULL, "
        "category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL, merchant TEXT, notes TEXT, active INTEGER NOT NULL DEFAULT 1)");
    await db.insert('categories', {'name': 'Groceries', 'type': 'expense', 'color': '#22c55e'});
    await db.insert('transactions', {'amount_fils': 500, 'type': 'expense', 'date': '2026-01-01', 'description': 'x', 'merchant': 'Shop', 'category_id': 1});

    await LocalStore.upgrade(db, 1, {'groceries': {'groceries'}});

    expect((await db.query('merchants')).map((m) => m['name']), ['Shop'], reason: 'v3 backfills merchants from entries');
    expect((await db.query('categories', where: 'name = ?', whereArgs: ['Groceries'])).single['uid'], 'default:groceries');
    final tx = (await db.query('transactions')).single;
    expect((tx['amount_fils'], tx['account_id'] != null, tx['uid'] != null), (500, true, true));
    expect(await db.query('circles'), isEmpty, reason: 'and on to v8');
  });
}
