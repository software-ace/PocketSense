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

  test('a saved layout reads back: unknown names dropped, Loans never hidden, a new section placed where it belongs', () {
    final layout = AppSettings.homeLayoutFrom(['recent', 'gone', 'daily', 'recent', 'loans'], ['daily', 'loans', 'gone']);
    final order = layout.order;
    expect(order.toSet(), HomeSection.values.toSet(), reason: 'every section once');
    expect(order.indexOf(HomeSection.recent) < order.indexOf(HomeSection.daily), isTrue, reason: 'the saved order is kept');
    expect(order.indexOf(HomeSection.daily) < order.indexOf(HomeSection.loans), isTrue);
    expect(layout.hidden, {HomeSection.daily});
    expect(AppSettings.homeLayoutFrom(null, null).order, HomeSection.values, reason: 'nothing saved: the default order');
  });

  test('Accounts, added after a layout was saved, goes right under Totals, not at the bottom', () {
    final saved = [for (final s in HomeSection.values) if (s != HomeSection.accounts) s.name].reversed.toList();
    final order = AppSettings.homeLayoutFrom(saved, null).order;
    expect(order[order.indexOf(HomeSection.totals) + 1], HomeSection.accounts);
    expect(order.first, HomeSection.recent, reason: 'the rest keeps its saved order');
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

  group('desktop, where Loans and Accounts are rail tabs', () {
    void desktop(WidgetTester tester) {
      tester.view.physicalSize = const Size(2800, 1800); // 1400 × 900
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Home leaves their cards out', (tester) async {
      desktop(tester);
      // First, so they'd be on screen if shown.
      AppSettings.homeLayout.value = (
        order: [...desktopTabSections, ...HomeSection.values.where((s) => !desktopTabSections.contains(s))],
        hidden: const {},
      );
      await tester.pumpWidget(localizedApp(const DashboardScreen()));
      await settleWithDb(tester);
      expect(find.text('Owed to you'), findsNothing);
      expect(find.text('Accounts'), findsNothing);
      expect(find.text('Income (mo)'), findsOneWidget, reason: 'the rest of Home is there');
    });

    testWidgets('Settings → Home page leaves them out, and a reorder keeps their places', (tester) async {
      desktop(tester);
      await tester.pumpWidget(localizedApp(const HomeLayoutScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Loans'), findsNothing);
      expect(find.text('Accounts'), findsNothing);

      // Totals' handle dragged below Daily Spending, the next listed row.
      final handle = find.descendant(
          of: find.ancestor(of: find.text('Totals (this month and year)'), matching: find.byType(SwitchListTile)),
          matching: find.byIcon(Icons.drag_handle));
      final rowHeight = tester.getSize(find.byType(SwitchListTile).first).height;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(Offset(0, rowHeight * 0.25));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(AppSettings.homeLayout.value.order.take(4),
          [HomeSection.daily, HomeSection.accounts, HomeSection.loans, HomeSection.totals]);
    });
  });
}
