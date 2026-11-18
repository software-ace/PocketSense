import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/csv_files.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/models/models.dart';

// #29: one level of subcategories under a category, never two.
void main() {
  final repo = FinanceRepo();
  late LocalStore store;
  final day = DateTime(2026, 11, 3);

  setUp(() async {
    store = await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
  });

  Future<Category> cat(String name) async => (await repo.categories()).firstWhere((c) => c.name == name);
  Future<int> add(String name, {String type = 'expense', int? parentId}) =>
      repo.insertCategory(name: name, type: type, color: '#000000', parentId: parentId);
  Future<int> spend(int fils, int categoryId) =>
      repo.insertTransaction(amountFils: fils, type: 'expense', date: day, description: 'x', categoryId: categoryId);

  group('two levels only', () {
    test('a subcategory takes its parent\'s type', () async {
      final salary = await add('Salary', type: 'income');
      await add('Bonus', type: 'expense', parentId: salary);
      expect((await cat('Bonus')).type, 'income');
    });

    test('no subcategory under a subcategory, under itself, or for one that has its own', () async {
      final car = await add('Car');
      final fuel = await add('Fuel', parentId: car);
      final home = await add('Home');
      await expectLater(add('Diesel', parentId: fuel), throwsArgumentError);
      await expectLater(repo.updateCategory(home, name: 'Home', type: 'expense', color: '#000000', parentId: home), throwsArgumentError);
      await expectLater(repo.updateCategory(car, name: 'Car', type: 'expense', color: '#000000', parentId: home), throwsArgumentError);
      expect((await cat('Car')).parentId, isNull);
    });

    test("a parent's change of type carries its subcategories", () async {
      final car = await add('Car');
      await add('Fuel', parentId: car);
      await repo.updateCategory(car, name: 'Car', type: 'income', color: '#000000');
      expect((await cat('Fuel')).type, 'income');
    });
  });

  group('roll-ups', () {
    late int car, fuel;
    setUp(() async {
      car = await add('Car');
      fuel = await add('Fuel', parentId: car);
      await spend(1000, car);
      await spend(250, fuel);
    });

    test("filtering by a parent finds its subcategories' entries too", () async {
      expect((await repo.transactions(categoryId: car)).map((t) => t.amountFils), unorderedEquals([1000, 250]));
      expect((await repo.transactions(categoryId: fuel)).map((t) => t.amountFils), [250]);
    });

    test("a parent's budget counts its subcategories; a subcategory's only its own", () async {
      await repo.insertBudget(categoryId: car, limitFils: 5000);
      await repo.insertBudget(categoryId: fuel, limitFils: 500);
      final spent = {for (final p in await repo.budgetProgress(now: day)) p.budget.categoryId: p.spentFils};
      expect(spent, {car: 1250, fuel: 250});
    });

    test('By category shows parents only, with their subcategories in them', () async {
      final slices = await repo.spendingByCategory(day, day);
      expect([for (final s in slices) (s.label, s.fils)], [('Car', 1250)]);
    });
  });

  group('delete', () {
    test("a subcategory's entries and recurring items move to its parent, and its budget goes", () async {
      final car = await add('Car');
      final fuel = await add('Fuel', parentId: car);
      await spend(250, fuel);
      await repo.insertRecurring(description: 'Fill-up', amountFils: 100, frequency: 'monthly', anchorDate: day, categoryId: fuel);
      await repo.insertBudget(categoryId: fuel, limitFils: 500);

      await repo.deleteCategory(fuel);

      expect((await repo.transactions()).single.categoryId, car);
      expect((await repo.recurring()).single.categoryId, car);
      expect(await repo.budgets(), isEmpty);
    });

    test("a parent's subcategories become top-level; its own entries are uncategorized", () async {
      final car = await add('Car');
      final fuel = await add('Fuel', parentId: car);
      await spend(1000, car);
      await spend(250, fuel);

      await repo.deleteCategory(car);

      expect((await cat('Fuel')).parentId, isNull);
      expect({for (final t in await repo.transactions()) t.amountFils: t.categoryId}, {1000: null, 250: fuel});
    });
  });

  group('backup', () {
    test('a restore keeps subcategories under their parents', () async {
      final car = await add('Car');
      await add('Fuel', parentId: car);
      final json = await Backup.export(store);

      final fresh = await LocalStore.openInMemoryForTest();
      await Backup.import(fresh, json);

      final rows = {for (final r in await fresh.db.query('categories')) r['name']: r};
      expect(rows['Fuel']!['parent_id'], rows['Car']!['id']);
    });

    test('a hand-edited file with a third level restores with two', () async {
      final a = await add('A');
      await add('B', parentId: a);
      final c = await add('C');
      // Edited by hand: A under C makes C → A → B.
      final doc = jsonDecode(await Backup.export(store)) as Map<String, dynamic>;
      ((doc['tables'] as Map)['categories'] as List).cast<Map<String, dynamic>>().firstWhere((r) => r['name'] == 'A')['parent_id'] = c;

      await Backup.import(store, jsonEncode(doc));

      expect({for (final x in await repo.categories()) x.name: x.parentId}, {'A': c, 'B': null, 'C': null});
    });
  });

  group('csv', () {
    Future<CsvPreview> preview(String csv) => CsvFiles.preview(CsvKind.categories, csv);

    test('export names each parent; an import links them, even a subcategory listed first', () async {
      final car = await add('Car');
      await add('Fuel', parentId: car);
      expect(await CsvFiles.export(CsvKind.categories), contains('"Fuel","expense","#000000","Car"'));

      await CsvFiles.importPreview(await preview('name,type,parent\nTolls,expense,Trip\nTrip,expense,\n'));

      expect((await cat('Tolls')).parentId, (await cat('Trip')).id);
    });

    test('a parent the import would not honour is rejected, not quietly changed', () async {
      final car = await add('Car');
      await add('Fuel', parentId: car);
      await add('Salary', type: 'income');
      final p = await preview('name,type,parent\n'
          'A,expense,Nowhere\n' // nowhere
          'B,expense,b\n' // itself
          'C,expense,Salary\n' // of the other type
          'D,expense,Fuel\n' // a subcategory
          'E,expense,Trip\n' // a row that is rejected itself
          'Trip,expens,\n'
          'F,expense,Car\n'); // fine
      expect([for (final r in p.rows) r.problem], ['parent', 'parent', 'parent', 'parent', 'parent', 'type', null]);
    });
  });
}
