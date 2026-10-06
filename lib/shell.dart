import 'dart:async';

import 'package:flutter/material.dart';

import 'data/auto_backup.dart';
import 'sync/sync_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/recurring_screen.dart';
import 'l10n/l10n.dart';
import 'utils/platform.dart';

/// Root scaffold that adapts navigation to the viewport:
/// - Wide (≥ 900 px): left [NavigationRail] with labelled icons.
/// - Narrow (< 900 px): bottom bar with 4 primary tabs.
/// Categories moved to Settings (gear icon in each tab's app bar).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<({String peer, int changes})> _arrivals;

  // Daily backup when the app opens or comes back (it may stay alive for
  // days), and sync with paired devices then too.
  @override
  void initState() {
    super.initState();
    AutoBackup.runIfDue();
    SyncService.instance.start().ignore();
    _lifecycle = AppLifecycleListener(onResume: () {
      AutoBackup.runIfDue();
      SyncService.instance.resumed().ignore();
    });
    _arrivals = SyncService.instance.arrivals.stream.listen((a) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.syncArrived(a.changes, a.peer))));
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _arrivals.cancel();
    SyncService.instance.stop();
    super.dispose();
  }

  static const _pages = <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    BudgetsScreen(),
    RecurringScreen(),
  ];

  // Single source of truth for all tabs (bottom bar + navigation rail).
  List<_Dest> _dests(BuildContext context) {
    final l = context.l10n;
    return [
      _Dest(Icons.space_dashboard_rounded, l.navHome),
      _Dest(Icons.swap_vert_rounded, l.navActivity),
      _Dest(Icons.price_change_rounded, l.navBudgets),
      _Dest(Icons.repeat_rounded, l.navRecurring),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUi.isDesktop(context)) {
      return _buildDesktop(context);
    }
    return _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    context.l10n.appTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ),
            ),
            destinations: _dests(context)
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.icon,
                          color: Theme.of(context).colorScheme.primary),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.outline,
        items: _dests(context)
            .map((d) => BottomNavigationBarItem(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final String label;
  const _Dest(this.icon, this.label);
}
