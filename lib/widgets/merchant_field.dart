import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';

/// The optional merchant field of the transaction and recurring forms. As
/// you type it suggests merchants from the list, and when nothing there is
/// like what's typed, offers to add it. The controller holds the name.
class MerchantField extends StatefulWidget {
  const MerchantField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<MerchantField> createState() => _MerchantFieldState();
}

class _MerchantFieldState extends State<MerchantField> {
  List<Merchant> _merchants = [];

  @override
  void initState() {
    super.initState();
    FinanceRepo().merchants().then((m) {
      if (mounted) setState(() => _merchants = m);
    }).catchError((_) {});
  }

  /// Adds what's typed to the merchant list and refreshes the suggestions.
  /// The field keeps the typed name, so the form is saved with it selected.
  Future<void> _create() async {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return;
    try {
      await FinanceRepo().insertMerchant(name);
      final merchants = await FinanceRepo().merchants();
      if (!mounted) return;
      setState(() => _merchants = merchants);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Suggestions: everything that contains what's typed, shown while the
    // text isn't yet an exact (case-insensitive) hit. When there is nothing
    // like it in the list, offer to create it.
    final query = widget.controller.text.trim().toLowerCase();
    final exists = query.isNotEmpty && _merchants.any((m) => m.name.toLowerCase() == query);
    final matches = query.isEmpty || exists
        ? const <Merchant>[]
        : _merchants.where((m) => m.name.toLowerCase().contains(query)).take(3).toList();
    final prompt = query.isNotEmpty && !exists && matches.isEmpty;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: widget.controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: l.merchantOptional, hintText: l.merchantSearchHint),
      ),
      for (final m in matches)
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storefront, size: 18),
          title: Text(m.name),
          onTap: () => setState(() => widget.controller.text = m.name),
        ),
      if (prompt)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            Expanded(child: Text(l.merchantNotFound, style: Theme.of(context).textTheme.bodyMedium)),
            TextButton(onPressed: _create, child: Text(l.createMerchant)),
          ]),
        ),
    ]);
  }
}
