// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pocket Sense';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get add => 'Add';

  @override
  String get newItem => 'New';

  @override
  String get more => 'More';

  @override
  String get done => 'Done';

  @override
  String get all => 'All';

  @override
  String get expense => 'Expense';

  @override
  String get income => 'Income';

  @override
  String get category => 'Category';

  @override
  String get categoryOptional => 'Category (optional)';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get description => 'Description';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get merchant => 'Merchant';

  @override
  String get merchantOptional => 'Merchant (optional)';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notesHint => 'Any extra details…';

  @override
  String get type => 'Type';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get transactionFallback => 'Transaction';

  @override
  String deleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String deleteNamedTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get couldNotLoad => 'Could not load';

  @override
  String get navHome => 'Home';

  @override
  String get navOverview => 'Overview';

  @override
  String get navActivity => 'Activity';

  @override
  String get navBudgets => 'Budgets';

  @override
  String get navRecurring => 'Recurring';

  @override
  String get settings => 'Settings';

  @override
  String get startupErrorTitle => 'Couldn\'t open your data';

  @override
  String keyringUnavailable(String detail) {
    return 'The system keyring is unavailable ($detail). Pocket Sense keeps its encryption key there. On Linux, make sure a Secret Service provider such as GNOME Keyring or KWallet is running and unlocked.';
  }

  @override
  String get dbKeyLost =>
      'Your data is encrypted, but its key is no longer in the system keyring, so it can\'t be opened. You can erase it and start over.';

  @override
  String get eraseAllTitle => 'Erase all data?';

  @override
  String get eraseAllBody =>
      'Everything stored in Pocket Sense on this device is deleted. This cannot be undone.';

  @override
  String get erase => 'Erase';

  @override
  String get eraseAndStartOver => 'Erase and start over';

  @override
  String get catGroceries => 'Groceries';

  @override
  String get catDining => 'Dining Out';

  @override
  String get catTransport => 'Transport';

  @override
  String get catHousing => 'Housing';

  @override
  String get catUtilities => 'Utilities';

  @override
  String get catEntertainment => 'Entertainment';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catHealth => 'Health';

  @override
  String get catSubscriptions => 'Subscriptions';

  @override
  String get catOtherExpense => 'Other Expense';

  @override
  String get catSalary => 'Salary';

  @override
  String get catFreelance => 'Freelance';

  @override
  String get catOtherIncome => 'Other Income';

  @override
  String get statIncomeMonth => 'Income (mo)';

  @override
  String get statSpentMonth => 'Spent (mo)';

  @override
  String get statNetMonth => 'Net (mo)';

  @override
  String get statYearTotal => 'Spent this year';

  @override
  String get chartDaily => 'Daily Spending (30d)';

  @override
  String get chartByCategory => 'By Category (30d)';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get noData => 'No data';

  @override
  String get noExpensesYet => 'No expenses yet';

  @override
  String get addByVoice => 'Add by voice';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get searchTransactions => 'Search transactions…';

  @override
  String get search => 'Search…';

  @override
  String get noTransactionsHint => 'Tap Add to record your first entry.';

  @override
  String get deleteTransactionTitle => 'Delete transaction?';

  @override
  String addFailed(String error) {
    return 'Failed to add: $error';
  }

  @override
  String updateFailed(String error) {
    return 'Failed to update: $error';
  }

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get newTransaction => 'New transaction';

  @override
  String get checkAndSave => 'Check and save';

  @override
  String dateToday(String date) {
    return 'Today · $date';
  }

  @override
  String dateYesterday(String date) {
    return 'Yesterday · $date';
  }

  @override
  String get enterPositiveAmount =>
      'Enter an amount above zero, with at most 3 decimals.';

  @override
  String activeBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active budgets',
      one: '1 active budget',
      zero: 'No active budgets',
    );
    return '$_temp0';
  }

  @override
  String get newBudget => 'New budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get noBudgets => 'No budgets set';

  @override
  String get noBudgetsHint =>
      'Set a weekly or monthly limit per category to track spending.';

  @override
  String deleteBudgetTitle(String category) {
    return 'Delete budget for \"$category\"?';
  }

  @override
  String get deleteBudgetBody =>
      'This will remove the spending limit. Existing transactions are unaffected.';

  @override
  String periodThisWeek(String range) {
    return 'This week · $range';
  }

  @override
  String periodThisMonth(String month) {
    return 'This month · $month';
  }

  @override
  String overBudgetBy(String amount) {
    return 'Over budget by $amount';
  }

  @override
  String amountRemaining(String amount) {
    return '$amount remaining';
  }

  @override
  String get weeklyLimit => 'Weekly limit';

  @override
  String get monthlyLimit => 'Monthly limit';

  @override
  String get freqWeekly => 'Weekly';

  @override
  String get freqBiweekly => 'Bi-weekly';

  @override
  String get freqMonthly => 'Monthly';

  @override
  String get freqQuarterly => 'Quarterly';

  @override
  String get freqYearly => 'Yearly';

  @override
  String recurringCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recurring items',
      one: '1 recurring item',
      zero: 'No recurring items',
    );
    return '$_temp0';
  }

  @override
  String get newRecurring => 'New recurring';

  @override
  String get noRecurring => 'No recurring items';

  @override
  String get noRecurringHint =>
      'Add salary, rent, subscriptions, and bills to see what is coming up.';

  @override
  String postedAsTransaction(String name) {
    return 'Posted \"$name\" as a transaction';
  }

  @override
  String postFailed(String error) {
    return 'Post failed: $error';
  }

  @override
  String get deleteRecurringBody =>
      'This recurring item will be removed. This cannot be undone.';

  @override
  String get frequency => 'Frequency';

  @override
  String get nextDue => 'Next Due';

  @override
  String get status => 'Status';

  @override
  String overdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'Due today';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Due in $days days',
      one: 'Due in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get inactive => 'Inactive';

  @override
  String get paused => 'Paused';

  @override
  String get postAsTransaction => 'Post as transaction';

  @override
  String get postAsTransactionHint => 'Records it today in Activity';

  @override
  String recurringSuffix(String name) {
    return '$name (recurring)';
  }

  @override
  String recurringNote(String name) {
    return 'Posted from recurring item \"$name\"';
  }

  @override
  String get newRecurringItem => 'New recurring item';

  @override
  String get editRecurringItem => 'Edit recurring item';

  @override
  String get firstDueDate => 'First due date';

  @override
  String get active => 'Active';

  @override
  String get showingInList => 'Showing in list';

  @override
  String get hiddenFromList => 'Hidden from list';

  @override
  String get categories => 'Categories';

  @override
  String get categoriesSubtitle => 'Income and expense categories';

  @override
  String get deleteCategoryBody =>
      'Transactions tagged with this category will become uncategorized. Budgets for it will be removed. This cannot be undone.';

  @override
  String categoriesShown(int shown, int total) {
    return '$shown of $total categories';
  }

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get noCategories => 'No categories';

  @override
  String get noExpenseCategories => 'No expense categories';

  @override
  String get noIncomeCategories => 'No income categories';

  @override
  String get noCategoriesHint => 'Create one to start tagging transactions.';

  @override
  String get name => 'Name';

  @override
  String get color => 'Color';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get voiceDownloading => 'Downloading speech model…';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceStarting => 'Starting…';

  @override
  String get voiceTitle => 'Voice entry';

  @override
  String voiceDownloadNote(int mb) {
    return 'One-time download, about $mb MB. After this, voice entry works offline.';
  }

  @override
  String get voiceHint =>
      'Try: \"Spent 3.5 on lunch at Reem\"\n\"Received 500 from Acme yesterday\"';

  @override
  String get voiceDidntCatch =>
      'Didn\'t catch that. Tap the mic and try again.';

  @override
  String get voiceMicPermissionOff =>
      'Microphone permission is off. Allow it in Settings → Apps → Pocket Sense.';

  @override
  String get voiceNeedsConnection =>
      'Speech recognition needs a connection on this phone, or an offline English speech pack.';

  @override
  String voiceFailed(String detail) {
    return 'Speech recognition failed ($detail).';
  }

  @override
  String get voiceUnavailable =>
      'Speech recognition isn\'t available on this phone.';

  @override
  String get voiceModelDownloadFailed =>
      'Couldn\'t download the speech model. Check your connection and try again.';

  @override
  String voiceCouldntStart(String detail) {
    return 'Speech recognition couldn\'t start ($detail).';
  }

  @override
  String get voiceNeedsParecord =>
      'Can\'t open the microphone: voice entry needs parecord (from PulseAudio, or PipeWire\'s pulse tools).';

  @override
  String voiceMicOpenFailed(String detail) {
    return 'Couldn\'t open the microphone ($detail).';
  }

  @override
  String voiceMicStopped(String detail) {
    return 'The microphone stopped ($detail).';
  }

  @override
  String get backup => 'Backup';

  @override
  String get exportData => 'Export data';

  @override
  String get exportDataSubtitle => 'Save everything to a JSON file';

  @override
  String get importData => 'Import data';

  @override
  String get importDataSubtitle => 'Replace everything with a backup file';

  @override
  String get exportWarningTitle => 'Export an unencrypted file?';

  @override
  String get exportWarningBody =>
      'The backup file is not encrypted. Anyone who opens it can read your finances, so keep it somewhere safe.';

  @override
  String get exportAction => 'Export';

  @override
  String get exportDone => 'Backup saved.';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importConfirmTitle => 'Replace all data?';

  @override
  String get importConfirmBody =>
      'Everything currently in Pocket Sense is replaced by the backup. This cannot be undone.';

  @override
  String get importAction => 'Replace';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count records.',
      one: 'Restored 1 record.',
    );
    return '$_temp0';
  }

  @override
  String get backupNotJson =>
      'This file isn\'t valid JSON, so nothing was changed.';

  @override
  String get backupNotABackup =>
      'This isn\'t a Pocket Sense backup, so nothing was changed.';

  @override
  String get backupTooNew =>
      'This backup comes from a newer version of Pocket Sense. Update the app, then try again.';

  @override
  String backupWrongCurrency(String currency) {
    return 'This backup uses another currency ($currency), so nothing was changed.';
  }

  @override
  String backupBadData(String detail) {
    return 'The backup contains invalid data, so nothing was changed. ($detail)';
  }

  @override
  String backupReadFailed(String error) {
    return 'Couldn\'t read the file: $error';
  }

  @override
  String get security => 'Security';

  @override
  String get appLock => 'App lock';

  @override
  String get appLockSubtitle => 'Ask for a PIN when opening Pocket Sense';

  @override
  String get changePin => 'Change PIN';

  @override
  String get useBiometrics => 'Unlock with fingerprint or face';

  @override
  String get enterPin => 'Enter your PIN';

  @override
  String get enterCurrentPin => 'Enter your current PIN';

  @override
  String get chooseNewPin => 'Choose a PIN (4–6 digits)';

  @override
  String get confirmNewPin => 'Enter the PIN again';

  @override
  String get pinsDontMatch => 'The PINs don\'t match. Try again.';

  @override
  String get pinSet => 'App lock is on.';

  @override
  String get pinChanged => 'PIN changed.';

  @override
  String wrongPin(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'Wrong PIN. $remaining tries left before a wait.',
      one: 'Wrong PIN. 1 try left before a wait.',
      zero: 'Wrong PIN.',
    );
    return '$_temp0';
  }

  @override
  String tooManyAttempts(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Too many wrong PINs. Try again in $seconds seconds.',
      one: 'Too many wrong PINs. Try again in 1 second.',
    );
    return '$_temp0';
  }

  @override
  String get continueAction => 'Continue';

  @override
  String get forgotPin => 'Forgot PIN?';

  @override
  String get forgotPinBody =>
      'Your PIN can\'t be recovered. The only way back in is to erase all data on this device and start over. If you have a backup file, you can import it afterwards.';

  @override
  String get biometricReason => 'Unlock Pocket Sense';

  @override
  String get biometricUnlock => 'Use fingerprint or face';

  @override
  String get deleteDigit => 'Delete digit';

  @override
  String onboardingStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get welcomeTitle => 'Welcome to Pocket Sense';

  @override
  String get welcomeBody =>
      'Your finances stay on this device, encrypted. Nothing is uploaded anywhere.';

  @override
  String get startFresh => 'Start fresh';

  @override
  String get startFreshSubtitle =>
      'Begin with empty data and starter categories';

  @override
  String get importBackupOption => 'Import a backup';

  @override
  String get importBackupOptionSubtitle =>
      'Restore your data from a Pocket Sense backup file';

  @override
  String get backupLaterHint =>
      'You can import or export any time in Settings → Backup.';

  @override
  String get secureTitle => 'Protect your data';

  @override
  String get secureBody => 'Set a PIN so only you can open Pocket Sense.';

  @override
  String get setPin => 'Set a PIN';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get securityLaterHint =>
      'You can change this any time in Settings → Security.';

  @override
  String get biometricOfferTitle => 'Unlock with fingerprint or face?';

  @override
  String get biometricOfferBody =>
      'Use your fingerprint or face instead of typing the PIN. The PIN always works too.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get notNow => 'Not now';
}
