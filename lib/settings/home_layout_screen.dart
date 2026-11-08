import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_settings.dart';

/// Settings → Home page: drag to reorder what Home shows, and switch parts
/// off. Saved as it changes.
class HomeLayoutScreen extends StatelessWidget {
  const HomeLayoutScreen({super.key});

  static String name(AppLocalizations l, HomeSection s) => switch (s) {
        HomeSection.totals => l.homeTotals,
        HomeSection.loans => l.loans,
        HomeSection.accounts => l.accounts,
        HomeSection.daily => l.chartDaily,
        HomeSection.category => l.chartByCategory,
        HomeSection.merchant => l.chartByMerchant,
        HomeSection.monthTotals => l.chartMonthTotals,
        HomeSection.monthly => l.chartMonthly,
        HomeSection.pace => l.chartPace,
        HomeSection.weekday => l.chartWeekday,
        HomeSection.recent => l.recentActivity,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.homePage)),
      body: ValueListenableBuilder(
        valueListenable: AppSettings.homeLayout,
        builder: (context, layout, _) => ReorderableListView.builder(
          // The handle drags on every platform; the default (long-press on
          // phones, a handle at the end on desktop) would sit on the switch.
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
            child: Text(l.homePageHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ),
          itemCount: layout.order.length,
          // [to] is already the final index, counted without the moved row.
          onReorderItem: (from, to) {
            final order = [...layout.order];
            order.insert(to, order.removeAt(from));
            AppSettings.setHomeLayout(order, layout.hidden);
          },
          itemBuilder: (context, i) {
            final s = layout.order[i];
            final loans = s == HomeSection.loans;
            return SwitchListTile(
              key: ValueKey(s),
              secondary: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
              title: Text(name(l, s)),
              subtitle: loans ? Text(l.homeLoansAlwaysShown) : null,
              value: !layout.hidden.contains(s),
              // Loans' card is the only way into Loans.
              onChanged: loans
                  ? null
                  : (on) => AppSettings.setHomeLayout(layout.order, on ? ({...layout.hidden}..remove(s)) : {...layout.hidden, s}),
            );
          },
        ),
      ),
    );
  }
}
