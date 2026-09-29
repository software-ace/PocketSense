import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'app_lock.dart';
import 'pin_pad.dart';

/// Full-screen PIN steps used from Settings.

/// Asks for a new PIN twice and saves it. Returns true once it's set.
Future<bool> chooseNewPin(BuildContext context) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _NewPinPage())) == true;

/// Asks for the current PIN (with the same throttling as the lock screen).
/// Returns true if it was entered correctly; true straight away if no PIN is set.
Future<bool> confirmCurrentPin(BuildContext context) async {
  if (!await AppLock.instance.enabled) return true;
  if (!context.mounted) return false;
  return await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _CurrentPinPage())) == true;
}

class _NewPinPage extends StatefulWidget {
  const _NewPinPage();

  @override
  State<_NewPinPage> createState() => _NewPinPageState();
}

class _NewPinPageState extends State<_NewPinPage> {
  String? _first;
  String? _message;

  Future<void> _submit(String pin) async {
    final l = context.l10n;
    if (_first == null) {
      setState(() {
        _first = pin;
        _message = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _message = l.pinsDontMatch;
      });
      return;
    }
    await AppLock.instance.setPin(pin);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.appLock)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PinPad(
            // Keyed by step so the second entry starts empty and refocused.
            key: ValueKey(_first == null),
            title: _first == null ? l.chooseNewPin : l.confirmNewPin,
            // The confirmation must match the first entry's length.
            length: _first?.length,
            message: _message,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _CurrentPinPage extends StatefulWidget {
  const _CurrentPinPage();

  @override
  State<_CurrentPinPage> createState() => _CurrentPinPageState();
}

class _CurrentPinPageState extends State<_CurrentPinPage> {
  int? _length;
  String? _message;
  bool _waiting = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    AppLock.instance.pinLength.then((n) {
      if (mounted) setState(() => _length = n);
    });
    AppLock.instance.waitRemaining().then((w) {
      if (w != null && mounted) _lockedOut(w);
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  void _lockedOut(Duration wait) {
    setState(() {
      _waiting = true;
      _message = context.l10n.tooManyAttempts((wait.inMilliseconds / 1000).ceil());
    });
    _retry?.cancel();
    _retry = Timer(wait, () {
      if (mounted) {
        setState(() {
          _waiting = false;
          _message = null;
        });
      }
    });
  }

  Future<void> _submit(String pin) async {
    final result = await AppLock.instance.verify(pin);
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        Navigator.pop(context, true);
      case PinRejected(:final triesBeforeWait):
        setState(() => _message = context.l10n.wrongPin(triesBeforeWait));
      case PinLockedOut(:final wait):
        _lockedOut(wait);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.appLock)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _length == null
              ? const CircularProgressIndicator()
              : PinPad(title: l.enterCurrentPin, length: _length, enabled: !_waiting, message: _message, onSubmit: _submit),
        ),
      ),
    );
  }
}
