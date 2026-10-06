import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../utils/recurring.dart';
import '../widgets/amount_field.dart';
import '../widgets/state_views.dart';
import '../widgets/data_aware.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> with DataAware {
  final _repo = FinanceRepo();
  List<RecurringExpense> _items = [];
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
      final l = context.l10n;
      await _repo.postRecurring(r, description: l.recurringSuffix(r.description));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.postedAsTransaction(r.description))));
      await _load();
    } catch (e, st) {
      debugPrint('postRecurring error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.postFailed('$e')), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(RecurringExpense r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteNamedTitle(r.description)),
        content: Text(ctx.l10n.deleteRecurringBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRecurring(r.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.navRecurring), actions: const [SyncButton(), SettingsButton()]),
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
                        padding: EdgeInsets.fromLTRB(PlatformUi.hPadding(context), 8, PlatformUi.hPadding(context), 0),
                        child: Row(children: [
                          Expanded(child: Text(l.recurringCount(_items.length), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: Text(l.newRecurring)),
                        ]),
                      ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(child: EmptyView(icon: Icons.repeat, title: l.noRecurring, subtitle: l.noRecurringHint))
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
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.all(PlatformUi.hPadding(context)),
      child: Card(
        margin: EdgeInsets.zero,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          columns: [
            DataColumn(label: Text(l.description)),
            DataColumn(label: Text(l.frequency)),
            DataColumn(label: Text(l.category)),
            DataColumn(label: Align(alignment: AlignmentDirectional.centerEnd, child: Text(l.amount))),
            DataColumn(label: Text(l.nextDue)),
            DataColumn(label: Text(l.status)),
            DataColumn(label: SizedBox(width: 64)),
          ],
          rows: _items.map((r) {
            final next = nextOccurrence(r.frequency, r.anchorDate, DateTime.now());
            final days = daysUntil(next);
            final overdue = days < 0;
            return DataRow(cells: [
              DataCell(Text(r.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              DataCell(Text(formatFrequency(l, r.frequency), style: const TextStyle(fontSize: 13))),
              DataCell(Text(r.categoryName ?? '—', style: const TextStyle(fontSize: 13))),
              DataCell(Align(alignment: AlignmentDirectional.centerEnd, child: Text(formatMoney(r.amountFils, showSign: _isIncome(r)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isIncome(r) ? Colors.green : null)))),
              DataCell(Text(r.active ? DateFormat.yMMMd().format(next) : '—', style: const TextStyle(fontSize: 13))),
              DataCell(r.active
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: overdue ? Colors.red.shade100 : (days <= 7 ? Colors.amber.shade100 : Colors.green.shade100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        overdue ? l.overdueDays(-days) : (days == 0 ? l.dueToday : l.dueInDays(days)),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: overdue ? Colors.red.shade900 : (days <= 7 ? Colors.orange.shade900 : Colors.green.shade900)),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                      child: Text(l.inactive, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.outline)),
                    )),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.play_arrow_rounded, size: 20), tooltip: l.postAsTransaction, visualDensity: VisualDensity.compact, onPressed: () => _post(r)),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: l.edit, visualDensity: VisualDensity.compact, onPressed: () => _edit(r)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), tooltip: l.delete, visualDensity: VisualDensity.compact, onPressed: () => _delete(r)),
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
    final l = context.l10n;
    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          onTap: () => _edit(r),
          onLongPress: () => _longPressSheet(r),
          leading: CircleAvatar(child: Icon(_isIncome(r) ? Icons.arrow_upward : Icons.event_repeat)),
          title: Row(children: [
            Expanded(child: Text(r.description)),
            if (!r.active) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)), child: Text(l.inactive, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10))),
            ],
          ]),
          subtitle: Text([formatFrequency(l, r.frequency), ?r.categoryName].join(' · ')),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(formatMoney(r.amountFils, showSign: _isIncome(r)), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: _isIncome(r) ? Colors.green : null)),
            if (r.active)
              Text(
                overdue ? l.overdueDays(-days) : (days == 0 ? l.dueToday : l.dueInDays(days)),
                style: theme.textTheme.bodySmall?.copyWith(color: overdue ? Colors.redAccent : theme.colorScheme.outline),
              )
            else
              Text(l.paused, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
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
          ListTile(leading: const Icon(Icons.play_arrow_rounded), title: Text(ctx.l10n.postAsTransaction), subtitle: Text(ctx.l10n.postAsTransactionHint), onTap: () { Navigator.pop(ctx); _post(r); }),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(ctx.l10n.edit), onTap: () { Navigator.pop(ctx); _edit(r); }),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _delete(r); }),
        ]),
      ),
    );
  }

  bool _isIncome(RecurringExpense r) => r.type == 'income';
}

// ── Dialog ────────────────────────────────────────────────────────────────

class _RecurringDialog extends StatefulWidget {
  final RecurringExpense? existing;
  final List<Category> cats;
  const _RecurringDialog({this.existing, required this.cats});

  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _amtCtrl = TextEditingController(text: widget.existing != null ? amountToInput(widget.existing!.amountFils) : '');
  late final _merchCtrl = TextEditingController(text: widget.existing?.merchant ?? '');
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late String _freq = widget.existing?.frequency ?? 'monthly';
  late int? _catId = widget.existing?.categoryId;
  late bool _active = widget.existing?.active ?? true;
  // Anchor date drives every future due date (weekday / day-of-month).
  late DateTime _anchor = widget.existing?.anchorDate ?? DateTime.now();
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: context.l10n.firstDueDate,
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
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final desc = _descCtrl.text.trim();
    final fils = parseAmount(_amtCtrl.text)!;
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      final anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
      final merch = _merchCtrl.text.trim().isEmpty ? null : _merchCtrl.text.trim();
      final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      if (widget.existing == null) {
        await repo.insertRecurring(description: desc, amountFils: fils, type: _type, frequency: _freq, anchorDate: anchor, categoryId: _catId, merchant: merch, notes: notes, active: _active);
      } else {
        await repo.updateRecurring(widget.existing!.id, description: desc, amountFils: fils, type: _type, frequency: _freq, anchorDate: anchor, categoryId: _catId, merchant: merch, notes: notes, active: _active);
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
    final theme = Theme.of(context);
    final typeCats = widget.cats.where((c) => c.type == _type).toList();
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.newRecurringItem : l.editRecurringItem),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'expense', label: Text(l.expense), icon: const Icon(Icons.arrow_downward, size: 16)),
                ButtonSegment(value: 'income', label: Text(l.income), icon: const Icon(Icons.arrow_upward, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (sel) => setState(() {
                _type = sel.first;
                // Categories are typed; keep only one that matches the new type.
                if (!widget.cats.any((c) => c.id == _catId && c.type == _type)) _catId = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            autofocus: widget.existing == null,
            decoration: InputDecoration(labelText: l.description),
            validator: (v) => (v ?? '').trim().isEmpty ? l.enterDescription : null,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          AmountField(controller: _amtCtrl, label: l.amount),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _freq,
            decoration: InputDecoration(labelText: l.frequency),
            items: frequencies.map((f) => DropdownMenuItem(value: f, child: Text(formatFrequency(l, f)))).toList(),
            onChanged: (v) => setState(() => _freq = v!),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickAnchor,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(labelText: l.firstDueDate, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(DateFormat.yMMMd().format(_anchor)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            // Keyed by type so the field resets when the category list changes.
            key: ValueKey(_type),
            initialValue: typeCats.any((c) => c.id == _catId) ? _catId : null,
            decoration: InputDecoration(labelText: l.categoryOptional),
            items: typeCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 16),
          TextField(controller: _merchCtrl, decoration: InputDecoration(labelText: l.merchantOptional)),
          const SizedBox(height: 16),
          TextField(controller: _notesCtrl, decoration: InputDecoration(labelText: l.notesOptional, hintText: l.notesHint)),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.power_settings_new),
              title: Text(l.active),
              subtitle: Text(widget.existing!.active ? l.showingInList : l.hiddenFromList, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
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
