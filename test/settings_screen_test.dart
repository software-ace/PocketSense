import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/settings_screen.dart';

void main() {
  testWidgets('gear icon opens Settings, which lists Categories', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: AppBar(actions: const [SettingsButton()])),
    ));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Categories'), findsOneWidget);
  });
}
