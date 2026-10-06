import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// App-wide preferences that aren't financial data (those live in the
/// encrypted database). Stored with shared_preferences.
class AppSettings {
  AppSettings._();

  static const _localeKey = 'locale';
  static const _onboardingKey = 'onboarding.step';
  static const _autoDirKey = 'autoBackup.dir';
  static const _autoLastKey = 'autoBackup.last';
  static const _autoErrorKey = 'autoBackup.error';
  static const _syncOnKey = 'sync.enabled';
  static const _syncNameKey = 'sync.name';

  /// The chosen UI language, or null to follow the system.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// First-run onboarding progress: 0 = choose data, 1 = security, 2 = done.
  /// Saved per step, so closing the app mid-way resumes where it stopped
  /// (and "Start fresh" isn't offered again after an import).
  static int onboardingStep = 0;
  static const onboardingDone = 2;

  /// Automatic backup: the folder (null = off), the day of the last
  /// successful backup (yyyy-MM-dd), and why the last attempt failed.
  static final autoBackup = ValueNotifier<({String? dir, String? last, String? error})>((dir: null, last: null, error: null));

  /// Sync with paired devices on the local network: on or off (off by
  /// default), and the name other devices see this one by.
  static final sync = ValueNotifier<({bool enabled, String name})>((enabled: false, name: ''));

  static final _prefs = SharedPreferencesAsync();

  static Future<void> load() async {
    try {
      final code = await _prefs.getString(_localeKey);
      locale.value = AppLocalizations.supportedLocales.where((l) => l.languageCode == code).firstOrNull;
      onboardingStep = await _prefs.getInt(_onboardingKey) ?? 0;
      autoBackup.value = (
        dir: await _prefs.getString(_autoDirKey),
        last: await _prefs.getString(_autoLastKey),
        error: await _prefs.getString(_autoErrorKey),
      );
      sync.value = (enabled: await _prefs.getBool(_syncOnKey) ?? false, name: await _prefs.getString(_syncNameKey) ?? '');
    } catch (_) {
      // Unreadable preferences: follow the system language, show onboarding.
    }
  }

  static Future<void> setOnboardingStep(int step) async {
    onboardingStep = step;
    await _prefs.setInt(_onboardingKey, step);
  }

  static Future<void> setAutoBackupDir(String? dir) async {
    autoBackup.value = (dir: dir, last: null, error: null);
    for (final k in [_autoDirKey, _autoLastKey, _autoErrorKey]) {
      await _prefs.remove(k);
    }
    if (dir != null) await _prefs.setString(_autoDirKey, dir);
  }

  /// Records a backup attempt: [last] on success, [error] on failure.
  static Future<void> setAutoBackupResult({String? last, String? error}) async {
    final v = autoBackup.value;
    autoBackup.value = (dir: v.dir, last: last ?? v.last, error: error);
    if (last != null) await _prefs.setString(_autoLastKey, last);
    error == null ? await _prefs.remove(_autoErrorKey) : await _prefs.setString(_autoErrorKey, error);
  }

  static Future<void> setSync({bool? enabled, String? name}) async {
    sync.value = (enabled: enabled ?? sync.value.enabled, name: name ?? sync.value.name);
    if (enabled != null) await _prefs.setBool(_syncOnKey, enabled);
    if (name != null) await _prefs.setString(_syncNameKey, name);
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
