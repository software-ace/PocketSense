import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../security/amount_privacy.dart';
import '../security/lock_gate.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../utils/quick_add.dart';
import '../widgets/account_field.dart';
import '../widgets/amount_field.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_delete_background.dart';
import '../widgets/data_aware.dart';
import '../widgets/merchant_field.dart';
import '../utils/voice_parser.dart';
import '../widgets/voice_entry_sheet.dart';
import '../settings/app_settings.dart';
import '../settings/app_style.dart';
import 'accounts_screen.dart' show accountAvatar;
import 'loans_screen.dart' show DateField;
import 'settings_screen.dart';
import 'sync_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with DataAware {
  final _repo = FinanceRepo();
  final _searchCtrl = TextEditingController();
  String? _typeFilter; // null=all, 'income', 'expense'
  // Exact filters beside the type, each combinable with search: one
  // category, merchant and account. Kept whole, so the chip can name it.
  Category? _category;
  // Kept by id: entries store the name, which a rename changes.
  Merchant? _merchant;
  Account? _account;
  // The Account filter shows once there's more than one, as in the form.
  List<Account> _accounts = const [];
  List<Transaction> _items = [];
  Object? _error;
  bool _loading = true;

  // Picks first, so a renamed merchant is filtered by its new name.
  @override
  void onDataChanged() => _refreshPicks().catchError((_) {}).whenComplete(_load);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPicks();
    // A request from launch is already waiting; later ones arrive while running.
    QuickAddRequests.pending.addListener(_onQuickAdd);
    LockGate.unlocked.addListener(_onQuickAdd);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onQuickAdd());
  }

  @override
  void dispose() {
    QuickAddRequests.pending.removeListener(_onQuickAdd);
    LockGate.unlocked.removeListener(_onQuickAdd);
    super.dispose();
  }

  /// The home-screen widget or an app-icon shortcut: open the form over
  /// whichever tab is showing, once unlocked (voice would listen under the
  /// lock screen otherwise).
  void _onQuickAdd() {
    final request = QuickAddRequests.pending.value;
    if (request == null || !LockGate.unlocked.value || !mounted) return;
    QuickAddRequests.pending.value = null;
    switch (request) {
      case QuickAdd.voice when voiceEntrySupported:
        _addByVoice();
      case QuickAdd.income:
        _addTransaction(type: 'income');
      case QuickAdd.expense || QuickAdd.voice:
        _addTransaction();
    }
  }

  // Bumped by every load: an older search that answers late is dropped.
  int _loads = 0;

  // How many entries to show; "Show older entries" raises it.
  static const _page = 200;
  int _limit = _page;

  // A full page: there may be older ones.
  bool get _more => _items.length >= _limit;

  void _showOlder() {
    _limit += _page;
    _load();
  }

  Widget _olderButton() => Center(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton.icon(onPressed: _showOlder, icon: const Icon(Icons.expand_more), label: Text(context.l10n.showOlderEntries))));

  /// Loads with the type filter and whatever is typed in search.
  Future<void> _load() async {
    final load = ++_loads;
    // No spinner here: it shows only before the first load, not per keystroke.
    if (_error != null) setState(() => _error = null);
    try {
      final items = await _repo.transactions(
          type: _typeFilter, q: _searchCtrl.text.trim(), categoryId: _category?.id, merchant: _merchant?.name, accountId: _account?.id, limit: _limit);
      if (!mounted || load != _loads) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || load != _loads) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// After a change anywhere (a rename, a delete, sync): each picked filter
  /// follows its item's new name, and one that's gone is cleared.
  Future<void> _refreshPicks() async {
    final accounts = await _repo.accounts();
    final categories = _category == null ? null : await _repo.categories();
    final merchants = _merchant == null ? null : await _repo.merchants();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _account = accounts.where((a) => a.id == _account?.id).firstOrNull;
      _category = categories?.where((c) => c.id == _category?.id).firstOrNull;
      _merchant = merchants?.where((m) => m.id == _merchant?.id).firstOrNull;
    });
  }

  bool get _filtered =>
      _typeFilter != null || _searchCtrl.text.trim().isNotEmpty || _category != null || _merchant != null || _account != null;

  void _setType(String? type) {
    setState(() {
      _typeFilter = type;
      // An expense category under Income would only ever show nothing.
      if (type != null && _category?.type != type) _category = null;
    });
    _load();
  }

  void _setFilter(VoidCallback change) {
    setState(change);
    _load();
  }

  /// Category, Merchant and (with more than one) Account: each opens a list
  /// to pick one from; a picked one shows its name and an ✕ to clear it.
  Widget _filters() {
    final l = context.l10n;
    Widget chip(String label, String? picked, IconData icon, Future<void> Function() pick, VoidCallback clear) => picked == null
        ? ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: pick)
        : InputChip(avatar: Icon(icon, size: 18), label: Text(picked), selected: true, onPressed: pick, onDeleted: () => _setFilter(clear));
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        chip(l.category, _category?.name, Icons.category_outlined, _pickCategory, () => _category = null),
        chip(l.merchant, _merchant?.name, Icons.storefront_outlined, _pickMerchant, () => _merchant = null),
        if (_accounts.length > 1 || _account != null)
          chip(l.account, _account?.name, Icons.account_balance_wallet_outlined, _pickAccount, () => _account = null),
      ]),
    );
  }

  Future<void> _pickCategory() async {
    // Only the chosen type's categories: the others would match nothing.
    final cats = [for (final c in await _repo.categories()) if (_typeFilter == null || c.type == _typeFilter) c];
    if (!mounted) return;
    final picked = await _pickFrom<Category>(context.l10n.category, [
      for (final c in cats)
        (label: c.name, value: c, leading: CircleAvatar(radius: 7, backgroundColor: parseHex(c.color) ?? Colors.grey)),
    ]);
    if (picked != null) _setFilter(() => _category = picked);
  }

  Future<void> _pickMerchant() async {
    final merchants = await _repo.merchants();
    if (!mounted) return;
    final picked = await _pickFrom<Merchant>(context.l10n.merchant, [
      for (final m in merchants) (label: m.name, value: m, leading: null),
    ]);
    if (picked != null) _setFilter(() => _merchant = picked);
  }

  Future<void> _pickAccount() async {
    final l = context.l10n;
    final picked = await _pickFrom<Account>(l.account, [
      for (final a in _accounts) (label: a.closed ? l.accountClosedName(a.name) : a.name, value: a, leading: accountAvatar(a.kind, radius: 14)),
    ]);
    if (picked != null) _setFilter(() => _account = picked);
  }

  Future<T?> _pickFrom<T>(String title, List<_Option<T>> options) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _FilterPicker<T>(title: title, options: options),
      );

  Future<void> _addTransaction({String type = 'expense'}) => addTransaction(context, type: type);

  Future<void> _addByVoice() => addByVoice(context);

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
        accountId: draft.accountId,
      );
    } catch (e) {
      if (mounted) _toast(context.l10n.updateFailed('$e'));
    }
  }

  Future<bool> _confirmDelete(Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.deleteTransactionTitle),
        content: Text('${t.description.isNotEmpty ? t.description : (t.merchant ?? c.l10n.transactionFallback)} (${formatMoney(t.amountFils)})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.delete)),
        ],
      ),
    );
    return ok == true;
  }

  /// [confirmed]: a swipe already asked (in confirmDismiss).
  Future<void> _delete(Transaction t, {bool confirmed = false}) async {
    if (!confirmed && !await _confirmDelete(t)) return;
    try {
      await _repo.deleteTransaction(t.id);
    } catch (e) {
      if (!mounted) return;
      _toast(context.l10n.deleteFailed('$e'));
      await _load(); // brings back a row a swipe took away
    }
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
          const AmountsButton(),
          const SyncButton(),
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
                onChanged: (_) => _load(),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: _typeSegments(l),
              selected: {_typeFilter ?? ''},
              onSelectionChanged: (s) => _setType(s.first.isEmpty ? null : s.first),
            ),
          ]),
          const SizedBox(height: 10),
          _filters(),
          const SizedBox(height: 12),
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
        actions: const [AmountsButton(), SyncButton(), SettingsButton()],
      ),
      // Both ways to add sit in thumb reach; the app bar keeps only status.
      floatingActionButton: const AddEntryFab(),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(hintText: l.search, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true, prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => _load(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<String>(
            segments: _typeSegments(l),
            selected: {_typeFilter ?? ''},
            onSelectionChanged: (s) => _setType(s.first.isEmpty ? null : s.first),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: _filters()),
        Expanded(child: _buildBody(theme, desktop: false)),
      ]),
    );
  }

  Widget _buildBody(ThemeData theme, {required bool desktop}) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error.toString(), onRetry: _load);
    if (_items.isEmpty && _filtered) {
      return EmptyView(icon: Icons.search_off, title: context.l10n.noMatchingTransactions, subtitle: context.l10n.noMatchingTransactionsHint);
    }
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DataTable(
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
              DataCell(Text(t.description.isNotEmpty ? t.description : (t.merchant ?? context.l10n.transactionFallback), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _catColor(t).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(t.categoryName ?? l.uncategorized, style: TextStyle(fontSize: 12, color: _catColor(t))))),
              DataCell(Text(t.merchant ?? '—', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1)),
              DataCell(Text(t.type == 'income' ? l.income : l.expense, style: TextStyle(fontSize: 12, color: t.type == 'income' ? Theme.of(context).income : Theme.of(context).expense))),
              DataCell(Align(alignment: AlignmentDirectional.centerEnd, child: Text(formatMoney(t.amountFils, showSign: t.type == 'income'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.type == 'income' ? Theme.of(context).income : null)))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: l.edit, onPressed: () => _editTransaction(t), visualDensity: VisualDensity.compact),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18), tooltip: l.delete, onPressed: () => _delete(t), visualDensity: VisualDensity.compact),
              ])),
            ]);
          }).toList(),
          ),
          if (_more) _olderButton(),
        ]),
      ),
    );
  }

  Widget _mobileList(ThemeData theme) {
    return ListView.builder(
      // Room below the last row so the floating add button never covers it.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _items.length + (_more ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _items.length) return _olderButton();
        final t = _items[i];
        return Dismissible(
          key: ValueKey(t.id),
          direction: DismissDirection.endToStart,
          background: const SwipeDeleteBackground(),
          // Asked before the row leaves: Cancel keeps it in place.
          confirmDismiss: (_) => _confirmDelete(t),
          onDismissed: (_) {
            setState(() => _items.remove(t));
            _delete(t, confirmed: true);
          },
          child: ListTile(
            onTap: () => _editTransaction(t),
            onLongPress: () => _mobileActionSheet(t),
            leading: CircleAvatar(radius: 18, backgroundColor: _catColor(t).withValues(alpha: 0.15), child: Text(t.categoryName?.isNotEmpty == true ? t.categoryName![0].toUpperCase() : '•', style: TextStyle(color: _catColor(t)))),
            title: Text(t.description.isNotEmpty ? t.description : (t.merchant ?? context.l10n.transactionFallback)),
            subtitle: Text(formatDate(t.date)),
            trailing: Text(formatMoney(t.amountFils, showSign: t.type == 'income'), style: TextStyle(fontWeight: FontWeight.w600, color: t.type == 'income' ? Theme.of(context).income : null)),
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
          ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error), title: Text(ctx.l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)), onTap: () { Navigator.pop(ctx); _delete(t); }),
        ]),
      ),
    );
  }

  // LCD has one ink: category colours vanish on its green screen.
  Color _catColor(Transaction t) =>
      (AppSettings.appStyle.value == WidgetStyle.lcd ? null : parseHex(t.categoryColor)) ?? Theme.of(context).colorScheme.primary;

  Future<_TxDraft?> _showForm(BuildContext context, Transaction? existing, {String? type}) async {
    final result = await showModalBottomSheet<_TxDraft>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _TxFormSheet(existing: existing, type: type),
    );
    return result;
  }
}

/// Opens the new-entry form and saves what it returns; open tabs reload by
/// themselves. [accountId]: the account it starts in (an account's own
/// screen); null is the default.
Future<void> addTransaction(BuildContext context, {String type = 'expense', int? accountId}) async {
  final draft = await showModalBottomSheet<_TxDraft>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _TxFormSheet(type: type, accountId: accountId),
  );
  if (draft == null || !context.mounted) return;
  final l = context.l10n;
  try {
    await FinanceRepo().insertTransaction(
      amountFils: draft.amountFils,
      type: draft.type,
      date: draft.date,
      description: draft.description,
      merchant: draft.merchant,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.addFailed('$e'))));
  }
}

/// Speak → parse → the normal form, pre-filled, so nothing is saved
/// without the user checking it.
Future<void> addByVoice(BuildContext context) async {
  final heard = await showVoiceEntrySheet(context);
  if (heard == null || !context.mounted) return;
  final repo = FinanceRepo();
  final starterNames = starterCategoryNames(context.l10n);
  final guess = parseVoiceEntry(heard, categories: await repo.categories(), starterNames: starterNames);
  if (!context.mounted) return;
  final draft = await showModalBottomSheet<_TxDraft>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _TxFormSheet(voice: guess, heard: heard),
  );
  if (draft == null || !context.mounted) return;
  final l = context.l10n;
  try {
    await repo.insertTransaction(
      amountFils: draft.amountFils,
      type: draft.type,
      date: draft.date,
      description: draft.description,
      merchant: draft.merchant,
      categoryId: draft.categoryId,
      accountId: draft.accountId,
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.addFailed('$e'))));
  }
}

/// The phone's way to add an entry (Home and Activity): where voice entry
/// works, a pill split in two, [ 🎤 | + Add ]; elsewhere just + Add.
class AddEntryFab extends StatelessWidget {
  const AddEntryFab({super.key});

  @override
  Widget build(BuildContext context) {
    // heroTag null: Home's and Activity's live side by side in the tabs.
    if (!voiceEntrySupported) {
      return FloatingActionButton.extended(heroTag: null, onPressed: () => addTransaction(context), icon: const Icon(Icons.add), label: Text(context.l10n.add));
    }
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
              onTap: () => addByVoice(context),
              child: SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Icon(Icons.mic_none, color: fg))),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 14, endIndent: 14, color: fg.withValues(alpha: 0.3)),
          InkWell(
            onTap: () => addTransaction(context),
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
  final int? accountId;
  final DateTime date;
  _TxDraft(this.amountFils, this.type, this.description, {required this.date, this.merchant, this.categoryId, this.accountId});
}

class _TxFormSheet extends StatefulWidget {
  final Transaction? existing;
  final VoiceDraft? voice; // pre-fill from a spoken sentence
  final String? heard;
  final String? type; // a new one's starting type
  final int? accountId; // a new one's account; null is the default
  const _TxFormSheet({this.existing, this.voice, this.heard, this.type, this.accountId});
  @override
  State<_TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<_TxFormSheet> {
  late final int? _initialFils = widget.existing?.amountFils ?? widget.voice?.amountFils;
  late final _amtCtrl = TextEditingController(text: _initialFils != null ? amountToInput(_initialFils) : '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? widget.voice?.description ?? '');
  late final _merchCtrl = TextEditingController(text: widget.existing?.merchant ?? widget.voice?.merchant ?? '');
  late String _type = widget.existing?.type ?? widget.voice?.type ?? widget.type ?? 'expense';
  late int? _catId = widget.existing?.categoryId ?? widget.voice?.categoryId;
  late int? _accountId = widget.existing?.accountId ?? widget.accountId;
  late DateTime _date = widget.existing?.date ?? widget.voice?.date ?? todayDate();
  List<dynamic> _cats = [];
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

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
    final typeCats = cats.where((c) => c.type == _type).toList();
    final isEdit = widget.existing != null;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // Keeps Save above the navigation bar: Android 15+ draws apps behind it.
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
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
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              // An expense category can't stay selected on an income, and vice versa.
              if (!cats.any((c) => c.id == _catId && c.type == _type)) _catId = null;
            }),
          ),
          const SizedBox(height: 16),
          AmountField(controller: _amtCtrl, label: l.amount),
          const SizedBox(height: 12),
          DateField(
            label: l.date,
            value: _date,
            onPicked: (d) => setState(() => _date = d),
            // A little ahead, for bills you already know are coming.
            lastDate: () {
              final t = todayDate();
              return DateTime(t.year + 1, t.month, t.day);
            }(),
          ),
          const SizedBox(height: 12),
          TextField(controller: _descCtrl, decoration: InputDecoration(labelText: l.descriptionOptional)),
          const SizedBox(height: 12),
          MerchantField(controller: _merchCtrl),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // Categories load async; only select once the item exists.
            // Rebuilt when the type flips too, so a cleared selection shows as cleared.
            key: ValueKey('${cats.length}-$_type'),
            initialValue: typeCats.any((c) => c.id == _catId) ? _catId : null,
            decoration: InputDecoration(labelText: l.categoryOptional),
            items: typeCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _catId = v),
          ),
          AccountField(value: _accountId, onChanged: (v) => setState(() => _accountId = v)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) {
                setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
                return;
              }
              final fils = parseAmount(_amtCtrl.text)!;
              final desc = _descCtrl.text.trim();
              final merch = _merchCtrl.text.trim();
              // Saved as typed (maybe empty): the fallback title is filled in when
              // shown, so it follows the UI language instead of the one at save time.
              Navigator.pop(context, _TxDraft(fils, _type, desc, date: _date, merchant: merch.isEmpty ? null : merch, categoryId: _catId, accountId: _accountId));
            },
            child: Text(l.save),
          ),
          ]),
        ),
      )),
    );
  }
}

typedef _Option<T> = ({String label, T value, Widget? leading});

/// A list to pick one filter value from, with a search box once it's long.
class _FilterPicker<T> extends StatefulWidget {
  const _FilterPicker({super.key, required this.title, required this.options});
  final String title;
  final List<_Option<T>> options;

  @override
  State<_FilterPicker<T>> createState() => _FilterPickerState<T>();
}

class _FilterPickerState<T> extends State<_FilterPicker<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _query.trim().toLowerCase();
    final shown = [for (final o in widget.options) if (q.isEmpty || o.label.toLowerCase().contains(q)) o];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (widget.options.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: l.search, isDense: true, prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          if (widget.options.isEmpty || shown.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l.noMatchingTransactions, textAlign: TextAlign.center))
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final o in shown) ListTile(leading: o.leading, title: Text(o.label), onTap: () => Navigator.pop(context, o.value)),
              ]),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
