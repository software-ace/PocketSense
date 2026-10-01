import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Localized names for the starter categories, keyed like `defaultCategories`.
Map<String, String> starterCategoryNames(AppLocalizations l) => {
      'groceries': l.catGroceries,
      'dining': l.catDining,
      'transport': l.catTransport,
      'housing': l.catHousing,
      'utilities': l.catUtilities,
      'entertainment': l.catEntertainment,
      'shopping': l.catShopping,
      'health': l.catHealth,
      'subscriptions': l.catSubscriptions,
      'otherExpense': l.catOtherExpense,
      'salary': l.catSalary,
      'freelance': l.catFreelance,
      'otherIncome': l.catOtherIncome,
    };

/// Every default name each starter category has had, in every language
/// (lower-cased), keyed like `defaultCategories`. A category still called
/// one of these hasn't been renamed by the user.
Map<String, Set<String>> starterCategoryDefaultNames() {
  final result = <String, Set<String>>{};
  for (final locale in AppLocalizations.supportedLocales) {
    for (final e in starterCategoryNames(lookupAppLocalizations(locale)).entries) {
      (result[e.key] ??= {}).add(e.value.toLowerCase());
    }
  }
  return result;
}

/// The language the app runs in: the one chosen in Settings, else the
/// device's when it's supported, else English. (Not the first supported
/// locale: that list is alphabetical, so a German or French phone would
/// get Arabic.)
Locale resolveAppLocale(Locale? chosen, Locale? device) =>
    chosen ??
    AppLocalizations.supportedLocales.firstWhere((s) => s.languageCode == device?.languageCode,
        orElse: () => const Locale('en'));
