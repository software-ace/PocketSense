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
import 'package:pocket_sense/settings/app_style.dart';
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
    AppSettings.appStyle.value = WidgetStyle.plain;
  });

  Future<void> openSettings(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(localizedApp(Scaffold(appBar: AppBar(actions: const [SettingsButton()])), locale: locale));
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
  }

  testWidgets('Settings → Data has Import and Export Transactions', (tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'Export Transactions'), 200);
    expect(find.widgetWithText(ListTile, 'Import Transactions'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Export Transactions'), findsOneWidget);
  });

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

  testWidgets('the currency list filters by code or name, English names too in Arabic', (tester) async {
    await openSettings(tester, locale: const Locale('ar'));
    await tester.tap(find.widgetWithText(ListTile, 'العملة'));
    await tester.pumpAndSettle();

    Future<void> search(String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.pumpAndSettle();
    }

    await search('krona');
    expect(find.text('كرونة سويدية'), findsOneWidget);
    expect(find.text('كرونة نرويجية'), findsNothing, reason: 'that one is a krone');
    expect(find.text('دينار أردني'), findsNothing);
    await search('SEK');
    expect(find.text('كرونة سويدية'), findsOneWidget);
    await search('دينار');
    expect(find.text('دينار أردني'), findsOneWidget);
    expect(find.text('دينار كويتي'), findsOneWidget);
    await search('zzz');
    expect(find.text('لا توجد عملة مطابقة'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'Import Backup'), 200);
    expect(find.widgetWithText(ListTile, 'Export Backup'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Import Backup'), findsOneWidget);

    // Export first asks whether to encrypt; cancelling there writes nothing.
    await tester.tap(find.widgetWithText(ListTile, 'Export Backup'));
    await tester.pumpAndSettle();
    expect(find.text('Encrypt this backup?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Encrypt this backup?'), findsNothing);

    // Encrypting with no backup password yet asks for one before writing anything.
    await tester.tap(find.widgetWithText(ListTile, 'Export Backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encrypt'));
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
    // Barely in view isn't enough to tap it.
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sent, [false]);

    await AppSettings.load();
    expect(AppSettings.privateScreen.value, isFalse);
    expect(sent, [false, false], reason: 'applied again at the next launch');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Hide amounts is on by default, and turning it off is saved', (tester) async {
    await AppSettings.load();
    expect(AppSettings.hideAmounts.value, isTrue);

    await openSettings(tester);
    final toggle = find.widgetWithText(SwitchListTile, 'Hide amounts');
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(AppSettings.hideAmounts.value, isFalse);
    AppSettings.hideAmounts.value = true;
    await AppSettings.load();
    expect(AppSettings.hideAmounts.value, isFalse, reason: 'read back from storage');
  });

  testWidgets('Appearance: a style is kept, and Light / Dark only applies to Plain', (tester) async {
    await openSettings(tester);
    await tester.tap(find.widgetWithText(ListTile, 'App style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receipt'));
    await tester.pumpAndSettle();

    expect(AppSettings.appStyle.value, WidgetStyle.receipt);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Theme')).enabled, isFalse);
    AppSettings.appStyle.value = WidgetStyle.plain;
    await AppSettings.load();
    expect(AppSettings.appStyle.value, WidgetStyle.receipt, reason: 'read back from storage');
  });

  for (final style in appStyles) {
    testWidgets('the ${style.name} style draws its cards and frame', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: appTheme(Brightness.light, style: style),
        builder: (context, child) => StyleFrame(style: style, child: child!),
        home: const Scaffold(body: Column(children: [Card(child: ListTile(title: Text('Rent'))), Card(child: SizedBox(width: 333, height: 40))])),
      ));
      expect(tester.takeException(), isNull);
      expect(Theme.of(tester.element(find.text('Rent'))).income, styleColors(style).income);
    });
  }

  testWidgets('the LCD frame takes its own height off the keyboard, so nothing gaps above it', (tester) async {
    late MediaQueryData inside;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(400, 800), padding: EdgeInsets.only(top: 24, bottom: 24), viewInsets: EdgeInsets.only(bottom: 300)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: StyleFrame(style: WidgetStyle.lcd, child: Builder(builder: (context) {
          inside = MediaQuery.of(context);
          return const SizedBox();
        })),
      ),
    ));
    // 24 gesture bar + 6 plastic + 14 bezel sit under the app already.
    expect(inside.viewInsets.bottom, 300 - 44);
    expect(inside.padding, EdgeInsets.zero);
  });

  test('every style reads at WCAG contrast: 4.5:1 for text, 3:1 for chart marks', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
    }

    final themes = {
      for (final s in appStyles) s.name: appTheme(Brightness.light, style: s),
      'plain dark': appTheme(Brightness.dark),
      'plain black': appTheme(Brightness.dark, black: true),
    };
    for (final MapEntry(key: name, value: t) in themes.entries) {
      final c = t.colorScheme;
      final card = t.cardTheme.color ?? c.surfaceContainerLow;
      final pairs = {
        'text on page': (c.onSurface, c.surface, 4.5),
        'text on card': (c.onSurface, card, 4.5),
        'muted text on card': (c.onSurfaceVariant, card, 4.5),
        'outline text on page': (c.outline, c.surface, 4.5),
        'outline text on card': (c.outline, card, 4.5),
        'primary on page': (c.primary, c.surface, 4.5),
        'primary on card': (c.primary, card, 4.5),
        'button text': (c.onPrimary, c.primary, 4.5),
        'selected tab': (c.onSecondaryContainer, c.secondaryContainer, 4.5),
        'error on page': (c.error, c.surface, 4.5),
        'error on card': (c.error, card, 4.5),
        'overdue tile': (c.onErrorContainer, c.errorContainer, 4.5),
        'income on card': (t.income, card, 4.5),
        'expense mark on card': (t.expense, card, 3.0),
        'snackbar': (c.onInverseSurface, c.inverseSurface, 4.5),
      };
      for (final MapEntry(key: what, value: (fg, bg, need)) in pairs.entries) {
        expect(ratio(fg, bg), greaterThanOrEqualTo(need), reason: '$name: $what');
      }
    }
  });
}
