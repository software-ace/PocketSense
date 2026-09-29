import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_settings.dart';

/// Language names are written in their own language, so a person can find
/// theirs whatever the UI is currently showing.
const languageNames = {'en': 'English', 'ar': 'العربية'};

/// The language chooser used by Settings and the welcome screen.
Future<void> pickLanguage(BuildContext context) async {
  final l = context.l10n;
  final current = AppSettings.locale.value?.languageCode;
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l.language),
      children: [
        RadioGroup<String>(
          groupValue: current ?? '',
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RadioListTile<String>(value: '', title: Text(l.languageSystem)),
            for (final e in languageNames.entries) RadioListTile<String>(value: e.key, title: Text(e.value)),
          ]),
        ),
      ],
    ),
  );
  if (picked == null) return;
  await AppSettings.setLocale(picked.isEmpty ? null : Locale(picked));
}
