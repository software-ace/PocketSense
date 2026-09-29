import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pocket_sense/screens/settings_screen.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    AppSettings.locale.value = null;
  });

  Future<void> openSettings(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(localizedApp(Scaffold(appBar: AppBar(actions: const [SettingsButton()])), locale: locale));
    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
  }

  testWidgets('gear icon opens Settings, which lists Categories and Language', (tester) async {
    await openSettings(tester);
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Categories'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
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
    expect(find.widgetWithText(ListTile, 'Export data'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Import data'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Export data'));
    await tester.pumpAndSettle();
    expect(find.text('Export an unencrypted file?'), findsOneWidget, reason: 'warns before writing plaintext');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
