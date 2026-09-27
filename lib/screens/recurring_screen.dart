import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../utils/recurring.dart';
import '../widgets/state_views.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final _repo = FinanceRepo();
  List<RecurringExpense> _items = [];
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
      final results = await Future.wait([_repo.recurring(), _repo.categories()]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<RecurringExpense>;
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

  Future<void> _edit(RecurringExpense? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecurringDialog(existing: existing, cats: _cats),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _post(RecurringExpense r) async {
    try {
      await _repo.postRecurring(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Posted "${r.description}" as a transaction')));
      await _load();
    } catch (e, st) {
      debugPrint('postRecurring error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(RecurringExpense r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${r.description}"?'),
        content: const Text('This recurring expense will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRecurring(r.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
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
                        padding: EdgeInsets.fromLTRB(PlatformUi.hPadding(context), 8, PlatformUi.hPadding(context), 0),
                        child: Row(children: [
                          Expanded(child: Text('${_items.length} active recurring expenses', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: const Text('New expense')),
                        ]),
                      ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(child: EmptyView(icon: Icons.repeat, title: 'No recurring expenses', subtitle: 'Add rent, subscriptions, and bills to see upcoming dues.'))
                          : desktop
                              ? _buildTable(theme)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: _items.length,
                                  itemBuilder: (_, i) => _mobileCard(theme, _items[i]),
                                ),
                    ),
                  ]),
      ),
    );
  }

  Widget _buildTable(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(PlatformUi.hPadding(context)),
      child: Card(
        margin: EdgeInsets.zero,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          columns: const [
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Frequency')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Align(alignment: Alignment.centerRight, child: Text('Amount'))),
            DataColumn(label: Text('Next Due')),
            DataColumn(label: Text('Status')),
            DataColumn(label: SizedBox(width: 64)),
          ],
          rows: _items.map((r) {
            final next = nextOccurrence(r.frequency, r.anchorDate, DateTime.now());
            final days = daysUntil(next);
            final overdue = days < 0;
            return DataRow(cells: [
              DataCell(Text(r.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              DataCell(Text(formatFrequency(r.frequency), style: const TextStyle(fontSize: 13))),
              DataCell(Text(r.categoryName ?? '—', style: const TextStyle(fontSize: 13))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(formatMoney(r.amountCents), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))),
              DataCell(Text(r.active ? _fmtDate(next) : '—', style: const TextStyle(fontSize: 13))),
              DataCell(r.active
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: overdue ? Colors.red.shade100 : (days <= 7 ? Colors.amber.shade100 : Colors.green.shade100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        overdue ? 'Overdue ${-days}d' : (days == 0 ? 'Today' : 'In $days d'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: overdue ? Colors.red.shade900 : (days <= 7 ? Colors.orange.shade900 : Colors.green.shade900)),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                      child: Text('Inactive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.outline)),
                    )),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.play_arrow_rounded, size: 20), tooltip: 'Post as transaction', visualDensity: VisualDensity.compact, onPressed: () => _post(r)),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Edit', visualDensity: VisualDensity.compact, onPressed: () => _edit(r)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), tooltip: 'Delete', visualDensity: VisualDensity.compact, onPressed: () => _delete(r)),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _mobileCard(ThemeData theme, RecurringExpense r) {
    final next = nextOccurrence(r.frequency, r.anchorDate, DateTime.now());
    final days = daysUntil(next);
    final overdue = days < 0;
    final opacity = r.active ? 1.0 : 0.5;
    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          onTap: () => _edit(r),
          onLongPress: () => _longPressSheet(r),
          leading: CircleAvatar(child: Icon(Icons.event_repeat)),
          title: Row(children: [
            Expanded(child: Text(r.description)),
            if (!r.active) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)), child: Text('Inactive', style: theme.textTheme.labelSmall?.copyWith(fontSize: 10))),
            ],
          ]),
          subtitle: Text('${formatFrequency(r.frequency)} · ${r.categoryName ?? ''}'.trim()),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMoney(r.amountCents), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (r.active)
              Text(
                overdue ? 'Overdue by ${-days}d' : (days == 0 ? 'Due today' : 'Due in $days d'),
                style: theme.textTheme.bodySmall?.copyWith(color: overdue ? Colors.redAccent : theme.colorScheme.outline),
              )
            else
              Text('Paused', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
      ),
    );
  }

  void _longPressSheet(RecurringExpense r) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.play_arrow_rounded), title: const Text('Post as transaction'), subtitle: const Text('Records this expense today in Activity'), onTap: () { Navigator.pop(ctx); _post(r); }),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () { Navigator.pop(ctx); _edit(r); }),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: const Text('Delete', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _delete(r); }),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Dialog ────────────────────────────────────────────────────────────────

const _freqs = [
  ('weekly', 'Weekly'),
  ('biweekly', 'Bi-weekly'),
  ('monthly', 'Monthly'),
  ('quarterly', 'Quarterly'),
  ('yearly', 'Yearly'),
];

class _RecurringDialog extends StatefulWidget {
  final RecurringExpense? existing;
  final List<Category> cats;
  const _RecurringDialog({this.existing, required this.cats});

  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _amtCtrl = TextEditingController(text: widget.existing != null ? (widget.existing!.amountCents / 100).toStringAsFixed(2) : '');
  late final _merchCtrl = TextEditingController(text: widget.existing?.merchant ?? '');
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  late String _freq = widget.existing?.frequency ?? 'monthly';
  late int? _catId = widget.existing?.categoryId;
  late bool _active = widget.existing?.active ?? true;
  // Anchor date drives every future due date (weekday / day-of-month).
  late DateTime _anchor = widget.existing?.anchorDate ?? DateTime.now();
  bool _saving = false;

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'First due date',
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    _merchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (desc.isEmpty || amt <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      final cents = (amt * 100).round();
      final anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
      final merch = _merchCtrl.text.trim().isEmpty ? null : _merchCtrl.text.trim();
      final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      if (widget.existing == null) {
        await repo.insertRecurring(description: desc, amountCents: cents, frequency: _freq, anchorDate: anchor, categoryId: _catId, merchant: merch, notes: notes, active: _active);
      } else {
        await repo.updateRecurring(widget.existing!.id, description: desc, amountCents: cents, frequency: _freq, anchorDate: anchor, categoryId: _catId, merchant: merch, notes: notes, active: _active);
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
    final theme = Theme.of(context);
    final expenseCats = widget.cats.where((c) => c.type == 'expense').toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New recurring expense' : 'Edit recurring expense'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _descCtrl, autofocus: widget.existing == null, decoration: const InputDecoration(labelText: 'Description'), onSubmitted: (_) => _save()),
          const SizedBox(height: 16),
          TextField(controller: _amtCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ ')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _freq,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: _freqs.map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2))).toList(),
            onChanged: (v) => setState(() => _freq = v!),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickAnchor,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'First due date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(DateFormat('MMM d, y').format(_anchor)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _catId,
            decoration: const InputDecoration(labelText: 'Category (optional)'),
            items: expenseCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 16),
          TextField(controller: _merchCtrl, decoration: const InputDecoration(labelText: 'Merchant (optional)')),
          const SizedBox(height: 16),
          TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Any extra details…')),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.power_settings_new),
              title: const Text('Active'),
              subtitle: Text(widget.existing!.active ? 'Showing in list' : 'Hidden from list', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
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
