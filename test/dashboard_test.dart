import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/dashboard_screen.dart';

import 'helpers/localized_app.dart';
import 'helpers/screen_with_db.dart';

void main() {
  setUp(useSeededTestDb);

  Future<void> pumpDashboard(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    // A 540-wide phone: at the helper's 400, the stat cards overflow by a few
    // pixels in the test font, which is taller than real ones.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(const DashboardScreen(), locale: locale));
    await settleWithDb(tester);
  }

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('By Merchant shows the top 5, the rest as Other, and spending without a merchant', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(() async {
      for (final (i, m) in ['A', 'B', 'C', 'D', 'E', 'F', 'G', null].indexed) {
        await FinanceRepo().insertTransaction(amountFils: (10 - i) * 1000, type: 'expense', date: today, description: 'x', merchant: m);
      }
    });
    await pumpDashboard(tester);
    await scrollTo(tester, 'By Merchant (30d)');

    for (final m in ['A', 'B', 'C', 'D', 'E']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('F'), findsNothing);
    expect(find.text('Other'), findsOneWidget); // F + G + no merchant
  });

  testWidgets('the trend charts draw with data, and the week starts on Saturday in Arabic', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 5000, type: 'expense', date: today, description: 'x');
      await FinanceRepo().insertTransaction(amountFils: 90000, type: 'income', date: today, description: 'y');
    });
    await pumpDashboard(tester);
    for (final title in ['Income vs Spending (6 months)', 'This Month vs Last Month', 'By Weekday (12-week daily average)']) {
      await scrollTo(tester, title);
    }
    expect(find.byType(BarChart), findsNWidgets(2));
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Last month'), findsOneWidget);
    expect(find.text('No data'), findsNothing);

    await pumpDashboard(tester, locale: const Locale('ar'));
    await scrollTo(tester, 'حسب أيام الأسبوع (المتوسط اليومي لـ 12 أسبوعًا)');
    // Full Arabic names don't fit a phone's bar slots: the one-letter forms,
    // Saturday first.
    final labels = tester.widgetList<Text>(find.descendant(of: find.byType(BarChart).last, matching: find.byType(Text))).map((t) => t.data);
    expect(labels.where((d) => d != null && double.tryParse(d) == null).toList(), ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']);
  });
}
