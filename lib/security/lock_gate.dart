import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_lock.dart';
import 'biometrics.dart';
import 'pin_pad.dart';

/// Covers the whole app (every route, via MaterialApp.builder) with the PIN
/// screen when the lock is on: at launch, and when coming back after
/// [relockAfter] in the background. The app stays mounted underneath,
/// offstage, so unlocking returns to exactly where you were.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child, required this.onEraseAll, this.relockAfter = const Duration(seconds: 30)});

  final Widget child;

  /// "Forgot PIN" → erase everything and start over.
  final Future<void> Function() onEraseAll;
  final Duration relockAfter;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool? _locked; // null while checking whether the lock is on
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    AppLock.instance.enabled.then((on) {
      if (mounted) setState(() => _locked = on);
    }, onError: (_) {
      // Keystore unreachable: Boot reports it (the database key lives there too).
      if (mounted) setState(() => _locked = false);
    });
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onHide() => _hiddenAt ??= DateTime.now();

  Future<void> _onShow() async {
    final hidden = _hiddenAt;
    _hiddenAt = null;
    if (hidden == null || DateTime.now().difference(hidden) < widget.relockAfter) return;
    if (await AppLock.instance.enabled && mounted) setState(() => _locked = true);
  }

  Future<void> _erase() async {
    await widget.onEraseAll();
    await AppLock.instance.disable();
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return Stack(children: [
      Offstage(offstage: locked != false, child: TickerMode(enabled: locked == false, child: widget.child)),
      if (locked == null) const ColoredBox(color: Colors.black, child: SizedBox.expand()),
      if (locked == true)
        // Its own Navigator: the app's is underneath, and "Forgot PIN" needs dialogs.
        // HeroControllerScope.none: otherwise it takes MaterialApp's HeroController
        // from the app's Navigator and leaves it ownerless when unlocked, which
        // breaks every later push (buttons stop working, only the nav bar survives).
        HeroControllerScope.none(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => LockScreen(onUnlocked: () => setState(() => _locked = false), onEraseAll: _erase),
            ),
          ),
        ),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked, required this.onEraseAll});

  final VoidCallback onUnlocked;
  final Future<void> Function() onEraseAll;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _lock = AppLock.instance;
  int? _length;
  String? _message;
  Duration? _wait;
  Timer? _tick;
  bool _biometrics = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final length = await _lock.pinLength;
    final wait = await _lock.waitRemaining();
    final bio = await _lock.biometricsEnabled && await Biometrics.instance.available();
    if (!mounted) return;
    setState(() {
      _length = length;
      _biometrics = bio;
    });
    if (wait != null) _startWait(wait);
    if (bio && wait == null) _tryBiometrics();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _startWait(Duration wait) {
    final until = DateTime.now().add(wait);
    _tick?.cancel();
    void update() {
      final left = until.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _wait = left > Duration.zero ? left : null;
        _message = _wait == null ? null : context.l10n.tooManyAttempts((left.inMilliseconds / 1000).ceil());
      });
      if (_wait == null) _tick?.cancel();
    }

    update();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  Future<void> _tryBiometrics() async {
    if (await Biometrics.instance.authenticate(context.l10n.biometricReason)) {
      await _lock.unlockedByBiometrics();
      widget.onUnlocked();
    }
  }

  Future<void> _submit(String pin) async {
    final result = await _lock.verify(pin);
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        widget.onUnlocked();
      case PinRejected(:final triesBeforeWait):
        setState(() => _message = context.l10n.wrongPin(triesBeforeWait));
      case PinLockedOut(:final wait):
        _startWait(wait);
    }
  }

  Future<void> _forgot() async {
    final l = context.l10n;
    Future<bool> ask(String title, String body, String action, {bool danger = false}) async =>
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(
                style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
        ) ==
        true;
    // Two steps on purpose: this deletes everything.
    if (!await ask(l.forgotPin, l.forgotPinBody, l.continueAction)) return;
    if (!mounted || !await ask(l.eraseAllTitle, l.eraseAllBody, l.erase, danger: true)) return;
    await widget.onEraseAll();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _length == null
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline, size: 40, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    PinPad(
                      title: l.enterPin,
                      length: _length,
                      enabled: _wait == null,
                      message: _message,
                      onSubmit: _submit,
                      leadingKey: _biometrics
                          ? IconButton(
                              tooltip: l.biometricUnlock,
                              iconSize: 32,
                              icon: const Icon(Icons.fingerprint),
                              onPressed: _wait == null ? _tryBiometrics : null,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _forgot, child: Text(l.forgotPin)),
                  ]),
          ),
        ),
      ),
    );
  }
}
