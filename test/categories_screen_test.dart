import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/categories_screen.dart';

import 'helpers/screen_with_db.dart';

void main() {
  setUp(useSeededTestDb);

  // Categories can come from a paired device or a backup with any text.
  testWidgets('a category with a colour that is not #rrggbb still lists', (tester) async {
    await tester.runAsync(() async =>
        (await LocalStore.instance()).insertRow('categories', {'name': 'Odd', 'type': 'expense', 'color': 'red'}));
    await pumpScreenWithDb(tester, const CategoriesScreen());
    expect(tester.takeException(), isNull);
    final list = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Odd'), 300, scrollable: list);
    expect(tester.takeException(), isNull, reason: 'its row builds');
    expect(find.text('Odd'), findsOneWidget);
  });

  testWidgets('a new subcategory is saved under its parent, of its type, and listed under it', (tester) async {
    await pumpScreenWithDb(tester, const CategoriesScreen());
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Tips');
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();
    // Its type is the parent's, and can't be changed apart from it.
    final type = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(type.selected, {'income'});
    expect(type.onSelectionChanged, isNull);

    await tester.tap(find.text('Save'));
    await settleWithDb(tester);

    final cats = (await tester.runAsync(FinanceRepo().categories))!;
    final bonus = cats.firstWhere((c) => c.name == 'Tips');
    expect((bonus.type, bonus.parentId), ('income', cats.firstWhere((c) => c.name == 'Salary').id));
    await tester.tap(find.widgetWithText(Tab, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('In Salary'), findsNWidgets(2), reason: 'the starter Bonus, and Tips');
  });
}
