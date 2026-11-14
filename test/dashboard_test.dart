import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
    await scrollTo(tester, 'By Merchant');

    for (final m in ['A', 'B', 'C', 'D', 'E']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('F'), findsNothing);
    expect(find.text('Other'), findsOneWidget); // F + G + no merchant
  });

  testWidgets('a long amount shrinks to fit its card instead of wrapping', (tester) async {
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 14842150, type: 'expense', date: DateTime.now(), description: 'x');
      await FinanceRepo().insertLoan(person: 'P', direction: 'lent', amountFils: 14842150, date: DateTime.now(), description: 'x');
    });
    await pumpDashboard(tester);
    expect(tester.takeException(), isNull);
    // One line, as tall as this month's JOD 0.000 next to it: not wrapped.
    double height(String text) => tester.getSize(find.text(text).first).height;
    expect(height('JOD\u00A014,842.150'), height('JOD\u00A00.000'));
  });

  testWidgets('the trend charts draw with data, and the week starts on Saturday in Arabic', (tester) async {
    final today = DateTime.now();
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 5000, type: 'expense', date: today, description: 'x');
      await FinanceRepo().insertTransaction(amountFils: 90000, type: 'income', date: today, description: 'y');
    });
    await pumpDashboard(tester);
    // Home builds its cards lazily, so check each chart once it's in view.
    for (final (title, chart) in [
      ('Income vs Spending (6 months)', BarChart),
      ('Monthly Income vs Spending', PieChart),
      ('This Month vs Last Month', LineChart),
      ('By Weekday (12-week daily average)', BarChart),
    ]) {
      await scrollTo(tester, title);
      final card = find.ancestor(of: find.text(title), matching: find.byType(Card));
      expect(find.descendant(of: card, matching: find.byType(chart)), findsOneWidget, reason: title);
    }
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

  // What the month picker shows (month names are on the chart's axis too).
  Finder inPicker(String text, {String chart = 'totals'}) => find.descendant(of: find.byKey(Key('monthPicker-$chart')), matching: find.text(text));
  void expectPicked(DateTime m) {
    expect(inPicker(DateFormat.y().format(m)), findsOneWidget);
    expect(inPicker(DateFormat.MMM().format(m)), findsOneWidget);
  }

  testWidgets('By Merchant shows the month picked on its own picker, and By Category keeps its own', (tester) async {
    final now = DateTime.now();
    final old = DateTime(now.year, now.month - 8, 15);
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 4000, type: 'expense', date: old, description: 'x', merchant: 'Old Shop');
      await FinanceRepo().insertTransaction(amountFils: 2000, type: 'expense', date: now, description: 'y', merchant: 'New Shop');
    });
    await pumpDashboard(tester);
    await scrollTo(tester, 'By Merchant');
    expect(find.text('New Shop'), findsOneWidget, reason: 'the current month by default');
    expect(find.text('Old Shop'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('monthPicker-merchant')));
    await tester.pumpAndSettle();
    await tester.tap(inPicker(DateFormat.MMM().format(now), chart: 'merchant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DateFormat.yMMM().format(old)));
    await settleWithDb(tester);

    expect(find.text('Old Shop'), findsOneWidget);
    expect(find.text('New Shop'), findsNothing);
    // Just above By Merchant: still built, so bring it back into view.
    await tester.ensureVisible(find.byKey(const Key('monthPicker-category'), skipOffstage: false));
    await tester.pumpAndSettle();
    expect(inPicker(DateFormat.y().format(now), chart: 'category'), findsOneWidget, reason: 'By Category still on the current month');
    expect(inPicker(DateFormat.MMM().format(now), chart: 'category'), findsOneWidget);
  });

  testWidgets('Monthly Income vs Spending shows a month picked from the list', (tester) async {
    final now = DateTime.now();
    final old = DateTime(now.year, now.month - 8, 15);
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 7000, type: 'income', date: old, description: 'x');
      await FinanceRepo().insertTransaction(amountFils: 9500, type: 'expense', date: old, description: 'y');
    });
    await pumpDashboard(tester);
    await scrollTo(tester, 'Monthly Income vs Spending');
    expect(find.textContaining('Income: '), findsNothing, reason: 'nothing this month yet');

    await tester.tap(inPicker(DateFormat.MMM().format(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DateFormat.yMMM().format(old)));
    await settleWithDb(tester);

    expectPicked(old);
    // Slice labels are painted, not widgets: read them off the chart.
    expect(tester.widget<PieChart>(find.byType(PieChart).last).data.sections.map((x) => x.title), ['JOD\n7.000', 'JOD\n9.500']);
    expect(find.text('Expense: JOD\u00A09.500'), findsOneWidget, reason: 'and in the legend');
  });

  testWidgets('the arrows step Monthly Income vs Spending by month and by year, within the months there are', (tester) async {
    final now = DateTime.now();
    DateTime back(int months) => DateTime(now.year, now.month - months);
    // By Category and By Merchant have pickers with the same tooltips.
    Finder inTotals(String tooltip) => find.descendant(of: find.byKey(const Key('monthPicker-totals')), matching: find.byTooltip(tooltip));
    IconButton arrow(String tooltip) => tester.widget<IconButton>(find.ancestor(of: inTotals(tooltip), matching: find.byType(IconButton)));
    Future<void> tap(String tooltip) async {
      await tester.tap(inTotals(tooltip));
      await settleWithDb(tester);
    }

    // Entries this month last year, and two months ago.
    await tester.runAsync(() async {
      await FinanceRepo().insertTransaction(amountFils: 7000, type: 'income', date: DateTime(now.year - 1, now.month, 3), description: 'x');
      await FinanceRepo().insertTransaction(amountFils: 900, type: 'expense', date: DateTime(now.year, now.month - 2, 3), description: 'y');
    });
    await pumpDashboard(tester);
    await scrollTo(tester, 'Monthly Income vs Spending');
    // The title in view isn't enough: the arrows sit above and below it.
    await tester.ensureVisible(find.byKey(const Key('monthPicker-totals')));
    await tester.pumpAndSettle();

    expectPicked(back(0));
    expect(arrow('Next month').onPressed, isNull, reason: 'nothing after the current month');
    expect(arrow('Next year').onPressed, isNull);
    await tap('Previous month');
    expectPicked(back(1));
    await tap('Next month');
    expectPicked(back(0));

    await tap('Previous year');
    expectPicked(back(12));
    expect(arrow('Previous month').onPressed, isNull, reason: 'nothing before the oldest month with entries');
    expect(arrow('Previous year').onPressed, isNull);
    await tap('Next year');
    expectPicked(back(0));
  });
}
