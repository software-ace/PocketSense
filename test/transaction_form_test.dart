import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';

import 'helpers/localized_app.dart';

void main() {
  setUp(() async {
    LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest(seed: true));
  });

  // The database is real (sqflite ffi), so its futures need real time.
  // Pumps until the loading spinner is gone (it never settles while shown).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    // Phone-sized, so the mobile layout and the whole sheet fit.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(const TransactionsScreen()));
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    // The sheet loads its categories after it opens, with no spinner.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  Future<void> openCategories(WidgetTester tester) async {
    await tester.tap(find.text('Category (optional)'));
    await tester.pumpAndSettle();
  }

  testWidgets('category list only offers categories of the chosen type', (tester) async {
    await openAddSheet(tester);

    await openCategories(tester);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Salary'), findsNothing);
    await tester.tap(find.text('Groceries').last);
    await tester.pumpAndSettle();

    // Switching to income drops the expense category and offers income ones.
    await tester.tap(find.text('Income').last); // the sheet's, not the list filter's
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsNothing);
    await openCategories(tester);
    expect(find.text('Salary'), findsWidgets);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('an untitled transaction is saved untitled and titled when shown', (tester) async {
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = (await tester.runAsync(() => FinanceRepo().transactions()))!.single;
    // Not the word "Transaction" in whatever language was on at the time.
    expect(saved.description, isEmpty);
    expect(find.text('Transaction'), findsOneWidget);
  });
}
