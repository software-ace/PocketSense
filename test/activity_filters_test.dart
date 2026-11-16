import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';

import 'helpers/screen_with_db.dart';

void main() {
  setUp(useSeededTestDb);
  final repo = FinanceRepo();

  // Lunch and Dinner at Reem (one typed "reem"), coffee at Reem Bakery, a taxi.
  Future<({int food, int transport, int bank})> seed() async {
    final food = await repo.insertCategory(name: 'Food', type: 'expense', color: '#22c55e');
    final transport = await repo.insertCategory(name: 'Rides', type: 'expense', color: '#3b82f6');
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
    for (final m in ['Reem', 'Reem Bakery', 'Careem']) {
      await repo.insertMerchant(m);
    }
    final day = DateTime(2026, 11, 10);
    await repo.insertTransaction(amountFils: 3500, type: 'expense', date: day, description: 'Lunch', merchant: 'Reem', categoryId: food);
    await repo.insertTransaction(amountFils: 6000, type: 'expense', date: day, description: 'Dinner', merchant: 'reem', categoryId: food, accountId: bank);
    await repo.insertTransaction(amountFils: 1500, type: 'expense', date: day, description: 'Coffee', merchant: 'Reem Bakery', categoryId: food);
    await repo.insertTransaction(amountFils: 2000, type: 'expense', date: day, description: 'Taxi', merchant: 'Careem', categoryId: transport);
    return (food: food, transport: transport, bank: bank);
  }

  Future<List<String>> found({int? categoryId, String? merchant, int? accountId, String? q}) async => [
        for (final t in await repo.transactions(categoryId: categoryId, merchant: merchant, accountId: accountId, q: q)) t.description,
      ]..sort();

  test('the merchant filter is that merchant exactly, in any letter case; category and account combine with search', () async {
    final ids = await seed();
    expect(await found(merchant: 'REEM'), ['Dinner', 'Lunch'], reason: 'not Reem Bakery, unlike search');
    expect(await found(q: 'reem'), ['Coffee', 'Dinner', 'Lunch', 'Taxi'], reason: 'search finds text anywhere');
    expect(await found(categoryId: ids.food), ['Coffee', 'Dinner', 'Lunch']);
    expect(await found(categoryId: ids.food, q: 'din'), ['Dinner']);
    expect(await found(merchant: 'Reem', accountId: ids.bank), ['Dinner']);
  });

  testWidgets('Activity filters by a picked merchant and category, and says when nothing matches', (tester) async {
    await tester.runAsync(seed);
    await pumpScreenWithDb(tester, const TransactionsScreen());
    expect(find.text('Taxi'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Merchant'));
    await settleWithDb(tester); // the list loads from the database
    await tester.tap(find.widgetWithText(ListTile, 'Reem'));
    await settleWithDb(tester);
    expect(find.widgetWithText(InputChip, 'Reem'), findsOneWidget, reason: 'the chip names the pick');
    expect([for (final d in ['Lunch', 'Dinner', 'Coffee', 'Taxi']) if (find.text(d).evaluate().isNotEmpty) d], ['Lunch', 'Dinner']);

    // Rides at Reem: nothing.
    await tester.tap(find.widgetWithText(ActionChip, 'Category'));
    await settleWithDb(tester); // the list loads from the database
    // A long list has a search box.
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'rid');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Rides'));
    await settleWithDb(tester);
    expect(find.text('Nothing matches'), findsOneWidget);

    // Clearing the merchant leaves Rides: the taxi.
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Reem'), matching: find.byIcon(Icons.clear)));
    await settleWithDb(tester);
    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
  });

  testWidgets('a picked merchant follows a rename elsewhere, and a deleted category clears its filter', (tester) async {
    final ids = (await tester.runAsync(seed))!;
    await pumpScreenWithDb(tester, const TransactionsScreen());
    await tester.tap(find.widgetWithText(ActionChip, 'Merchant'));
    await settleWithDb(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Reem'));
    await settleWithDb(tester);

    // The entries now say "Reem Restaurant": filtering by the old name would find nothing.
    final reem = (await tester.runAsync(repo.merchants))!.firstWhere((m) => m.name == 'Reem');
    await tester.runAsync(() => repo.renameMerchant(reem.id, 'Reem Restaurant'));
    await settleWithDb(tester);
    expect(find.widgetWithText(InputChip, 'Reem Restaurant'), findsOneWidget);
    expect([for (final d in ['Lunch', 'Dinner', 'Coffee', 'Taxi']) if (find.text(d).evaluate().isNotEmpty) d], ['Lunch', 'Dinner']);

    // A category deleted while picked: its filter goes, rather than showing nothing.
    await tester.tap(find.widgetWithText(ActionChip, 'Category'));
    await settleWithDb(tester);
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'rid');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Rides'));
    await settleWithDb(tester);
    expect(find.text('Nothing matches'), findsOneWidget);
    await tester.runAsync(() => repo.deleteCategory(ids.transport));
    await settleWithDb(tester);
    expect(find.widgetWithText(ActionChip, 'Category'), findsOneWidget, reason: 'the chip is back to unpicked');
    expect(find.text('Lunch'), findsOneWidget);
  });
}
