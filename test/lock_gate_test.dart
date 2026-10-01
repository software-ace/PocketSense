import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/security/app_lock.dart';
import 'package:pocket_sense/security/lock_gate.dart';

import 'helpers/localized_app.dart';

void main() {
  late MemorySecretStore store;
  var erased = 0;

  setUp(() async {
    store = MemorySecretStore();
    AppLock.instance = AppLock(store: store, iterations: 1000);
    erased = 0;
  });

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(localizedApp(LockGate(
      onEraseAll: () async => erased++,
      child: const Scaffold(body: Text('the app')),
    )));
    // Let the keystore reads (real futures) finish, then build.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    // Hashing runs in an isolate: give it real time.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  bool appVisible(WidgetTester tester) => find.text('the app').hitTestable().evaluate().isNotEmpty;

  testWidgets('without a PIN the app shows straight away', (tester) async {
    await pumpGate(tester);
    expect(appVisible(tester), isTrue);
    expect(find.text('Enter your PIN'), findsNothing);
  });

  testWidgets('with a PIN the app stays hidden until the right PIN', (tester) async {
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    await pumpGate(tester);
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(appVisible(tester), isFalse);

    await typePin(tester, '1111');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(appVisible(tester), isFalse);

    await typePin(tester, '2468');
    expect(appVisible(tester), isTrue);
  });

  // As in main.dart: above the app's Navigator, so there are two Navigators
  // under MaterialApp's one HeroController.
  testWidgets('after unlocking, the app can still push routes', (tester) async {
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => LockGate(onEraseAll: () async => erased++, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('pushed page'))),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await typePin(tester, '2468');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('pushed page'), findsOneWidget);
  });

  testWidgets('forgot PIN erases only after two confirmations', (tester) async {
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    await pumpGate(tester);

    await tester.tap(find.text('Forgot PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(erased, 0);
    await tester.tap(find.text('Erase'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(erased, 1);
    expect(await tester.runAsync(() => AppLock.instance.enabled), isFalse);
    expect(appVisible(tester), isTrue);
  });
}
