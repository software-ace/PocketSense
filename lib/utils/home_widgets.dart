import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_store.dart';
import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../settings/app_settings.dart';
import 'format.dart';

/// Android home-screen widgets with amounts: Overview (total balance and
/// spending on a day) and Account (one account's balance). Nothing is saved
/// for them: while the app runs, this sends MainActivity finished text
/// (channel pocketsense/widgets), again whenever data or a setting changes,
/// and Android only holds the views. After a reboot they ask to open the app.
/// Amounts show only with Settings → Amounts on widgets; otherwise •••.
abstract final class HomeWidgets {
  static const _channel = MethodChannel('pocketsense/widgets');
  static final _prefs = SharedPreferencesAsync();
  // Account widgets' accounts: "<widget id>:<account uid>". Not amounts.
  static const _accountsKey = 'widgets.accounts';

  /// An Account widget tapped before it had an account: its id. The shell
  /// asks which account once the app is unlocked, then sets it back to null.
  static final choosing = ValueNotifier<int?>(null);

  static bool _busy = false;
  static bool _again = false;
  static LocalStore? _store;
  static List<Listenable> get _settings => [AppSettings.locale, AppSettings.widgetAmounts, AppSettings.widgetStyle, AppSettings.currency];

  static Future<void> start() async {
    if (!Platform.isAndroid || _store != null) return;
    _store = await LocalStore.instance();
    _store!.changes.addListener(refresh);
    for (final s in _settings) {
      s.addListener(refresh);
    }
    _channel.setMethodCallHandler((call) async {
      // A widget was placed while the app runs.
      if (call.method == 'refresh') await refresh();
      if (call.method == 'choose') choosing.value = call.arguments as int;
    });
    _channel.invokeMethod<int>('take').then((id) => choosing.value ??= id).ignore();
    await refresh();
  }

  /// After Erase all data too: the widgets go back to asking to open the app.
  static void stop() {
    if (_store == null) return;
    _store!.changes.removeListener(refresh);
    _store = null;
    for (final s in _settings) {
      s.removeListener(refresh);
    }
    _channel.setMethodCallHandler(null);
    _channel.invokeMethod('clear').ignore();
  }

  static Future<void> setAccount(int widgetId, String accountUid) async {
    await _saveAccounts({...await _accounts(), widgetId: accountUid});
    await refresh();
  }

  static Future<void> _saveAccounts(Map<int, String> map) =>
      _prefs.setStringList(_accountsKey, [for (final e in map.entries) '${e.key}:${e.value}']);

  static Future<Map<int, String>> _accounts() async => {
        for (final s in await _prefs.getStringList(_accountsKey) ?? const <String>[])
          if (s.indexOf(':') case final i when i > 0) ?int.tryParse(s.substring(0, i)): s.substring(i + 1),
      };

  static Future<void> refresh() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _run();
      } while (_again);
    } catch (e, st) {
      debugPrint('widgets: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  static Future<void> _run() async {
    final placed = await _channel.invokeMapMethod<String, List<Object?>>('ids');
    final overview = [...?placed?['overview']?.cast<int>()];
    final account = [...?placed?['account']?.cast<int>()];
    // A removed widget's choice goes with it; only when Android answered, so
    // a failed lookup never wipes them.
    final chosen = await _accounts();
    if (placed != null && chosen.keys.any((id) => !account.contains(id))) {
      await _saveAccounts({for (final id in account) id: ?chosen[id]});
    }
    final style = AppSettings.widgetStyle.value.name;
    final locale = resolveAppLocale(AppSettings.locale.value, PlatformDispatcher.instance.locale);
    final l = lookupAppLocalizations(locale);
    // In the app's language, which Android's own strings don't follow. Quick
    // add wears the style and these words even with no balance widgets.
    final common = {
      'rtl': locale.languageCode == 'ar',
      'style': style,
      'stamp': l.widgetStamp,
      'hiddenLabel': l.widgetAmountHidden,
      'expense': l.expense,
      'income': l.income,
      'voice': l.addByVoice,
    };
    if (overview.isEmpty && account.isEmpty) return _channel.invokeMethod('show', {...common, 'widgets': const []});
    final repo = FinanceRepo();
    final today = todayDate();
    await _channel.invokeMethod('show', {
      ...common,
      'widgets': views(
        l: l,
        accounts: await repo.accounts(),
        spent: (await repo.totals(today, today)).expense,
        today: today,
        amounts: AppSettings.widgetAmounts.value,
        overview: overview,
        account: {for (final id in account) id: chosen[id]},
      ),
    });
  }

  /// What each widget shows. [account]: each Account widget's chosen account
  /// uid, null before one is chosen. One whose account is gone (deleted,
  /// maybe on another device) asks again.
  @visibleForTesting
  static List<Map<String, Object?>> views({
    required AppLocalizations l,
    required List<Account> accounts,
    required int spent,
    required DateTime today,
    required bool amounts,
    required List<int> overview,
    required Map<int, String?> account,
  }) {
    String money(int fils) => amounts ? formatMoney(fils, locale: l.localeName, showHidden: true) : '•••';
    final total = accounts.fold(0, (sum, a) => sum + a.balanceFils);
    return [
      for (final id in overview)
        {
          'id': id,
          'label': l.totalBalance,
          'amount': money(total),
          // Dated, not "today": nothing redraws it at midnight while the app is closed.
          'label2': l.widgetSpentOn(DateFormat.MMMd(l.localeName).format(today)),
          'amount2': money(spent),
          // The cat sleeps; and the hint, since ••• could pass for broken.
          'hidden': !amounts,
          // Only here: Account is too small.
          if (!amounts) 'hint': l.widgetAmountsHint,
        },
      for (final MapEntry(key: id, value: uid) in account.entries)
        if (accounts.where((a) => a.uid == uid).firstOrNull case final a?)
          {'id': id, 'label': a.name, 'amount': money(a.balanceFils), 'hidden': !amounts}
        else
          {'id': id, 'label': l.widgetChooseAccount, 'amount': '', 'choose': true},
    ];
  }
}
