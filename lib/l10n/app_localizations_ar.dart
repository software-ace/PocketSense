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

  @override
  String get backup => 'النسخ الاحتياطي';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get exportDataSubtitle => 'حفظ كل البيانات في ملف JSON';

  @override
  String get importData => 'استيراد البيانات';

  @override
  String get importDataSubtitle => 'استبدال كل البيانات بملف نسخة احتياطية';

  @override
  String get exportWarningTitle => 'تصدير ملف غير مشفّر؟';

  @override
  String get exportWarningBody =>
      'ملف النسخة الاحتياطية غير مشفّر، ويستطيع أي شخص يفتحه الاطلاع على بياناتك المالية، لذا احفظه في مكان آمن.';

  @override
  String get exportAction => 'تصدير';

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
    return 'تستخدم هذه النسخة الاحتياطية عملة أخرى ($currency)، لذا لم يتغيّر شيء.';
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
}
