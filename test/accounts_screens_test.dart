import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/accounts_screen.dart';
import 'package:pocket_sense/screens/dashboard_screen.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/settings/manage_accounts_screen.dart';
import 'package:pocket_sense/utils/format.dart';
import 'package:pocket_sense/widgets/account_field.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/screen_with_db.dart';

void main() {
  final repo = FinanceRepo();
  final day = DateTime.now();

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    AppSettings.defaultAccount.value = null;
    await useSeededTestDb();
    addTearDown(() => maskAmounts = false);
  });

  Future<int> cashId(WidgetTester tester) async => (await tester.runAsync(() => repo.defaultAccountId()))!;

  testWidgets('with only Cash, entry forms show no account field', (tester) async {
    await pumpScreenWithDb(tester, Scaffold(body: AccountField(value: null, onChanged: (_) {})));
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
  });

  testWidgets("editing an entry in a closed account still shows that account, so saving doesn't move it", (tester) async {
    final visa = (await tester.runAsync(() async {
      final id = await repo.insertAccount(name: 'Visa card', kind: 'card');
      await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
      await repo.closeAccount(id);
      return id;
    }))!;
    int? picked;
    await pumpScreenWithDb(tester, Scaffold(body: AccountField(value: visa, onChanged: (v) => picked = v)));
    expect(find.text('Visa card (closed)'), findsOneWidget, reason: 'selected, as it is');
    await tester.tap(find.text('Visa card (closed)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arab Bank').last);
    await tester.pumpAndSettle();
    expect(picked, isNot(visa));
  });

  testWidgets('Home masks account balances; closing one shows the real amount it moves, even under Hide amounts', (tester) async {
    final cash = await cashId(tester);
    await tester.runAsync(() async {
      await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
      await repo.insertTransaction(amountFils: 185500, type: 'income', date: day, description: 'x', accountId: cash);
    });
    maskAmounts = true;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpScreenWithDb(tester, const DashboardScreen());
    expect(find.text('Accounts'), findsWidgets);
    expect(find.text(formatMoney(185500, showHidden: true)), findsNothing, reason: 'Home stays masked');

    await pumpScreenWithDb(tester, const ManageAccountsScreen());
    await tester.tap(find.text('Cash'));
    await settleWithDb(tester);
    await tester.ensureVisible(find.text('Close account'));
    await tester.tap(find.text('Close account'));
    await settleWithDb(tester);
    expect(find.textContaining('Cash still holds ${formatMoney(185500, showHidden: true)}'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await settleWithDb(tester);

    final accounts = (await tester.runAsync(() => repo.accounts()))!;
    expect([for (final a in accounts) (a.name, a.closed, a.balanceFils)], [('Arab Bank', false, 185500), ('Cash', true, 0)]);
    expect((await tester.runAsync(() => repo.defaultAccountId())), accounts.first.id, reason: 'Cash was the default: Arab Bank took over');
  });

  testWidgets('a transfer from the Accounts screen moves money without touching the totals', (tester) async {
    final cash = await cashId(tester);
    await tester.runAsync(() async {
      await repo.insertAccount(name: 'Savings', kind: 'savings');
      await repo.insertTransaction(amountFils: 50000, type: 'income', date: day, description: 'x', accountId: cash);
    });
    await pumpScreenWithDb(tester, const AccountsScreen());
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await settleWithDb(tester);
    await tester.enterText(find.byType(TextFormField).first, '20');
    await tester.pumpAndSettle();
    expect(find.text('After this transfer'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settleWithDb(tester);

    final balances = {for (final a in (await tester.runAsync(() => repo.accounts()))!) a.name: a.balanceFils};
    expect(balances, {'Cash': 30000, 'Savings': 20000});
    expect((await tester.runAsync(() => repo.totals(DateTime(2000), DateTime(2100))))!.income, 50000);
  });

  testWidgets('deleting a transfer asks first: Cancel keeps it', (tester) async {
    final cash = await cashId(tester);
    final transfer = (await tester.runAsync(() async {
      final savings = await repo.insertAccount(name: 'Savings', kind: 'savings');
      final id = await repo.insertTransfer(fromId: cash, toId: savings, amountFils: 20000, date: day);
      return (await repo.transfers()).firstWhere((t) => t.id == id);
    }))!;
    await pumpScreenWithDb(tester, Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => showTransferSheet(c, existing: transfer), child: const Text('open')))));
    Future<int> count() async => (await tester.runAsync(() => repo.transfers()))!.length;

    await tester.tap(find.text('open'));
    await settleWithDb(tester);
    await tester.tap(find.text('Delete transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this transfer?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleWithDb(tester);
    expect(await count(), 1);

    await tester.tap(find.text('Delete transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settleWithDb(tester);
    expect(await count(), 0);
    expect(find.text('Delete transfer'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('tapping Save twice on a new account adds one account', (tester) async {
    await pumpScreenWithDb(tester, const ManageAccountsScreen());
    await tester.tap(find.text('New account'));
    await settleWithDb(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Wallet');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await settleWithDb(tester);
    final names = [for (final a in (await tester.runAsync(() => repo.accounts()))!) a.name];
    expect(names.where((n) => n == 'Wallet'), hasLength(1));
  });
}
