import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that aren't financial data (those live in the
/// encrypted database). Stored with shared_preferences.
class AppSettings {
  AppSettings._();

  static const _localeKey = 'locale';
  static const _onboardingKey = 'onboarding.step';
  static const supportedLanguages = ['en', 'ar'];

  /// The chosen UI language, or null to follow the system.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// First-run onboarding progress: 0 = choose data, 1 = security, 2 = done.
  /// Saved per step, so closing the app mid-way resumes where it stopped
  /// (and "Start fresh" isn't offered again after an import).
  static int onboardingStep = 0;
  static const onboardingDone = 2;

  static final _prefs = SharedPreferencesAsync();

  static Future<void> load() async {
    try {
      final code = await _prefs.getString(_localeKey);
      locale.value = supportedLanguages.contains(code) ? Locale(code!) : null;
      onboardingStep = await _prefs.getInt(_onboardingKey) ?? 0;
    } catch (_) {
      // Unreadable preferences: follow the system language, show onboarding.
    }
  }

  static Future<void> setOnboardingStep(int step) async {
    onboardingStep = step;
    await _prefs.setInt(_onboardingKey, step);
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
