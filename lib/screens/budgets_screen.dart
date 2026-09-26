import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _repo = FinanceRepo();
  List<Budget> _budgets = [];
  Map<int, int> _spentByCat = {};
  List<Category> _cats = [];
  Object? _error;
  bool _loading = true;

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
      final results = await Future.wait([
        _repo.budgets(),
        _repo.transactions(from: monthStart, to: now, type: 'expense', limit: 2000),
        _repo.categories(),
      ]);
      if (!mounted) return;
      final budgets = (results[0] as List<Budget>).where((x) => x.active).toList();
      final txs = results[1] as List<Transaction>;
      final spent = <int, int>{};
      for (final t in txs) {
        if (t.categoryId != null) {
          spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amountCents;
        }
      }
      setState(() {
        _budgets = budgets;
        _spentByCat = spent;
        _cats = results[2] as List<Category>;
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
        title: Text('Delete budget for "${b.categoryName ?? 'Category'}"?'),
        content: const Text('This will remove the spending limit. Existing transactions are unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteBudget(b.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: desktop ? null : FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error.toString(), onRetry: _load)
                : Column(children: [
                    if (desktop)
                      Padding(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                        child: Row(children: [
                          Expanded(child: Text('${_budgets.length} active budgets', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: const Text('New budget')),
                        ]),
                      ),
                    Expanded(
                      child: _budgets.isEmpty
                          ? Center(child: EmptyView(icon: Icons.dashboard_customize_outlined, title: 'No budgets set', subtitle: 'Set a monthly limit per category to track spending.'))
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                              itemCount: _budgets.length,
                              itemBuilder: (_, i) {
                                final b = _budgets[i];
                                final color = _hex(b.categoryColor, theme.colorScheme.primary);
                                final spent = _spentByCat[b.categoryId] ?? 0;
                                final ratio = b.limitCents > 0 ? (spent / b.limitCents).clamp(0.0, 1.5) : 0.0;
                                final over = spent > b.limitCents;

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
                                          Expanded(child: Text(b.categoryName ?? 'Category', style: theme.textTheme.titleSmall)),
                                          Text('${formatMoney(spent)} / ${formatMoney(b.limitCents)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: over ? const Color(0xFFFF5252) : null)),
                                          if (desktop) ...[
                                            const SizedBox(width: 4),
                                            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Edit', visualDensity: VisualDensity.compact, onPressed: () => _edit(b)),
                                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), tooltip: 'Delete', visualDensity: VisualDensity.compact, onPressed: () => _delete(b)),
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
                                          Text(over ? 'Over budget by ${formatMoney(spent - b.limitCents)}' : '${formatMoney(b.limitCents - spent)} remaining', style: theme.textTheme.bodySmall?.copyWith(color: over ? Colors.redAccent : theme.colorScheme.outline)),
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
  late final _amtCtrl = TextEditingController(text: widget.existing != null ? (widget.existing!.limitCents / 100).toStringAsFixed(2) : '');
  late String _period = widget.existing?.period ?? 'monthly';
  bool _saving = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (_catId == null || amt <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      final cents = (amt * 100).round();
      if (widget.existing == null) {
        await repo.insertBudget(categoryId: _catId!, limitCents: cents, period: _period);
      } else {
        await repo.updateBudget(widget.existing!.id, categoryId: _catId!, limitCents: cents, period: _period);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only expense categories make sense for budgets.
    final expenseCats = widget.cats.where((c) => c.type == 'expense').toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New budget' : 'Edit budget'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<int>(
            initialValue: _catId,
            decoration: const InputDecoration(labelText: 'Category'),
            items: expenseCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amtCtrl,
            autofocus: widget.existing == null,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '\$ '),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
