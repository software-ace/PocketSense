import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'app_lock.dart';

/// PIN entry: dots for what's typed and a phone-style keypad. Also takes
/// digits, Backspace and Enter from a hardware keyboard (Linux).
///
/// With [length] set, submits as soon as that many digits are in; otherwise
/// shows a Continue button once [AppLock.minLength] digits are typed.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onSubmit,
    this.length,
    this.message,
    this.messageIsError = true,
    this.enabled = true,
    this.leadingKey,
  });

  final String title;
  final int? length;

  /// Gets the typed PIN; the pad clears once this completes.
  final Future<void> Function(String pin) onSubmit;
  final String? message;
  final bool messageIsError;
  final bool enabled;

  /// Optional key left of 0, e.g. the biometric button.
  final Widget? leadingKey;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;
  final _focus = FocusNode();

  int get _max => widget.length ?? AppLock.maxLength;
  bool get _canType => widget.enabled && !_busy;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (!_canType || _pin.length >= _max) return;
    setState(() => _pin += d);
    if (widget.length != null && _pin.length == widget.length) _submit();
  }

  void _backspace() {
    if (!_canType || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_busy || _pin.length < AppLock.minLength) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_pin);
    } finally {
      if (mounted) {
        setState(() {
          _pin = '';
          _busy = false;
        });
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _digit(ch);
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
    } else if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    Widget key(String d) => _Key(onTap: _canType ? () => _digit(d) : null, child: Text(d, style: theme.textTheme.headlineSmall));

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        // Dots: filled for typed digits; with a known length, hollow for the rest.
        Semantics(
          label: '${_pin.length}',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < (widget.length ?? (_pin.length < AppLock.minLength ? AppLock.minLength : _pin.length)); i++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? scheme.primary : Colors.transparent,
                  border: Border.all(color: i < _pin.length ? scheme.primary : scheme.outline, width: 2),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: widget.message == null
                ? null
                : Text(widget.message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: widget.messageIsError ? scheme.error : scheme.outline)),
          ),
        ),
        // Keypads read left-to-right in every language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: _Key.size, height: _Key.size, child: widget.leadingKey),
              key('0'),
              _Key(
                onTap: _canType && _pin.isNotEmpty ? _backspace : null,
                tooltip: l.deleteDigit,
                child: const Icon(Icons.backspace_outlined),
              ),
            ]),
          ]),
        ),
        if (widget.length == null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canType && _pin.length >= AppLock.minLength ? _submit : null,
            child: Text(l.continueAction),
          ),
        ],
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, this.onTap, this.tooltip});

  static const size = 76.0;
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          shape: const CircleBorder(),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Center(child: child)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
