import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../security/amount_privacy.dart';
import '../settings/manage_accounts_screen.dart';
import '../utils/format.dart';
import '../widgets/amount_field.dart';
import '../widgets/data_aware.dart';
import '../widgets/state_views.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'transactions_screen.dart';

/// An account's icon and color by kind. Savings is a vault, never a piggy bank.
(IconData, Color) accountLook(String kind) => switch (kind) {
      'bank' => (Icons.account_balance_outlined, Colors.indigo),
      'savings' => (Icons.lock_outline, Colors.amber.shade800),
      'card' => (Icons.credit_card, Colors.pink),
      _ => (Icons.payments_outlined, Colors.green),
    };

Widget accountAvatar(String kind, {double radius = 20}) {
  final (icon, color) = accountLook(kind);
  return CircleAvatar(radius: radius, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: radius));
}

/// Home → Accounts: every open account with its balance. Transfer moves
/// money between them; Manage (Settings → Accounts) adds and edits them.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, this.tab = false});

  /// A desktop rail tab rather than a page pushed from Home: it gets the
  /// other tabs' app bar buttons.
  final bool tab;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with DataAware {
  List<Account>? _accounts;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await FinanceRepo().accounts();
    if (mounted) setState(() => _accounts = a);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final accounts = _accounts;
    final open = [for (final a in accounts ?? const <Account>[]) if (!a.closed) a];
    final total = (accounts ?? const <Account>[]).fold(0, (sum, a) => sum + a.balanceFils);
    return Scaffold(
      appBar: AppBar(title: Text(l.accounts), actions: widget.tab ? const [AmountsButton(), SyncButton(), SettingsButton()] : null),
      body: accounts == null
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.totalBalance, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(formatMoney(total), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(l.transferNotIncome, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final a in open) AccountTile(account: a),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                if (open.length > 1) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showTransferSheet(context),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l.transfer),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageAccountsScreen())),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.manageAccounts),
                  ),
                ),
              ]),
            ]),
    );
  }
}

/// One account in a list: tap for its screen.
class AccountTile extends StatelessWidget {
  const AccountTile({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = account;
    return ListTile(
      leading: accountAvatar(a.kind),
      title: Text(a.name),
      subtitle: Text('${l.accountKind(a.kind)} · ${l.accountEntries(a.entries)}'),
      trailing: Text(formatMoney(a.balanceFils), style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen(accountId: a.id))),
    );
  }
}

/// One account: its balance, this month's money in and out, and its entries
/// and transfers, newest first. Tapping a transfer edits it.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.accountId});
  final int accountId;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with DataAware {
  Account? _account;
  Map<int, String> _names = const {};
  List<Transaction> _entries = const [];
  List<Transfer> _transfers = const [];
  ({int income, int expense}) _month = (income: 0, expense: 0);
  bool _loading = true;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = FinanceRepo();
    final id = widget.accountId;
    final now = DateTime.now();
    final accounts = await repo.accounts();
    final entries = await repo.transactions(accountId: id, limit: 1 << 30);
    final transfers = await repo.transfers(accountId: id);
    final month = await repo.totals(DateTime(now.year, now.month), now, accountId: id);
    if (!mounted) return;
    setState(() {
      _account = accounts.where((a) => a.id == id).firstOrNull;
      _names = {for (final a in accounts) a.id: a.name};
      _entries = entries;
      _transfers = transfers;
      _month = month;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final a = _account;
    if (_loading) return Scaffold(appBar: AppBar(), body: const LoadingView());
    // Deleted meanwhile, maybe on another device.
    if (a == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(l.accountGone)));

    // Entries and transfers in one list, newest first.
    final rows = <({DateTime date, Widget tile})>[
      for (final t in _entries)
        (
          date: t.date,
          tile: ListTile(
            leading: CircleAvatar(
              backgroundColor: t.type == 'income' ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest,
              child: Icon(t.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: t.type == 'income' ? Colors.green : null),
            ),
            title: Text(t.description.isEmpty ? (t.merchant ?? (t.type == 'income' ? l.income : l.expense)) : t.description),
            subtitle: Text([?t.merchant, DateFormat.MMMd().format(t.date)].join(' · ')),
            trailing: Text(formatMoney(t.type == 'income' ? t.amountFils : -t.amountFils, showSign: t.type == 'income'),
                style: TextStyle(fontWeight: FontWeight.w600, color: t.type == 'income' ? Colors.green : null)),
          ),
        ),
      for (final t in _transfers)
        (
          date: t.date,
          tile: ListTile(
            leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: Icon(Icons.swap_horiz, size: 18, color: theme.colorScheme.onPrimaryContainer)),
            title: Text(t.fromId == a.id ? l.transferToAccount(_names[t.toId] ?? '—') : l.transferFromAccount(_names[t.fromId] ?? '—')),
            subtitle: Text([l.transfer, ?t.note, DateFormat.MMMd().format(t.date)].join(' · ')),
            trailing: Text(formatMoney(t.fromId == a.id ? -t.amountFils : t.amountFils, showSign: t.toId == a.id),
                style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            onTap: () => showTransferSheet(context, existing: t),
          ),
        ),
    ]..sort((x, y) => y.date.compareTo(x.date));

    final open = !a.closed;
    return Scaffold(
      appBar: AppBar(title: Text(a.closed ? l.accountClosedName(a.name) : a.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.balance, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              Text(formatMoney(a.balanceFils), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _figure(theme, l.incomeThisMonth, formatMoney(_month.income), Colors.green)),
                Expanded(child: _figure(theme, l.spentThisMonth, formatMoney(_month.expense), null)),
              ]),
              if (open) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: FilledButton(onPressed: () => addTransaction(context, accountId: a.id), child: Text(l.addEntry))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showTransferSheet(context, fromId: a.id),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l.transfer),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final r in rows) r.tile,
            ListTile(
              leading: CircleAvatar(backgroundColor: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.horizontal_rule, size: 18)),
              title: Text(l.openingBalance, style: TextStyle(color: theme.colorScheme.outline)),
              trailing: Text(formatMoney(a.openingFils), style: TextStyle(color: theme.colorScheme.outline)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _figure(ThemeData theme, String label, String value, Color? color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ]);
}

/// New transfer (from [fromId] if given), or edit [existing].
Future<void> showTransferSheet(BuildContext context, {Transfer? existing, int? fromId}) async {
  final accounts = await FinanceRepo().accounts();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TransferSheet(accounts: accounts, existing: existing, fromId: fromId),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.accounts, this.existing, this.fromId});
  final List<Account> accounts;
  final Transfer? existing;
  final int? fromId;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final _open = [for (final a in widget.accounts) if (!a.closed || a.id == widget.existing?.fromId || a.id == widget.existing?.toId) a];
  late int? _from = widget.existing?.fromId ?? widget.fromId ?? _open.firstOrNull?.id;
  late int? _to = widget.existing?.toId ?? _open.where((a) => a.id != _from).firstOrNull?.id;
  late final _amountCtrl = TextEditingController(text: widget.existing == null ? '' : amountToInput(widget.existing!.amountFils));
  late final _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  final _formKey = GlobalKey<FormState>();
  var _autovalidate = AutovalidateMode.disabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The preview follows the amount as it's typed.
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Account? _account(int? id) => widget.accounts.where((a) => a.id == id).firstOrNull;

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate() || _from == null || _to == null || _from == _to) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _saving = true);
    final repo = FinanceRepo();
    final fils = parseAmount(_amountCtrl.text)!;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      final e = widget.existing;
      if (e == null) {
        await repo.insertTransfer(fromId: _from!, toId: _to!, amountFils: fils, date: _date, note: note);
      } else {
        await repo.updateTransfer(e.id, fromId: _from!, toId: _to!, amountFils: fils, date: _date, note: note);
      }
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$err'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final fils = parseAmount(_amountCtrl.text) ?? 0;
    // An edit's old amount is already in the balances.
    final old = widget.existing;
    int before(Account a) =>
        a.balanceFils + (old == null ? 0 : (a.id == old.fromId ? old.amountFils : 0) - (a.id == old.toId ? old.amountFils : 0));
    final from = _account(_from), to = _account(_to);
    final same = _from != null && _from == _to;
    // Amounts show here even under Hide amounts: you can't move money blind.
    String money(int f) => formatMoney(f, showHidden: true);
    DropdownButtonFormField<int> picker(String label, int? value, ValueChanged<int?> onChanged) => DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final a in _open) DropdownMenuItem(value: a.id, child: Text('${a.name} · ${money(a.balanceFils)}'))],
          onChanged: onChanged,
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(old == null ? l.transfer : l.editTransfer, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              picker(l.transferFrom, _from, (v) => setState(() => _from = v)),
              Align(
                child: IconButton(
                  tooltip: l.transferSwap,
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => setState(() {
                    final from = _from;
                    _from = _to;
                    _to = from;
                  }),
                ),
              ),
              // Keyed: the swap changes what it shows.
              KeyedSubtree(key: ValueKey('to-$_to-$_from'), child: picker(l.transferTo, _to, (v) => setState(() => _to = v))),
              if (same) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.transferSame, style: TextStyle(color: theme.colorScheme.error))),
              const SizedBox(height: 12),
              AmountField(controller: _amountCtrl, label: l.amount),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l.date, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
                  child: Text(DateFormat.yMMMd().format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _noteCtrl, decoration: InputDecoration(labelText: l.notesOptional)),
              if (from != null && to != null && !same) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.transferAfter, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 6),
                    for (final (a, delta) in [(from, -fils), (to, fils)])
                      Row(children: [
                        Expanded(child: Text(a.name)),
                        Text(money(before(a) + delta), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    const SizedBox(height: 6),
                    Text(l.transferNotIncome, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    if (before(from) - fils < 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l.transferBelowZero(from.name), style: TextStyle(color: Colors.orange.shade800)),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
              if (old != null)
                TextButton(
                  onPressed: () async {
                    await FinanceRepo().deleteTransfer(old.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text(l.deleteTransfer),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
