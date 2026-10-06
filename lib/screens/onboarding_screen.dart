import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../security/app_lock.dart';
import '../security/biometrics.dart';
import '../security/pin_flows.dart';
import '../settings/app_settings.dart';
import '../settings/language_picker.dart';
import 'backup_actions.dart';

/// First run: 1) import a backup or start fresh, 2) set a PIN, then offer
/// biometric unlock where available. Each step is saved as it completes
/// ([AppSettings.onboardingStep]), so quitting part-way resumes there.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.importer});

  final VoidCallback onDone;

  /// Picks and imports a backup; returns whether it worked. Replaced in tests.
  final Future<bool> Function(BuildContext context)? importer;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int _step = AppSettings.onboardingStep.clamp(0, 1);
  bool _offerBiometrics = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toSecurity() async {
    await AppSettings.setOnboardingStep(1);
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _import() => _run(() async {
        final importer = widget.importer ?? (c) => importBackup(c, confirmReplace: false);
        if (await importer(context)) await _toSecurity();
      });

  Future<void> _setPin() => _run(() async {
        if (!await chooseNewPin(context)) return;
        if (await Biometrics.instance.available()) {
          if (mounted) setState(() => _offerBiometrics = true);
        } else {
          await _finish();
        }
      });

  Future<void> _enableBiometrics() => _run(() async {
        // Proves the enrolled biometric works before relying on it.
        if (await Biometrics.instance.authenticate(context.l10n.biometricReason)) {
          await AppLock.instance.setBiometrics(true);
        }
        await _finish();
      });

  Future<void> _finish() async {
    await AppSettings.setOnboardingStep(AppSettings.onboardingDone);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final Widget body = switch ((_step, _offerBiometrics)) {
      (0, _) => _Page(
          icon: Icons.account_balance_wallet_rounded,
          title: l.welcomeTitle,
          body: l.welcomeBody,
          hint: l.backupLaterHint,
          // First, so the rest of the setup (and the starter categories'
          // names) is in the right language.
          top: Center(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => pickLanguage(context),
              icon: const Icon(Icons.translate, size: 18),
              label: Text(languageNames[Localizations.localeOf(context).languageCode] ?? l.language),
            ),
          ),
          children: [
            _Choice(
              icon: Icons.restore_page_outlined,
              title: l.importBackupOption,
              subtitle: l.importBackupOptionSubtitle,
              onTap: _busy ? null : _import,
            ),
            const SizedBox(height: 12),
            _Choice(
              icon: Icons.add_circle_outline,
              title: l.startFresh,
              subtitle: l.startFreshSubtitle,
              onTap: _busy ? null : () => _run(_toSecurity),
            ),
          ],
        ),
      (_, false) => _Page(
          icon: Icons.lock_outline,
          title: l.secureTitle,
          body: l.secureBody,
          hint: l.securityLaterHint,
          children: [
            FilledButton.icon(onPressed: _busy ? null : _setPin, icon: const Icon(Icons.pin_outlined), label: Text(l.setPin)),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : () => _run(_finish), child: Text(l.skipForNow)),
          ],
        ),
      (_, true) => _Page(
          icon: Icons.fingerprint,
          title: l.biometricOfferTitle,
          body: l.biometricOfferBody,
          children: [
            FilledButton(onPressed: _busy ? null : _enableBiometrics, child: Text(l.turnOn)),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : () => _run(_finish), child: Text(l.notNow)),
          ],
        ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.onboardingStep(_step + 1, 2),
                    textAlign: TextAlign.center, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 8),
                // Two short bars, like a page indicator.
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _step ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ]),
                const SizedBox(height: 32),
                AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: KeyedSubtree(key: ValueKey((_step, _offerBiometrics)), child: body)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.icon, required this.title, required this.body, required this.children, this.hint, this.top});

  final Widget? top;
  final IconData icon;
  final String title;
  final String body;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (top != null) ...[top!, const SizedBox(height: 24)],
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
        ),
      ),
      const SizedBox(height: 24),
      Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 32),
      ...children,
      if (hint != null) ...[
        const SizedBox(height: 24),
        Text(hint!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
      ],
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
        leading: Icon(icon, color: scheme.primary, size: 28),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
