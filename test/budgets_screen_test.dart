import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/budgets_screen.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

/// A phone's width in the test font, whose square glyphs run wider than real
/// ones: hence a lower pixel ratio than pumpScreenWithDb's.
Future<void> pumpBudgetsOnPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(localizedApp(const BudgetsScreen()));
  await settleWithDb(tester);
}

void main() {
  setUp(useSeededTestDb);
  final repo = FinanceRepo();

  Future<int> groceriesId() async => (await repo.categories()).firstWhere((c) => c.name == 'Groceries').id;

  testWidgets('a budget overspent fourfold says 400%, not the bar\'s cap', (tester) async {
    await tester.runAsync(() async {
      final groceries = await groceriesId();
      await repo.insertBudget(categoryId: groceries, limitFils: 100000);
      await repo.insertTransaction(amountFils: 400000, type: 'expense', date: DateTime.now(), description: 'x', categoryId: groceries);
    });
    await pumpBudgetsOnPhone(tester);
    expect(find.text('400%'), findsOneWidget);
  });

  group('on a phone, a budget can be deleted', () {
    Future<void> pumpWithBudget(WidgetTester tester) async {
      await tester.runAsync(() async => repo.insertBudget(categoryId: await groceriesId(), limitFils: 100000));
      await pumpBudgetsOnPhone(tester);
    }

    Future<void> confirmAndExpectGone(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleWithDb(tester);
      expect(await tester.runAsync(repo.budgetProgress), isEmpty);
      expect(find.text('Groceries'), findsNothing);
      await settleWithDb(tester); // the reload after the delete
    }

    testWidgets('by swiping its card, after Cancel kept it', (tester) async {
      await pumpWithBudget(tester);
      await tester.drag(find.text('Groceries'), const Offset(-600, 0));
      await settleWithDb(tester);
      await tester.tap(find.text('Cancel'));
      await settleWithDb(tester);
      expect(await tester.runAsync(repo.budgetProgress), hasLength(1), reason: 'Cancel must not delete');
      expect(find.text('Groceries'), findsOneWidget);

      await tester.drag(find.text('Groceries'), const Offset(-600, 0));
      await settleWithDb(tester);
      await confirmAndExpectGone(tester);
    });

    testWidgets('from its edit dialog', (tester) async {
      await pumpWithBudget(tester);
      await tester.tap(find.text('Groceries'));
      await settleWithDb(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleWithDb(tester);
      await confirmAndExpectGone(tester);
    });
  });
}
