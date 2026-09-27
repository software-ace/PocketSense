import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sync_controller.dart';
import 'categories_screen.dart';

/// Home for app configuration. Categories live here rather than in the main
/// navigation: they're set up once and rarely touched afterwards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static String? get _email {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null; // Supabase not initialized (widget tests)
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final pending = SyncController.instance.status.value.pending;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(pending > 0
            ? '$pending change${pending == 1 ? " hasn't" : "s haven't"} uploaded yet. They stay on this device and upload the next time you sign in here.'
            : 'Your data stays in your account. Sign in again to see it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Pop Settings first; the auth gate then swaps the whole app for sign-in.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await Supabase.instance.client.auth.signOut();
  }

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
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Account', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(_email ?? 'Signed in'),
            subtitle: const Text('Your data is private to this account'),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Log out', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmLogout(context),
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
