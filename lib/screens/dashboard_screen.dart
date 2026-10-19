import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/data_aware.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with DataAware {
  final _repo = FinanceRepo();
  bool _loading = true;
  Object? _error;

  ({int income, int expense})? _month;
  ({int income, int expense})? _year;
  List<Transaction> _recent = [];
  List<({String? label, int fils, String? color})> _byCategory = [];
  List<({String? label, int fils})> _byMerchant = [];
  List<({DateTime month, int income, int expense})> _monthly = [];
  ({List<int> thisMonth, List<int> lastMonth}) _pace = (thisMonth: const [], lastMonth: const []);
  List<int> _weekday = const [];
  List<({DateTime day, int fils})> _daily = [];

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final yearStart = DateTime(now.year, 1, 1);
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        _repo.totals(monthStart, now),
        _repo.totals(yearStart, now),
        _repo.transactions(limit: 8),
        _repo.spendingByCategory(thirtyDaysAgo, now),
        _repo.dailySpending(end: now, days: 30),
        _repo.spendingByMerchant(thirtyDaysAgo, now),
        _repo.monthlyTotals(now),
        _repo.monthPace(now),
        _repo.weekdayAverages(now),
      ]);

      if (!mounted) return;
      setState(() {
        _month = results[0] as ({int income, int expense});
        _year = results[1] as ({int income, int expense});
        _recent = results[2] as List<Transaction>;
        _byCategory = results[3] as List<({String? label, int fils, String? color})>;
        _daily = results[4] as List<({DateTime day, int fils})>;
        _byMerchant = results[5] as List<({String? label, int fils})>;
        _monthly = results[6] as List<({DateTime month, int income, int expense})>;
        _pace = results[7] as ({List<int> thisMonth, List<int> lastMonth});
        _weekday = results[8] as List<int>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(desktop ? l.navOverview : l.navHome), centerTitle: false, actions: const [SyncButton(), SettingsButton()]),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: CustomScrollView(
          slivers: [
            if (_loading)
            const SliverFillRemaining(child: LoadingView())
          else if (_error != null)
            SliverFillRemaining(
              child: ErrorView(message: _error.toString(), onRetry: _load),
            )
          else ...[
            // Stat cards row
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: PlatformUi.hPadding(context)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = desktop ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: desktop ? 2.4 : 1.8,
                      children: [
                        _statCard(theme, l.statIncomeMonth, formatMoney(_month?.income ?? 0), Icons.arrow_upward, Colors.green),
                        _statCard(theme, l.statSpentMonth, formatMoney(_month?.expense ?? 0), Icons.arrow_downward, Colors.redAccent),
                        _statCard(theme, l.statNetMonth, formatMoney((_month?.income ?? 0) - (_month?.expense ?? 0)), Icons.balance, Colors.blue),
                        _statCard(theme, l.statYearTotal, formatMoney(_year?.expense ?? 0), Icons.calendar_month, theme.colorScheme.primary),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Charts section
            _padded(_chartCard(theme, l.chartDaily, _buildLineChart())),
            _gap,
            ..._pair(desktop, _chartCard(theme, l.chartByCategory, _buildPieChart(_categorySlices())),
                _chartCard(theme, l.chartByMerchant, _buildPieChart(_merchantSlices()))),
            _gap,
            _padded(_chartCard(theme, l.chartMonthly, _buildMonthlyChart())),
            _gap,
            ..._pair(desktop, _chartCard(theme, l.chartPace, _buildPaceChart()), _chartCard(theme, l.chartWeekday, _buildWeekdayChart())),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Recent activity
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(PlatformUi.hPadding(context), 0, PlatformUi.hPadding(context), 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.recentActivity, style: theme.textTheme.titleMedium),
                ),
              ),
            ),
            if (_recent.isEmpty)
              SliverToBoxAdapter(child: EmptyView(icon: Icons.receipt_long, title: l.noTransactionsYet))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _activityTile(theme, _recent[i]),
                  childCount: _recent.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) =>
      SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: PlatformUi.hPadding(context)), child: child));

  static const _gap = SliverToBoxAdapter(child: SizedBox(height: 12));

  // Two cards: side by side on desktop, one under the other on a phone.
  List<Widget> _pair(bool desktop, Widget a, Widget b) => desktop
      ? [_padded(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]))]
      : [_padded(a), _gap, _padded(b)];

  Widget _statCard(ThemeData theme, String label, String value, IconData icon, Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
              ],
            ),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(ThemeData theme, String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (_daily.isEmpty) return Center(child: Text(context.l10n.noData));
    final spots = List.generate(_daily.length, (i) => FlSpot(i.toDouble(), _daily[i].fils / 1000));
    final maxFils = _daily.fold<int>(0, (a, b) => b.fils > a ? b.fils : a);
    // ~4 gridlines on a 1/2/5 step, with the top snapped to a step multiple.
    // (A fixed interval of 1 drew one label per dinar — hundreds, overlapping.)
    final step = _niceStep(maxFils > 0 ? maxFils / 1000 / 4 : 2.5);
    final maxY = ((maxFils / 1000) * 1.1 / step).ceil().clamp(1, 1 << 30) * step;
    final lastIdx = (_daily.length - 1).toDouble();

    // Axes stay left-to-right in Arabic too: days and amounts read that way.
    return Directionality(textDirection: TextDirection.ltr, child: LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(enabled: true),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (v) => FlLine(color: const Color(0x1F000000), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: step, reservedSize: 44,
              getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(compactAmount(v), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: 7, reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _daily.length) return const SizedBox.shrink();
                // fl_chart always adds a label at the axis end; it collides with
                // the last weekly tick one day earlier.
                if (v == lastIdx && idx % 7 != 0) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(DateFormat.MMMd().format(_daily[idx].day)));
              }),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            // Without this the spline dips below $0 next to a spike.
            preventCurveOverShooting: true,
            color: const Color(0xFF4F46E5),
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [const Color(0x334F46E5), const Color(0x054F46E5)],
            )),
          ),
        ],
      ),
    ));
  }

  static const _indigo = Color(0xFF4F46E5);

  // Shared by the trend charts: amounts on the left, [label] under each x.
  FlTitlesData _axes(double step, String Function(int x) label, {double interval = 1}) => FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, interval: step, reservedSize: 44,
              getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(compactAmount(v), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 24,
              getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4), child: Text(label(v.toInt()), style: const TextStyle(fontSize: 10)))),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  FlGridData _grid(double step) => FlGridData(
        drawVerticalLine: false,
        horizontalInterval: step,
        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0x1F000000), strokeWidth: 1),
      );

  double _maxY(int maxFils, double step) => ((maxFils / 1000) * 1.1 / step).ceil().clamp(1, 1 << 30) * step;

  Widget _legend(List<(String, Color)> items) => Wrap(spacing: 16, children: [
        for (final (label, color) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
      ]);

  BarTouchData _barTooltips() => BarTouchData(
      touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(formatMoney((rod.toY * 1000).round()),
              TextStyle(color: rod.color, fontWeight: FontWeight.w600, fontSize: 12))));

  // Income and spending side by side, one pair of bars per month.
  Widget _buildMonthlyChart() {
    final l = context.l10n;
    final maxFils = _monthly.fold<int>(0, (a, m) => math.max(a, math.max(m.income, m.expense)));
    if (maxFils == 0) return Center(child: Text(l.noData));
    final step = _niceStep(maxFils / 1000 / 4);
    BarChartRodData rod(int fils, Color color) =>
        BarChartRodData(toY: fils / 1000, color: color, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)));

    return Column(children: [
      // Months read left to right in Arabic too, as on the daily chart.
      Expanded(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: BarChart(BarChartData(
            maxY: _maxY(maxFils, step),
            barGroups: [
              for (final (i, m) in _monthly.indexed)
                BarChartGroupData(x: i, barsSpace: 4, barRods: [rod(m.income, Colors.green), rod(m.expense, Colors.redAccent)]),
            ],
            gridData: _grid(step),
            borderData: FlBorderData(show: false),
            titlesData: _axes(step, (i) => DateFormat.MMM().format(_monthly[i].month)),
            barTouchData: _barTooltips(),
          )),
        ),
      ),
      const SizedBox(height: 8),
      _legend([(l.income, Colors.green), (l.expense, Colors.redAccent)]),
    ]);
  }

  // Spent so far by each day of the month: this month against last month.
  Widget _buildPaceChart() {
    final l = context.l10n;
    final maxFils = math.max(_pace.thisMonth.lastOrNull ?? 0, _pace.lastMonth.lastOrNull ?? 0);
    if (maxFils == 0) return Center(child: Text(l.noData));
    final step = _niceStep(maxFils / 1000 / 4);
    final lastX = math.max(_pace.thisMonth.length, _pace.lastMonth.length) - 1;
    const lastMonthColor = Color(0xFF9CA3AF);
    LineChartBarData line(List<int> fils, Color color, {List<int>? dash}) => LineChartBarData(
          spots: [for (final (i, f) in fils.indexed) FlSpot(i.toDouble(), f / 1000)],
          color: color,
          barWidth: 3,
          dashArray: dash,
          dotData: FlDotData(show: false),
        );

    return Column(children: [
      Expanded(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LineChart(LineChartData(
            minX: 0,
            maxX: lastX.toDouble(),
            minY: 0,
            maxY: _maxY(maxFils, step),
            lineBarsData: [line(_pace.lastMonth, lastMonthColor, dash: [6, 4]), line(_pace.thisMonth, _indigo)],
            gridData: _grid(step),
            borderData: FlBorderData(show: false),
            // Days 1, 8, 15…; fl_chart also labels the axis end, which would
            // crowd the last of those.
            titlesData: _axes(step, (i) => i % 7 == 0 && lastX - i >= 3 ? '${i + 1}' : '', interval: 7),
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(formatMoney((s.y * 1000).round()),
                                TextStyle(color: s.bar.color, fontWeight: FontWeight.w600, fontSize: 12)),
                        ])),
          )),
        ),
      ),
      const SizedBox(height: 8),
      _legend([(l.thisMonth, _indigo), (l.lastMonth, lastMonthColor)]),
    ]);
  }

  // Average spent on each weekday, in the locale's week order (Saturday
  // first in Arabic).
  Widget _buildWeekdayChart() {
    final maxFils = _weekday.fold<int>(0, math.max);
    if (maxFils == 0) return Center(child: Text(context.l10n.noData));
    final step = _niceStep(maxFils / 1000 / 4);
    // firstDayOfWeekIndex counts from Sunday; _weekday starts on Monday.
    final first = (MaterialLocalizations.of(context).firstDayOfWeekIndex + 6) % 7;
    final order = [for (var k = 0; k < 7; k++) (first + k) % 7];

    // 2026-10-19 was a Monday.
    final days = [for (final d in order) DateTime(2026, 10, 19 + d)];

    return LayoutBuilder(builder: (context, box) {
      // Full names ("الأربعاء") can be wider than a bar's slot on a phone;
      // then the one-letter forms.
      String Function(DateTime) name = DateFormat.E().format;
      final slot = (box.maxWidth - 44) / 7 - 4;
      if (days.any((d) => _textWidth(name(d), 10) > slot)) name = DateFormat('EEEEE').format;

      return Directionality(
        textDirection: TextDirection.ltr,
        child: BarChart(BarChartData(
          maxY: _maxY(maxFils, step),
          barGroups: [
            for (final (k, d) in order.indexed)
              BarChartGroupData(x: k, barRods: [
                BarChartRodData(toY: _weekday[d] / 1000, color: _indigo, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
              ]),
          ],
          gridData: _grid(step),
          borderData: FlBorderData(show: false),
          titlesData: _axes(step, (k) => name(days[k])),
          barTouchData: _barTooltips(),
        )),
      );
    });
  }

  double _textWidth(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.copyWith(fontSize: fontSize)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  static double _niceStep(double raw) {
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10;
    return nice * mag;
  }

  List<({String label, int fils, Color color})> _categorySlices() => [
        for (final c in _byCategory) (label: c.label ?? context.l10n.uncategorized, fils: c.fils, color: _hex(c.color)),
      ];

  static const _merchantColors = [Color(0xFF4F46E5), Color(0xFF0EA5E9), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEC4899)];

  // The top 5, and everyone else as one slice: a pie can't show dozens.
  List<({String label, int fils, Color color})> _merchantSlices() {
    final l = context.l10n;
    final rest = _byMerchant.skip(5).fold<int>(0, (a, m) => a + m.fils);
    return [
      for (final (i, m) in _byMerchant.take(5).indexed)
        (label: m.label ?? l.noMerchant, fils: m.fils, color: m.label == null ? const Color(0xFF9CA3AF) : _merchantColors[i]),
      if (rest > 0) (label: l.otherMerchants, fils: rest, color: const Color(0xFF6B7280)),
    ];
  }

  Widget _buildPieChart(List<({String label, int fils, Color color})> slices) {
    final totalFils = slices.fold<int>(0, (a, b) => a + b.fils);
    if (totalFils == 0) return Center(child: Text(context.l10n.noExpensesYet));

    final sections = slices.map((item) {
      final pct = item.fils / totalFils;
      return PieChartSectionData(
        value: pct,
        color: item.color,
        radius: 55,
        showTitle: pct > 0.08,
        title: '${(pct * 100).toInt()}%',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: slices.take(6).length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final c = slices[i];
              return Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text(formatMoney(c.fils), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Color _hex(String? css) {
    if (css != null && css.startsWith('#') && css.length >= 7) {
      return Color(int.parse(css.substring(1, 7), radix: 16) | 0xFF000000);
    }
    return const Color(0xFF9CA3AF);
  }

  // `date` carries no time of day (formatting it always showed 00:00). Show the
  // entry time only when it was recorded on that same day; a back-dated entry's
  // creation time would be misleading.
  String _when(Transaction t) {
    final day = DateFormat.yMMMEd().format(t.date);
    final c = t.createdAt;
    final sameDay = c != null && c.year == t.date.year && c.month == t.date.month && c.day == t.date.day;
    return sameDay ? '$day · ${DateFormat.Hm().format(c)}' : day;
  }

  Widget _activityTile(ThemeData theme, Transaction t) {
    final color = _hex(t.categoryColor);
    return ListTile(
      leading: CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.15), child: Text(t.categoryName?.isNotEmpty == true ? t.categoryName![0].toUpperCase() : '•', style: TextStyle(color: color, fontSize: 14))),
      title: Text(t.description.isNotEmpty ? t.description : (t.merchant ?? context.l10n.transactionFallback), style: const TextStyle(fontSize: 14)),
      subtitle: Text(_when(t), style: const TextStyle(fontSize: 12)),
      trailing: Text(formatMoney(t.amountFils, showSign: t.type == 'income'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: t.type == 'income' ? Colors.green : null)),
    );
  }
}
