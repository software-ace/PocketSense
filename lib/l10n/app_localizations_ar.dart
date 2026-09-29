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
  String get dbKeyLost =>
      'بياناتك مشفّرة، لكن مفتاحها لم يعد موجودًا في حافظة المفاتيح، لذا لا يمكن فتحها. يمكنك مسحها والبدء من جديد.';

  @override
  String get eraseAllTitle => 'مسح كل البيانات؟';

  @override
  String get eraseAllBody =>
      'سيُحذف كل ما يخزّنه Pocket Sense على هذا الجهاز. لا يمكن التراجع عن ذلك.';

  @override
  String get erase => 'مسح';

  @override
  String get eraseAndStartOver => 'مسح والبدء من جديد';

  @override
  String get catGroceries => 'بقالة';

  @override
  String get catDining => 'مطاعم';

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
  String get chartByCategory => 'حسب الفئة (30 يومًا)';

  @override
  String get recentActivity => 'آخر الحركات';

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
  String get enterPositiveAmount =>
      'أدخل مبلغًا أكبر من صفر، بثلاث منازل عشرية على الأكثر.';

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
  String recurringNote(String name) {
    return 'سُجّل من العنصر المتكرر «$name»';
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
}
