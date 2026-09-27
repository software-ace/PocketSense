import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/sync_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SyncAware {
  final _repo = FinanceRepo();
  bool _loading = true;
  Object? _error;

  ({int income, int expense})? _month;
  ({int income, int expense})? _year;
  List<Transaction> _recent = [];
  List<({String label, int cents, String? color})> _byCategory = [];
  List<({DateTime day, int cents})> _daily = [];

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
      ]);

      if (!mounted) return;
      setState(() {
        _month = results[0] as ({int income, int expense});
        _year = results[1] as ({int income, int expense});
        _recent = results[2] as List<Transaction>;
        _byCategory = results[3] as List<({String label, int cents, String? color})>;
        _daily = results[4] as List<({DateTime day, int cents})>;
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

    return Scaffold(
      appBar: AppBar(title: Text(desktop ? 'Overview' : 'Home'), centerTitle: false, actions: const [SyncIndicator()]),
      body: RefreshIndicator(
        onRefresh: () => syncAndReload(_load),
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
                        _statCard(theme, 'Income (mo)', formatMoney(_month?.income ?? 0), Icons.arrow_upward, Colors.green),
                        _statCard(theme, 'Spent (mo)', formatMoney(_month?.expense ?? 0), Icons.arrow_downward, Colors.redAccent),
                        _statCard(theme, 'Net (mo)', formatMoney((_month?.income ?? 0) - (_month?.expense ?? 0)), Icons.balance, Colors.blue),
                        _statCard(theme, 'Year total', formatMoney(_year?.expense ?? 0), Icons.calendar_month, theme.colorScheme.primary),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Charts section
            if (desktop)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: PlatformUi.hPadding(context)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _chartCard(theme, 'Daily Spending (30d)', _buildLineChart())),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _chartCard(theme, 'By Category (30d)', _buildPieChart())),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: PlatformUi.hPadding(context)),
                  child: _chartCard(theme, 'Daily Spending (30d)', _buildLineChart()),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: PlatformUi.hPadding(context)),
                  child: _chartCard(theme, 'By Category (30d)', _buildPieChart()),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Recent activity
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(PlatformUi.hPadding(context), 0, PlatformUi.hPadding(context), 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recent Activity', style: theme.textTheme.titleMedium),
                ),
              ),
            ),
            if (_recent.isEmpty)
              const SliverToBoxAdapter(child: EmptyView(icon: Icons.receipt_long, title: 'No transactions yet'))
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
    if (_daily.isEmpty) return const Center(child: Text('No data'));
    final spots = List.generate(_daily.length, (i) => FlSpot(i.toDouble(), _daily[i].cents / 100));
    final maxCents = _daily.fold<int>(0, (a, b) => b.cents > a ? b.cents : a);
    // ~4 gridlines on a 1/2/5 step, with the top snapped to a step multiple.
    // (A fixed interval of 1 drew one label per dollar — hundreds, overlapping.)
    final step = _niceStep(maxCents > 0 ? maxCents / 100 / 4 : 2.5);
    final maxY = ((maxCents / 100) * 1.1 / step).ceil().clamp(1, 1 << 30) * step;
    final lastIdx = (_daily.length - 1).toDouble();

    return LineChart(
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
                  child: Text(_compactMoney(v), style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
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
    );
  }

  static double _niceStep(double raw) {
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10;
    return nice * mag;
  }

  static String _compactMoney(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '\$${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
    }
    return '\$${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)}';
  }

  Widget _buildPieChart() {
    if (_byCategory.isEmpty) return const Center(child: Text('No expenses yet'));
    final totalCents = _byCategory.fold<int>(0, (a, b) => a + b.cents);
    if (totalCents == 0) return const Center(child: Text('No expenses yet'));

    final sections = _byCategory.asMap().entries.map((e) {
      final item = e.value;
      final pct = item.cents / totalCents;
      final color = _hex(item.color);
      return PieChartSectionData(
        value: pct,
        color: color,
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
            itemCount: _byCategory.take(5).length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final c = _byCategory[i];
              return Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _hex(c.color), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Expanded(child: Text(c.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  Text(formatMoney(c.cents), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
      title: Text(t.description.isNotEmpty ? t.description : (t.merchant ?? 'Transaction'), style: const TextStyle(fontSize: 14)),
      subtitle: Text(_when(t), style: const TextStyle(fontSize: 12)),
      trailing: Text(formatMoney(t.amountCents, showSign: t.type == 'income'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: t.type == 'income' ? Colors.green : null)),
    );
  }
}
