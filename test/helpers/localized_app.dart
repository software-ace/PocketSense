import 'package:flutter/material.dart';
import 'package:pocket_sense/l10n/app_localizations.dart';
import 'package:pocket_sense/settings/app_settings.dart';

/// A MaterialApp with the app's localizations, for widget tests.
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) {
  AppSettings.applyToIntl(locale);
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}
