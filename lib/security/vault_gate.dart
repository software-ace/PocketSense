import 'dart:io';

import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/db_key.dart';
import '../data/local_store.dart';
import '../data/passphrase_vault.dart';
import '../l10n/l10n.dart';

/// What [VaultGate] shows: the app ([none]), the passphrase screen, or a
/// new-passphrase screen.
enum VaultNeed { none, unlock, create }

/// Linux without a system keyring: asks for the [PassphraseVault]'s
/// passphrase, or for a new one on a fresh install, before anything below
/// reads a secret. With a keyring, and on other platforms, it's just [child].
class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.onErase, required this.child});

  /// Erases all data and starts over, after "Forgot passphrase?".
  final Future<void> Function() onErase;
  final Widget child;

  @override
  State<VaultGate> createState() => _VaultGateState();

  /// The checks run in order and only as far as needed: asking for the
  /// keyring can show an unlock prompt.
  @visibleForTesting
  static Future<VaultNeed> decide({
    required bool linux,
    required bool vaultOpen,
    required Future<bool> Function() vaultExists,
    required Future<bool> Function() keyringAvailable,
    required Future<bool> Function() dataExists,
  }) async {
    if (!linux || vaultOpen) return VaultNeed.none;
    // Once there's a vault, it holds the keys, keyring or not.
    if (await vaultExists()) return VaultNeed.unlock;
    if (await keyringAvailable()) return VaultNeed.none;
    // Data made with a keyring that's only down for now: its key is in there,
    // so Boot's "Try again" is the way forward, not a vault without that key.
    if (await dataExists()) return VaultNeed.none;
    return VaultNeed.create;
  }
}

class _VaultGateState extends State<VaultGate> {
  VaultNeed? _need; // null while checking

  @override
  void initState() {
    super.initState();
    VaultGate.decide(
      linux: Platform.isLinux,
      vaultOpen: PassphraseVault.current != null,
      vaultExists: () => PassphraseVault.file().exists(),
      keyringAvailable: SecureStore.keyringAvailable,
      dataExists: () async => File(await LocalStore.path()).exists(),
    ).then((need) => mounted ? setState(() => _need = need) : null);
  }

  Future<void> _opened(PassphraseVault vault, {required bool erase}) async {
    PassphraseVault.current = vault;
    if (erase) await widget.onErase();
    if (mounted) setState(() => _need = VaultNeed.none);
  }

  @override
  Widget build(BuildContext context) => switch (_need) {
        VaultNeed.none => widget.child,
        null => const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        // Its own Navigator, for "Forgot passphrase?"'s dialog, as LockGate does.
        _ => HeroControllerScope.none(
            child: Navigator(
              key: ValueKey(_need),
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _PassphraseScreen(
                  create: _need == VaultNeed.create,
                  onOpened: _opened,
                ),
              ),
            ),
          ),
      };
}

class _PassphraseScreen extends StatefulWidget {
  const _PassphraseScreen({required this.create, required this.onOpened});
  final bool create;
  final Future<void> Function(PassphraseVault vault, {required bool erase}) onOpened;

  @override
  State<_PassphraseScreen> createState() => _PassphraseScreenState();
}

class _PassphraseScreenState extends State<_PassphraseScreen> {
  late bool _create = widget.create;
  // After "Forgot passphrase?": the old data goes once the new vault is made.
  bool _erase = false;
  final _passCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _wrong;
  bool _busy = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _wrong = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final vault = _create ? await PassphraseVault.create(_passCtrl.text) : await PassphraseVault.open(_passCtrl.text);
      await widget.onOpened(vault, erase: _erase);
    } on BackupException {
      if (mounted) setState(() => _wrong = context.l10n.vaultWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.eraseAllTitle),
        content: Text(l.vaultForgotBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.erase),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The data stays until a new passphrase is set; quitting now just asks again.
    setState(() {
      _create = _erase = true;
      _passCtrl.clear();
      _wrong = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(_create ? l.vaultCreateTitle : l.vaultUnlockTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(_create ? l.vaultCreateBody : l.vaultUnlockBody, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l.vaultPassphrase, errorText: _wrong, errorMaxLines: 2),
                    onFieldSubmitted: _create ? null : (_) => _submit(),
                    validator: (v) => _create && (v ?? '').length < PassphraseVault.minLength ? l.passwordTooShort(PassphraseVault.minLength) : null,
                  ),
                  if (_create) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _repeatCtrl,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l.vaultRepeat),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => v != _passCtrl.text ? l.vaultMismatch : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_create ? l.continueAction : l.unlock),
                  ),
                  if (!_create) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : _forgot, child: Text(l.vaultForgot)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
