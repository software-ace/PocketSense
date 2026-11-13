import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/platform.dart';
import 'app_settings.dart';

/// Settings → Home page: drag to reorder what Home shows, and switch parts
/// off. Saved as it changes.
class HomeLayoutScreen extends StatelessWidget {
  const HomeLayoutScreen({super.key});

  static String name(AppLocalizations l, HomeSection s) => switch (s) {
        HomeSection.totals => l.homeTotals,
        HomeSection.loans => l.loans,
        HomeSection.circles => l.circles,
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
        builder: (context, layout, _) {
          // On desktop the rail's tabs aren't on Home, so they aren't listed.
          final desktop = PlatformUi.isDesktop(context);
          final rows = [for (final s in layout.order) if (!desktop || !desktopTabSections.contains(s)) s];
          return ReorderableListView.builder(
            // The handle drags on every platform; the default (long-press on
            // phones, a handle at the end on desktop) would sit on the switch.
            buildDefaultDragHandles: false,
            header: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(l.homePageHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            ),
            itemCount: rows.length,
            // [to] is already the final index, counted without the moved row.
            onReorderItem: (from, to) {
              final moved = [...rows];
              moved.insert(to, moved.removeAt(from));
              // Unlisted sections keep their places; the listed ones fill the rest in the new order.
              final next = moved.iterator;
              final order = [for (final s in layout.order) if (rows.contains(s)) (next..moveNext()).current else s];
              AppSettings.setHomeLayout(order, layout.hidden);
            },
            itemBuilder: (context, i) {
              final s = rows[i];
              final fixed = alwaysShownSections.contains(s);
              return SwitchListTile(
                key: ValueKey(s),
                secondary: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                title: Text(name(l, s)),
                subtitle: fixed ? Text(s == HomeSection.loans ? l.homeLoansAlwaysShown : l.homeCirclesAlwaysShown) : null,
                value: !layout.hidden.contains(s),
                onChanged: fixed
                    ? null
                    : (on) => AppSettings.setHomeLayout(layout.order, on ? ({...layout.hidden}..remove(s)) : {...layout.hidden, s}),
              );
            },
          );
        },
      ),
    );
  }
}
