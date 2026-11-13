// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Pocket Sense';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get add => 'إضافة';

  @override
  String get newItem => 'جديد';

  @override
  String get more => 'المزيد';

  @override
  String get done => 'تم';

  @override
  String whatsNewTitle(String version) {
    return 'ما الجديد في $version';
  }

  @override
  String get whatsNewFeatures => 'ميزات جديدة';

  @override
  String get whatsNewImprovements => 'تحسينات';

  @override
  String get whatsNewChanges => 'تغييرات';

  @override
  String get whatsNewFixes => 'إصلاحات';

  @override
  String get all => 'الكل';

  @override
  String get expense => 'مصروف';

  @override
  String get income => 'دخل';

  @override
  String get category => 'الفئة';

  @override
  String get categoryOptional => 'الفئة (اختياري)';

  @override
  String get amount => 'المبلغ';

  @override
  String get date => 'التاريخ';

  @override
  String get description => 'الوصف';

  @override
  String get descriptionOptional => 'الوصف (اختياري)';

  @override
  String get merchant => 'المتجر';

  @override
  String get merchantOptional => 'المتجر (اختياري)';

  @override
  String get merchantSearchHint => 'ابحث عن تاجر أو أنشئه…';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get notesHint => 'أي تفاصيل إضافية…';

  @override
  String get type => 'النوع';

  @override
  String get uncategorized => 'بدون فئة';

  @override
  String get transactionFallback => 'معاملة';

  @override
  String deleteFailed(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String saveFailed(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String deleteNamedTitle(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get couldNotLoad => 'تعذّر التحميل';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navOverview => 'نظرة عامة';

  @override
  String get navActivity => 'الحركات';

  @override
  String get navBudgets => 'الميزانيات';

  @override
  String get navRecurring => 'المتكررة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get startupErrorTitle => 'تعذّر فتح بياناتك';

  @override
  String keyringUnavailable(String detail) {
    return 'حافظة المفاتيح في النظام غير متاحة ($detail). يحتفظ Pocket Sense بمفتاح التشفير فيها. على لينكس، تأكّد من تشغيل موفّر Secret Service مثل GNOME Keyring أو KWallet وفتح قفله.';
  }

  @override
  String keystoreUnavailableAndroid(String detail) {
    return 'لم يستجب مخزن المفاتيح في أندرويد، حيث يحتفظ Pocket Sense بمفتاح التشفير ($detail). لم يُحذف شيء. حاول مرة أخرى، أو أعد تشغيل هاتفك إذا تكرّر ذلك.';
  }

  @override
  String get dbKeyLost =>
      'بياناتك مشفّرة، لكن مفتاحها لم يعد موجودًا في حافظة المفاتيح، لذا لا يمكن فتحها. يمكنك مسحها والبدء من جديد.';

  @override
  String get eraseAllTitle => 'مسح كل البيانات؟';

  @override
  String get eraseAllBody =>
      'سيُحذف كل ما يخزّنه Pocket Sense على هذا الجهاز. لا يمكن التراجع عن ذلك. تحتفظ الأجهزة المتزامنة ببياناتها، وتتوقف عن المزامنة مع هذا الجهاز.';

  @override
  String get erase => 'مسح';

  @override
  String get eraseAndStartOver => 'مسح والبدء من جديد';

  @override
  String get catGroceries => 'بقالة';

  @override
  String get catDining => 'مطاعم';

  @override
  String get catCoffee => 'قهوة';

  @override
  String get catTransport => 'مواصلات';

  @override
  String get catHousing => 'سكن';

  @override
  String get catUtilities => 'فواتير الخدمات';

  @override
  String get catEntertainment => 'ترفيه';

  @override
  String get catShopping => 'تسوّق';

  @override
  String get catHealth => 'صحة';

  @override
  String get catSubscriptions => 'اشتراكات';

  @override
  String get catOtherExpense => 'مصروفات أخرى';

  @override
  String get catSalary => 'راتب';

  @override
  String get catFreelance => 'عمل حر';

  @override
  String get catOtherIncome => 'دخل آخر';

  @override
  String get catLoansPaid => 'ديون مدفوعة';

  @override
  String get catLoansReceived => 'ديون مقبوضة';

  @override
  String get statIncomeMonth => 'الدخل (الشهر)';

  @override
  String get statSpentMonth => 'المصروف (الشهر)';

  @override
  String get statNetMonth => 'الصافي (الشهر)';

  @override
  String get statYearTotal => 'مصروف السنة';

  @override
  String get chartDaily => 'الإنفاق اليومي (30 يومًا)';

  @override
  String get chartByCategory => 'حسب الفئة';

  @override
  String get chartByMerchant => 'حسب المتجر';

  @override
  String get noMerchant => 'بدون متجر';

  @override
  String get otherMerchants => 'أخرى';

  @override
  String get chartMonthly => 'الدخل والإنفاق (6 أشهر)';

  @override
  String get nextYear => 'السنة التالية';

  @override
  String get previousYear => 'السنة السابقة';

  @override
  String get pickMonth => 'اختر الشهر';

  @override
  String get chartMonthTotals => 'الدخل مقابل الإنفاق الشهري';

  @override
  String get chartPace => 'هذا الشهر مقابل الشهر الماضي';

  @override
  String get chartWeekday => 'حسب أيام الأسبوع (المتوسط اليومي لـ 12 أسبوعًا)';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get lastMonth => 'الشهر الماضي';

  @override
  String get recentActivity => 'آخر الحركات';

  @override
  String get homePage => 'الصفحة الرئيسية';

  @override
  String get homePageSubtitle => 'اختر ما تعرضه الرئيسية وترتيبه';

  @override
  String get homePageHint =>
      'اسحب الصف من مقبضه لنقله، وأوقف ما لا تحتاجه في الرئيسية.';

  @override
  String get homeTotals => 'الإجماليات (هذا الشهر والسنة)';

  @override
  String get homeLoansAlwaysShown => 'يظهر دائمًا: منه تدخل إلى الديون';

  @override
  String get noTransactionsYet => 'لا توجد معاملات بعد';

  @override
  String get noData => 'لا توجد بيانات';

  @override
  String get noExpensesYet => 'لا توجد مصروفات بعد';

  @override
  String get addByVoice => 'إضافة بالصوت';

  @override
  String get addTransaction => 'إضافة معاملة';

  @override
  String get searchTransactions => 'ابحث في المعاملات…';

  @override
  String get search => 'بحث…';

  @override
  String get noTransactionsHint => 'اضغط «إضافة» لتسجيل أول معاملة.';

  @override
  String get deleteTransactionTitle => 'حذف المعاملة؟';

  @override
  String addFailed(String error) {
    return 'فشلت الإضافة: $error';
  }

  @override
  String updateFailed(String error) {
    return 'فشل التحديث: $error';
  }

  @override
  String get editTransaction => 'تعديل المعاملة';

  @override
  String get newTransaction => 'معاملة جديدة';

  @override
  String get checkAndSave => 'راجِع واحفظ';

  @override
  String dateToday(String date) {
    return 'اليوم · $date';
  }

  @override
  String dateYesterday(String date) {
    return 'أمس · $date';
  }

  @override
  String enterPositiveAmount(int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'أدخل مبلغًا أكبر من صفر، بـ$decimals منزلة عشرية على الأكثر.',
      many: 'أدخل مبلغًا أكبر من صفر، بـ$decimals منزلة عشرية على الأكثر.',
      few: 'أدخل مبلغًا أكبر من صفر، بـ$decimals منازل عشرية على الأكثر.',
      two: 'أدخل مبلغًا أكبر من صفر، بمنزلتين عشريتين على الأكثر.',
      one: 'أدخل مبلغًا أكبر من صفر، بمنزلة عشرية واحدة على الأكثر.',
      zero: 'أدخل مبلغًا صحيحًا أكبر من صفر، بلا منازل عشرية.',
    );
    return '$_temp0';
  }

  @override
  String get enterAmount => 'أدخل المبلغ';

  @override
  String get enterDescription => 'أدخل وصفًا';

  @override
  String get enterName => 'أدخل اسمًا';

  @override
  String get chooseCategory => 'اختر فئة';

  @override
  String activeBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ميزانية نشطة',
      many: '$count ميزانية نشطة',
      few: '$count ميزانيات نشطة',
      two: 'ميزانيتان نشطتان',
      one: 'ميزانية نشطة واحدة',
      zero: 'لا توجد ميزانيات نشطة',
    );
    return '$_temp0';
  }

  @override
  String get newBudget => 'ميزانية جديدة';

  @override
  String get editBudget => 'تعديل الميزانية';

  @override
  String get noBudgets => 'لا توجد ميزانيات';

  @override
  String get noBudgetsHint =>
      'حدّد سقفًا أسبوعيًا أو شهريًا لكل فئة لمتابعة إنفاقك.';

  @override
  String deleteBudgetTitle(String category) {
    return 'حذف ميزانية «$category»؟';
  }

  @override
  String get deleteBudgetBody =>
      'سيُزال سقف الإنفاق، ولن تتأثر المعاملات الحالية.';

  @override
  String periodThisWeek(String range) {
    return 'هذا الأسبوع · $range';
  }

  @override
  String periodThisMonth(String month) {
    return 'هذا الشهر · $month';
  }

  @override
  String overBudgetBy(String amount) {
    return 'تجاوزت الميزانية بمقدار $amount';
  }

  @override
  String amountRemaining(String amount) {
    return 'المتبقي $amount';
  }

  @override
  String get weeklyLimit => 'السقف الأسبوعي';

  @override
  String get monthlyLimit => 'السقف الشهري';

  @override
  String get freqWeekly => 'أسبوعي';

  @override
  String get freqBiweekly => 'كل أسبوعين';

  @override
  String get freqMonthly => 'شهري';

  @override
  String get freqQuarterly => 'كل ثلاثة أشهر';

  @override
  String get freqYearly => 'سنوي';

  @override
  String recurringCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر متكرر',
      many: '$count عنصرًا متكررًا',
      few: '$count عناصر متكررة',
      two: 'عنصران متكرران',
      one: 'عنصر متكرر واحد',
      zero: 'لا توجد عناصر متكررة',
    );
    return '$_temp0';
  }

  @override
  String get newRecurring => 'عنصر متكرر جديد';

  @override
  String get noRecurring => 'لا توجد عناصر متكررة';

  @override
  String get noRecurringHint =>
      'أضف الراتب والإيجار والاشتراكات والفواتير لترى ما هو قادم.';

  @override
  String postedAsTransaction(String name) {
    return 'سُجّل «$name» كمعاملة';
  }

  @override
  String postFailed(String error) {
    return 'فشل التسجيل: $error';
  }

  @override
  String get deleteRecurringBody =>
      'سيُحذف هذا العنصر المتكرر. لا يمكن التراجع عن ذلك.';

  @override
  String get frequency => 'التكرار';

  @override
  String get nextDue => 'الاستحقاق التالي';

  @override
  String get status => 'الحالة';

  @override
  String overdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر $days يوم',
      many: 'متأخر $days يومًا',
      few: 'متأخر $days أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'مستحق اليوم';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'مستحق بعد $days يوم',
      many: 'مستحق بعد $days يومًا',
      few: 'مستحق بعد $days أيام',
      two: 'مستحق بعد يومين',
      one: 'مستحق بعد يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get inactive => 'غير نشط';

  @override
  String get paused => 'متوقف مؤقتًا';

  @override
  String get postAsTransaction => 'تسجيل كمعاملة';

  @override
  String get postAsTransactionHint => 'يُسجَّل اليوم في الحركات';

  @override
  String recurringSuffix(String name) {
    return '$name (متكرر)';
  }

  @override
  String get newRecurringItem => 'عنصر متكرر جديد';

  @override
  String get editRecurringItem => 'تعديل العنصر المتكرر';

  @override
  String get firstDueDate => 'تاريخ الاستحقاق الأول';

  @override
  String get active => 'نشط';

  @override
  String get showingInList => 'ظاهر في القائمة';

  @override
  String get hiddenFromList => 'مخفي من القائمة';

  @override
  String get categories => 'الفئات';

  @override
  String get categoriesSubtitle => 'فئات الدخل والمصروفات';

  @override
  String get deleteCategoryBody =>
      'ستصبح المعاملات المصنّفة بهذه الفئة بلا فئة، وستُحذف ميزانياتها. لا يمكن التراجع عن ذلك.';

  @override
  String categoriesShown(int shown, int total) {
    return '$shown من أصل $total فئة';
  }

  @override
  String get newCategory => 'فئة جديدة';

  @override
  String get editCategory => 'تعديل الفئة';

  @override
  String get noCategories => 'لا توجد فئات';

  @override
  String get noExpenseCategories => 'لا توجد فئات مصروفات';

  @override
  String get noIncomeCategories => 'لا توجد فئات دخل';

  @override
  String get noCategoriesHint => 'أنشئ فئة لتبدأ بتصنيف معاملاتك.';

  @override
  String get merchants => 'التجار';

  @override
  String get merchantsSubtitle => 'الأسماء التي تتعامل معها';

  @override
  String merchantsShown(int count) {
    return '$count تاجر';
  }

  @override
  String get newMerchant => 'تاجر جديد';

  @override
  String get editMerchant => 'تعديل التاجر';

  @override
  String get noMerchants => 'لا يوجد تجار بعد';

  @override
  String get noMerchantsHint =>
      'أنشئ تاجرًا وسيظهر في اقتراحات نموذج المعاملة.';

  @override
  String get deleteMerchantBody =>
      'يُزال التاجر من القائمة فقط، وتحتفظ معاملاتك السابقة باسمه.';

  @override
  String get merchantNotFound => 'التاجر غير موجود. هل تريد إنشاءه؟';

  @override
  String get createMerchant => 'أنشئه';

  @override
  String get duplicateMerchant => 'هذا التاجر موجود بالفعل';

  @override
  String get name => 'الاسم';

  @override
  String get color => 'اللون';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String themeName(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'system': 'حسب النظام',
      'light': 'فاتح',
      'dark': 'داكن',
      'black': 'أسود (AMOLED)',
      'other': '$theme',
    });
    return '$_temp0';
  }

  @override
  String get currency => 'العملة';

  @override
  String currencyName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'JOD': 'دينار أردني',
      'SAR': 'ريال سعودي',
      'AED': 'درهم إماراتي',
      'KWD': 'دينار كويتي',
      'QAR': 'ريال قطري',
      'BHD': 'دينار بحريني',
      'OMR': 'ريال عماني',
      'EGP': 'جنيه مصري',
      'IQD': 'دينار عراقي',
      'LBP': 'ليرة لبنانية',
      'SYP': 'ليرة سورية',
      'MAD': 'درهم مغربي',
      'DZD': 'دينار جزائري',
      'TND': 'دينار تونسي',
      'LYD': 'دينار ليبي',
      'YER': 'ريال يمني',
      'SDG': 'جنيه سوداني',
      'USD': 'دولار أمريكي',
      'EUR': 'يورو',
      'GBP': 'جنيه إسترليني',
      'TRY': 'ليرة تركية',
      'INR': 'روبية هندية',
      'PKR': 'روبية باكستانية',
      'CAD': 'دولار كندي',
      'AUD': 'دولار أسترالي',
      'CHF': 'فرنك سويسري',
      'JPY': 'ين ياباني',
      'CNY': 'يوان صيني',
      'SEK': 'كرونة سويدية',
      'HKD': 'دولار هونغ كونغ',
      'IDR': 'روبية إندونيسية',
      'MRU': 'أوقية موريتانية',
      'DJF': 'فرنك جيبوتي',
      'SOS': 'شلن صومالي',
      'KMF': 'فرنك قمري',
      'SGD': 'دولار سنغافوري',
      'KRW': 'وون كوري جنوبي',
      'NOK': 'كرونة نرويجية',
      'NZD': 'دولار نيوزيلندي',
      'MXN': 'بيزو مكسيكي',
      'TWD': 'دولار تايواني جديد',
      'ZAR': 'راند جنوب أفريقي',
      'BRL': 'ريال برازيلي',
      'DKK': 'كرونة دنماركية',
      'PLN': 'زلوتي بولندي',
      'THB': 'بات تايلاندي',
      'CZK': 'كرونة تشيكية',
      'HUF': 'فورنت مجري',
      'CLP': 'بيزو تشيلي',
      'PHP': 'بيزو فلبيني',
      'MYR': 'رينغيت ماليزي',
      'RON': 'ليو روماني',
      'RUB': 'روبل روسي',
      'COP': 'بيزو كولومبي',
      'PEN': 'سول بيروفي',
      'ARS': 'بيزو أرجنتيني',
      'BGN': 'ليف بلغاري',
      'NGN': 'نايرا نيجيرية',
      'ISK': 'كرونة آيسلندية',
      'VND': 'دونغ فيتنامي',
      'BDT': 'تاكا بنغلاديشية',
      'UAH': 'هريفنيا أوكرانية',
      'KES': 'شلن كيني',
      'RSD': 'دينار صربي',
      'ALL': 'ليك ألباني',
      'BAM': 'مارك بوسني قابل للتحويل',
      'MKD': 'دينار مقدوني',
      'MDL': 'ليو مولدوفي',
      'BYN': 'روبل بيلاروسي',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get noCurrencyMatches => 'لا توجد عملة مطابقة';

  @override
  String get currencyChangeNote =>
      'لا تُحوَّل المبالغ: يبقى 12.5 كما هو بالعملة الجديدة.';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get voiceDownloading => 'جارٍ تنزيل نموذج الكلام…';

  @override
  String get voiceListening => 'جارٍ الاستماع…';

  @override
  String get voiceStarting => 'جارٍ البدء…';

  @override
  String get voiceTitle => 'الإدخال الصوتي';

  @override
  String voiceDownloadNote(int mb) {
    return 'تنزيل لمرة واحدة، نحو $mb ميغابايت. بعدها يعمل الإدخال الصوتي دون اتصال.';
  }

  @override
  String get voiceHint =>
      'الإدخال الصوتي بالإنجليزية فقط حاليًا. جرّب:\n\"Spent 3.5 on lunch at Reem\"';

  @override
  String get voiceDidntCatch =>
      'لم أتمكّن من فهم ما قلته. اضغط على الميكروفون وحاول مجددًا.';

  @override
  String get voiceMicPermissionOff =>
      'إذن الميكروفون مُعطّل. فعّله من الإعدادات ← التطبيقات ← Pocket Sense.';

  @override
  String get voiceNeedsConnection =>
      'يحتاج التعرّف على الكلام في هذا الهاتف إلى اتصال بالإنترنت، أو إلى حزمة كلام إنجليزية تعمل دون اتصال.';

  @override
  String voiceFailed(String detail) {
    return 'فشل التعرّف على الكلام ($detail).';
  }

  @override
  String get voiceUnavailable => 'التعرّف على الكلام غير متاح على هذا الهاتف.';

  @override
  String get voiceModelDownloadFailed =>
      'تعذّر تنزيل نموذج الكلام. تحقّق من اتصالك وحاول مجددًا.';

  @override
  String voiceCouldntStart(String detail) {
    return 'تعذّر بدء التعرّف على الكلام ($detail).';
  }

  @override
  String get voiceNeedsParecord =>
      'تعذّر فتح الميكروفون: يحتاج الإدخال الصوتي إلى parecord (من PulseAudio أو أدوات pulse في PipeWire).';

  @override
  String voiceMicOpenFailed(String detail) {
    return 'تعذّر فتح الميكروفون ($detail).';
  }

  @override
  String voiceMicStopped(String detail) {
    return 'توقّف الميكروفون ($detail).';
  }

  @override
  String get backup => 'النسخ الاحتياطي';

  @override
  String get exportData => 'تصدير نسخة احتياطية';

  @override
  String get exportDataSubtitle => 'حفظ كل البيانات في ملف مشفّر';

  @override
  String get importData => 'استيراد نسخة احتياطية';

  @override
  String get importDataSubtitle => 'استبدال كل البيانات بملف نسخة احتياطية';

  @override
  String get importTransactions => 'استيراد الحركات';

  @override
  String get importTransactionsSubtitle => 'إضافة حركات من ملف CSV';

  @override
  String get exportTransactions => 'تصدير الحركات';

  @override
  String get exportTransactionsSubtitle =>
      'حفظ كل الحركات في ملف CSV لجداول البيانات. لا تُضمَّن التحويلات بين الحسابات.';

  @override
  String get importCsv => 'استيراد CSV';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String get csvSaved => 'حُفظ ملف CSV.';

  @override
  String get csvCantImportTitle => 'لم يُستورد شيء';

  @override
  String csvMissingColumns(String columns) {
    return 'يجب أن يحتوي الصف الأول على هذه الأعمدة: $columns.';
  }

  @override
  String csvLayoutHint(String columns) {
    return 'صدّر ملفًا أولًا لترى الشكل: الأعمدة $columns، والتاريخ مثل 2026-11-08، والنوع income أو expense، والمبلغ مثل 12.5.';
  }

  @override
  String get csvNotUtf8 =>
      'هذا الملف ليس نصًا بترميز UTF-8. في Excel احفظه بصيغة \"CSV UTF-8\".';

  @override
  String get csvRowsFound => 'صفوف';

  @override
  String get csvWillImport => 'ستُستورد';

  @override
  String get csvDuplicate => 'مكررة';

  @override
  String get csvRejected => 'مرفوضة';

  @override
  String get csvPreviewNote =>
      'لا يُحفظ شيء قبل الاستيراد. تُطابق الفئات بالاسم، والحركة ذات الفئة غير الموجودة لديك تبقى بلا فئة. اضغط رقمًا لعرض تلك الصفوف فقط.';

  @override
  String get csvColDate => 'التاريخ';

  @override
  String get csvColAmount => 'المبلغ';

  @override
  String get csvColDetails => 'التفاصيل';

  @override
  String get csvColStatus => 'الحالة';

  @override
  String get csvNew => 'جديدة';

  @override
  String get csvDuplicateTag => 'مكررة';

  @override
  String get csvRejectedTag => 'مرفوضة';

  @override
  String get csvProblemDate => 'يجب أن يكون التاريخ مثل 2026-11-08.';

  @override
  String get csvProblemType => 'يجب أن يكون النوع income أو expense.';

  @override
  String get csvProblemNoAmount => 'لا مبلغ في عمود المبلغ.';

  @override
  String get csvProblemAmount => 'يجب أن يكون المبلغ رقمًا أكبر من 0.';

  @override
  String get csvProblemDecimalComma => 'استخدم النقطة العشرية: 12.5 وليس 12,5.';

  @override
  String get csvLayoutTitle => 'شكل الملف';

  @override
  String get csvRuleDate => 'date: السنة-الشهر-اليوم، مثل 2026-11-08.';

  @override
  String get csvRuleType => 'type: income أو expense.';

  @override
  String get csvRuleAmount =>
      'amount: أكبر من 0، بنقطة عشرية (12.75). الفاصلة للآلاف فقط (1,250). بلا إشارة سالب: النوع يحدد إن كان إنفاقًا.';

  @override
  String get csvRuleOptional =>
      'يمكن ترك category وmerchant وaccount فارغة: الحساب الفارغ أو غير المعروف يعني حسابك الافتراضي. ترتيب الأعمدة حر، وتُتجاهل الأعمدة الأخرى.';

  @override
  String get csvExample => 'مثال';

  @override
  String get csvNoRowsHere => 'لا صفوف هنا.';

  @override
  String csvImportN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count حركة',
      many: 'استيراد $count حركة',
      few: 'استيراد $count حركات',
      two: 'استيراد حركتين',
      one: 'استيراد حركة واحدة',
      zero: 'لا شيء للاستيراد',
    );
    return '$_temp0';
  }

  @override
  String get importCategories => 'استيراد الفئات';

  @override
  String get importMerchants => 'استيراد المتاجر';

  @override
  String csvImportCategoriesN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count فئة',
      many: 'استيراد $count فئة',
      few: 'استيراد $count فئات',
      two: 'استيراد فئتين',
      one: 'استيراد فئة واحدة',
      zero: 'لا شيء للاستيراد',
    );
    return '$_temp0';
  }

  @override
  String csvImportMerchantsN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استيراد $count متجر',
      many: 'استيراد $count متجرًا',
      few: 'استيراد $count متاجر',
      two: 'استيراد متجرين',
      one: 'استيراد متجر واحد',
      zero: 'لا شيء للاستيراد',
    );
    return '$_temp0';
  }

  @override
  String get csvPreviewNoteNames =>
      'لا يُحفظ شيء قبل الاستيراد. تُتخطّى الأسماء الموجودة لديك بأي حالة أحرف. اضغط رقمًا لعرض تلك الصفوف فقط.';

  @override
  String get csvColName => 'الاسم';

  @override
  String get csvColType => 'النوع';

  @override
  String get csvColColor => 'اللون';

  @override
  String get csvProblemName => 'الاسم فارغ.';

  @override
  String get csvProblemColor => 'يجب أن يكون اللون مثل #4f46e5.';

  @override
  String get csvRuleName => 'name: اسم الفئة، فئة في كل صف.';

  @override
  String get csvRuleColor =>
      'color: اختياري، مثل #4f46e5. بدونه تكون الفئة رمادية.';

  @override
  String get csvRuleMerchant =>
      'name: اسم المتجر، متجر في كل صف. الأسماء ذات المسافات تبقى كاملة.';

  @override
  String get csvSumCategoriesAdded => 'فئات أُضيفت';

  @override
  String get csvSumMerchantsAdded => 'متاجر أُضيفت';

  @override
  String get csvSumAlreadyThere => 'موجودة في قائمتك';

  @override
  String get csvImporting => 'جارٍ الاستيراد…';

  @override
  String csvImportingDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف. تُتخطّى المكررة والمرفوضة.',
      many: '$count صفًا. تُتخطّى المكررة والمرفوضة.',
      few: '$count صفوف. تُتخطّى المكررة والمرفوضة.',
      two: 'صفان. تُتخطّى المكررة والمرفوضة.',
      one: 'صف واحد. تُتخطّى المكررة والمرفوضة.',
    );
    return '$_temp0';
  }

  @override
  String get csvImportComplete => 'اكتمل الاستيراد';

  @override
  String get csvImportCompleteBody =>
      'حُفظت حركاتك وشُفّرت مثل كل شيء آخر في Pocket Sense.';

  @override
  String get csvSumAdded => 'حركات أُضيفت';

  @override
  String get csvSumDuplicates => 'تُخطّيت لأنها مكررة';

  @override
  String get csvSumRejected => 'صفوف مرفوضة';

  @override
  String get csvSumCategories => 'فئات طُوبقت';

  @override
  String get csvSumMerchants => 'متاجر جديدة حُفظت';

  @override
  String get csvSumUncategorized => 'صفوف بلا فئة';

  @override
  String get exportDone => 'حُفظت النسخة الاحتياطية.';

  @override
  String exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get importConfirmTitle => 'استبدال كل البيانات؟';

  @override
  String get importConfirmBody =>
      'سيُستبدل كل ما في Pocket Sense حاليًا بمحتوى النسخة الاحتياطية. لا يمكن التراجع عن ذلك.';

  @override
  String get importAction => 'استبدال';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استُعيد $count سجل.',
      many: 'استُعيد $count سجلًا.',
      few: 'استُعيدت $count سجلات.',
      two: 'استُعيد سجلان.',
      one: 'استُعيد سجل واحد.',
      zero: 'لم يُستعد أي سجل.',
    );
    return '$_temp0';
  }

  @override
  String get backupNotJson =>
      'هذا الملف ليس بصيغة JSON صحيحة، لذا لم يتغيّر شيء.';

  @override
  String get backupNotABackup =>
      'هذا الملف ليس نسخة احتياطية من Pocket Sense، لذا لم يتغيّر شيء.';

  @override
  String get backupTooNew =>
      'هذه النسخة الاحتياطية من إصدار أحدث من Pocket Sense. حدّث التطبيق ثم حاول مجددًا.';

  @override
  String backupWrongCurrency(String currency) {
    return 'تستخدم هذه النسخة الاحتياطية عملة لا يدعمها Pocket Sense ($currency)، لذا لم يتغيّر شيء.';
  }

  @override
  String backupBadData(String detail) {
    return 'تحتوي النسخة الاحتياطية على بيانات غير صالحة، لذا لم يتغيّر شيء. ($detail)';
  }

  @override
  String backupReadFailed(String error) {
    return 'تعذّرت قراءة الملف: $error';
  }

  @override
  String get backupPassword => 'كلمة مرور النسخ الاحتياطي';

  @override
  String get backupPasswordSubtitle => 'تشفّر ملفات النسخ الاحتياطي';

  @override
  String get chooseBackupPassword => 'اختر كلمة مرور للنسخ الاحتياطي';

  @override
  String get backupPasswordWarning =>
      'تُشفَّر النسخ الاحتياطية بكلمة المرور هذه. يتذكّرها Pocket Sense على هذا الجهاز، لكنك ستحتاجها لاستعادة نسخة على أي جهاز آخر. إن نسيتها فلن يمكن فتح نسخك الاحتياطية.';

  @override
  String get backupPasswordChangeNote =>
      'النسخ التي أنشأتها سابقًا تبقى بكلمة المرور التي أُنشئت بها.';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get repeatPasswordLabel => 'أعد كتابة كلمة المرور';

  @override
  String passwordTooShort(int min) {
    return 'استخدم $min أحرف على الأقل';
  }

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get backupPasswordSaved => 'حُفظت كلمة مرور النسخ الاحتياطي.';

  @override
  String get encryptedBackupTitle => 'هذه النسخة الاحتياطية مشفّرة';

  @override
  String get encryptedBackupBody => 'أدخل كلمة المرور التي أُنشئت بها.';

  @override
  String get backupWrongPassword =>
      'كلمة المرور خاطئة أو الملف تالف. لم يتغيّر شيء.';

  @override
  String get preparingBackup => 'جارٍ تشفير النسخة الاحتياطية…';

  @override
  String get unlock => 'فتح';

  @override
  String get autoBackup => 'النسخ الاحتياطي التلقائي';

  @override
  String get autoBackupOff => 'متوقف';

  @override
  String autoBackupOn(String folder) {
    return 'يوميًا، إلى $folder';
  }

  @override
  String autoBackupLast(String date) {
    return 'آخر نسخة: $date';
  }

  @override
  String autoBackupFailed(String error) {
    return 'فشل آخر نسخ احتياطي تلقائي: $error';
  }

  @override
  String get autoBackupFolderUnusable =>
      'لا يستطيع Pocket Sense الكتابة في هذا المجلد. على Android، اختر مجلدًا داخل Documents أو Download.';

  @override
  String get security => 'الأمان';

  @override
  String get appLock => 'قفل التطبيق';

  @override
  String get appLockSubtitle => 'طلب رمز PIN عند فتح Pocket Sense';

  @override
  String get changePin => 'تغيير رمز PIN';

  @override
  String get useBiometrics => 'الفتح بالبصمة أو الوجه';

  @override
  String get hideAmounts => 'إخفاء المبالغ';

  @override
  String get hideAmountsSubtitle => 'عرض ••• بدل كل مبلغ حتى تضغط على العين';

  @override
  String get showAmounts => 'إظهار المبالغ';

  @override
  String get privateScreen => 'شاشة خاصة';

  @override
  String get privateScreenSubtitle =>
      'إخفاء Pocket Sense في التطبيقات الأخيرة، ومنع لقطات الشاشة وتسجيلها';

  @override
  String get enterPin => 'أدخل رمز PIN';

  @override
  String get enterCurrentPin => 'أدخل رمز PIN الحالي';

  @override
  String get chooseNewPin => 'اختر رمز PIN (من 4 إلى 6 أرقام)';

  @override
  String get confirmNewPin => 'أدخل الرمز مرة أخرى';

  @override
  String get pinsDontMatch => 'الرمزان غير متطابقين. حاول مرة أخرى.';

  @override
  String get pinSet => 'قفل التطبيق مُفعّل.';

  @override
  String get pinChanged => 'تم تغيير رمز PIN.';

  @override
  String wrongPin(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'رمز خاطئ. بقيت $remaining محاولة قبل الانتظار.',
      many: 'رمز خاطئ. بقيت $remaining محاولة قبل الانتظار.',
      few: 'رمز خاطئ. بقيت $remaining محاولات قبل الانتظار.',
      two: 'رمز خاطئ. بقيت محاولتان قبل الانتظار.',
      one: 'رمز خاطئ. بقيت محاولة واحدة قبل الانتظار.',
      zero: 'رمز خاطئ.',
    );
    return '$_temp0';
  }

  @override
  String tooManyAttempts(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'محاولات خاطئة كثيرة. حاول مجددًا بعد $seconds ثانية.',
      many: 'محاولات خاطئة كثيرة. حاول مجددًا بعد $seconds ثانية.',
      few: 'محاولات خاطئة كثيرة. حاول مجددًا بعد $seconds ثوانٍ.',
      two: 'محاولات خاطئة كثيرة. حاول مجددًا بعد ثانيتين.',
      one: 'محاولات خاطئة كثيرة. حاول مجددًا بعد ثانية واحدة.',
    );
    return '$_temp0';
  }

  @override
  String get continueAction => 'متابعة';

  @override
  String get forgotPin => 'نسيت الرمز؟';

  @override
  String get forgotPinBody =>
      'لا يمكن استعادة رمز PIN. الطريقة الوحيدة للدخول هي مسح كل البيانات على هذا الجهاز والبدء من جديد. إذا كان لديك ملف نسخة احتياطية، يمكنك استيراده بعد ذلك.';

  @override
  String get biometricReason => 'افتح Pocket Sense';

  @override
  String get biometricUnlock => 'استخدام البصمة أو الوجه';

  @override
  String get deleteDigit => 'حذف رقم';

  @override
  String onboardingStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get welcomeTitle => 'مرحبًا بك في Pocket Sense';

  @override
  String get welcomeBody =>
      'تبقى بياناتك المالية على هذا الجهاز، مشفّرة. لا يُرفع أي شيء إلى أي مكان.';

  @override
  String get startFresh => 'البدء من جديد';

  @override
  String get startFreshSubtitle => 'ابدأ ببيانات فارغة وفئات جاهزة';

  @override
  String get importBackupOption => 'استيراد نسخة احتياطية';

  @override
  String get importBackupOptionSubtitle =>
      'استعِد بياناتك من ملف نسخة احتياطية من Pocket Sense';

  @override
  String get backupLaterHint =>
      'يمكنك الاستيراد أو التصدير في أي وقت من الإعدادات ← النسخ الاحتياطي.';

  @override
  String get secureTitle => 'احمِ بياناتك';

  @override
  String get secureBody => 'عيّن رمز PIN حتى لا يفتح Pocket Sense أحد غيرك.';

  @override
  String get setPin => 'تعيين رمز PIN';

  @override
  String get skipForNow => 'تخطَّ الآن';

  @override
  String get securityLaterHint =>
      'يمكنك تغيير ذلك في أي وقت من الإعدادات ← الأمان.';

  @override
  String get biometricOfferTitle => 'الفتح بالبصمة أو الوجه؟';

  @override
  String get biometricOfferBody =>
      'استخدم بصمتك أو وجهك بدل كتابة الرمز. سيبقى الرمز يعمل دائمًا.';

  @override
  String get turnOn => 'تفعيل';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get about => 'حول التطبيق';

  @override
  String get sponsor => 'ادعم Pocket Sense';

  @override
  String get sponsorSubtitle => 'ادعم تطويره عبر GitHub Sponsors';

  @override
  String get aboutDescription =>
      'متتبّع مالي شخصي خاص يعمل دون اتصال. تبقى بياناتك مشفّرة على جهازك.';

  @override
  String get aboutLegalese =>
      '© 2026 software-ace\nبرمجيات حرة بموجب رخصة GNU GPL الإصدار 3 أو أحدث.';

  @override
  String get syncSection => 'المزامنة';

  @override
  String get syncToggle => 'المزامنة مع أجهزتك الأخرى';

  @override
  String get syncToggleSubtitle =>
      'يُبقي Pocket Sense متطابقاً على أجهزتك عبر شبكة Wi-Fi الخاصة بك. لا يمرّ شيء عبر الإنترنت.';

  @override
  String get syncDeviceName => 'اسم هذا الجهاز';

  @override
  String get syncDeviceNameHint => 'تعرف أجهزتك الأخرى هذا الجهاز بهذا الاسم';

  @override
  String get syncPairDevice => 'إقران جهاز';

  @override
  String get syncPairDeviceSubtitle =>
      'افتح هذه الشاشة على الجهازين، على شبكة Wi-Fi نفسها';

  @override
  String syncVisibleAs(String name) {
    return 'تراه الأجهزة الأخرى باسم $name';
  }

  @override
  String get syncPairHelp =>
      'افتح الإعدادات ← المزامنة ← إقران جهاز على جهازك الآخر أيضاً، ثم اضغط عليه أدناه.';

  @override
  String get syncLooking => 'جارٍ البحث عن أجهزة…';

  @override
  String get syncNotFoundHint =>
      'لا شيء بعد؟ تأكّد من أن:\n• الجهازين على شبكة Wi-Fi نفسها (شبكات الضيوف تمنع ذلك غالباً)\n• هذه الشاشة مفتوحة على الجهازين\n• على Linux، يسمح الجدار الناري بالمنفذ 47823 (TCP و UDP)';

  @override
  String get syncPairedTag => 'مقترن';

  @override
  String get syncConnecting => 'جارٍ الاتصال…';

  @override
  String get syncCodeTitle => 'تحقّق من الرمز';

  @override
  String syncCodeBody(String name) {
    return 'تأكّد أن $name يعرض الرمز نفسه:';
  }

  @override
  String syncIncomingTitle(String name) {
    return '$name يريد الإقران';
  }

  @override
  String get syncCodesMatch => 'الرمزان متطابقان';

  @override
  String get syncCodesDiffer => 'غير متطابقين';

  @override
  String syncWaitingFor(String name) {
    return 'بانتظار تأكيد $name…';
  }

  @override
  String syncPairedWith(String name) {
    return 'تم الإقران مع $name';
  }

  @override
  String get syncFirstTitle => 'على الجهازين بيانات';

  @override
  String syncFirstBody(String name) {
    return 'هل تريد دمج البيانات، أم استبدال ما على هذا الجهاز ببيانات $name؟';
  }

  @override
  String get syncCombine => 'دمج';

  @override
  String get syncReplace => 'استبدال بيانات هذا الجهاز';

  @override
  String get syncReplaceTitle => 'استبدال بيانات هذا الجهاز؟';

  @override
  String syncReplaceBody(String name) {
    return 'سيُمسح كل ما على هذا الجهاز ويُستبدل ببيانات $name. لا يمكن التراجع عن ذلك، لذا قد ترغب في تصدير نسخة احتياطية أولاً.';
  }

  @override
  String get syncReplaceAction => 'استبدال';

  @override
  String get syncErrUnreachable =>
      'تعذّر الوصول إلى ذلك الجهاز. هل Pocket Sense مفتوح عليه، على شبكة Wi-Fi نفسها؟';

  @override
  String get syncErrDeclined => 'رُفض الإقران، أو استغرق وقتاً طويلاً.';

  @override
  String get syncErrBusy =>
      'ذلك الجهاز يقترن بجهاز آخر. حاول مجدداً بعد لحظات.';

  @override
  String get syncErrVersion =>
      'حدّث Pocket Sense على الجهازين إلى الإصدار نفسه.';

  @override
  String syncErrCurrency(String currency) {
    return 'يستخدم الجهاز الآخر $currency. اختر العملة نفسها على الجهازين من الإعدادات ← عام.';
  }

  @override
  String get syncErrCode => 'أُلغي الإقران.';

  @override
  String syncErrFailed(String detail) {
    return 'تعذّر الإقران: $detail';
  }

  @override
  String syncStateSynced(String when) {
    return 'تمت المزامنة $when';
  }

  @override
  String get syncStateNever => 'لم تتم المزامنة بعد';

  @override
  String get syncStateSyncing => 'جارٍ المزامنة…';

  @override
  String get syncStateUnreachable => 'غير موجود على هذه الشبكة';

  @override
  String get syncStateNeedsUpdate =>
      'حدّث Pocket Sense على الجهازين إلى الإصدار نفسه';

  @override
  String get syncStateOtherCurrency =>
      'يستخدم عملة أخرى: اختر العملة نفسها على الجهازين';

  @override
  String get syncStateNotPaired =>
      'لم يعد ذلك الجهاز مقترناً بهذا الجهاز. ألغِ إقرانه هنا، ثم أقرنهما من جديد.';

  @override
  String get syncStateFailed => 'فشلت آخر مزامنة';

  @override
  String syncLastSeen(String state, String when) {
    return '$state · آخر مزامنة $when';
  }

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get syncUnpair => 'إلغاء الإقران';

  @override
  String syncUnpairTitle(String name) {
    return 'إلغاء إقران $name؟';
  }

  @override
  String get syncUnpairBody =>
      'تبقى البيانات على الجهازين، لكنهما يتوقفان عن مشاركة التغييرات.';

  @override
  String syncArrived(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير',
      many: '$count تغييراً',
      few: '$count تغييرات',
      two: 'تغييران',
      one: 'تغيير واحد',
    );
    return '$_temp0 من $name';
  }

  @override
  String get importConfirmSynced =>
      'ستحصل أجهزتك المتزامنة على البيانات نفسها عند مزامنتها التالية.';

  @override
  String syncStartFailed(String detail) {
    return 'تعذّر بدء المزامنة: $detail';
  }

  @override
  String get loans => 'الديون';

  @override
  String get owedToYou => 'مستحق لك';

  @override
  String get youOwe => 'عليك';

  @override
  String get owesYou => 'مدين لك';

  @override
  String get loanEven => 'متعادلان';

  @override
  String get loansUnsettled => 'غير مسدَّدة';

  @override
  String get loansSettled => 'مسدَّدة';

  @override
  String get newLoan => 'دين جديد';

  @override
  String get editLoan => 'تعديل الدين';

  @override
  String get loanTitle => 'الدين';

  @override
  String get iLent => 'أقرضت';

  @override
  String get iBorrowed => 'اقترضت';

  @override
  String get loanPerson => 'الشخص';

  @override
  String get enterPerson => 'أدخل اسمًا';

  @override
  String get dueDateOptional => 'تاريخ الاستحقاق (اختياري)';

  @override
  String get clearDueDate => 'إزالة تاريخ الاستحقاق';

  @override
  String dueOn(String date) {
    return 'يستحق في $date';
  }

  @override
  String overdueSince(String date) {
    return 'متأخر · كان مستحقًا في $date';
  }

  @override
  String lentOn(String date) {
    return 'أقرضت · $date';
  }

  @override
  String borrowedOn(String date) {
    return 'اقترضت · $date';
  }

  @override
  String youLentPerson(String name) {
    return 'أقرضت $name';
  }

  @override
  String youBorrowedFrom(String name) {
    return 'اقترضت من $name';
  }

  @override
  String amountRepaid(String amount) {
    return 'سُدِّد $amount';
  }

  @override
  String amountLeft(String amount) {
    return 'المتبقي $amount';
  }

  @override
  String get repayments => 'الدفعات';

  @override
  String get noRepaymentsYet => 'لا دفعات بعد';

  @override
  String get recordRepayment => 'تسجيل دفعة';

  @override
  String get settleLoan => 'تسوية';

  @override
  String get settleLoanTitle => 'تسوية هذا الدين؟';

  @override
  String settleLentBody(String person, String amount) {
    return 'سيُسجَّل أن $person سدّد المتبقي $amount اليوم، ويُضاف ذلك إلى الحركات، ويُغلق الدين.';
  }

  @override
  String settleBorrowedBody(String person, String amount) {
    return 'سيُسجَّل أنك دفعت إلى $person المتبقي $amount اليوم، ويُضاف ذلك إلى الحركات، ويُغلق الدين.';
  }

  @override
  String repayUpTo(String amount) {
    return 'حتى $amount';
  }

  @override
  String amountAtMost(String amount) {
    return '$amount على الأكثر، وهو المتبقي';
  }

  @override
  String amountAtLeastRepaid(String amount) {
    return '$amount على الأقل، فهذا ما سُدِّد';
  }

  @override
  String get deleteLoanTitle => 'حذف هذا الدين؟';

  @override
  String deleteLoanBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يُحذف $count قيد له في الحركات أيضًا.',
      many: 'يُحذف $count قيدًا له في الحركات أيضًا.',
      few: 'تُحذف قيوده الـ$count في الحركات أيضًا.',
      two: 'يُحذف قيداه في الحركات أيضًا.',
      one: 'يُحذف قيده في الحركات أيضًا.',
      zero: 'ليس له قيود في الحركات.',
    );
    return '$_temp0';
  }

  @override
  String get noLoansYet => 'لا ديون بعد';

  @override
  String get noLoansHint => 'يظهر هنا ما تقرضه أو تقترضه، وما بقي منه.';

  @override
  String get noSettledLoans => 'لا ديون مسدَّدة';

  @override
  String get noOpenLoans => 'لا شيء مستحق لك أو عليك';

  @override
  String loanPaymentFor(String person) {
    return 'دفعة إلى $person';
  }

  @override
  String loanPaymentFrom(String person) {
    return 'دفعة من $person';
  }

  @override
  String get reminder => 'تذكير';

  @override
  String get reminderOff => 'إيقاف';

  @override
  String get reminderSameDayDueTime => 'في نفس اليوم وقت الاستحقاق';

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'قبل $days يوم',
      many: 'قبل $days يومًا',
      few: 'قبل $days أيام',
      two: 'قبل يومين',
      one: 'قبل يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get reminderWeekBefore => 'قبل أسبوع';

  @override
  String get dueTime => 'وقت الاستحقاق';

  @override
  String get reminderPermissionOff =>
      'الإشعارات متوقفة لتطبيق Pocket Sense، لذا لن تظهر التذكيرات. فعّلها من إعدادات أندرويد ← التطبيقات ← Pocket Sense ← الإشعارات.';

  @override
  String get reminderBackgroundNote =>
      'لتصلك التذكيرات، اسمح لتطبيق Pocket Sense بالتشغيل التلقائي وبالعمل دون قيود على البطارية.';

  @override
  String get reminderOpenSettings => 'فتح الإعدادات';

  @override
  String get reminderDesktopNote =>
      'تظهر التذكيرات أثناء فتح Pocket Sense، وتظهر الفائتة منها عند فتحه.';

  @override
  String get reminderTitle => 'تذكير بالدفع';

  @override
  String get reminderChannel => 'التذكيرات';

  @override
  String get reminderOpen => 'فتح';

  @override
  String get reminderCreate => 'إنشاء معاملة';

  @override
  String get reminderDismiss => 'تجاهل';

  @override
  String reminderWhen(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'مستحق بعد $days يوم',
      many: 'مستحق بعد $days يومًا',
      few: 'مستحق بعد $days أيام',
      two: 'مستحق بعد يومين',
      one: 'مستحق غدًا',
      zero: 'مستحق اليوم',
    );
    return '$_temp0';
  }

  @override
  String reminderLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر $days يوم',
      many: 'متأخر $days يومًا',
      few: 'متأخر $days أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String reminderRecurring(String name, String when) {
    return '$name $when. راجع المتكررة.';
  }

  @override
  String reminderRecurringAmount(String name, String amount, String when) {
    return '$name ($amount) $when. راجع المتكررة.';
  }

  @override
  String reminderLoan(String person, String when) {
    return 'قرضك مع $person $when.';
  }

  @override
  String reminderLent(String person, String amount, String when) {
    return '$person مدين لك بـ $amount، $when.';
  }

  @override
  String reminderBorrowed(String person, String amount, String when) {
    return 'أنت مدين لـ $person بـ $amount، $when.';
  }

  @override
  String get reminderAmounts => 'المبالغ في التذكيرات';

  @override
  String get reminderAmountsSubtitle =>
      'عرض المبالغ في إشعارات تذكير المتكررة والقروض';

  @override
  String get cashAccount => 'نقد';

  @override
  String get account => 'الحساب';

  @override
  String get accounts => 'الحسابات';

  @override
  String get accountsSubtitle =>
      'أضف حساباتك النقدية والبنكية والادخارية وبطاقاتك، أو أعد تسميتها أو أغلقها أو احذفها';

  @override
  String accountClosedName(String name) {
    return '$name (مغلق)';
  }

  @override
  String accountKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'bank': 'بنك',
      'savings': 'ادخار',
      'card': 'بطاقة',
      'other': 'نقد',
    });
    return '$_temp0';
  }

  @override
  String accountEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حركة',
      many: '$count حركة',
      few: '$count حركات',
      two: 'حركتان',
      one: 'حركة واحدة',
      zero: 'لا حركات',
    );
    return '$_temp0';
  }

  @override
  String get totalBalance => 'الرصيد الإجمالي';

  @override
  String get balance => 'الرصيد';

  @override
  String get transfer => 'تحويل';

  @override
  String get editTransfer => 'تعديل التحويل';

  @override
  String get transferFrom => 'من';

  @override
  String get transferTo => 'إلى';

  @override
  String get transferSwap => 'تبديل من وإلى';

  @override
  String get transferSame => 'اختر حسابين مختلفين.';

  @override
  String get transferAfter => 'بعد هذا التحويل';

  @override
  String get transferNotIncome =>
      'التحويل بين حساباتك ليس دخلًا ولا إنفاقًا: تبقى المجاميع والمخططات والميزانيات كما هي.';

  @override
  String transferBelowZero(String name) {
    return 'هذا يجعل رصيد $name أقل من صفر. يمكنك المتابعة مع ذلك.';
  }

  @override
  String transferToAccount(String name) {
    return 'إلى $name';
  }

  @override
  String transferFromAccount(String name) {
    return 'من $name';
  }

  @override
  String get deleteTransfer => 'حذف التحويل';

  @override
  String get manageAccounts => 'إدارة';

  @override
  String get accountGone => 'حُذف هذا الحساب.';

  @override
  String get incomeThisMonth => 'الوارد هذا الشهر';

  @override
  String get spentThisMonth => 'الصادر هذا الشهر';

  @override
  String get addEntry => 'إضافة حركة';

  @override
  String get openingBalance => 'الرصيد الافتتاحي';

  @override
  String get openingBalanceHint =>
      'ما فيه اليوم، ولا يُحسب دخلًا. لبطاقة عليك دين، ابدأ بإشارة سالب: -120.';

  @override
  String get defaultBadge => 'افتراضي';

  @override
  String get newAccount => 'حساب جديد';

  @override
  String get editAccount => 'تعديل الحساب';

  @override
  String get accountName => 'الاسم';

  @override
  String get accountKindLabel => 'النوع';

  @override
  String get useForNewEntries => 'استخدامه للحركات الجديدة';

  @override
  String get useForNewEntriesHint => 'لتغييره، فعّله لحساب آخر';

  @override
  String closedAccounts(int count) {
    return 'المغلقة · $count';
  }

  @override
  String get reopen => 'إعادة فتح';

  @override
  String get closedAccountsNote =>
      'تحتفظ الحسابات المغلقة بسجلها، فلا تتغير المخططات والمجاميع السابقة. وتختفي من الرئيسية وقوائم اختيار الحساب والتحويل.';

  @override
  String get lastAccountNote =>
      'يلزم حساب مفتوح واحد على الأقل، لذا يبقى هذا الحساب.';

  @override
  String get closeAccount => 'إغلاق الحساب';

  @override
  String get closeAccountHint =>
      'يحتفظ بسجله، ويختفي من الرئيسية وقوائم الاختيار والتحويل.';

  @override
  String closeAccountTitle(String name) {
    return 'إغلاق $name؟';
  }

  @override
  String closeAccountMoney(String name, String amount) {
    return 'ما زال في $name مبلغ $amount. يُنقل، كتحويل، إلى:';
  }

  @override
  String closeAccountOwes(String name, String amount) {
    return 'على $name دين $amount. يُسدّد، كتحويل، من:';
  }

  @override
  String closeAccountRecurring(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وتنتقل إليه حركاته المتكررة الـ$count أيضًا.',
      many: 'وتنتقل إليه حركاته المتكررة الـ$count أيضًا.',
      few: 'وتنتقل إليه حركاته المتكررة الـ$count أيضًا.',
      two: 'وتنتقل إليه حركتاه المتكررتان أيضًا.',
      one: 'وتنتقل إليه حركته المتكررة أيضًا.',
    );
    return '$_temp0';
  }

  @override
  String get closeAccountKeeps =>
      'تبقى حركاته في سجلك ومخططاتك، ويمكنك إعادة فتحه من الإعدادات ← الحسابات.';

  @override
  String get closeAccountConfirm => 'إغلاق';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String deleteAccountTitle(String name) {
    return 'حذف $name؟';
  }

  @override
  String deleteAccountBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'لا يُحذف شيء مما فيه: تُنقل حركاته الـ$count وتحويلاته ورصيده الافتتاحي إلى:',
      many:
          'لا يُحذف شيء مما فيه: تُنقل حركاته الـ$count وتحويلاته ورصيده الافتتاحي إلى:',
      few:
          'لا يُحذف شيء مما فيه: تُنقل حركاته الـ$count وتحويلاته ورصيده الافتتاحي إلى:',
      two: 'لا يُحذف شيء مما فيه: تُنقل حركتاه وتحويلاته ورصيده الافتتاحي إلى:',
      one: 'لا يُحذف شيء مما فيه: تُنقل حركته وتحويلاته ورصيده الافتتاحي إلى:',
      zero: 'لا يُحذف شيء مما فيه: تُنقل تحويلاته ورصيده الافتتاحي إلى:',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountNoUndo =>
      'لا يمكن التراجع عن هذا، هنا أو على أجهزتك المقترنة. توقفت عن استخدامه فقط؟ أغلقه بدلًا من ذلك.';

  @override
  String get deleteAccountConfirm => 'نقل وحذف';

  @override
  String becomesDefaultIfDefault(String name) {
    return 'إن كان هذا حسابك الافتراضي، يصبح $name هو الافتراضي.';
  }

  @override
  String get csvSumUnknownAccounts =>
      'صفوف وُضعت في حسابك الافتراضي (الحساب غير موجود)';

  @override
  String get catCirclePayments => 'دفعات الجمعيات';

  @override
  String get catCirclePayouts => 'قبض الجمعيات';

  @override
  String get circles => 'الجمعيات';

  @override
  String get circleTitle => 'جمعية';

  @override
  String get newCircle => 'جمعية جديدة';

  @override
  String get editCircle => 'تعديل الجمعية';

  @override
  String get circleName => 'الاسم';

  @override
  String get enterCircleName => 'أدخل اسمًا';

  @override
  String get circleContribution => 'الدفعة في كل دورة';

  @override
  String get circleRounds => 'عدد المشاركين';

  @override
  String get circleYourTurn => 'دورك (رقم الدورة)';

  @override
  String get circleFirstPayment => 'أول دفعة';

  @override
  String circleRoundsRange(int max) {
    return 'من 2 إلى $max';
  }

  @override
  String circleTurnRange(int rounds) {
    return 'من 1 إلى $rounds';
  }

  @override
  String get noCirclesYet => 'لا جمعيات بعد';

  @override
  String get noCirclesHint =>
      'تابع الجمعيات التي تشارك فيها: ما تدفعه في كل دورة، ومتى يأتي دورك، وما لك وما عليك.';

  @override
  String get noActiveCircles => 'لا جمعيات جارية';

  @override
  String get noFinishedCircles => 'لا جمعيات منتهية';

  @override
  String get circlesActive => 'جارية';

  @override
  String get circlesFinished => 'منتهية';

  @override
  String get circlesOweYou => 'لك عند الجمعيات';

  @override
  String get youOweCircles => 'عليك للجمعيات';

  @override
  String get circleOwesYou => 'لك عند الجمعية';

  @override
  String get youOweCircle => 'عليك للجمعية';

  @override
  String circleRoundOf(int round, int rounds) {
    return 'الدورة $round من $rounds';
  }

  @override
  String circleTerms(String amount, int rounds, String frequency) {
    return '$amount × $rounds · $frequency';
  }

  @override
  String circleTurnOn(String date) {
    return 'دورك: $date';
  }

  @override
  String circlePayoutOf(String amount) {
    return 'قبض $amount';
  }

  @override
  String get circleUpToTurn => 'تدفع حتى دورك';

  @override
  String get circleAfterTurn => 'تدفع بعد دورك';

  @override
  String circlePaid(String amount) {
    return 'دُفع $amount';
  }

  @override
  String get circleSchedule => 'الجدول';

  @override
  String get recordCirclePayment => 'تسجيل دفعة';

  @override
  String get recordCirclePayout => 'تسجيل القبض';

  @override
  String circlePayoutReceived(String amount) {
    return 'تم القبض: $amount';
  }

  @override
  String get deleteCircleTitle => 'حذف هذه الجمعية؟';

  @override
  String circlePaymentTo(String name) {
    return 'دفعة جمعية $name';
  }

  @override
  String circlePayoutFrom(String name) {
    return 'قبض جمعية $name';
  }

  @override
  String reminderCircle(String name, String when) {
    return 'دفعة جمعية $name $when.';
  }

  @override
  String reminderCircleAmount(String name, String amount, String when) {
    return 'دفعة جمعية $name بقيمة $amount $when.';
  }

  @override
  String get homeCirclesAlwaysShown => 'يظهر دائمًا: منه تدخل إلى الجمعيات';

  @override
  String get vaultCreateTitle => 'عيّن عبارة مرور';

  @override
  String get vaultCreateBody =>
      'لا تعمل أي حلقة مفاتيح للنظام (مثل GNOME Keyring أو KWallet)، لذلك يحفظ Pocket Sense مفاتيح التشفير في ملف مقفل بعبارة المرور هذه. ستكتبها في كل مرة تفتح فيها التطبيق. إن نسيتها فلا يمكن استرجاع بياناتك.';

  @override
  String get vaultUnlockTitle => 'أدخل عبارة المرور';

  @override
  String get vaultUnlockBody =>
      'يحفظ Pocket Sense مفاتيح التشفير في ملف مقفل بعبارة المرور، لأنه لم تكن هناك حلقة مفاتيح للنظام عند إعداده.';

  @override
  String get vaultPassphrase => 'عبارة المرور';

  @override
  String get vaultRepeat => 'أعد كتابة عبارة المرور';

  @override
  String get vaultMismatch => 'عبارتا المرور غير متطابقتين';

  @override
  String get vaultWrong => 'عبارة المرور غير صحيحة';

  @override
  String get vaultForgot => 'نسيت عبارة المرور؟';

  @override
  String get vaultForgotBody =>
      'لا يمكن فتح بياناتك دون عبارة المرور. هل تريد مسحها والبدء من جديد بعبارة مرور جديدة؟ يمكنك استيراد نسخة احتياطية بعد ذلك.';

  @override
  String circleNextReminder(String time) {
    return 'تذكير دفعتك القادمة بعد: $time';
  }

  @override
  String countdownDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String countdownHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String countdownMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String countdownSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get countdownSeparator => '، ';

  @override
  String nextReminderIn(String time) {
    return 'تذكيرك القادم بعد: $time';
  }
}
