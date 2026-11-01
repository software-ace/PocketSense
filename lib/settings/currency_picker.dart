import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/format.dart';
import 'app_settings.dart';

/// The currency chooser used by Settings and the welcome screen. Returns
/// whether the currency changed. [existingData]: amounts are already
/// recorded, so say that they won't be converted.
Future<bool> pickCurrency(BuildContext context, {bool existingData = false}) async {
  final l = context.l10n;
  // People often know a currency by its English name or code, so those
  // match in Arabic too.
  final english = lookupAppLocalizations(const Locale('en'));
  var query = '';
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final theme = Theme.of(ctx);
      final q = query.trim().toLowerCase();
      final shown = [
        for (final c in currencies)
          if ('${c.code} ${l.currencyName(c.code)} ${english.currencyName(c.code)}'.toLowerCase().contains(q)) c,
      ];
      return Dialog(
        // A fixed height, so the dialog doesn't jump around while the list
        // filters; only the list scrolls, so the search field stays put.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(l.currency, style: theme.textTheme.headlineSmall),
            ),
            if (existingData)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(l.currencyChangeNote, style: theme.textTheme.bodySmall),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: l.search,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(l.noCurrencyMatches, style: theme.textTheme.bodyMedium))
                  : RadioGroup<String>(
                      groupValue: appCurrency.code,
                      onChanged: (v) => Navigator.pop(ctx, v),
                      child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
                        for (final c in shown)
                          RadioListTile<String>(
                            value: c.code,
                            title: Text(l.currencyName(c.code)),
                            secondary: Text(c.code, style: theme.textTheme.labelLarge),
                          ),
                      ]),
                    ),
            ),
          ]),
        ),
      );
    }),
  );
  final currency = Currency.byCode(picked);
  if (currency == null || currency == appCurrency) return false;
  await AppSettings.setCurrency(currency);
  return true;
}
