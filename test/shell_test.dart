import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/security/app_lock.dart';
import 'package:pocket_sense/shell.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    AppLock.instance = AppLock(store: MemorySecretStore());
    await useSeededTestDb();
  });

  // Every tab stays mounted, so their floating buttons must not share the
  // default hero tag, or pushing any route (e.g. Settings) throws.
  testWidgets('a route can be pushed over the phone tabs', (tester) async {
    // Phone layout, a little wider than pumpScreenWithDb's so Home's stat
    // cards fit the test font.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(const Shell()));
    await settleWithDb(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settleWithDb(tester);
    expect(tester.takeException(), isNull);
  });
}
