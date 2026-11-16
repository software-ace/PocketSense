import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pocket_sense/l10n/l10n.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/utils/home_widgets.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  final l = lookupAppLocalizations(const Locale('en'));
  Account account(String uid, String name, int balance) =>
      Account(id: uid.hashCode, uid: uid, name: name, kind: 'bank', openingFils: 0, closed: false, balanceFils: balance, entries: 0);
  final accounts = [account('cash', 'Cash', 12500), account('bank', 'Arab Bank', 1000000)];

  List<Map<String, Object?>> views({required bool amounts}) => HomeWidgets.views(
        l: l,
        accounts: accounts,
        spent: 3750,
        today: DateTime(2026, 11, 16),
        amounts: amounts,
        overview: [1],
        account: {2: 'bank', 3: null, 4: 'deleted'},
      );

  test('with Amounts on widgets on, they show the total, the dated spending and each account', () {
    expect(views(amounts: true), [
      {'id': 1, 'label': 'Total balance', 'amount': 'JOD 1,012.500', 'label2': 'Spent on Nov 16', 'amount2': 'JOD 3.750', 'hidden': false},
      {'id': 2, 'label': 'Arab Bank', 'amount': 'JOD 1,000.000', 'hidden': false},
      // No account yet, or its account is gone: it asks for one.
      {'id': 3, 'label': 'Tap to choose an account', 'amount': '', 'choose': true},
      {'id': 4, 'label': 'Tap to choose an account', 'amount': '', 'choose': true},
    ]);
  });

  test('off (the default), every amount is •••', () {
    final amounts = [
      for (final w in views(amounts: false))
        for (final k in ['amount', 'amount2'])
          if (w[k] case final String a when a.isNotEmpty) a,
    ];
    expect(amounts, ['•••', '•••', '•••']);
    // The widgets know, so the cat sleeps.
    expect([for (final w in views(amounts: false)) if (w['choose'] != true) w['hidden']], [true, true]);
    // Overview says where to show them; with amounts on it doesn't (first test).
    expect(views(amounts: false).first['hint'], 'Show amounts in Settings →\u00A0Security');
  });
}
