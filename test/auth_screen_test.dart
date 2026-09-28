import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stands in for Supabase auth: records each call and answers with whatever
/// the test queued. Unstubbed methods throw, so a stray network call fails.
class FakeAuth extends Fake implements GoTrueClient {
  final calls = <String>[];
  Object? signUpError;
  Session? signUpSession;
  Completer<void>? signUpGate;
  Object? signInError;
  Object? verifyError;

  Never _throw(Object e) => throw e;

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    calls.add('signUp $email $password');
    await signUpGate?.future;
    if (signUpError != null) _throw(signUpError!);
    return AuthResponse(session: signUpSession);
  }

  @override
  Future<AuthResponse> signInWithPassword({String? email, String? phone, required String password, String? captchaToken}) async {
    calls.add('signIn $email');
    if (signInError != null) _throw(signInError!);
    return AuthResponse();
  }

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    calls.add('verify ${type.name} $email $token');
    if (verifyError != null) _throw(verifyError!);
    return AuthResponse();
  }

  @override
  Future<ResendResponse> resend({String? email, String? phone, required OtpType type, String? emailRedirectTo, String? captchaToken}) async {
    calls.add('resend ${type.name} $email');
    return ResendResponse();
  }

  @override
  Future<void> resetPasswordForEmail(String email, {String? redirectTo, String? captchaToken}) async {
    calls.add('resetPassword $email');
  }
}

Session fakeSession() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-09-28T00:00:00Z'),
    );

void main() {
  late FakeAuth auth;
  setUp(() => auth = FakeAuth());

  Future<void> pump(WidgetTester t) => t.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder button(String label) => find.widgetWithText(FilledButton, label);
  bool enabled(WidgetTester t, String label) => t.widget<TextFormField>(field(label)).enabled;

  Future<void> tapAndSettle(WidgetTester t, Finder f) async {
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> openRegister(WidgetTester t) async {
    await pump(t);
    await tapAndSettle(t, find.textContaining('Create one'));
  }

  Future<void> register(WidgetTester t, {String email = 'new@example.com', String password = 'longenough1', String? confirm}) async {
    await openRegister(t);
    await t.enterText(field('Email'), email);
    await t.enterText(field('New password'), password);
    await t.enterText(field('Confirm password'), confirm ?? password);
    await tapAndSettle(t, button('Create account'));
  }

  testWidgets('starts on sign in with forgot-password and register links', (t) async {
    await pump(t);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Create one'), findsOneWidget);
    expect(field('Confirm password'), findsNothing);
  });

  testWidgets('sign in rejects an invalid email and empty password', (t) async {
    await pump(t);
    await t.enterText(field('Email'), 'not-an-email');
    await t.tap(button('Sign in'));
    await t.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  group('registration', () {
    testWidgets('shows email, new password and confirm fields', (t) async {
      await openRegister(t);
      expect(find.text('Create account'), findsWidgets);
      expect(field('Email'), findsOneWidget);
      expect(field('New password'), findsOneWidget);
      expect(field('Confirm password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('empty form is rejected without calling the server', (t) async {
      await openRegister(t);
      await t.tap(button('Create account'));
      await t.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    final badPasswords = <String, (String, String)>{
      'only spaces': (' ' * 10, "Password can't be only spaces"),
      'too short': ('short', 'Use at least 8 characters'),
      'over 72 bytes': ('x' * 73, 'Use at most 72 characters'),
      // 24 × 4-byte emoji = 96 bytes: fine by length, over bcrypt's limit.
      'multi-byte over 72 bytes': ('🔒' * 24, 'Use at most 72 characters'),
    };
    badPasswords.forEach((name, spec) {
      testWidgets('new password: $name', (t) async {
        await register(t, password: spec.$1);
        expect(find.text(spec.$2), findsOneWidget);
        expect(auth.calls, isEmpty);
      });
    });

    testWidgets('72-byte password is accepted', (t) async {
      await register(t, password: 'x' * 72);
      expect(auth.calls, hasLength(1));
    });

    testWidgets('empty confirm asks to confirm, not "do not match"', (t) async {
      await register(t, confirm: '');
      expect(find.text('Confirm your password'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('requires a valid email, 8+ characters and matching passwords', (t) async {
      await register(t, email: 'me@example', password: 'short', confirm: 'different');
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('exactly 8 characters is accepted', (t) async {
      await register(t, password: '12345678');
      expect(auth.calls, ['signUp new@example.com 12345678']);
    });

    testWidgets('show-password toggle reveals both password fields', (t) async {
      await openRegister(t);
      bool obscured(String label) =>
          t.widget<EditableText>(find.descendant(of: field(label), matching: find.byType(EditableText))).obscureText;
      expect(obscured('New password'), isTrue);
      expect(obscured('Confirm password'), isTrue);
      await tapAndSettle(t, find.byTooltip('Show password'));
      expect(obscured('New password'), isFalse);
      expect(obscured('Confirm password'), isFalse);
    });

    testWidgets('success sends trimmed email and moves to the confirm-code step', (t) async {
      await register(t, email: '  new@example.com  ');
      expect(auth.calls, ['signUp new@example.com longenough1']);
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.text('We emailed a code to new@example.com.'), findsOneWidget);
      expect(field('Code from email'), findsOneWidget);
      expect(field('New password'), findsNothing);
      expect(enabled(t, 'Email'), isFalse, reason: 'the code belongs to this email');
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('with email confirmation off, a returned session skips the code step', (t) async {
      auth.signUpSession = fakeSession();
      await register(t);
      expect(auth.calls, hasLength(1));
      expect(find.text('Confirm your email'), findsNothing);
    });

    testWidgets('button is disabled while the request is in flight', (t) async {
      auth.signUpGate = Completer();
      await openRegister(t);
      await t.enterText(field('Email'), 'new@example.com');
      await t.enterText(field('New password'), 'longenough1');
      await t.enterText(field('Confirm password'), 'longenough1');
      await t.tap(find.byType(FilledButton));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await t.tap(find.byType(FilledButton));
      auth.signUpGate!.complete();
      await t.pumpAndSettle();
      expect(auth.calls, hasLength(1));
    });

    final serverErrors = <String, (Object, String)>{
      'existing email': (const AuthException('User already registered', code: 'user_already_exists'), 'An account with this email already exists. Sign in instead.'),
      'weak password': (const AuthException('Password is known to be weak', code: 'weak_password'), 'That password is too weak. Try a longer one.'),
      'rate limit': (const AuthException('email rate limit exceeded', code: 'over_email_send_rate_limit'), 'Too many attempts. Wait a minute and try again.'),
      // What a broken signup trigger surfaces as ("Database error saving new user").
      'server failure': (const AuthException('Database error saving new user', statusCode: '500', code: 'unexpected_failure'), "Couldn't complete that right now. Please try again later."),
      'offline': (const SocketException('Failed host lookup'), 'No internet connection. Check your network and try again.'),
    };
    serverErrors.forEach((name, spec) {
      testWidgets('$name: shows a friendly error and stays on register', (t) async {
        auth.signUpError = spec.$1;
        await register(t);
        expect(find.text(spec.$2), findsOneWidget);
        expect(find.text('Create account'), findsWidgets);
        expect(field('New password'), findsOneWidget);
        expect(t.widget<FilledButton>(button('Create account')).onPressed, isNotNull, reason: 'user can retry');
      });
    });

    testWidgets('switching to sign in keeps the email and password, drops confirm', (t) async {
      await openRegister(t);
      await t.enterText(field('Email'), 'new@example.com');
      await t.enterText(field('New password'), 'longenough1');
      await t.enterText(field('Confirm password'), 'longenough1');
      await tapAndSettle(t, find.textContaining('Sign in'));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('longenough1'), findsOneWidget);
      await tapAndSettle(t, find.textContaining('Create one'));
      expect(find.text('longenough1'), findsNothing, reason: 'new password starts empty');
    });

    // Regression: Form.reset() used to rewind the email to its text at the
    // screen's last build, blanking anything typed since.
    testWidgets('email typed on sign in carries over to register', (t) async {
      await pump(t);
      await t.enterText(field('Email'), 'new@example.com');
      await tapAndSettle(t, find.textContaining('Create one'));
      expect(find.text('new@example.com'), findsOneWidget);
    });
  });

  group('confirm email', () {
    testWidgets('rejects a malformed code without calling the server', (t) async {
      await register(t);
      final cases = {
        '': 'Enter the code from the email',
        '12a456': 'The code is numbers only',
        '12345': 'Check the code — it should be 6 to 10 digits',
        '12345678901': 'Check the code — it should be 6 to 10 digits',
      };
      for (final MapEntry(key: bad, value: message) in cases.entries) {
        await t.enterText(field('Code from email'), bad);
        await t.tap(button('Confirm'));
        await t.pump();
        expect(find.text(message), findsOneWidget, reason: '"$bad"');
      }
      expect(auth.calls.where((c) => c.startsWith('verify')), isEmpty);
    });

    testWidgets('verifies the trimmed code as a signup OTP', (t) async {
      await register(t);
      await t.enterText(field('Code from email'), ' 123456 ');
      await tapAndSettle(t, button('Confirm'));
      expect(auth.calls.last, 'verify signup new@example.com 123456');
      expect(find.textContaining('wrong or has expired'), findsNothing);
    });

    testWidgets('wrong or expired code shows an error and stays put', (t) async {
      auth.verifyError = const AuthException('Token has expired or is invalid', code: 'otp_expired');
      await register(t);
      await t.enterText(field('Code from email'), '000000');
      await tapAndSettle(t, button('Confirm'));
      expect(find.text('That code is wrong or has expired. Request a new one.'), findsOneWidget);
      expect(find.text('Confirm your email'), findsOneWidget);
    });

    testWidgets('resend asks for a new signup code', (t) async {
      await register(t);
      await tapAndSettle(t, find.text('Resend code'));
      expect(auth.calls.last, 'resend signup new@example.com');
      expect(find.text('Sent a new code to new@example.com.'), findsOneWidget);
    });

    testWidgets('back to sign in leaves the confirm step', (t) async {
      await register(t);
      await tapAndSettle(t, find.text('Back to sign in'));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(enabled(t, 'Email'), isTrue);
    });

    testWidgets('signing in before confirming jumps to the code step', (t) async {
      auth.signInError = const AuthException('Email not confirmed', code: 'email_not_confirmed');
      await pump(t);
      await t.enterText(field('Email'), 'new@example.com');
      await t.enterText(field('Password'), 'longenough1');
      await tapAndSettle(t, button('Sign in'));
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('Confirm your email first'), findsOneWidget);
      await tapAndSettle(t, find.text('Resend code'));
      expect(auth.calls.last, 'resend signup new@example.com');
    });
  });

  group('message timing', () {
    testWidgets('no errors while typing before the first submit', (t) async {
      await openRegister(t);
      await t.enterText(field('Email'), 'a');
      await t.enterText(field('New password'), 'x');
      await t.pump();
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Use at least 8 characters'), findsNothing);
    });

    testWidgets('after a failed submit, each error clears as its field is fixed', (t) async {
      await pump(t);
      await t.tap(button('Sign in'));
      await t.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      await t.enterText(field('Email'), 'me@example.com');
      await t.pump();
      expect(find.text('Enter your email'), findsNothing);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('confirm re-checks when the password changes', (t) async {
      await register(t, password: 'longenough1', confirm: 'longenough2');
      expect(find.text('Passwords do not match'), findsOneWidget);
      await t.enterText(field('New password'), 'longenough2');
      await t.pump();
      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('switching pages drops the previous page\'s errors', (t) async {
      await pump(t);
      await t.tap(button('Sign in'));
      await t.pump();
      await tapAndSettle(t, find.text('Forgot password?'));
      expect(find.text('Enter your email'), findsNothing);
      await t.enterText(field('Email'), 'x');
      await t.pump();
      expect(find.text('Enter a valid email'), findsNothing, reason: 'new page starts quiet');
    });

    testWidgets('sign in rejects a whitespace-only password', (t) async {
      await pump(t);
      await t.enterText(field('Email'), 'me@example.com');
      await t.enterText(field('Password'), '   ');
      await t.tap(button('Sign in'));
      await t.pump();
      expect(find.text('Enter your password'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('a server error clears once the user edits', (t) async {
      auth.signInError = const AuthException('Invalid login credentials', code: 'invalid_credentials');
      await pump(t);
      await t.enterText(field('Email'), 'me@example.com');
      await t.enterText(field('Password'), 'wrongpass');
      await tapAndSettle(t, button('Sign in'));
      expect(find.text('Wrong email or password.'), findsOneWidget);
      await t.enterText(field('Password'), 'rightpass');
      await t.pump();
      expect(find.text('Wrong email or password.'), findsNothing);
    });
  });

  group('forgot password', () {
    testWidgets('empty or invalid email is rejected without calling the server', (t) async {
      await pump(t);
      await tapAndSettle(t, find.text('Forgot password?'));
      await t.tap(button('Send code'));
      await t.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      await t.enterText(field('Email'), 'me@');
      await t.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('reset step validates code, new password and confirm', (t) async {
      await pump(t);
      await t.enterText(field('Email'), 'me@example.com');
      await tapAndSettle(t, find.text('Forgot password?'));
      await tapAndSettle(t, button('Send code'));
      expect(auth.calls, ['resetPassword me@example.com']);
      expect(find.text('Set a new password'), findsOneWidget);
      await t.ensureVisible(button('Save password'));
      await t.tap(button('Save password'));
      await t.pump();
      expect(find.text('Enter the code from the email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      expect(find.text('Confirm your password'), findsOneWidget);
    });
  });

  testWidgets('forgot password asks only for the email', (t) async {
    await pump(t);
    await tapAndSettle(t, find.text('Forgot password?'));
    expect(find.text('Reset password'), findsOneWidget);
    expect(button('Send code'), findsOneWidget);
    expect(field('Password'), findsNothing);
    await tapAndSettle(t, find.text('Back to sign in'));
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
