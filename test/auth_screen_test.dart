import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/auth_screen.dart';

// Supabase is never initialized here: every test stops at client-side
// validation, which must reject bad input before any network call.
void main() {
  Future<void> pump(WidgetTester t) => t.pumpWidget(const MaterialApp(home: AuthScreen()));
  Finder field(String label) => find.widgetWithText(TextFormField, label);

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
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await t.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('register requires 8+ characters and matching passwords', (t) async {
    await pump(t);
    await t.tap(find.textContaining('Create one'));
    await t.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);

    await t.enterText(field('Email'), 'me@example.com');
    await t.enterText(field('New password'), 'short');
    await t.enterText(field('Confirm password'), 'different');
    await t.tap(find.widgetWithText(FilledButton, 'Create account'));
    await t.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('forgot password asks only for the email', (t) async {
    await pump(t);
    await t.tap(find.text('Forgot password?'));
    await t.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send code'), findsOneWidget);
    expect(field('Password'), findsNothing);
    await t.tap(find.text('Back to sign in'));
    await t.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
