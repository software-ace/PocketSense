import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
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
}
