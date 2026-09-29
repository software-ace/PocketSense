import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

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
}
