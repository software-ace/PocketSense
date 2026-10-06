import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backup.dart';
import '../l10n/l10n.dart';
import '../security/app_lock.dart';
import '../security/biometrics.dart';
import '../security/pin_flows.dart';
import '../settings/app_settings.dart';
import '../settings/language_picker.dart';
import '../utils/format.dart';
import 'backup_actions.dart';
import 'categories_screen.dart';
import 'sync_screen.dart';

/// Home for app configuration. Categories live here rather than in the main
/// navigation: they're set up once and rarely touched afterwards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              subtitle: Text(locale == null ? l.languageSystem : languageNames[locale.languageCode]!),
              onTap: () => pickLanguage(context),
            ),
          ),
          header(l.security),
          const _SecuritySection(),
          header(l.settingsData),
          ListTile(
            leading: const Icon(Icons.category_rounded),
            title: Text(l.categories),
            subtitle: Text(l.categoriesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          header(l.syncSection),
          const SyncSection(),
          header(l.backup),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l.exportData),
            subtitle: Text(l.exportDataSubtitle),
            onTap: () => exportBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore_page_outlined),
            title: Text(l.importData),
            subtitle: Text(l.importDataSubtitle),
            onTap: () => importBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l.backupPassword),
            subtitle: Text(l.backupPasswordSubtitle),
            onTap: () async {
              final changing = await BackupPassword.read() != null;
              if (context.mounted) await setBackupPassword(context, changing: changing);
            },
          ),
          ValueListenableBuilder(
            valueListenable: AppSettings.autoBackup,
            builder: (context, auto, _) => SwitchListTile(
              secondary: const Icon(Icons.schedule),
              title: Text(l.autoBackup),
              subtitle: Text([
                auto.dir == null ? l.autoBackupOff : l.autoBackupOn(auto.dir!),
                if (auto.error != null) l.autoBackupFailed(auto.error!)
                else if (auto.last != null) l.autoBackupLast(formatDate(DateTime.parse(auto.last!))),
              ].join('\n')),
              isThreeLine: auto.dir != null,
              value: auto.dir != null,
              onChanged: (on) => on ? enableAutoBackup(context) : AppSettings.setAutoBackupDir(null),
            ),
          ),
          header(l.about),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: l.appTitle,
            // pubspec.yaml's version, passed in by `flutter build`/`run`.
            applicationVersion: const String.fromEnvironment('FLUTTER_BUILD_NAME'),
            applicationIcon: Image.asset('assets/splash_icon.png', width: 48, height: 48),
            applicationLegalese: l.aboutLegalese,
            aboutBoxChildren: [
              const SizedBox(height: 16),
              Text(l.aboutDescription),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://github.com/software-ace/PocketSense'), mode: LaunchMode.externalApplication),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    // One-colour mark, tinted so it shows in light and dark themes.
                    Image.asset('assets/github.png', width: 20, height: 20, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('github.com/software-ace/PocketSense',
                          style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// App lock on/off, change PIN, and (Android) biometric unlock. Changes to
/// an existing lock ask for the current PIN first.
class _SecuritySection extends StatefulWidget {
  const _SecuritySection();

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  bool? _enabled;
  bool _biometrics = false;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final lock = AppLock.instance;
    final enabled = await lock.enabled;
    final bio = await lock.biometricsEnabled;
    final available = await Biometrics.instance.available();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _biometrics = bio;
        _biometricsAvailable = available;
      });
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _toggleLock(bool on) async {
    final l = context.l10n;
    if (on) {
      if (await chooseNewPin(context)) _toast(l.pinSet);
    } else if (await confirmCurrentPin(context)) {
      await AppLock.instance.disable();
    }
    await _refresh();
  }

  Future<void> _changePin() async {
    final l = context.l10n;
    if (!await confirmCurrentPin(context) || !mounted) return;
    if (await chooseNewPin(context)) _toast(l.pinChanged);
    await _refresh();
  }

  Future<void> _toggleBiometrics(bool on) async {
    // Turning it on proves the enrolled biometric works before relying on it.
    if (on && !await Biometrics.instance.authenticate(context.l10n.biometricReason)) return;
    await AppLock.instance.setBiometrics(on);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final enabled = _enabled;
    if (enabled == null) return const SizedBox(height: 56);
    return Column(children: [
      SwitchListTile(
        secondary: const Icon(Icons.lock_outline),
        title: Text(l.appLock),
        subtitle: Text(l.appLockSubtitle),
        value: enabled,
        onChanged: _toggleLock,
      ),
      if (enabled) ...[
        ListTile(leading: const Icon(Icons.pin_outlined), title: Text(l.changePin), onTap: _changePin),
        if (_biometricsAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l.useBiometrics),
            value: _biometrics,
            onChanged: _toggleBiometrics,
          ),
      ],
    ]);
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
