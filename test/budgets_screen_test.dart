import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/budgets_screen.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

void main() {
  setUp(useSeededTestDb);

  testWidgets('a budget overspent fourfold says 400%, not the bar\'s cap', (tester) async {
    final repo = FinanceRepo();
    await tester.runAsync(() async {
      final groceries = (await repo.categories()).firstWhere((c) => c.name == 'Groceries').id;
      await repo.insertBudget(categoryId: groceries, limitFils: 100000);
      await repo.insertTransaction(amountFils: 400000, type: 'expense', date: DateTime.now(), description: 'x', categoryId: groceries);
    });
    // A phone's width in the test font, whose square glyphs run wider than real ones.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(const BudgetsScreen()));
    await settleWithDb(tester);
    expect(find.text('400%'), findsOneWidget);
  });
}
