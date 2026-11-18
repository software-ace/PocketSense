import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../security/amount_privacy.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/amount_field.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_delete_background.dart';
import '../widgets/data_aware.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with DataAware {
  final _repo = FinanceRepo();
  List<({Budget budget, int spentFils, DateTime start, DateTime end})> _budgets = [];
  List<Category> _cats = [];
  Object? _error;
  bool _loading = true;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // "This week · Sep 22 – 28" / "This month · September"
  static String _periodLabel(AppLocalizations l, String period, DateTime start, DateTime end) => period == 'weekly'
      ? l.periodThisWeek('${DateFormat.MMMd().format(start)} – ${start.month == end.month ? DateFormat.d().format(end) : DateFormat.MMMd().format(end)}')
      : l.periodThisMonth(DateFormat.MMMM().format(start));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_repo.budgetProgress(), _repo.categories()]);
      if (!mounted) return;
      setState(() {
        _budgets = results[0] as List<({Budget budget, int spentFils, DateTime start, DateTime end})>;
        _cats = results[1] as List<Category>;
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

  Future<void> _edit(Budget? existing) async {
    final r = await showDialog<Object>(
      context: context,
      builder: (_) => _BudgetDialog(existing: existing, cats: _cats),
    );
    if (r == _BudgetDialog.deleteResult && existing != null) await _delete(existing);
  }

  Future<bool> _confirmDelete(Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteBudgetTitle(b.categoryName ?? ctx.l10n.category)),
        content: Text(ctx.l10n.deleteBudgetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    return ok == true;
  }

  /// [confirmed]: a swipe already asked (in confirmDismiss).
  Future<void> _delete(Budget b, {bool confirmed = false}) async {
    if (!confirmed && !await _confirmDelete(b)) return;
    try {
      await _repo.deleteBudget(b.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
      await _load(); // brings back a card a swipe took away
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.navBudgets), actions: const [AmountsButton(), SyncButton(), SettingsButton()]),
      floatingActionButton: desktop ? null : FloatingActionButton.extended(heroTag: null, onPressed: () => _edit(null), icon: const Icon(Icons.add), label: Text(l.newItem)),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error.toString(), onRetry: _load)
                : Column(children: [
                    if (desktop)
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                        child: Row(children: [
                          Expanded(child: Text(l.activeBudgets(_budgets.length), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: Text(l.newBudget)),
                        ]),
                      ),
                    Expanded(
                      child: _budgets.isEmpty
                          ? Center(child: EmptyView(icon: Icons.dashboard_customize_outlined, title: l.noBudgets, subtitle: l.noBudgetsHint))
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                              itemCount: _budgets.length,
                              itemBuilder: (_, i) {
                                final p = _budgets[i];
                                final b = p.budget;
                                final color = parseHex(b.categoryColor) ?? theme.colorScheme.primary;
                                final spent = p.spentFils;
                                final ratio = b.limitFils > 0 ? (spent / b.limitFils).clamp(0.0, 1.5) : 0.0;
                                final over = spent > b.limitFils;

                                final card = Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _edit(b),
                                    onSecondaryTapDown: (_) => _delete(b),
                                    child: Padding(
                                      padding: EdgeInsets.all(desktop ? 20 : 14),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          CircleAvatar(radius: desktop ? 16 : 14, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.tag, size: 14, color: color)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(b.categoryName ?? l.category, style: theme.textTheme.titleSmall),
                                              Text(_periodLabel(l, p.budget.period, p.start, p.end), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                                            ]),
                                          ),
                                          Text('${formatMoney(spent)} / ${formatMoney(b.limitFils)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: over ? theme.colorScheme.error : null)),
                                          if (desktop) ...[
                                            const SizedBox(width: 4),
                                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: l.edit, visualDensity: VisualDensity.compact, onPressed: () => _edit(b)),
                                            IconButton(icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error), tooltip: l.delete, visualDensity: VisualDensity.compact, onPressed: () => _delete(b)),
                                          ],
                                        ]),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            minHeight: desktop ? 10 : 8,
                                            value: ratio.clamp(0.0, 1.0),
                                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            color: over ? theme.colorScheme.error : color,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          Text(over ? l.overBudgetBy(formatMoney(spent - b.limitFils)) : l.amountRemaining(formatMoney(b.limitFils - spent)), style: theme.textTheme.bodySmall?.copyWith(color: over ? theme.colorScheme.error : theme.colorScheme.outline)),
                                          // The real share: ratio is capped for the bar only.
                                          Text('${b.limitFils > 0 ? spent * 100 ~/ b.limitFils : 0}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                        ]),
                                      ]),
                                    ),
                                  ),
                                );
                                if (desktop) return card;
                                return Dismissible(
                                  key: ValueKey(b.id),
                                  direction: DismissDirection.endToStart,
                                  background: const SwipeDeleteBackground(margin: EdgeInsets.symmetric(vertical: 6), radius: 12),
                                  // Asked before the card leaves: Cancel keeps it in place.
                                  confirmDismiss: (_) => _confirmDelete(b),
                                  onDismissed: (_) {
                                    setState(() => _budgets.remove(p));
                                    _delete(b, confirmed: true);
                                  },
                                  child: card,
                                );
                              },
                            ),
                    ),
                  ]),
      ),
    );
  }


}

// ── Dialog ────────────────────────────────────────────────────────────────

class _BudgetDialog extends StatefulWidget {
  final Budget? existing;
  final List<Category> cats;
  const _BudgetDialog({this.existing, required this.cats});

  /// Popped by the Delete button; the screen asks to confirm, then deletes.
  static const deleteResult = 'delete';

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late int? _catId = widget.existing?.categoryId;
  late final _amtCtrl = TextEditingController(text: widget.existing != null ? amountToInput(widget.existing!.limitFils) : '');
  late String _period = widget.existing?.period ?? 'monthly';
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final fils = parseAmount(_amtCtrl.text)!;
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      if (widget.existing == null) {
        await repo.insertBudget(categoryId: _catId!, limitFils: fils, period: _period);
      } else {
        await repo.updateBudget(widget.existing!.id, categoryId: _catId!, limitFils: fils, period: _period);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only expense categories make sense for budgets. A parent's counts its
    // subcategories too; a subcategory's, only its own.
    final expenseCats = Category.tree([for (final c in widget.cats) if (c.type == 'expense') c]);
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.newBudget : l.editBudget),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<int>(
            initialValue: _catId,
            decoration: InputDecoration(labelText: l.category),
            validator: (v) => v == null ? l.chooseCategory : null,
            items: [
              for (final c in expenseCats)
                DropdownMenuItem(value: c.id, child: Padding(padding: EdgeInsetsDirectional.only(start: c.parentId == null ? 0 : 16), child: Text(c.name, overflow: TextOverflow.ellipsis))),
            ],
            // The dialog's width, not the longest name's: a long subcategory would overflow it.
            isExpanded: true,
            // Not indented once picked.
            selectedItemBuilder: (_) => [for (final c in expenseCats) Text(c.name, overflow: TextOverflow.ellipsis)],
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 16),
          AmountField(
            controller: _amtCtrl,
            autofocus: widget.existing == null,
            label: _period == 'weekly' ? l.weeklyLimit : l.monthlyLimit,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'monthly', label: Text(l.freqMonthly)),
              ButtonSegment(value: 'weekly', label: Text(l.freqWeekly)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          ]),
        ),
      ),
      actions: [
        // Mobile only: desktop cards already carry a trash icon.
        if (widget.existing != null && !PlatformUi.isDesktop(context))
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, _BudgetDialog.deleteResult),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l.delete),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save),
        ),
      ],
    );
  }
}
