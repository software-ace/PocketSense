import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/widgets/whats_new.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';

void main() {
  test('changelog lines go under their tag, in English and Arabic; untagged ones stay', () {
    expect(parseChangelog('• New: currencies\n• Fixed: a crash\n\n• improved: speed\n• Charts on Home'), {
      ChangeKind.feature: ['Currencies'],
      ChangeKind.fix: ['A crash'],
      ChangeKind.improvement: ['Speed'],
      ChangeKind.other: ['Charts on Home'],
    });
    expect(parseChangelog('• جديد: العملات\n• تغيير: الترتيب\n• إصلاح: عطل'), {
      ChangeKind.feature: ['العملات'],
      ChangeKind.change: ['الترتيب'],
      ChangeKind.fix: ['عطل'],
    });
    expect(parseChangelog('• New charts on Home: by merchant'), {ChangeKind.other: ['New charts on Home: by merchant']},
        reason: '"New" is only a tag when the colon follows it');
  });

  group('showWhatsNewIfUpdated', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      AppSettings.whatsNewSeen = null;
      // Its cached loads belong to the previous test's fake clock.
      rootBundle.clear();
    });

    Future<void> open(WidgetTester tester, int build) async {
      await tester.pumpWidget(localizedApp(Builder(
        builder: (context) => TextButton(onPressed: () => showWhatsNewIfUpdated(context, build: build), child: const Text('go')),
      )));
      await tester.tap(find.text('go'));
      // Assets load for real.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('after skipping versions: everything since the last one, once', (tester) async {
      AppSettings.whatsNewSeen = 502; // 2.2.7, now on 504 (2.2.9)
      await open(tester, 504);
      expect(find.byType(WhatsNewDialog), findsOneWidget);
      expect(find.textContaining('Four charts on Home'), findsOneWidget, reason: '2.2.9');
      expect(find.text('Fixes'), findsOneWidget, reason: '2.2.8 fixed the keystore');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await open(tester, 504);
      expect(find.byType(WhatsNewDialog), findsNothing);
      expect(AppSettings.whatsNewSeen, 504);
    });

    testWidgets('an install from before "What\'s new": only the current version', (tester) async {
      await open(tester, 504);
      expect(find.textContaining('Four charts on Home'), findsOneWidget);
      expect(find.text('Fixes'), findsNothing);
    });
  });
}
