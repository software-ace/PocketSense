import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/format.dart';
import 'app_settings.dart';

/// The currency chooser used by Settings and the welcome screen. Returns
/// whether the currency changed. [existingData]: amounts are already
/// recorded, so say that they won't be converted.
Future<bool> pickCurrency(BuildContext context, {bool existingData = false}) async {
  final l = context.l10n;
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l.currency),
      children: [
        if (existingData)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l.currencyChangeNote, style: Theme.of(ctx).textTheme.bodySmall),
          ),
        RadioGroup<String>(
          groupValue: appCurrency.code,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final c in currencies)
              RadioListTile<String>(
                value: c.code,
                title: Text(l.currencyName(c.code)),
                secondary: Text(c.code, style: Theme.of(ctx).textTheme.labelLarge),
              ),
          ]),
        ),
      ],
    ),
  );
  final currency = Currency.byCode(picked);
  if (currency == null || currency == appCurrency) return false;
  await AppSettings.setCurrency(currency);
  return true;
}
