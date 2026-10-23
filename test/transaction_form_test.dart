import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';

import 'helpers/screen_with_db.dart';

TextField _merchantField(WidgetTester tester) =>
    tester.widget<TextField>(find.widgetWithText(TextField, 'Merchant (optional)'));

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

  testWidgets('Save sits above the navigation bar', (tester) async {
    // 3-button navigation: a 48 dp bar the app is drawn behind (Android 15+).
    tester.view.padding = tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 2.7);
    await openAddSheet(tester);

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom, lessThanOrEqualTo(screen - 48));
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

  testWidgets('the amount field only takes digits and separators', (tester) async {
    await openAddSheet(tester);
    final amount = find.widgetWithText(TextField, 'Amount');
    String text() => tester.widget<TextField>(amount).controller!.text;

    await tester.enterText(amount, '3.5Lunch6 R-');
    expect(text(), '3.56');

    await tester.enterText(amount, '١٬٢٠٠٫٥');
    expect(text(), '١٬٢٠٠٫٥', reason: 'Arabic digits and separators still go in');
  });

  testWidgets('typing an unknown merchant offers to create it, and creating keeps it in the field', (tester) async {
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Merchant (optional)'), 'Zaid');
    await tester.pump();
    expect(find.text('Merchant not found. Create it?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Create it'));
    await settleWithDb(tester);

    // Created and selected: the field keeps the name and the prompt is gone.
    expect(_merchantField(tester).controller!.text, 'Zaid');
    expect(find.text('Merchant not found. Create it?'), findsNothing);

    final merchants = (await tester.runAsync(() => FinanceRepo().merchants()))!;
    expect(merchants.single.name, 'Zaid');

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await tester.tap(find.text('Save'));
    await settleWithDb(tester);

    final saved = (await tester.runAsync(() => FinanceRepo().transactions()))!.single;
    expect(saved.merchant, 'Zaid');
  });

  testWidgets('editing can clear the merchant, even one deleted from the list, and the category', (tester) async {
    await tester.runAsync(() async {
      final repo = FinanceRepo();
      final cat = (await repo.categories()).firstWhere((c) => c.type == 'expense').id;
      await repo.insertTransaction(amountFils: 3560, type: 'expense', date: DateTime.now(), description: 'Lunch', merchant: 'Zaid', categoryId: cat);
    });
    await pumpScreenWithDb(tester, const TransactionsScreen());
    await tester.tap(find.text('Lunch'));
    await settleWithDb(tester);
    expect(find.text('Merchant not found. Create it?'), findsOneWidget, reason: 'Zaid is not in the list');

    await tester.enterText(find.widgetWithText(TextField, 'Merchant (optional)'), '');
    // The form's type switch (the list's filter is under it); clears the expense category.
    await tester.tap(find.text('Income').last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settleWithDb(tester);

    final saved = (await tester.runAsync(() => FinanceRepo().transactions()))!.single;
    expect(saved.merchant, isNull);
    expect(saved.categoryId, isNull);
  });

  testWidgets('typing a partial name suggests merchants and picking one fills the field', (tester) async {
    await tester.runAsync(() => FinanceRepo().insertMerchant('Amazon'));
    await openAddSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Merchant (optional)'), 'Ama');
    await tester.pump();
    expect(find.text('Amazon'), findsOneWidget);
    expect(find.text('Merchant not found. Create it?'), findsNothing);

    await tester.tap(find.text('Amazon'));
    await tester.pump();
    expect(_merchantField(tester).controller!.text, 'Amazon');
  });
}
