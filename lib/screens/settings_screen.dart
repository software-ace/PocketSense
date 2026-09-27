import 'package:flutter/material.dart';

import 'categories_screen.dart';

/// Home for app configuration. Categories live here rather than in the main
/// navigation: they're set up once and rarely touched afterwards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Data', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.category_rounded),
            title: const Text('Categories'),
            subtitle: const Text('Income and expense categories'),
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
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      );
}
