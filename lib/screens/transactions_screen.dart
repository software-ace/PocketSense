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
import '../utils/voice_parser.dart';
import '../widgets/voice_entry_sheet.dart';
import 'settings_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with DataAware {
  final _repo = FinanceRepo();
  final _searchCtrl = TextEditingController();
  String? _typeFilter; // null=all, 'income', 'expense'
  List<Transaction> _items = [];
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
      final items = await _repo.transactions(type: _typeFilter);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _addTransaction() async {
    final draft = await _showForm(context, null);
    if (draft == null || !mounted) return;
    try {
      await _repo.insertTransaction(
        amountFils: draft.amountFils,
        type: draft.type,
        date: draft.date,
        description: draft.description,
        merchant: draft.merchant,
        categoryId: draft.categoryId,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(context.l10n.addFailed('$e'));
    }
  }

  /// Speak → parse → the normal form, pre-filled, so nothing is saved
  /// without the user checking it.
  Future<void> _addByVoice() async {
    final heard = await showVoiceEntrySheet(context);
    if (heard == null || !mounted) return;
    final starterNames = starterCategoryNames(context.l10n);
    final guess = parseVoiceEntry(heard, categories: await _repo.categories(), starterNames: starterNames);
    if (!mounted) return;
    final draft = await showModalBottomSheet<_TxDraft>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _TxFormSheet(voice: guess, heard: heard),
    );
    if (draft == null || !mounted) return;
    try {
      await _repo.insertTransaction(
        amountFils: draft.amountFils,
        type: draft.type,
        date: draft.date,
        description: draft.description,
        merchant: draft.merchant,
        categoryId: draft.categoryId,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(context.l10n.addFailed('$e'));
    }
  }

  Future<void> _editTransaction(Transaction t) async {
    final draft = await _showForm(context, t);
    if (draft == null || !mounted) return;
    try {
      await _repo.updateTransaction(
        t.id,
        amountFils: draft.amountFils,
        type: draft.type,
        date: draft.date,
        description: draft.description,
        merchant: draft.merchant,
        categoryId: draft.categoryId,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(context.l10n.updateFailed('$e'));
    }
  }

  Future<void> _delete(Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.deleteTransactionTitle),
        content: Text('${t.description} (${formatMoney(t.amountFils)})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteTransaction(t.id);
    await _load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);

    if (desktop) return _buildDesktop(theme);
    return _buildMobile(theme);
  }

  List<ButtonSegment<String>> _typeSegments(AppLocalizations l) => [
        ButtonSegment(value: '', label: Text(l.all)),
        ButtonSegment(value: 'expense', label: Text(l.expense)),
        ButtonSegment(value: 'income', label: Text(l.income)),
      ];

  Widget _buildDesktop(ThemeData theme) {
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navActivity),
        actions: [
          if (voiceEntrySupported) IconButton(icon: const Icon(Icons.mic_none), tooltip: l.addByVoice, onPressed: _addByVoice),
          IconButton(icon: const Icon(Icons.add), tooltip: l.addTransaction, onPressed: _addTransaction),
          const SettingsButton(),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(hintText: l.searchTransactions, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, prefixIcon: const Icon(Icons.search)),
                onChanged: (_) => _applyFilters(),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: _typeSegments(l),
              selected: {_typeFilter ?? ''},
              onSelectionChanged: (s) {
                setState(() => _typeFilter = s.first.isEmpty ? null : s.first);
                _load();
              },
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(theme, desktop: true)),
        ]),
      ),
    );
  }

  Widget _buildMobile(ThemeData theme) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navActivity),
        actions: const [SettingsButton()],
      ),
      // Both ways to add sit in thumb reach; the app bar keeps only status.
      floatingActionButton: voiceEntrySupported
          ? _AddSplitFab(onVoice: _addByVoice, onAdd: _addTransaction)
          : FloatingActionButton.extended(onPressed: _addTransaction, icon: const Icon(Icons.add), label: Text(l.add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(hintText: l.search, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<String>(
            segments: _typeSegments(l),
            selected: {_typeFilter ?? ''},
            onSelectionChanged: (s) {
              setState(() => _typeFilter = s.first.isEmpty ? null : s.first);
              _load();
            },
          ),
        ),
        Expanded(child: _buildBody(theme, desktop: false)),
      ]),
    );
  }

  Widget _buildBody(ThemeData theme, {required bool desktop}) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error.toString(), onRetry: _load);
    if (_items.isEmpty) return EmptyView(icon: Icons.receipt_long, title: context.l10n.noTransactionsYet, subtitle: context.l10n.noTransactionsHint);

    if (desktop) return _dataTable(theme);
    return _mobileList(theme);
  }

  Widget _dataTable(ThemeData theme) {
    final l = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columns: [
            DataColumn(label: Text(l.date)),
            DataColumn(label: Text(l.description)),
            DataColumn(label: Text(l.category)),
            DataColumn(label: Text(l.merchant)),
            DataColumn(label: Text(l.type)),
            DataColumn(label: Align(alignment: AlignmentDirectional.centerEnd, child: Text(l.amount))),
            DataColumn(label: SizedBox(width: 72)),
          ],
          rows: _items.map((t) {
            final fmt = DateFormat.yMMMd();
            return DataRow(cells: [
              DataCell(Text(fmt.format(t.date), style: const TextStyle(fontSize: 13))),
              DataCell(Text(t.description.isNotEmpty ? t.description : (t.merchant ?? '—'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _catColor(t).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(t.categoryName ?? l.uncategorized, style: TextStyle(fontSize: 12, color: _catColor(t))))),
              DataCell(Text(t.merchant ?? '—', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1)),
              DataCell(Text(t.type == 'income' ? l.income : l.expense, style: TextStyle(fontSize: 12, color: t.type == 'income' ? Colors.green : Colors.redAccent))),
              DataCell(Align(alignment: AlignmentDirectional.centerEnd, child: Text(formatMoney(t.amountFils, showSign: t.type == 'income'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.type == 'income' ? Colors.green : null)))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: l.edit, onPressed: () => _editTransaction(t), visualDensity: VisualDensity.compact),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18), tooltip: l.delete, onPressed: () => _delete(t), visualDensity: VisualDensity.compact),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _mobileList(ThemeData theme) {
    return ListView.builder(
      // Room below the last row so the floating add button never covers it.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final t = _items[i];
        return Dismissible(
          key: ValueKey(t.id),
          direction: DismissDirection.endToStart,
          background: Container(color: Colors.red.shade400, alignment: AlignmentDirectional.centerEnd, padding: const EdgeInsetsDirectional.only(end: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) => _delete(t),
          child: ListTile(
            onTap: () => _editTransaction(t),
            onLongPress: () => _mobileActionSheet(t),
            leading: CircleAvatar(radius: 18, backgroundColor: _catColor(t).withValues(alpha: 0.15), child: Text(t.categoryName?.isNotEmpty == true ? t.categoryName![0].toUpperCase() : '•', style: TextStyle(color: _catColor(t)))),
            title: Text(t.description.isNotEmpty ? t.description : (t.merchant ?? context.l10n.transactionFallback)),
            subtitle: Text(formatDate(t.date)),
            trailing: Text(formatMoney(t.amountFils, showSign: t.type == 'income'), style: TextStyle(fontWeight: FontWeight.w600, color: t.type == 'income' ? Colors.green : null)),
          ),
        );
      },
    );
  }

  void _mobileActionSheet(Transaction t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(ctx.l10n.edit), onTap: () { Navigator.pop(ctx); _editTransaction(t); }),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(ctx); _delete(t); }),
        ]),
      ),
    );
  }

  Color _catColor(Transaction t) {
    if (t.categoryColor != null && t.categoryColor!.startsWith('#') && t.categoryColor!.length >= 7) {
      return Color(int.parse('FF${t.categoryColor!.substring(1, 7)}', radix: 16));
    }
    return Theme.of(context).colorScheme.primary;
  }

  void _applyFilters() {
    // Client-side search filter over already-loaded rows for responsiveness.
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {});
      return;
    }
    // Re-query server for accuracy when searching.
    _repo.transactions(type: _typeFilter, q: q).then((items) {
      if (mounted) setState(() => _items = items);
    }).catchError((_) {});
  }

  Future<_TxDraft?> _showForm(BuildContext context, Transaction? existing) async {
    final result = await showModalBottomSheet<_TxDraft>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _TxFormSheet(existing: existing),
    );
    return result;
  }
}

/// Extended-FAB-shaped pill split in two: [ 🎤 | + Add ].
class _AddSplitFab extends StatelessWidget {
  final VoidCallback onVoice;
  final VoidCallback onAdd;
  const _AddSplitFab({required this.onVoice, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;
    return Material(
      color: scheme.primaryContainer,
      elevation: 6,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 56,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(
            message: context.l10n.addByVoice,
            child: InkWell(
              onTap: onVoice,
              child: SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Icon(Icons.mic_none, color: fg))),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 14, endIndent: 14, color: fg.withValues(alpha: 0.3)),
          InkWell(
            onTap: onAdd,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 0),
                child: Row(children: [
                  Icon(Icons.add, color: fg),
                  const SizedBox(width: 8),
                  Text(context.l10n.add, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TxDraft {
  final int amountFils;
  final String type;
  final String description;
  final String? merchant;
  final int? categoryId;
  final DateTime date;
  _TxDraft(this.amountFils, this.type, this.description, {required this.date, this.merchant, this.categoryId});
}

class _TxFormSheet extends StatefulWidget {
  final Transaction? existing;
  final VoiceDraft? voice; // pre-fill from a spoken sentence
  final String? heard;
  const _TxFormSheet({this.existing, this.voice, this.heard});
  @override
  State<_TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<_TxFormSheet> {
  late final int? _initialFils = widget.existing?.amountFils ?? widget.voice?.amountFils;
  late final _amtCtrl = TextEditingController(text: _initialFils != null ? amountToInput(_initialFils) : '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? widget.voice?.description ?? '');
  late final _merchCtrl = TextEditingController(text: widget.existing?.merchant ?? widget.voice?.merchant ?? '');
  late String _type = widget.existing?.type ?? widget.voice?.type ?? 'expense';
  late int? _catId = widget.existing?.categoryId ?? widget.voice?.categoryId;
  late DateTime _date = widget.existing?.date ?? widget.voice?.date ?? _today();
  List<dynamic> _cats = [];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      // A little ahead, for bills you already know are coming.
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel() {
    final diff = _date.difference(_today()).inDays;
    final day = DateFormat.yMMMEd().format(_date);
    final l = context.l10n;
    return switch (diff) { 0 => l.dateToday(day), -1 => l.dateYesterday(day), _ => day };
  }

  @override
  void initState() {
    super.initState();
    FinanceRepo().categories().then((c) => setState(() => _cats = c)).catchError((_) {});
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _descCtrl.dispose();
    _merchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _cats.cast<Category>();
    final isEdit = widget.existing != null;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(isEdit ? l.editTransaction : (widget.heard != null ? l.checkAndSave : l.newTransaction), style: Theme.of(context).textTheme.titleLarge),
          if (widget.heard != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.mic_none, size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(child: Text('"${widget.heard}"', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.outline))),
            ]),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'expense', label: Text(l.expense)),
              ButtonSegment(value: 'income', label: Text(l.income)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          AmountField(controller: _amtCtrl, label: l.amount),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: InputDecoration(labelText: l.date, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(_dateLabel()),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: InputDecoration(labelText: l.descriptionOptional)),
          const SizedBox(height: 12),
          TextField(controller: _merchCtrl, decoration: InputDecoration(labelText: l.merchantOptional)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // Categories load async; only select once the item exists.
            key: ValueKey(cats.length),
            initialValue: cats.any((c) => c.id == _catId) ? _catId : null,
            decoration: InputDecoration(labelText: l.categoryOptional),
            items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _catId = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final fils = parseAmount(_amtCtrl.text) ?? 0;
              if (fils <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.enterPositiveAmount)));
                return;
              }
              final desc = _descCtrl.text.trim();
              final merch = _merchCtrl.text.trim();
              final effectiveDesc = desc.isNotEmpty ? desc : (merch.isNotEmpty ? merch : l.transactionFallback);
              Navigator.pop(context, _TxDraft(fils, _type, effectiveDesc, date: _date, merchant: merch.isEmpty ? null : merch, categoryId: _catId));
            },
            child: Text(l.save),
          ),
        ]),
      ),
    );
  }
}
