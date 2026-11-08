import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/dashboard_screen.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/settings/home_layout_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    await useSeededTestDb();
    addTearDown(() => AppSettings.homeLayout.value = (order: HomeSection.values, hidden: const {}));
  });

  test('a saved layout reads back: unknown names dropped, new sections shown at the end, Loans never hidden', () {
    final layout = AppSettings.homeLayoutFrom(['recent', 'gone', 'daily', 'recent', 'loans'], ['daily', 'loans', 'gone']);
    expect(layout.order.take(3), [HomeSection.recent, HomeSection.daily, HomeSection.loans]);
    expect(layout.order.toSet(), HomeSection.values.toSet(), reason: 'every section once');
    expect(layout.hidden, {HomeSection.daily});
    expect(AppSettings.homeLayoutFrom(null, null).order, HomeSection.values, reason: 'nothing saved: the default order');
  });

  testWidgets('Home follows the layout: hidden parts are gone, the rest in its order', (tester) async {
    AppSettings.homeLayout.value = (
      order: [HomeSection.recent, ...HomeSection.values.where((s) => s != HomeSection.recent)],
      hidden: {HomeSection.totals, HomeSection.daily},
    );
    await pumpScreenWithDb(tester, const DashboardScreen());

    expect(find.text('Income (mo)'), findsNothing);
    expect(find.text('Daily Spending (30d)'), findsNothing);
    final recent = tester.getTopLeft(find.text('Recent Activity')).dy;
    expect(recent, lessThan(tester.getTopLeft(find.text('Loans')).dy), reason: 'Recent Activity moved to the top');
  });

  testWidgets('Settings → Home page switches a part off, and Loans stays on', (tester) async {
    await tester.pumpWidget(localizedApp(const HomeLayoutScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('By Merchant'));
    await tester.pumpAndSettle();
    expect(AppSettings.homeLayout.value.hidden, {HomeSection.merchant});

    final loans = tester.widget<SwitchListTile>(find.ancestor(of: find.text('Loans'), matching: find.byType(SwitchListTile)));
    expect(loans.onChanged, isNull);
    expect(find.text("Always shown: it's the way into Loans"), findsOneWidget);
  });
}
