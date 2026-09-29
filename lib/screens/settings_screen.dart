import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../settings/app_settings.dart';
import 'categories_screen.dart';

/// Home for app configuration. Categories live here rather than in the main
/// navigation: they're set up once and rarely touched afterwards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Language names are written in their own language, so a person can find
  // theirs whatever the UI is currently showing.
  static const _languageNames = {'en': 'English', 'ar': 'العربية'};

  Future<void> _pickLanguage(BuildContext context) async {
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
              for (final e in _languageNames.entries) RadioListTile<String>(value: e.key, title: Text(e.value)),
            ]),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await AppSettings.setLocale(picked.isEmpty ? null : Locale(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    Widget header(String text) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
          child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          header(l.settingsGeneral),
          ValueListenableBuilder<Locale?>(
            valueListenable: AppSettings.locale,
            builder: (context, locale, _) => ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l.language),
              subtitle: Text(locale == null ? l.languageSystem : _languageNames[locale.languageCode]!),
              onTap: () => _pickLanguage(context),
            ),
          ),
          header(l.settingsData),
          ListTile(
            leading: const Icon(Icons.category_rounded),
            title: Text(l.categories),
            subtitle: Text(l.categoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
        ],
      ),
    );
  }
}

/// Gear icon for the app-bar corner; opens [SettingsScreen].
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.l10n.settings,
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      );
}
