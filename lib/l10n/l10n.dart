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
