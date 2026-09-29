import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that aren't financial data (those live in the
/// encrypted database). Stored with shared_preferences.
class AppSettings {
  AppSettings._();

  static const _localeKey = 'locale';
  static const supportedLanguages = ['en', 'ar'];

  /// The chosen UI language, or null to follow the system.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  static final _prefs = SharedPreferencesAsync();

  static Future<void> load() async {
    try {
      final code = await _prefs.getString(_localeKey);
      locale.value = supportedLanguages.contains(code) ? Locale(code!) : null;
    } catch (_) {
      // Unreadable preferences just mean "follow the system".
    }
  }

  static Future<void> setLocale(Locale? value) async {
    locale.value = value;
    if (value == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, value.languageCode);
    }
  }

  /// Keeps intl (money and date formatting) in step with the UI language.
  /// Numbers use Latin digits in Arabic too, as Jordanian banks and shops
  /// print them. Flutter's Arabic date symbols ask for Arabic-Indic digits,
  /// so that is switched off explicitly.
  static void applyToIntl(Locale resolved) {
    final code = resolved.languageCode;
    DateFormat.useNativeDigitsByDefaultFor(code, false);
    Intl.defaultLocale = code;
  }
}
