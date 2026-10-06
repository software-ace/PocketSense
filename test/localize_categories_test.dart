import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

void main() {
  late LocalStore store;
  final repo = FinanceRepo();
  final en = starterCategoryNames(lookupAppLocalizations(const Locale('en')));
  final ar = starterCategoryNames(lookupAppLocalizations(const Locale('ar')));
  final defaults = starterCategoryDefaultNames();

  setUp(() async {
    store = await LocalStore.openInMemoryForTest(seed: true, categoryNames: en);
    LocalStore.overrideInstanceForTest(store);
  });

  Future<Set<String>> names() async => {for (final c in await repo.categories()) c.name};

  test('knows every default name in every language', () {
    expect(defaults['groceries'], containsAll(['groceries', 'بقالة']));
    expect(defaults.keys, hasLength(13));
  });

  test('switching language renames the starter categories, both ways', () async {
    expect(await repo.localizeStarterCategories(ar, defaults), 13);
    expect(await names(), {...ar.values});

    expect(await repo.localizeStarterCategories(en, defaults), 13);
    expect(await names(), {...en.values});
  });

  test('names the user chose are kept', () async {
    final groceries = (await repo.categories()).firstWhere((c) => c.name == 'Groceries');
    await repo.updateCategory(groceries.id, name: 'Carrefour', type: 'expense', color: groceries.color);
    await repo.insertCategory(name: 'Kids', type: 'expense', color: '#000000');

    await repo.localizeStarterCategories(ar, defaults);
    final now = await names();
    expect(now, containsAll(['Carrefour', 'Kids', 'مطاعم']));
    expect(now, isNot(contains('بقالة')));
  });

  test('a rename that would clash with an existing name is skipped', () async {
    await repo.insertCategory(name: 'صحة', type: 'expense', color: '#000000'); // user-made, same as ar "Health"
    await repo.localizeStarterCategories(ar, defaults);
    final now = await names();
    expect(now, contains('Health'), reason: 'left alone instead of breaking the unique name');
    expect(now.where((n) => n == 'صحة'), hasLength(1));
  });

  test('nothing to do when names already match', () async {
    expect(await repo.localizeStarterCategories(en, defaults), 0);
  });

  test('transactions keep their category through a rename', () async {
    final food = (await repo.categories()).firstWhere((c) => c.name == 'Dining Out');
    await repo.insertTransaction(amountFils: 2500, type: 'expense', date: DateTime(2026, 9, 29), description: 'Lunch', categoryId: food.id);
    await repo.localizeStarterCategories(ar, defaults);
    expect((await repo.transactions()).single.categoryName, 'مطاعم');
  });
}
