import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True while a password reset is mid-flight. Verifying the reset code signs
/// the user in *before* the new password is saved; the auth gate holds this
/// screen until both steps finish so the flow can't be cut short.
final ValueNotifier<bool> passwordResetInProgress = ValueNotifier(false);

enum _Mode { signIn, signUp, confirmSignUp, forgot, reset }

/// Sign in, register, confirm email, and reset password — one screen, several
/// modes. Email codes are used instead of links: links have to hand off from
/// the mail app back into this app, which is fragile on Android.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.auth});

  /// Defaults to the app's Supabase client; tests pass a fake.
  final GoTrueClient? auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _minPassword = 8;
  // bcrypt (Supabase's password hash) only reads the first 72 bytes, and the
  // server rejects anything longer — catch it here with a clear message.
  static const _maxPasswordBytes = 72;

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _showPassword = false;
  // Off until the first submit, so nobody gets scolded mid-typing; then on,
  // so each message clears the moment its field is fixed.
  bool _autovalidate = false;
  String? _error;
  String? _info;

  GoTrueClient get _auth => widget.auth ?? Supabase.instance.client.auth;
  String get _emailValue => _email.text.trim();

  @override
  void dispose() {
    for (final c in [_email, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Mode mode, {String? info}) {
    final email = _email.text, password = _password.text;
    // reset() clears validation errors, but it also rewinds each controller to
    // its text at this screen's last build — which can predate what was just
    // typed. Reset first, then set every field explicitly.
    _form.currentState?.reset();
    setState(() {
      _mode = mode;
      _autovalidate = false;
      _error = null;
      _info = info;
      _email.text = email;
      _password.text = mode == _Mode.signIn ? password : '';
      _code.clear();
      _confirm.clear();
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      switch (_mode) {
        case _Mode.signIn:
          await _auth.signInWithPassword(email: _emailValue, password: _password.text);
        case _Mode.signUp:
          final res = await _auth.signUp(email: _emailValue, password: _password.text);
          // With email confirmation off, signUp returns a session and the gate
          // takes over. Otherwise the user must confirm first.
          if (res.session == null && mounted) _go(_Mode.confirmSignUp, info: 'We emailed a code to $_emailValue.');
        case _Mode.confirmSignUp:
          await _auth.verifyOTP(email: _emailValue, token: _code.text.trim(), type: OtpType.signup);
        case _Mode.forgot:
          await _auth.resetPasswordForEmail(_emailValue);
          if (mounted) _go(_Mode.reset, info: 'If an account exists for $_emailValue, a reset code is on its way.');
        case _Mode.reset:
          passwordResetInProgress.value = true;
          try {
            await _auth.verifyOTP(email: _emailValue, token: _code.text.trim(), type: OtpType.recovery);
            await _auth.updateUser(UserAttributes(password: _password.text));
          } finally {
            passwordResetInProgress.value = false;
          }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _friendly(e);
      // Signing in before confirming: jump straight to the code step.
      if (e is AuthException && e.code == 'email_not_confirmed') {
        _go(_Mode.confirmSignUp, info: 'Confirm your email first — enter the code we sent, or resend it.');
        return;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _Mode.reset) {
        await _auth.resetPasswordForEmail(_emailValue);
      } else {
        await _auth.resend(email: _emailValue, type: OtpType.signup);
      }
      if (mounted) setState(() => _info = 'Sent a new code to $_emailValue.');
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _friendly(Object e) {
    if (e is SocketException || e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (e is AuthException) {
      switch (e.code) {
        case 'invalid_credentials':
          return 'Wrong email or password.';
        case 'user_already_exists':
        case 'email_exists':
          return 'An account with this email already exists. Sign in instead.';
        case 'otp_expired':
          return 'That code is wrong or has expired. Request a new one.';
        case 'weak_password':
          return 'That password is too weak. Try a longer one.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Too many attempts. Wait a minute and try again.';
        case 'same_password':
          return 'Choose a password different from your current one.';
        // Server-side failure, e.g. "Database error saving new user" — the
        // raw text means nothing to the user and they can't fix it.
        case 'unexpected_failure':
          return "Couldn't complete that right now. Please try again later.";
      }
      return e.message;
    }
    return 'Something went wrong: $e';
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) => (v == null || v.trim().isEmpty) ? 'Enter your password' : null;

  String? _validateNewPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Enter a password';
    if (s.trim().isEmpty) return "Password can't be only spaces";
    if (s.length < _minPassword) return 'Use at least $_minPassword characters';
    if (utf8.encode(s).length > _maxPasswordBytes) return 'Use at most $_maxPasswordBytes characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Confirm your password';
    return v == _password.text ? null : 'Passwords do not match';
  }

  static String? _validateCode(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter the code from the email';
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'The code is numbers only';
    if (s.length < 6 || s.length > 10) return 'Check the code — it should be 6 to 10 digits';
    return null;
  }

  // A server error describes the last attempt; drop it once the user edits.
  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle, action) = switch (_mode) {
      _Mode.signIn => ('Welcome back', 'Sign in to sync your finances.', 'Sign in'),
      _Mode.signUp => ('Create account', 'Your data stays private to your account.', 'Create account'),
      _Mode.confirmSignUp => ('Confirm your email', 'Enter the code from the confirmation email.', 'Confirm'),
      _Mode.forgot => ('Reset password', "We'll email you a code to set a new password.", 'Send code'),
      _Mode.reset => ('Set a new password', 'Enter the code from the email and your new password.', 'Save password'),
    };
    final needsPassword = _mode == _Mode.signIn || _mode == _Mode.signUp || _mode == _Mode.reset;
    final newPassword = _mode == _Mode.signUp || _mode == _Mode.reset;
    final needsCode = _mode == _Mode.confirmSignUp || _mode == _Mode.reset;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  autovalidateMode: _autovalidate ? AutovalidateMode.always : AutovalidateMode.disabled,
                  onChanged: _clearError,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      enabled: _mode != _Mode.confirmSignUp && _mode != _Mode.reset,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                      validator: _validateEmail,
                    ),
                    if (needsCode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: needsPassword ? TextInputAction.next : TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Code from email', prefixIcon: Icon(Icons.pin_outlined)),
                        validator: _validateCode,
                        onFieldSubmitted: needsPassword ? null : (_) => _submit(),
                      ),
                    ],
                    if (needsPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: [newPassword ? AutofillHints.newPassword : AutofillHints.password],
                        textInputAction: newPassword ? TextInputAction.next : TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: newPassword ? 'New password' : 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: newPassword ? _validateNewPassword : _validatePassword,
                        onFieldSubmitted: newPassword ? null : (_) => _submit(),
                      ),
                    ],
                    if (newPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)),
                        validator: _validateConfirm,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_mode == _Mode.signIn)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _busy ? null : () => _go(_Mode.forgot), child: const Text('Forgot password?')),
                      ),
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(action),
                    ),
                    const SizedBox(height: 12),
                    ..._footer(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _footer() => switch (_mode) {
        _Mode.signIn => [
            TextButton(onPressed: _busy ? null : () => _go(_Mode.signUp), child: const Text("Don't have an account? Create one")),
          ],
        _Mode.signUp => [
            TextButton(onPressed: _busy ? null : () => _go(_Mode.signIn), child: const Text('Already have an account? Sign in')),
          ],
        _Mode.confirmSignUp || _Mode.reset => [
            TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend code')),
            TextButton(onPressed: _busy ? null : () => _go(_Mode.signIn), child: const Text('Back to sign in')),
          ],
        _Mode.forgot => [
            TextButton(onPressed: _busy ? null : () => _go(_Mode.signIn), child: const Text('Back to sign in')),
          ],
      };
}
