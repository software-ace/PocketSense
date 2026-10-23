import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart' show currencyFractionDigits;

// Money is stored everywhere as integer thousandths of the main unit, "fils"
// as in 1 JOD = 1000 fils, whatever the currency. Sums never pick up
// floating-point error, and switching currency relabels amounts without
// touching the data.
const filsPerDinar = 1000;

/// A currency amounts can be shown in. One for all of the app's data: no
/// exchange rates, which would need the internet.
class Currency {
  const Currency(this.code, [this.arabic]);

  /// ISO 4217; written before the amount in English: "USD 12.50".
  final String code;

  /// Written after the amount in Arabic, e.g. "د.أ"; the code if null.
  final String? arabic;

  /// Decimal places in everyday use (CLDR, via intl): 3 for JOD, 2 for USD,
  /// 0 for JPY.
  int get decimals => currencyFractionDigits[code] ?? currencyFractionDigits['DEFAULT']!;

  static Currency? byCode(Object? code) => currencies.where((c) => c.code == code).firstOrNull;
}

/// Arab currencies first, then the most used elsewhere. None needs more than
/// 3 decimals, the most a fils amount holds.
const currencies = [
  Currency('JOD', 'د.أ'), Currency('SAR', 'ر.س'), Currency('AED', 'د.إ'), Currency('KWD', 'د.ك'), //
  Currency('QAR', 'ر.ق'), Currency('BHD', 'د.ب'), Currency('OMR', 'ر.ع'), Currency('EGP', 'ج.م'), //
  Currency('IQD', 'د.ع'), Currency('LBP', 'ل.ل'), Currency('SYP', 'ل.س'), Currency('MAD', 'د.م'), //
  Currency('DZD', 'د.ج'), Currency('TND', 'د.ت'), Currency('LYD', 'د.ل'), Currency('YER', 'ر.ي'), //
  Currency('SDG', 'ج.س'), Currency('USD'), Currency('EUR'), Currency('GBP'), Currency('TRY'), //
  Currency('INR'), Currency('PKR'), Currency('CAD'), Currency('AUD'), Currency('CHF'), Currency('JPY'), Currency('CNY'),
];

/// What amounts are shown in. AppSettings sets it before the app starts.
Currency appCurrency = currencies.first;

bool _arabic(String? locale) => (locale ?? Intl.getCurrentLocale()).startsWith('ar');

/// Latin digits in both languages (what banks and shops in the region
/// print), so the pattern always uses 'en' number symbols regardless of the
/// UI language.
final _numbers = <int, NumberFormat>{};
NumberFormat _number(int decimals) =>
    _numbers[decimals] ??= NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}', 'en');

/// "JOD 12.500" in English; "12.500 د.أ" in Arabic. The number sits in a
/// left-to-right isolate so a minus sign stays next to it in RTL text.
String formatMoney(int? fils, {bool showSign = false, String? locale}) {
  if (fils == null) return '—';
  final c = appCurrency;
  final sign = fils < 0 ? '-' : (showSign ? '+' : '');
  final n = _number(c.decimals).format(fils.abs() / filsPerDinar);
  return _arabic(locale) ? '\u2066$sign$n\u2069\u00A0${c.arabic ?? c.code}' : '$sign${c.code}\u00A0$n';
}

/// Short axis label without the currency, e.g. "1.5k" or "250".
String compactAmount(double dinars) {
  String trim(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  return dinars >= 1000 ? '${trim(dinars / 1000)}k' : trim(dinars);
}

/// The currency label for an amount field: a prefix in English, a suffix in
/// Arabic, matching [formatMoney].
({String? prefix, String? suffix}) currencyAffix({String? locale}) => _arabic(locale)
    ? (prefix: null, suffix: ' ${appCurrency.arabic ?? appCurrency.code}')
    : (prefix: '${appCurrency.code} ', suffix: null);

const _easternDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Parses what someone typed into an amount field into fils. Accepts Latin
/// or Arabic-Indic digits, `.` or `٫` as the decimal point, and thousands
/// separators. Returns null for anything else, including more decimals than
/// the currency has.
int? parseAmount(String input) {
  final b = StringBuffer();
  for (final ch in input.trim().split('')) {
    final e = _easternDigits.indexOf(ch), f = _persianDigits.indexOf(ch);
    if (e >= 0) {
      b.write(e);
    } else if (f >= 0) {
      b.write(f);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch != ',' && ch != '٬' && ch != ' ' && ch != '\u00A0') {
      b.write(ch);
    }
  }
  final m = RegExp('^(\\d*)(?:\\.(\\d{0,${appCurrency.decimals}}))?\$').firstMatch(b.toString());
  if (m == null || (m.group(1)!.isEmpty && (m.group(2) ?? '').isEmpty)) return null;
  final whole = m.group(1)!.isEmpty ? 0 : int.parse(m.group(1)!);
  final frac = int.parse((m.group(2) ?? '').padRight(3, '0'));
  return whole * filsPerDinar + frac;
}

/// Pre-fills an amount field: 12500 → "12.5", 12000 → "12".
String amountToInput(int fils) {
  final whole = fils ~/ filsPerDinar;
  final frac = (fils % filsPerDinar).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}

// A skeleton, not a fixed pattern: day/month order and punctuation follow
// the locale (Arabic reads "1 أكتوبر 2026", not "أكتوبر 1, 2026").
String formatDate(DateTime d) => DateFormat.yMMMd().format(d);
