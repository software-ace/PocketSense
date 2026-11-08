import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';

/// Which account an entry or recurring item is in. Lists the open accounts,
/// plus [value]'s own account even if it's closed, so editing an old entry
/// never moves it by itself. With nothing to choose (one account), it
/// doesn't show: someone with only Cash sees the form as it always was.
/// [value] null means the default account, which it selects once loaded.
class AccountField extends StatefulWidget {
  const AccountField({super.key, required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  State<AccountField> createState() => _AccountFieldState();
}

class _AccountFieldState extends State<AccountField> {
  List<Account> _accounts = const [];
  int? _default;

  @override
  void initState() {
    super.initState();
    final repo = FinanceRepo();
    Future.wait([repo.accounts(), repo.defaultAccountId()]).then((r) {
      if (!mounted) return;
      setState(() {
        _accounts = r[0] as List<Account>;
        _default = r[1] as int;
      });
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selected = widget.value ?? _default;
    final choices = [for (final a in _accounts) if (!a.closed || a.id == selected) a];
    if (choices.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<int>(
        // Rebuilt once loaded, so the default shows as selected.
        key: ValueKey('${_accounts.length}-$selected'),
        initialValue: choices.any((a) => a.id == selected) ? selected : null,
        decoration: InputDecoration(labelText: l.account),
        items: [
          for (final a in choices)
            DropdownMenuItem(value: a.id, child: Text(a.closed ? l.accountClosedName(a.name) : a.name)),
        ],
        onChanged: (v) {
          if (v != null) widget.onChanged(v);
        },
      ),
    );
  }
}
