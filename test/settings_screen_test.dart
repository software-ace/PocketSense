import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/main.dart' show appTheme;
import 'package:pocket_sense/screens/settings_screen.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/utils/format.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    AppSettings.locale.value = null;
    AppSettings.theme.value = AppTheme.system;
  });

  Future<void> openSettings(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(localizedApp(Scaffold(appBar: AppBar(actions: const [SettingsButton()])), locale: locale));
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
  }

  testWidgets('gear icon opens Settings, which lists Categories, Merchants and Language', (tester) async {
    await openSettings(tester);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
    expect(find.text('System default'), findsNWidgets(2), reason: 'language and theme');
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'Merchants'), 200);
    expect(find.widgetWithText(ListTile, 'Categories'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Merchants'), findsOneWidget);
  });

  testWidgets('choosing Black updates and persists the theme, which has a pure-black background', (tester) async {
    await openSettings(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Black (AMOLED)'));
    await tester.pumpAndSettle();

    expect(AppSettings.theme.value, AppTheme.black);
    expect(find.widgetWithText(ListTile, 'Black (AMOLED)'), findsOneWidget, reason: 'shown under Theme');
    AppSettings.theme.value = AppTheme.system;
    await AppSettings.load();
    expect(AppSettings.theme.value, AppTheme.black, reason: 'read back from storage');

    final black = appTheme(Brightness.dark, black: true);
    expect(black.scaffoldBackgroundColor, Colors.black);
    expect(appTheme(Brightness.dark).scaffoldBackgroundColor, isNot(Colors.black));
    // Dropdown menus paint with canvasColor; black would hide them.
    expect(black.canvasColor, isNot(Colors.black));
    expect(black.bottomNavigationBarTheme.backgroundColor, Colors.black);
  });

  testWidgets('choosing Arabic updates and persists the language', (tester) async {
    await openSettings(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(AppSettings.locale.value, const Locale('ar'));
    AppSettings.locale.value = null;
    await AppSettings.load();
    expect(AppSettings.locale.value, const Locale('ar'), reason: 'read back from storage');
  });

  testWidgets('choosing a currency saves it, says amounts aren\'t converted, and relabels amounts', (tester) async {
    await tester.runAsync(() async => LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest()));
    addTearDown(() => AppSettings.setCurrency(currencies.first));
    await openSettings(tester);
    expect(find.text('Jordanian dinar (JOD)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Currency'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Amounts aren't converted"), findsOneWidget);
    await tester.tap(find.text('Saudi riyal'));
    await tester.pumpAndSettle();

    expect(find.text('Saudi riyal (SAR)'), findsOneWidget);
    expect(formatMoney(12500, locale: 'en'), 'SAR\u00A012.50');
    appCurrency = currencies.first;
    await AppSettings.load();
    expect(appCurrency.code, 'SAR', reason: 'read back from storage');
  });

  testWidgets('Settings in Arabic is right-to-left and translated', (tester) async {
    await openSettings(tester, locale: const Locale('ar'));
    expect(find.widgetWithText(AppBar, 'الإعدادات'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('الإعدادات'))), TextDirection.rtl);
  });

  testWidgets('Arabic dates use Latin digits, like amounts', (tester) async {
    // Flutter's Arabic date symbols (loaded by the localization delegates)
    // default to Arabic-Indic digits.
    await openSettings(tester, locale: const Locale('ar'));
    final text = DateFormat.yMMMd().format(DateTime(2026, 9, 28));
    expect(text, contains('28'));
    expect(text, contains('2026'));
    expect(text, isNot(contains('٢')));
  });

  testWidgets('Settings offers backup export and import', (tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'Import data'), 200);
    expect(find.widgetWithText(ListTile, 'Export data'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Import data'), findsOneWidget);

    // No backup password yet: export asks for one before writing anything.
    await tester.tap(find.widgetWithText(ListTile, 'Export data'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a backup password'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a backup password'), findsNothing);
  });

  testWidgets('Private screen (Android) is on by default, and turning it off is saved and sent to Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final sent = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('pocketsense/window'), (call) async {
      sent.add(call.arguments);
      return null;
    });
    await AppSettings.load();
    expect(AppSettings.privateScreen.value, isTrue);
    expect(sent, isEmpty, reason: 'MainActivity already starts with it on');

    await openSettings(tester);
    final toggle = find.widgetWithText(SwitchListTile, 'Private screen');
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sent, [false]);

    await AppSettings.load();
    expect(AppSettings.privateScreen.value, isFalse);
    expect(sent, [false, false], reason: 'applied again at the next launch');
    debugDefaultTargetPlatformOverride = null;
  });
}
