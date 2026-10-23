import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/platform.dart';
import '../widgets/state_views.dart';
import '../widgets/data_aware.dart';

class MerchantsScreen extends StatefulWidget {
  const MerchantsScreen({super.key});
  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> with DataAware {
  final _repo = FinanceRepo();
  List<Merchant> _merchants = [];
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
      final m = await _repo.merchants();
      if (!mounted) return;
      setState(() {
        _merchants = m;
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

  Future<void> _edit(Merchant? existing) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _MerchantDialog(existing: existing, taken: _merchants.map((m) => m.name).toSet()));
    if (saved == true) await _load();
  }

  Future<void> _delete(Merchant m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteNamedTitle(m.name)),
        content: Text(ctx.l10n.deleteMerchantBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteMerchant(m.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.deleteFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = PlatformUi.isDesktop(context);
    final pad = PlatformUi.hPadding(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l.merchants)),
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
                          Expanded(child: Text(l.merchantsShown(_merchants.length), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
                          OutlinedButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add, size: 18), label: Text(l.newMerchant)),
                        ]),
                      ),
                    Expanded(
                      child: _merchants.isEmpty
                          ? Center(child: EmptyView(icon: Icons.storefront, title: l.noMerchants, subtitle: l.noMerchantsHint))
                          : ListView.builder(
                              padding: EdgeInsets.all(pad),
                              itemCount: _merchants.length,
                              itemBuilder: (_, i) {
                                final m = _merchants[i];
                                return Dismissible(
                                  key: ValueKey(m.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(color: Colors.red.shade400, alignment: AlignmentDirectional.centerEnd, padding: const EdgeInsetsDirectional.only(end: 20), child: const Icon(Icons.delete, color: Colors.white)),
                                  onDismissed: (_) => _delete(m),
                                  child: ListTile(
                                    onTap: () => _edit(m),
                                    leading: const CircleAvatar(radius: 18, child: Icon(Icons.storefront)),
                                    title: Text(m.name),
                                    trailing: PopupMenuButton<String>(
                                      tooltip: l.more,
                                      onSelected: (v) {
                                        if (v == 'edit') _edit(m);
                                        if (v == 'delete') _delete(m);
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(ctx.l10n.edit), contentPadding: EdgeInsets.zero)),
                                        PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: Text(ctx.l10n.delete, style: const TextStyle(color: Colors.redAccent)), contentPadding: EdgeInsets.zero)),
                                      ],
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
}

class _MerchantDialog extends StatefulWidget {
  final Merchant? existing;
  final Set<String> taken;
  const _MerchantDialog({this.existing, required this.taken});

  @override
  State<_MerchantDialog> createState() => _MerchantDialogState();
}

class _MerchantDialogState extends State<_MerchantDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final name = _nameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final repo = FinanceRepo();
      if (widget.existing == null) {
        await repo.insertMerchant(name);
      } else {
        await repo.renameMerchant(widget.existing!.id, name);
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
    final l = context.l10n;
    final taken = {
      for (final n in widget.taken) n.toLowerCase(),
      // Not a clash with itself while renaming.
      if (widget.existing != null) widget.existing!.name.toLowerCase(),
    };
    return AlertDialog(
      title: Text(widget.existing == null ? l.newMerchant : l.editMerchant),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: TextFormField(
            controller: _nameCtrl,
            autofocus: widget.existing == null,
            decoration: InputDecoration(labelText: l.name),
            validator: (v) {
              final name = (v ?? '').trim();
              if (name.isEmpty) return l.enterName;
              if (taken.contains(name.toLowerCase())) return l.duplicateMerchant;
              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.save)),
      ],
    );
  }
}
