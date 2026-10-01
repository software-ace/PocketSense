import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/budgets_screen.dart';
import 'package:pocket_sense/screens/categories_screen.dart';
import 'package:pocket_sense/screens/recurring_screen.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';

import 'helpers/screen_with_db.dart';

// Saving with a required field empty keeps the form open and says what's
// missing, under that field. Fixing the field clears its message.
void main() {
  setUp(useSeededTestDb);

  Future<void> open(WidgetTester tester, Widget screen, String button, {Locale locale = const Locale('en')}) async {
    await pumpScreenWithDb(tester, screen, locale: locale);
    await tester.tap(find.text(button));
    await settleWithDb(tester);
  }

  Future<void> save(WidgetTester tester, [String label = 'Save']) async {
    await tester.tap(find.text(label));
    await settleWithDb(tester);
  }

  testWidgets('transaction: amount is required and must be above zero', (tester) async {
    await open(tester, const TransactionsScreen(), 'Add');
    await save(tester);
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.text('New transaction'), findsOneWidget); // still open

    final amount = find.widgetWithText(TextFormField, 'Amount');
    await tester.enterText(amount, '0');
    await tester.pump();
    expect(find.text('Enter an amount above zero, with at most 3 decimals.'), findsOneWidget);

    await tester.enterText(amount, '5');
    await tester.pump();
    expect(find.text('Enter an amount above zero, with at most 3 decimals.'), findsNothing);
    await save(tester);
    expect(find.text('New transaction'), findsNothing);
    expect(await tester.runAsync(() => FinanceRepo().transactions()), hasLength(1));
  });

  testWidgets('transaction: the message is in the app language', (tester) async {
    await open(tester, const TransactionsScreen(), 'إضافة', locale: const Locale('ar'));
    await save(tester, 'حفظ');
    expect(find.text('أدخل المبلغ'), findsOneWidget);
  });

  testWidgets('recurring: description and amount are required', (tester) async {
    await open(tester, const RecurringScreen(), 'New');
    await save(tester);
    expect(find.text('Enter a description'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'Rent');
    await tester.pump();
    expect(find.text('Enter a description'), findsNothing);
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(await tester.runAsync(() => FinanceRepo().recurring()), isEmpty);
  });

  testWidgets('budget: category and limit are required', (tester) async {
    await open(tester, const BudgetsScreen(), 'New');
    await save(tester);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(await tester.runAsync(() => FinanceRepo().budgets()), isEmpty);
  });

  testWidgets('category: name is required, and blank spaces don\'t count', (tester) async {
    await open(tester, const CategoriesScreen(), 'New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '   ');
    await save(tester);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('New category'), findsWidgets); // still open
  });
}
