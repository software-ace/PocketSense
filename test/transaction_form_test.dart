import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';

import 'helpers/screen_with_db.dart';

void main() {
  setUp(useSeededTestDb);

  Future<void> openAddSheet(WidgetTester tester) async {
    await pumpScreenWithDb(tester, const TransactionsScreen());
    await tester.tap(find.text('Add'));
    await settleWithDb(tester);
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

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '5');
    await tester.tap(find.text('Save'));
    await settleWithDb(tester);

    final saved = (await tester.runAsync(() => FinanceRepo().transactions()))!.single;
    // Not the word "Transaction" in whatever language was on at the time.
    expect(saved.description, isEmpty);
    expect(find.text('Transaction'), findsOneWidget);
  });
}
