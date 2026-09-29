import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/onboarding_screen.dart';
import 'package:pocket_sense/security/app_lock.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';

void main() {
  late int done;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    AppSettings.onboardingStep = 0;
    AppLock.instance = AppLock(store: MemorySecretStore(), iterations: 1000);
    done = 0;
  });

  Future<void> pump(WidgetTester tester, {Future<bool> Function(BuildContext)? importer}) async {
    await tester.pumpWidget(localizedApp(OnboardingScreen(onDone: () => done++, importer: importer)));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  testWidgets('step 1 offers import or a fresh start; step 2 can be skipped', (tester) async {
    await pump(tester);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Import a backup'), findsOneWidget);
    expect(find.text('Start fresh'), findsOneWidget);

    await tester.tap(find.text('Start fresh'));
    await settle(tester);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(AppSettings.onboardingStep, 1, reason: 'saved, so a restart resumes here');

    await tester.tap(find.text('Skip for now'));
    await settle(tester);
    expect(done, 1);
    expect(AppSettings.onboardingStep, AppSettings.onboardingDone);
    expect(await tester.runAsync(() => AppLock.instance.enabled), isFalse);
  });

  testWidgets('the welcome step can switch the language', (tester) async {
    AppSettings.locale.value = null;
    await tester.pumpWidget(ValueListenableBuilder<Locale?>(
      valueListenable: AppSettings.locale,
      builder: (_, locale, _) => localizedApp(OnboardingScreen(onDone: () {}), locale: locale ?? const Locale('en')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(AppSettings.locale.value, const Locale('ar'));
    expect(find.text('استيراد نسخة احتياطية'), findsOneWidget);
    AppSettings.locale.value = null;
  });

  testWidgets('a failed import stays on step 1; a successful one moves on', (tester) async {
    var succeed = false;
    await pump(tester, importer: (_) async => succeed);

    await tester.tap(find.text('Import a backup'));
    await settle(tester);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    succeed = true;
    await tester.tap(find.text('Import a backup'));
    await settle(tester);
    expect(find.text('Step 2 of 2'), findsOneWidget);
  });

  testWidgets('resumes at the security step after a restart', (tester) async {
    AppSettings.onboardingStep = 1;
    await pump(tester);
    expect(find.text('Protect your data'), findsOneWidget);
  });

  testWidgets('setting a PIN turns the lock on and finishes', (tester) async {
    AppSettings.onboardingStep = 1;
    await pump(tester);

    await tester.tap(find.text('Set a PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a PIN (4–6 digits)'), findsOneWidget);
    for (final d in '1357'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump(); // a frame between taps, as a person would give
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the PIN again'), findsOneWidget);
    for (final d in '1357'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump(); // a frame between taps, as a person would give
    }
    await settle(tester);

    // No biometrics on the test host, so it finishes straight after the PIN.
    expect(done, 1);
    expect(await tester.runAsync(() => AppLock.instance.enabled), isTrue);
    expect(await tester.runAsync(() => AppLock.instance.verify('1357')), isA<PinAccepted>());
  });
}
