// Takes the README and store-listing screenshots from the real app, filled
// with docs/demo-backup.json. Run with integration_test/take_screenshots.sh;
// it never touches the device's own database, keyring or settings except on
// Android, where it uses the (throwaway) app install it runs in.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/l10n/l10n.dart';
import 'package:pocket_sense/main.dart' show appTheme;
import 'package:pocket_sense/screens/dashboard_screen.dart';
import 'package:pocket_sense/screens/sync_screen.dart';
import 'package:pocket_sense/screens/transactions_screen.dart';
import 'package:pocket_sense/security/app_lock.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/shell.dart';
import 'package:pocket_sense/sync/sync_node.dart';
import 'package:pocket_sense/sync/sync_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// gzip + base64 of docs/demo-backup.json: the test runs on the phone, which
// can't read the file from the computer.
const _demo = String.fromEnvironment('DEMO_BACKUP');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final phone = Platform.isAndroid;
  final shots = <String, String>{};
  final root = GlobalKey();
  final locale = ValueNotifier(const Locale('en'));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  }

  // The app's own pixels (no status bar or window frame), saved by the
  // driver at [path], relative to the repo.
  Future<void> shot(WidgetTester tester, String path) async {
    await settle(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(root));
    final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    shots[path] = base64.encode(png!.buffer.asUint8List());
  }

  Future<void> tab(WidgetTester tester, String Function(AppLocalizations) label) async {
    final nav = find.byType(phone ? BottomNavigationBar : NavigationRail);
    await tester.tap(find.descendant(of: nav, matching: find.text(label(lookupAppLocalizations(locale.value)))));
    await tester.pumpAndSettle();
  }

  Future<void> useLocale(WidgetTester tester, Locale l) async {
    locale.value = l;
    await settle(tester);
    // What Boot does when the language changes.
    await FinanceRepo().localizeStarterCategories(starterCategoryNames(lookupAppLocalizations(l)), starterCategoryDefaultNames());
  }

  // Sync as it looks with two paired devices. Only what the screens show is
  // faked: the service never starts, so no sockets and no sync key.
  Future<void> syncShots(WidgetTester tester, {required String me, String? settingsPath, required String pairPath}) async {
    final l = lookupAppLocalizations(locale.value);
    final service = SyncService.instance;
    final now = DateTime.now();
    Peer peer(String id, String name, Duration ago) => Peer({
          'id': id, 'name': name, 'public_key': '', 'received_seq': 0, 'sent_seq': 0,
          'last_sync': now.subtract(ago).toUtc().toIso8601String(), 'last_addr': null,
        });
    final other = phone ? 'Laptop' : 'Pixel 9';
    AppSettings.sync.value = (enabled: true, name: me);
    service.peers.value = [peer('a1', other, const Duration(minutes: 2)), peer('b2', 'Family tablet', const Duration(hours: 26))];
    service.states.value = {'a1': PeerState.synced, 'b2': PeerState.unreachable};
    await tester.pumpAndSettle();
    if (settingsPath != null) {
      Scrollable.ensureVisible(tester.element(find.text(l.syncToggle)), alignment: 0.15);
      await shot(tester, settingsPath);
    }
    // Before opening it: with no devices, the pair screen spins forever and
    // never settles.
    service.nearby.value = {
      'a1': NearbyDevice('a1', other, InternetAddress('192.168.1.23'), SyncNode.defaultPort, DateTime.now()),
      'c3': NearbyDevice('c3', 'Office PC', InternetAddress('192.168.1.40'), SyncNode.defaultPort, DateTime.now()),
    };
    await tester.ensureVisible(find.text(l.syncPairDevice));
    await tester.tap(find.text(l.syncPairDevice));
    await tester.pumpAndSettle();
    // What an incoming request from "Office PC" shows.
    final pair = tester.element(find.byType(PairScreen));
    showDialog<bool>(context: pair, barrierDismissible: false,
        builder: (c) => PairCodeDialog(title: c.l10n.syncIncomingTitle('Office PC'), name: 'Office PC', code: '482913'));
    await shot(tester, pairPath);
    Navigator.of(pair).pop(); // the dialog
    Navigator.of(pair).pop(); // the pair screen
    service.nearby.value = {};
    service.peers.value = [];
    service.states.value = {};
    AppSettings.sync.value = (enabled: false, name: '');
    await tester.pumpAndSettle();
  }

  testWidgets('screenshots', (tester) async {
    expect(_demo, isNotEmpty, reason: 'pass --dart-define=DEMO_BACKUP=…');
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    AppLock.instance = AppLock(store: MemorySecretStore());
    final store = phone ? await LocalStore.open() : await LocalStore.openInMemoryForTest();
    LocalStore.overrideInstanceForTest(store);
    await Backup.import(store, utf8.decode(gzip.decode(base64.decode(_demo))));

    // Phones at their own size; the desktop at a fixed 1280×800 window.
    if (!phone) {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.5;
    }
    await tester.pumpWidget(RepaintBoundary(
      key: root,
      child: ValueListenableBuilder(
        valueListenable: locale,
        builder: (_, l, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: l,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (device, _) {
            final resolved = resolveAppLocale(l, device);
            AppSettings.applyToIntl(resolved);
            return resolved;
          },
          theme: appTheme(Brightness.light),
          home: const Shell(),
        ),
      ),
    ));

    if (phone) {
      for (final lang in ['en-US', 'ar']) {
        if (lang == 'ar') await useLocale(tester, const Locale('ar'));
        final dir = 'fastlane/metadata/android/$lang/images/phoneScreenshots';
        await tab(tester, (l) => l.navHome);
        await shot(tester, '$dir/1_home.png');
        await tab(tester, (l) => l.navActivity);
        await shot(tester, '$dir/2_activity.png');
        await tester.tap(find.descendant(of: find.byType(TransactionsScreen), matching: find.byIcon(Icons.add)).first);
        await shot(tester, '$dir/3_add.png');
        Navigator.of(tester.element(find.byType(TransactionsScreen))).pop();
        await tester.pumpAndSettle();
        await tab(tester, (l) => l.navBudgets);
        await shot(tester, '$dir/4_budgets.png');
        await tab(tester, (l) => l.navRecurring);
        await shot(tester, '$dir/5_recurring.png');
        await tab(tester, (l) => l.navHome);
        await tester.tap(find.descendant(of: find.byType(DashboardScreen), matching: find.byIcon(Icons.settings_outlined)));
        await shot(tester, '$dir/6_settings.png');
        await syncShots(tester, me: 'Pixel 9', settingsPath: '$dir/7_sync.png', pairPath: '$dir/8_pair.png');
        Navigator.of(tester.element(find.byType(Shell, skipOffstage: false))).pop();
        await tester.pumpAndSettle();
      }
    } else {
      const dir = 'docs/screenshots';
      await shot(tester, '$dir/desktop-home.png');
      await tab(tester, (l) => l.navActivity);
      await shot(tester, '$dir/desktop-activity.png');
      await tab(tester, (l) => l.navBudgets);
      await shot(tester, '$dir/desktop-budgets.png');
      await tab(tester, (l) => l.navRecurring);
      await shot(tester, '$dir/desktop-recurring.png');
      await tab(tester, (l) => l.navHome);
      await tester.tap(find.descendant(of: find.byType(DashboardScreen), matching: find.byIcon(Icons.settings_outlined)));
      await tester.pumpAndSettle();
      await syncShots(tester, me: 'Laptop', pairPath: '$dir/desktop-sync.png');
      Navigator.of(tester.element(find.byType(Shell, skipOffstage: false))).pop();
      await tester.pumpAndSettle();
      await useLocale(tester, const Locale('ar'));
      await tab(tester, (l) => l.navHome);
      await shot(tester, '$dir/desktop-home-ar.png');
    }
    binding.reportData = shots;
  });
}
