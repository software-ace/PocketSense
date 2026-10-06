import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/l10n/l10n.dart';

void main() {
  test('follows a supported device language', () {
    expect(resolveAppLocale(null, const Locale('ar', 'JO')), const Locale('ar'));
    expect(resolveAppLocale(null, const Locale('en', 'US')), const Locale('en'));
  });

  test('falls back to English for other languages, or none', () {
    expect(resolveAppLocale(null, const Locale('de')), const Locale('en'));
    expect(resolveAppLocale(null, const Locale('fr', 'FR')), const Locale('en'));
    expect(resolveAppLocale(null, null), const Locale('en'));
  });

  test('the language chosen in Settings wins', () {
    expect(resolveAppLocale(const Locale('ar'), const Locale('en')), const Locale('ar'));
  });
}
