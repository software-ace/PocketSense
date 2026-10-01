import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';

import 'localized_app.dart';

/// A fresh in-memory database with the starter categories, used by the app.
Future<void> useSeededTestDb() async {
  LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest(seed: true));
}

/// The database is real (sqflite ffi), so its futures need real time: pumps
/// until the loading spinner is gone (it never settles while shown), then
/// gives late loads (e.g. a form's category list, which has no spinner) a
/// moment too.
Future<void> settleWithDb(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

/// Pumps [screen] at phone size, so it uses the mobile layout.
Future<void> pumpScreenWithDb(WidgetTester tester, Widget screen, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(localizedApp(screen, locale: locale));
  await settleWithDb(tester);
}
