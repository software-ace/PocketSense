import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Pocket Sense'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get categoryOptional;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @merchantOptional.
  ///
  /// In en, this message translates to:
  /// **'Merchant (optional)'**
  String get merchantOptional;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Any extra details…'**
  String get notesHint;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @transactionFallback.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionFallback;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(String error);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @deleteNamedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteNamedTitle(String name);

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get couldNotLoad;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get navBudgets;

  /// No description provided for @navRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get navRecurring;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your data'**
  String get startupErrorTitle;

  /// No description provided for @keyringUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The system keyring is unavailable ({detail}). Pocket Sense keeps its encryption key there. On Linux, make sure a Secret Service provider such as GNOME Keyring or KWallet is running and unlocked.'**
  String keyringUnavailable(String detail);

  /// No description provided for @dbKeyLost.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted, but its key is no longer in the system keyring, so it can\'t be opened. You can erase it and start over.'**
  String get dbKeyLost;

  /// No description provided for @eraseAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase all data?'**
  String get eraseAllTitle;

  /// No description provided for @eraseAllBody.
  ///
  /// In en, this message translates to:
  /// **'Everything stored in Pocket Sense on this device is deleted. This cannot be undone.'**
  String get eraseAllBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @eraseAndStartOver.
  ///
  /// In en, this message translates to:
  /// **'Erase and start over'**
  String get eraseAndStartOver;

  /// No description provided for @catGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get catGroceries;

  /// No description provided for @catDining.
  ///
  /// In en, this message translates to:
  /// **'Dining Out'**
  String get catDining;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get catHousing;

  /// No description provided for @catUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get catUtilities;

  /// No description provided for @catEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get catEntertainment;

  /// No description provided for @catShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get catShopping;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get catSubscriptions;

  /// No description provided for @catOtherExpense.
  ///
  /// In en, this message translates to:
  /// **'Other Expense'**
  String get catOtherExpense;

  /// No description provided for @catSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get catSalary;

  /// No description provided for @catFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get catFreelance;

  /// No description provided for @catOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other Income'**
  String get catOtherIncome;

  /// No description provided for @statIncomeMonth.
  ///
  /// In en, this message translates to:
  /// **'Income (mo)'**
  String get statIncomeMonth;

  /// No description provided for @statSpentMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent (mo)'**
  String get statSpentMonth;

  /// No description provided for @statNetMonth.
  ///
  /// In en, this message translates to:
  /// **'Net (mo)'**
  String get statNetMonth;

  /// No description provided for @statYearTotal.
  ///
  /// In en, this message translates to:
  /// **'Spent this year'**
  String get statYearTotal;

  /// No description provided for @chartDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Spending (30d)'**
  String get chartDaily;

  /// No description provided for @chartByCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category (30d)'**
  String get chartByCategory;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet;

  /// No description provided for @addByVoice.
  ///
  /// In en, this message translates to:
  /// **'Add by voice'**
  String get addByVoice;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @searchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions…'**
  String get searchTransactions;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get search;

  /// No description provided for @noTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Add to record your first entry.'**
  String get noTransactionsHint;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction?'**
  String get deleteTransactionTitle;

  /// No description provided for @addFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add: {error}'**
  String addFailed(String error);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update: {error}'**
  String updateFailed(String error);

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @newTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get newTransaction;

  /// No description provided for @checkAndSave.
  ///
  /// In en, this message translates to:
  /// **'Check and save'**
  String get checkAndSave;

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String dateToday(String date);

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {date}'**
  String dateYesterday(String date);

  /// No description provided for @enterPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero, with at most 3 decimals.'**
  String get enterPositiveAmount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get enterAmount;

  /// No description provided for @enterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get enterDescription;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get chooseCategory;

  /// No description provided for @activeBudgets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No active budgets} =1{1 active budget} other{{count} active budgets}}'**
  String activeBudgets(int count);

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get newBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @noBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets set'**
  String get noBudgets;

  /// No description provided for @noBudgetsHint.
  ///
  /// In en, this message translates to:
  /// **'Set a weekly or monthly limit per category to track spending.'**
  String get noBudgetsHint;

  /// No description provided for @deleteBudgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete budget for \"{category}\"?'**
  String deleteBudgetTitle(String category);

  /// No description provided for @deleteBudgetBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the spending limit. Existing transactions are unaffected.'**
  String get deleteBudgetBody;

  /// No description provided for @periodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week · {range}'**
  String periodThisWeek(String range);

  /// No description provided for @periodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month · {month}'**
  String periodThisMonth(String month);

  /// No description provided for @overBudgetBy.
  ///
  /// In en, this message translates to:
  /// **'Over budget by {amount}'**
  String overBudgetBy(String amount);

  /// No description provided for @amountRemaining.
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String amountRemaining(String amount);

  /// No description provided for @weeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit'**
  String get weeklyLimit;

  /// No description provided for @monthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get monthlyLimit;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get freqWeekly;

  /// No description provided for @freqBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Bi-weekly'**
  String get freqBiweekly;

  /// No description provided for @freqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get freqMonthly;

  /// No description provided for @freqQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get freqQuarterly;

  /// No description provided for @freqYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get freqYearly;

  /// No description provided for @recurringCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recurring items} =1{1 recurring item} other{{count} recurring items}}'**
  String recurringCount(int count);

  /// No description provided for @newRecurring.
  ///
  /// In en, this message translates to:
  /// **'New recurring'**
  String get newRecurring;

  /// No description provided for @noRecurring.
  ///
  /// In en, this message translates to:
  /// **'No recurring items'**
  String get noRecurring;

  /// No description provided for @noRecurringHint.
  ///
  /// In en, this message translates to:
  /// **'Add salary, rent, subscriptions, and bills to see what is coming up.'**
  String get noRecurringHint;

  /// No description provided for @postedAsTransaction.
  ///
  /// In en, this message translates to:
  /// **'Posted \"{name}\" as a transaction'**
  String postedAsTransaction(String name);

  /// No description provided for @postFailed.
  ///
  /// In en, this message translates to:
  /// **'Post failed: {error}'**
  String postFailed(String error);

  /// No description provided for @deleteRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'This recurring item will be removed. This cannot be undone.'**
  String get deleteRecurringBody;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @nextDue.
  ///
  /// In en, this message translates to:
  /// **'Next Due'**
  String get nextDue;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @overdueDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Overdue by 1 day} other{Overdue by {days} days}}'**
  String overdueDays(int days);

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Due in 1 day} other{Due in {days} days}}'**
  String dueInDays(int days);

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @postAsTransaction.
  ///
  /// In en, this message translates to:
  /// **'Post as transaction'**
  String get postAsTransaction;

  /// No description provided for @postAsTransactionHint.
  ///
  /// In en, this message translates to:
  /// **'Records it today in Activity'**
  String get postAsTransactionHint;

  /// No description provided for @recurringSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (recurring)'**
  String recurringSuffix(String name);

  /// No description provided for @recurringNote.
  ///
  /// In en, this message translates to:
  /// **'Posted from recurring item \"{name}\"'**
  String recurringNote(String name);

  /// No description provided for @newRecurringItem.
  ///
  /// In en, this message translates to:
  /// **'New recurring item'**
  String get newRecurringItem;

  /// No description provided for @editRecurringItem.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring item'**
  String get editRecurringItem;

  /// No description provided for @firstDueDate.
  ///
  /// In en, this message translates to:
  /// **'First due date'**
  String get firstDueDate;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @showingInList.
  ///
  /// In en, this message translates to:
  /// **'Showing in list'**
  String get showingInList;

  /// No description provided for @hiddenFromList.
  ///
  /// In en, this message translates to:
  /// **'Hidden from list'**
  String get hiddenFromList;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @categoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Income and expense categories'**
  String get categoriesSubtitle;

  /// No description provided for @deleteCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'Transactions tagged with this category will become uncategorized. Budgets for it will be removed. This cannot be undone.'**
  String get deleteCategoryBody;

  /// No description provided for @categoriesShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} categories'**
  String categoriesShown(int shown, int total);

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// No description provided for @noExpenseCategories.
  ///
  /// In en, this message translates to:
  /// **'No expense categories'**
  String get noExpenseCategories;

  /// No description provided for @noIncomeCategories.
  ///
  /// In en, this message translates to:
  /// **'No income categories'**
  String get noIncomeCategories;

  /// No description provided for @noCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Create one to start tagging transactions.'**
  String get noCategoriesHint;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @voiceDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading speech model…'**
  String get voiceDownloading;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get voiceStarting;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice entry'**
  String get voiceTitle;

  /// No description provided for @voiceDownloadNote.
  ///
  /// In en, this message translates to:
  /// **'One-time download, about {mb} MB. After this, voice entry works offline.'**
  String voiceDownloadNote(int mb);

  /// No description provided for @voiceHint.
  ///
  /// In en, this message translates to:
  /// **'Try: \"Spent 3.5 on lunch at Reem\"\n\"Received 500 from Acme yesterday\"'**
  String get voiceHint;

  /// No description provided for @voiceDidntCatch.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t catch that. Tap the mic and try again.'**
  String get voiceDidntCatch;

  /// No description provided for @voiceMicPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is off. Allow it in Settings → Apps → Pocket Sense.'**
  String get voiceMicPermissionOff;

  /// No description provided for @voiceNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition needs a connection on this phone, or an offline English speech pack.'**
  String get voiceNeedsConnection;

  /// No description provided for @voiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition failed ({detail}).'**
  String voiceFailed(String detail);

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available on this phone.'**
  String get voiceUnavailable;

  /// No description provided for @voiceModelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the speech model. Check your connection and try again.'**
  String get voiceModelDownloadFailed;

  /// No description provided for @voiceCouldntStart.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition couldn\'t start ({detail}).'**
  String voiceCouldntStart(String detail);

  /// No description provided for @voiceNeedsParecord.
  ///
  /// In en, this message translates to:
  /// **'Can\'t open the microphone: voice entry needs parecord (from PulseAudio, or PipeWire\'s pulse tools).'**
  String get voiceNeedsParecord;

  /// No description provided for @voiceMicOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the microphone ({detail}).'**
  String voiceMicOpenFailed(String detail);

  /// No description provided for @voiceMicStopped.
  ///
  /// In en, this message translates to:
  /// **'The microphone stopped ({detail}).'**
  String voiceMicStopped(String detail);

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save everything to a JSON file'**
  String get exportDataSubtitle;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything with a backup file'**
  String get importDataSubtitle;

  /// No description provided for @exportWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Export an unencrypted file?'**
  String get exportWarningTitle;

  /// No description provided for @exportWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The backup file is not encrypted. Anyone who opens it can read your finances, so keep it somewhere safe.'**
  String get exportWarningBody;

  /// No description provided for @exportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportAction;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace all data?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everything currently in Pocket Sense is replaced by the backup. This cannot be undone.'**
  String get importConfirmBody;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get importAction;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 record.} other{Restored {count} records.}}'**
  String importDone(int count);

  /// No description provided for @backupNotJson.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t valid JSON, so nothing was changed.'**
  String get backupNotJson;

  /// No description provided for @backupNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Pocket Sense backup, so nothing was changed.'**
  String get backupNotABackup;

  /// No description provided for @backupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup comes from a newer version of Pocket Sense. Update the app, then try again.'**
  String get backupTooNew;

  /// No description provided for @backupWrongCurrency.
  ///
  /// In en, this message translates to:
  /// **'This backup uses another currency ({currency}), so nothing was changed.'**
  String backupWrongCurrency(String currency);

  /// No description provided for @backupBadData.
  ///
  /// In en, this message translates to:
  /// **'The backup contains invalid data, so nothing was changed. ({detail})'**
  String backupBadData(String detail);

  /// No description provided for @backupReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the file: {error}'**
  String backupReadFailed(String error);

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @appLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for a PIN when opening Pocket Sense'**
  String get appLockSubtitle;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face'**
  String get useBiometrics;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get enterPin;

  /// No description provided for @enterCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get enterCurrentPin;

  /// No description provided for @chooseNewPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN (4–6 digits)'**
  String get chooseNewPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get confirmNewPin;

  /// No description provided for @pinsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs don\'t match. Try again.'**
  String get pinsDontMatch;

  /// No description provided for @pinSet.
  ///
  /// In en, this message translates to:
  /// **'App lock is on.'**
  String get pinSet;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed.'**
  String get pinChanged;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'{remaining, plural, =0{Wrong PIN.} =1{Wrong PIN. 1 try left before a wait.} other{Wrong PIN. {remaining} tries left before a wait.}}'**
  String wrongPin(int remaining);

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{Too many wrong PINs. Try again in 1 second.} other{Too many wrong PINs. Try again in {seconds} seconds.}}'**
  String tooManyAttempts(int seconds);

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPin;

  /// No description provided for @forgotPinBody.
  ///
  /// In en, this message translates to:
  /// **'Your PIN can\'t be recovered. The only way back in is to erase all data on this device and start over. If you have a backup file, you can import it afterwards.'**
  String get forgotPinBody;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pocket Sense'**
  String get biometricReason;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get biometricUnlock;

  /// No description provided for @deleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get deleteDigit;

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pocket Sense'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Your finances stay on this device, encrypted. Nothing is uploaded anywhere.'**
  String get welcomeBody;

  /// No description provided for @startFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get startFresh;

  /// No description provided for @startFreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Begin with empty data and starter categories'**
  String get startFreshSubtitle;

  /// No description provided for @importBackupOption.
  ///
  /// In en, this message translates to:
  /// **'Import a backup'**
  String get importBackupOption;

  /// No description provided for @importBackupOptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your data from a Pocket Sense backup file'**
  String get importBackupOptionSubtitle;

  /// No description provided for @backupLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can import or export any time in Settings → Backup.'**
  String get backupLaterHint;

  /// No description provided for @secureTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your data'**
  String get secureTitle;

  /// No description provided for @secureBody.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN so only you can open Pocket Sense.'**
  String get secureBody;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get setPin;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @securityLaterHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings → Security.'**
  String get securityLaterHint;

  /// No description provided for @biometricOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face?'**
  String get biometricOfferTitle;

  /// No description provided for @biometricOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face instead of typing the PIN. The PIN always works too.'**
  String get biometricOfferBody;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
