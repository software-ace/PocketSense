import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/amount_field.dart';
import '../widgets/state_views.dart';
import '../widgets/data_aware.dart';
import 'settings_screen.dart';

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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BudgetDialog(existing: existing, cats: _cats),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteBudgetTitle(b.categoryName ?? ctx.l10n.category)),
        content: Text(ctx.l10n.deleteBudgetBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteBudget(b.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.navBudgets), actions: const [SettingsButton()]),
      floatingActionButton: desktop ? null : FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: Text(l.newItem)),
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
                                final color = _hex(b.categoryColor, theme.colorScheme.primary);
                                final spent = p.spentFils;
                                final ratio = b.limitFils > 0 ? (spent / b.limitFils).clamp(0.0, 1.5) : 0.0;
                                final over = spent > b.limitFils;

                                return Card(
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
                                          Text('${formatMoney(spent)} / ${formatMoney(b.limitFils)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: over ? const Color(0xFFFF5252) : null)),
                                          if (desktop) ...[
                                            const SizedBox(width: 4),
                                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: l.edit, visualDensity: VisualDensity.compact, onPressed: () => _edit(b)),
                                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), tooltip: l.delete, visualDensity: VisualDensity.compact, onPressed: () => _delete(b)),
                                          ],
                                        ]),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            minHeight: desktop ? 10 : 8,
                                            value: ratio.clamp(0.0, 1.0),
                                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            color: over ? Colors.redAccent : color,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                          Text(over ? l.overBudgetBy(formatMoney(spent - b.limitFils)) : l.amountRemaining(formatMoney(b.limitFils - spent)), style: theme.textTheme.bodySmall?.copyWith(color: over ? Colors.redAccent : theme.colorScheme.outline)),
                                          Text('${(ratio * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                        ]),
                                      ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ]),
      ),
    );
  }

  Color _hex(String? css, Color fallback) {
    if (css != null && css.startsWith('#') && css.length >= 7) {
      return Color(int.parse(css.substring(1, 7), radix: 16) | 0xFF000000);
    }
    return fallback;
  }
}

// ── Dialog ────────────────────────────────────────────────────────────────

class _BudgetDialog extends StatefulWidget {
  final Budget? existing;
  final List<Category> cats;
  const _BudgetDialog({this.existing, required this.cats});

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
    // Only expense categories make sense for budgets.
    final expenseCats = widget.cats.where((c) => c.type == 'expense').toList();
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
            items: expenseCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save),
        ),
      ],
    );
  }
}
