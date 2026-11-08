import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/sync/merge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final repo = FinanceRepo();
  late LocalStore store;
  final day = DateTime(2026, 11, 3);

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    store = await LocalStore.openInMemoryForTest(seed: true);
    LocalStore.overrideInstanceForTest(store);
    AppSettings.defaultAccount.value = null;
  });

  Future<Account> account(String name) async => (await repo.accounts()).firstWhere((a) => a.name == name);
  Future<int> spend(int fils, {int? accountId}) =>
      repo.insertTransaction(amountFils: fils, type: 'expense', date: day, description: 'x', accountId: accountId);
  Future<int> earn(int fils, {int? accountId}) =>
      repo.insertTransaction(amountFils: fils, type: 'income', date: day, description: 'y', accountId: accountId);

  test('everyone starts with one account, Cash, the default; entries go into it', () async {
    final accounts = await repo.accounts();
    expect([for (final a in accounts) (a.name, a.uid, a.kind)], [('Cash', LocalStore.cashUid, 'cash')]);
    await earn(10000);
    await spend(2500);
    expect((await account('Cash')).balanceFils, 7500);
  });

  test('the starter Cash account follows the language, unless it was renamed', () async {
    await repo.localizeStarterCategories({LocalStore.cashNameKey: 'نقد'}, const {});
    expect((await repo.accounts()).single.name, 'نقد');
    final cash = (await repo.accounts()).single.id;
    await repo.updateAccount(cash, name: 'Wallet', kind: 'cash', openingFils: 0);
    await repo.localizeStarterCategories({LocalStore.cashNameKey: 'Cash'}, const {});
    expect((await repo.accounts()).single.name, 'Wallet');
  });

  test('balance = opening + income − spending ± transfers; transfers are neither income nor spending', () async {
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank', openingFils: 100000);
    final cash = (await account('Cash')).id;
    await earn(900000, accountId: bank);
    await spend(45500, accountId: bank);
    await repo.insertTransfer(fromId: bank, toId: cash, amountFils: 100000, date: day);

    expect((await account('Arab Bank')).balanceFils, 100000 + 900000 - 45500 - 100000);
    expect((await account('Cash')).balanceFils, 100000);
    final totals = await repo.totals(DateTime(2026, 11), DateTime(2026, 11, 30));
    expect(totals, (income: 900000, expense: 45500), reason: 'the transfer counts as neither');
    final months = await repo.monthlyTotals(DateTime(2026, 11, 30), months: 1);
    expect([months.single.income, months.single.expense], [900000, 45500]);
    expect(() => repo.insertTransfer(fromId: cash, toId: cash, amountFils: 1, date: day), throwsArgumentError);
  });

  test('closing moves the money left and the recurring items, and the target becomes the default', () async {
    final cash = (await account('Cash')).id;
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
    await earn(185500, accountId: cash);
    await repo.insertRecurring(description: 'Rent', amountFils: 450000, frequency: 'monthly', anchorDate: day, accountId: cash);

    await expectLater(repo.closeAccount(cash), throwsArgumentError, reason: 'money and an item to move, nowhere to go');
    await repo.closeAccount(cash, intoId: bank);

    expect((await account('Cash')).closed, isTrue);
    expect((await account('Cash')).balanceFils, 0);
    expect((await account('Arab Bank')).balanceFils, 185500);
    expect((await repo.recurring()).single.accountId, bank, reason: 'nothing posts into a hidden account');
    expect(await repo.defaultAccountId(), bank);
    expect((await repo.totals(DateTime(2026), DateTime(2027))).income, 185500, reason: 'the move is a transfer: totals unchanged');
  });

  test('closing a card that is owed pays it off from the target instead', () async {
    final card = await repo.insertAccount(name: 'Visa card', kind: 'card');
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank', openingFils: 500000);
    await spend(120000, accountId: card);

    await repo.closeAccount(card, intoId: bank);

    expect((await account('Visa card')).balanceFils, 0);
    expect((await account('Arab Bank')).balanceFils, 380000);
    final t = (await repo.transfers()).single;
    expect([t.fromId, t.toId, t.amountFils], [bank, card, 120000]);
  });

  test('deleting moves entries, recurring items and the opening balance, so no money is lost', () async {
    final cash = (await account('Cash')).id;
    final savings = await repo.insertAccount(name: 'Savings', kind: 'savings', openingFils: 5000000);
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
    await earn(1000, accountId: savings);
    await repo.insertTransfer(fromId: bank, toId: savings, amountFils: 300000, date: day);
    await repo.insertTransfer(fromId: savings, toId: cash, amountFils: 2000, date: day);
    final total = (await repo.accounts()).fold(0, (sum, a) => sum + a.balanceFils);

    await repo.deleteAccount(savings, intoId: bank);

    expect((await repo.accounts()).map((a) => a.name), ['Cash', 'Arab Bank']);
    expect((await repo.accounts()).fold(0, (sum, a) => sum + a.balanceFils), total, reason: 'the 5,000 opening balance moved too');
    expect((await repo.transactions(accountId: bank)).length, 1);
    final left = (await repo.transfers()).single;
    expect([left.fromId, left.toId], [bank, cash], reason: 'bank → savings went from an account to itself, so it went');
  });

  test('the last open account can be neither closed nor deleted', () async {
    final cash = (await account('Cash')).id;
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
    await repo.closeAccount(bank);
    await expectLater(repo.closeAccount(cash), throwsStateError);
    await expectLater(repo.deleteAccount(cash, intoId: bank), throwsStateError);
    await repo.deleteAccount(bank, intoId: cash);
    expect((await repo.accounts()).single.name, 'Cash');
  });

  test('a recurring item in a closed account posts into the default instead', () async {
    final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
    await repo.insertRecurring(description: 'Gym', amountFils: 30000, frequency: 'monthly', anchorDate: day, accountId: bank);
    // Closed on another device, which moved the item too; here it still points at it.
    await store.updateRow('accounts', bank, {'closed': 1});
    await repo.postRecurring((await repo.recurring()).single, description: 'Gym');
    expect((await repo.transactions()).single.accountId, (await account('Cash')).id);
  });

  group('sync', () {
    Future<void> sync(LocalStore from, LocalStore to) async => Merge.apply(to, await Merge.changesSince(from, 0));

    test('two devices that each upgraded end up with one Cash, with both sides\' entries in it', () async {
      final phone = store, laptop = await LocalStore.openInMemoryForTest(seed: true);
      await spend(1000);
      LocalStore.overrideInstanceForTest(laptop);
      await spend(2000);
      await sync(phone, laptop);
      await sync(laptop, phone);
      for (final s in [phone, laptop]) {
        LocalStore.overrideInstanceForTest(s);
        expect([for (final a in await repo.accounts()) (a.name, a.balanceFils)], [('Cash', -3000)]);
      }
    });

    test("a device paired later doesn't undo edits to Cash with its own starter Cash", () async {
      final phone = store;
      final cash = await account('Cash');
      await repo.updateAccount(cash.id, name: 'Wallet', kind: 'cash', openingFils: 500000);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final laptop = await LocalStore.openInMemoryForTest(seed: true);
      await sync(laptop, phone);
      await sync(phone, laptop);
      for (final s in [phone, laptop]) {
        LocalStore.overrideInstanceForTest(s);
        expect([for (final a in await repo.accounts()) (a.name, a.openingFils)], [('Wallet', 500000)]);
      }
    });

    test('accounts and transfers travel by uid, and an account deleted elsewhere keeps the entries added here', () async {
      final phone = store, laptop = await LocalStore.openInMemoryForTest(seed: true);
      final bank = await repo.insertAccount(name: 'Arab Bank', kind: 'bank');
      await repo.insertTransfer(fromId: bank, toId: (await account('Cash')).id, amountFils: 5000, date: day);
      await sync(phone, laptop);

      LocalStore.overrideInstanceForTest(laptop);
      expect((await account('Arab Bank')).balanceFils, -5000);
      expect((await account('Cash')).balanceFils, 5000);
      // An entry made on the laptop while the phone deletes the account.
      await spend(700, accountId: (await account('Arab Bank')).id);

      LocalStore.overrideInstanceForTest(phone);
      await repo.deleteAccount(bank, intoId: (await account('Cash')).id);
      await sync(phone, laptop);

      LocalStore.overrideInstanceForTest(laptop);
      expect([for (final a in await repo.accounts()) (a.name, a.balanceFils)], [('Cash', -700)],
          reason: 'the transfer went (Cash to Cash), and the laptop\'s new entry moved into Cash');
    });
  });

  test('an older backup, from before accounts, puts everything into Cash', () async {
    await spend(1000);
    final json = await Backup.export(store);
    final old = json
        .replaceFirst('"version": 3', '"version": 2')
        .replaceAll(RegExp(r'"accounts": \[[^\]]*\],'), '"accounts": [],')
        .replaceAll(RegExp(r',\s*"account_id": \d+'), '');
    final fresh = await LocalStore.openInMemoryForTest(seed: true);
    LocalStore.overrideInstanceForTest(fresh);
    await Backup.import(fresh, old);
    expect([for (final a in await repo.accounts()) (a.uid, a.balanceFils)], [(LocalStore.cashUid, -1000)]);
  });
}
