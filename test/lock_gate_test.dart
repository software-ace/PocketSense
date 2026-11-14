import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/db_key.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/security/amount_privacy.dart';
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

  Future<void> pumpGate(WidgetTester tester, {Duration relockAfter = const Duration(seconds: 30)}) async {
    await tester.pumpWidget(localizedApp(LockGate(
      onEraseAll: () async => erased++,
      relockAfter: relockAfter,
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

  void goAway(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  Future<void> comeBack(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // What the home-screen widget's requests wait on: voice entry would listen
  // under the lock screen otherwise.
  testWidgets('LockGate.unlocked is false while locked and from the moment the app goes away', (tester) async {
    addTearDown(() => LockGate.unlocked.value = true);
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    await pumpGate(tester, relockAfter: Duration.zero);
    expect(LockGate.unlocked.value, isFalse);
    await typePin(tester, '2468');
    expect(LockGate.unlocked.value, isTrue);

    // A widget tap arrives before the app shows again: closed already.
    goAway(tester);
    expect(LockGate.unlocked.value, isFalse);
    await comeBack(tester);
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(LockGate.unlocked.value, isFalse);
    await typePin(tester, '2468');
    expect(LockGate.unlocked.value, isTrue);
  });

  testWidgets('shown amounts hide again after the time away, with or without a PIN', (tester) async {
    await pumpGate(tester);
    AmountPrivacy.revealed.value = true;
    goAway(tester);
    await comeBack(tester);
    expect(AmountPrivacy.revealed.value, isTrue, reason: 'back within 30 seconds');

    await pumpGate(tester, relockAfter: Duration.zero);
    goAway(tester);
    await comeBack(tester);
    expect(AmountPrivacy.revealed.value, isFalse);
  });

  testWidgets('without a PIN, LockGate.unlocked opens again on return', (tester) async {
    addTearDown(() => LockGate.unlocked.value = true);
    await pumpGate(tester);
    expect(LockGate.unlocked.value, isTrue);
    goAway(tester);
    expect(LockGate.unlocked.value, isFalse);
    await comeBack(tester);
    expect(LockGate.unlocked.value, isTrue);
  });

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

  testWidgets('coming back after the timeout covers the app at once, before the keystore answers', (tester) async {
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    await pumpGate(tester, relockAfter: Duration.zero);
    await typePin(tester, '2468');
    expect(appVisible(tester), isTrue);

    // A keystore that answers only when told, as Android's takes a moment.
    final slow = _HeldReads(store);
    AppLock.instance = AppLock(store: slow, iterations: 1000);
    goAway(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); // the first frame back: the keystore hasn't answered yet
    expect(appVisible(tester), isFalse);

    slow.release();
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);
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

  // A keystore error used to open the app as if no PIN were set; a retry
  // that then reached the data would have skipped the PIN.
  testWidgets('if the keystore fails, the app stays hidden until a retry can check the PIN', (tester) async {
    final flaky = _FlakyStore();
    AppLock.instance = AppLock(store: flaky, iterations: 1000);
    await tester.runAsync(() => AppLock.instance.setPin('2468'));
    flaky.failing = true;
    await pumpGate(tester);
    expect(appVisible(tester), isFalse);
    expect(find.textContaining("Android's keystore"), findsOneWidget);

    flaky.failing = false;
    await tester.tap(find.text('Try again'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(appVisible(tester), isFalse);
  });
}

class _FlakyStore extends MemorySecretStore {
  bool failing = false;

  @override
  Future<String?> read(String key) async {
    if (failing) throw KeyStoreUnavailable('KeyStoreException');
    return super.read(key);
  }
}

/// Reads wait until [release], like a keystore that is slow to answer.
class _HeldReads implements SecretStore {
  _HeldReads(this.inner);
  final SecretStore inner;
  final _gate = Completer<void>();
  void release() => _gate.complete();
  @override
  Future<String?> read(String key) async {
    await _gate.future;
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);
  @override
  Future<void> delete(String key) => inner.delete(key);
}
