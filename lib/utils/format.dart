import 'dart:ui' show Color;

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
  Currency('SDG', 'ج.س'), Currency('MRU'), Currency('DJF'), Currency('SOS'), Currency('KMF'), //
  Currency('USD'), Currency('EUR'), Currency('GBP'), Currency('JPY'), Currency('CNY'), Currency('CHF'), //
  Currency('CAD'), Currency('AUD'), Currency('HKD'), Currency('SGD'), Currency('SEK'), Currency('KRW'), //
  Currency('NOK'), Currency('NZD'), Currency('INR'), Currency('MXN'), Currency('TWD'), Currency('ZAR'), //
  Currency('BRL'), Currency('DKK'), Currency('PLN'), Currency('THB'), Currency('IDR'), Currency('CZK'), //
  Currency('TRY'), Currency('HUF'), Currency('CLP'), Currency('PHP'), Currency('MYR'), Currency('RON'), //
  Currency('RUB'), Currency('COP'), Currency('PEN'), Currency('ARS'), Currency('BGN'), Currency('NGN'), //
  Currency('ISK'), Currency('VND'), Currency('PKR'), Currency('BDT'), Currency('UAH'), Currency('KES'), //
  Currency('RSD'), Currency('ALL'), Currency('BAM'), Currency('MKD'), Currency('MDL'), Currency('BYN'),
];

/// What amounts are shown in. AppSettings sets it before the app starts.
Currency appCurrency = currencies.first;

/// Hide amounts: every amount reads ••• (no digits, no sign) until revealed.
/// Set by AmountPrivacy, which also rebuilds the app when it changes.
bool maskAmounts = false;

bool _arabic(String? locale) => (locale ?? Intl.getCurrentLocale()).startsWith('ar');

/// Latin digits in both languages (what banks and shops in the region
/// print), so the pattern always uses 'en' number symbols regardless of the
/// UI language.
final _numbers = <int, NumberFormat>{};
NumberFormat _number(int decimals) =>
    _numbers[decimals] ??= NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}', 'en');

/// "JOD 12.500" in English; "12.500 د.أ" in Arabic. The number sits in a
/// left-to-right isolate so a minus sign stays next to it in RTL text.
/// [showHidden]: real even under Hide amounts, for a form's limits.
String formatMoney(int? fils, {bool showSign = false, String? locale, bool showHidden = false}) {
  if (fils == null) return '—';
  final c = appCurrency;
  // The same ••• for every amount: its length or sign would hint at the value.
  final mask = maskAmounts && !showHidden;
  final sign = mask ? '' : (fils < 0 ? '-' : (showSign ? '+' : ''));
  final n = mask ? '•••' : _number(c.decimals).format(fils.abs() / filsPerDinar);
  return _arabic(locale) ? '\u2066$sign$n\u2069\u00A0${c.arabic ?? c.code}' : '$sign${c.code}\u00A0$n';
}

/// Short axis label without the currency, e.g. "1.5k" or "250".
String compactAmount(double dinars) {
  if (maskAmounts) return '•••';
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

/// [input] with Arabic-Indic and Persian digits, and the Arabic decimal and
/// thousands separators, as their Latin forms; blanks dropped.
String latinDigits(String input) {
  final b = StringBuffer();
  for (final ch in input.trim().split('')) {
    final e = _easternDigits.indexOf(ch), f = _persianDigits.indexOf(ch);
    if (e >= 0) {
      b.write(e);
    } else if (f >= 0) {
      b.write(f);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch == '٬') {
      b.write(',');
    } else if (ch != ' ' && ch != '\u00A0') {
      b.write(ch);
    }
  }
  return b.toString();
}

/// Parses what someone typed into an amount field into fils. Accepts Latin
/// or Arabic-Indic digits, `.` or `٫` as the decimal point, and thousands
/// separators. Returns null for anything else, including more decimals than
/// the currency has, and a comma that isn't between thousands: `12,5` is a
/// decimal comma, which would otherwise read as 125. [decimals] overrides
/// the currency's (a file can hold what was typed in another currency).
int? parseAmount(String input, {int? decimals}) {
  final b = latinDigits(input);
  // A thousands separator follows a digit and comes before exactly three.
  if (b.contains(RegExp(r'(?<!\d),|,(?!\d{3}(?:[,.]|$))'))) return null;
  final m = RegExp('^(\\d*)(?:\\.(\\d{0,${decimals ?? appCurrency.decimals}}))?\$').firstMatch(b.replaceAll(',', ''));
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

/// Today at midnight, local time.
DateTime todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// A stored '#rrggbb' colour, opaque; null for anything else (a category can
/// come from a peer, a backup or a CSV file).
Color? parseHex(String? css) =>
    css != null && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(css) ? Color(int.parse(css.substring(1), radix: 16) | 0xFF000000) : null;
