import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../screens/accounts_screen.dart';
import '../utils/format.dart';
import '../widgets/data_aware.dart';
import '../widgets/state_views.dart';

/// Settings → Data → Accounts: add, edit, close, reopen and delete them.
class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> with DataAware {
  List<Account>? _accounts;
  int? _default;
  bool _showClosed = false;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = FinanceRepo();
    final accounts = await repo.accounts();
    final def = await repo.defaultAccountId();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _default = def;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final accounts = _accounts;
    if (accounts == null) return Scaffold(appBar: AppBar(title: Text(l.accounts)), body: const LoadingView());
    final open = [for (final a in accounts) if (!a.closed) a];
    final closed = [for (final a in accounts) if (a.closed) a];
    return Scaffold(
      appBar: AppBar(title: Text(l.accounts)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final a in open)
              ListTile(
                leading: accountAvatar(a.kind),
                title: Row(children: [
                  Flexible(child: Text(a.name)),
                  if (a.id == _default) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(6)),
                      child: Text(l.defaultBadge, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                    ),
                  ],
                ]),
                subtitle: Text('${l.accountKind(a.kind)} · ${formatMoney(a.balanceFils)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAccountForm(context, existing: a),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => showAccountForm(context), icon: const Icon(Icons.add), label: Text(l.newAccount)),
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.closedAccounts(closed.length), style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.outline)),
            trailing: Icon(_showClosed ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _showClosed = !_showClosed),
          ),
          if (_showClosed)
            for (final a in closed)
              ListTile(
                leading: accountAvatar(a.kind),
                title: Text(a.name),
                subtitle: Text(l.accountEntries(a.entries)),
                trailing: OutlinedButton(onPressed: () => FinanceRepo().reopenAccount(a.id), child: Text(l.reopen)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen(accountId: a.id))),
              ),
        ],
        const SizedBox(height: 12),
        Text(l.closedAccountsNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ]),
    );
  }
}

/// New account, or edit [existing] (where Close and Delete live).
Future<void> showAccountForm(BuildContext context, {Account? existing}) async {
  final repo = FinanceRepo();
  final accounts = await repo.accounts();
  final def = await repo.defaultAccountId();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AccountForm(existing: existing, accounts: accounts, isDefault: existing?.id == def),
  );
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.existing, required this.accounts, required this.isDefault});
  final Account? existing;
  final List<Account> accounts;
  final bool isDefault;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _openingCtrl = TextEditingController(text: _openingText(widget.existing?.openingFils ?? 0));
  late String _kind = widget.existing?.kind ?? 'bank';
  late bool _makeDefault = widget.isDefault;
  final _formKey = GlobalKey<FormState>();
  var _autovalidate = AutovalidateMode.disabled;

  static String _openingText(int fils) => fils == 0 ? '' : (fils < 0 ? '-${amountToInput(-fils)}' : amountToInput(fils));

  // Empty is 0; a leading minus is what a card owes.
  static int? _parseOpening(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final negative = t.startsWith('-') || t.startsWith('−');
    final fils = parseAmount(negative ? t.substring(1) : t);
    return fils == null ? null : (negative ? -fils : fils);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final repo = FinanceRepo();
    final name = _nameCtrl.text.trim(), opening = _parseOpening(_openingCtrl.text)!;
    final e = widget.existing;
    final int id;
    if (e == null) {
      id = await repo.insertAccount(name: name, kind: _kind, openingFils: opening);
    } else {
      await repo.updateAccount(e.id, name: name, kind: _kind, openingFils: opening);
      id = e.id;
    }
    if (_makeDefault && !widget.isDefault) await repo.setDefaultAccount(id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final e = widget.existing;
    final openCount = widget.accounts.where((a) => !a.closed).length;
    // The last open account stays: something has to take new entries.
    final canGo = e != null && !e.closed && openCount > 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(e == null ? l.newAccount : l.editAccount, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: e == null,
                decoration: InputDecoration(labelText: l.accountName),
                validator: (v) => (v ?? '').trim().isEmpty ? l.enterDescription : null,
              ),
              const SizedBox(height: 16),
              Text(l.accountKindLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [for (final k in Account.kinds) ButtonSegment(value: k, label: Text(l.accountKind(k)))],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _openingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: l.openingBalance, helperText: l.openingBalanceHint, helperMaxLines: 3),
                validator: (v) => _parseOpening(v ?? '') == null ? l.enterAmount : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.useForNewEntries),
                subtitle: widget.isDefault ? Text(l.useForNewEntriesHint) : null,
                value: _makeDefault,
                // On is changed by turning another account on.
                onChanged: widget.isDefault ? null : (v) => setState(() => _makeDefault = v),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: Text(l.save)),
              if (canGo) ...[
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _closeAccount(context, e, widget.accounts);
                  },
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(l.closeAccount),
                ),
                const SizedBox(height: 4),
                Text(l.closeAccountHint, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteAccount(context, e, widget.accounts);
                  },
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: Text(l.deleteAccount),
                ),
              ] else if (e != null && !e.closed) ...[
                const SizedBox(height: 12),
                Text(l.lastAccountNote, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// Amounts show in these dialogs even under Hide amounts: you can't move
// money blind.
String _money(int fils) => formatMoney(fils, showHidden: true);

/// Close: money left (or owed) and recurring items go to an account picked
/// here; nothing to move, it just asks.
Future<void> _closeAccount(BuildContext context, Account a, List<Account> accounts) async {
  final repo = FinanceRepo();
  final recurring = (await repo.recurring()).where((r) => r.accountId == a.id).length;
  final targets = [for (final t in accounts) if (!t.closed && t.id != a.id) t];
  final needsTarget = a.balanceFils != 0 || recurring > 0;
  if (!context.mounted) return;
  final into = await showDialog<int>(
    context: context,
    builder: (ctx) => _TargetDialog(
      title: ctx.l10n.closeAccountTitle(a.name),
      intro: a.balanceFils > 0
          ? ctx.l10n.closeAccountMoney(a.name, _money(a.balanceFils))
          : a.balanceFils < 0
              ? ctx.l10n.closeAccountOwes(a.name, _money(-a.balanceFils))
              : null,
      notes: [
        if (recurring > 0) ctx.l10n.closeAccountRecurring(recurring),
        ctx.l10n.closeAccountKeeps,
      ],
      targets: needsTarget ? targets : const [],
      delta: a.balanceFils,
      confirm: ctx.l10n.closeAccountConfirm,
      danger: false,
    ),
  );
  if (into == null) return;
  try {
    await repo.closeAccount(a.id, intoId: needsTarget ? into : null);
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
  }
}

/// Delete: everything in it moves to an account picked here, so nothing is
/// lost; closing instead is offered first.
Future<void> _deleteAccount(BuildContext context, Account a, List<Account> accounts) async {
  final targets = [for (final t in accounts) if (!t.closed && t.id != a.id) t];
  final into = await showDialog<int>(
    context: context,
    builder: (ctx) => _TargetDialog(
      title: ctx.l10n.deleteAccountTitle(a.name),
      intro: ctx.l10n.deleteAccountBody(a.entries),
      notes: [ctx.l10n.deleteAccountNoUndo],
      targets: targets,
      delta: a.balanceFils,
      confirm: ctx.l10n.deleteAccountConfirm,
      danger: true,
    ),
  );
  if (into == null) return;
  try {
    await FinanceRepo().deleteAccount(a.id, intoId: into);
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed('$e'))));
  }
}

/// Close's and Delete's dialog: pick where things go, with each target's
/// balance before and after. No [targets]: a plain confirm. Pops the
/// target's id, or 0 when there's none to pick.
class _TargetDialog extends StatefulWidget {
  const _TargetDialog({
    required this.title,
    required this.intro,
    required this.notes,
    required this.targets,
    required this.delta,
    required this.confirm,
    required this.danger,
  });
  final String title;
  final String? intro;
  final List<String> notes;
  final List<Account> targets;
  final int delta;
  final String confirm;
  final bool danger;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late int? _into = widget.targets.firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final picked = widget.targets.where((t) => t.id == _into).firstOrNull;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.intro != null) Text(widget.intro!),
          if (widget.targets.isNotEmpty)
            RadioGroup<int>(
              groupValue: _into,
              onChanged: (v) => setState(() => _into = v),
              child: Column(children: [
                for (final t in widget.targets)
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: t.id,
                    title: Text(t.name),
                    subtitle: Text('${_money(t.balanceFils)} → ${_money(t.balanceFils + widget.delta)}'),
                  ),
              ]),
            ),
          if (picked != null) Text(l.becomesDefaultIfDefault(picked.name), style: theme.textTheme.bodySmall),
          for (final n in widget.notes) Padding(padding: const EdgeInsets.only(top: 8), child: Text(n, style: theme.textTheme.bodySmall)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          style: widget.danger ? FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError) : null,
          onPressed: widget.targets.isEmpty ? () => Navigator.pop(context, 0) : (_into == null ? null : () => Navigator.pop(context, _into)),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
